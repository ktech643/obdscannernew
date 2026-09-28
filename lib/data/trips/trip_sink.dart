import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Where a recording's lines go. The recorder appends every second and
/// syncs every fifth; the file behind it is the trip's source of truth.
abstract interface class TripSink {
  /// Bytes known to be whole lines on disk (or in the OS cache, before a
  /// [sync]). A failed append never counts.
  int get committed;

  /// [ascii] must be whole lines. Throws [TripWriteFailure].
  Future<void> append(String ascii);

  /// fsync. Throws [TripWriteFailure].
  Future<void> sync();

  /// Best effort; never throws. A closed sink refuses further writes.
  Future<void> close();
}

/// A write the file refused. The sink has already rolled the file back to
/// [TripSink.committed] and can still take an `#end` line.
class TripWriteFailure implements Exception {
  const TripWriteFailure({required this.outOfSpace, this.cause});

  /// ENOSPC — errno 28 on Darwin and on Linux/Android alike (§9.7 "storage
  /// full"). Anything else is a write that failed for another reason.
  final bool outOfSpace;
  final FileSystemException? cause;

  static const enospc = 28;

  @override
  String toString() =>
      'TripWriteFailure(${outOfSpace ? 'out of space' : 'write failed'}'
      '${cause == null ? '' : ': $cause'})';
}

/// Opens a trip file for appending. The default; tests inject one that
/// fails the way a full disk does.
typedef TripFileOpener = Future<RandomAccessFile> Function(File file);

Future<RandomAccessFile> _openForAppend(File f) =>
    f.open(mode: FileMode.writeOnlyAppend);

/// A [TripSink] on one [RandomAccessFile], held open for the whole segment
/// on the root isolate (§B.31).
///
/// Held, not reopened per write: an append-mode open re-creates a file that
/// is gone, so a recorder that outlived Delete all data or a vehicle delete
/// would leave an orphan CSV behind. A held handle writes into the unlinked
/// inode, and nothing reappears.
///
/// `RandomAccessFile` refuses a second operation while one is pending, so
/// every operation here waits for the one before it: the recorder can fire
/// an append from a tick and a sync from a lifecycle edge without awaiting.
class FileTripSink implements TripSink {
  FileTripSink._(this._raf, this._path, this._committed);

  /// Opens [f], which must exist — [TripRepository.start] creates it with
  /// its header. A [truncateTo] below the file's length cuts it there first:
  /// a Resume continues after the last whole line, not after a torn one.
  static Future<FileTripSink> open(
    File f, {
    int? truncateTo,
    TripFileOpener opener = _openForAppend,
  }) async {
    if (!await f.exists()) {
      throw FileSystemException('The trip file is gone', f.path);
    }
    final raf = await opener(f);
    try {
      var committed = await raf.length();
      if (truncateTo != null && truncateTo < committed) {
        await raf.truncate(truncateTo);
        await raf.setPosition(truncateTo);
        committed = truncateTo;
      }
      return FileTripSink._(raf, f.path, committed);
    } catch (_) {
      try {
        await raf.close();
      } on FileSystemException {
        // The failure that brought us here is the one worth reporting.
      }
      rethrow;
    }
  }

  final RandomAccessFile _raf;
  final String _path;
  int _committed;
  bool _closed = false;
  Future<void> _tail = Future.value();

  @override
  int get committed => _committed;

  @override
  Future<void> append(String ascii) => _then(() async {
    _refuseIfClosed();
    final bytes = const AsciiEncoder().convert(ascii);
    try {
      await _raf.writeFrom(bytes);
    } on FileSystemException catch (e) {
      throw await _rollBack(e);
    }
    _committed += bytes.length;
  });

  @override
  Future<void> sync() => _then(() async {
    _refuseIfClosed();
    try {
      await _raf.flush();
    } on FileSystemException catch (e) {
      throw await _rollBack(e);
    }
  });

  @override
  Future<void> close() => _then(() async {
    if (_closed) return;
    _closed = true;
    try {
      await _raf.close();
    } on FileSystemException {
      // Everything that matters was synced before close; a handle that
      // will not close is not a lost sample.
    }
  });

  /// A full disk can take half a write. Cut the file back to the last
  /// whole line, and put the write position there too: `truncate` alone
  /// leaves the position past the end, and the next write would leave a
  /// run of NUL bytes before it.
  Future<TripWriteFailure> _rollBack(FileSystemException e) async {
    try {
      await _raf.truncate(_committed);
    } on FileSystemException {
      // Best effort: the reader ignores a torn tail anyway.
    }
    try {
      await _raf.setPosition(_committed);
    } on FileSystemException {
      // Best effort, as above.
    }
    return TripWriteFailure(
      outOfSpace: e.osError?.errorCode == TripWriteFailure.enospc,
      cause: e,
    );
  }

  void _refuseIfClosed() {
    if (_closed) throw StateError('The trip file $_path is closed');
  }

  /// Runs [op] after every operation already queued, success or failure,
  /// and hands its own outcome back to its caller alone.
  Future<void> _then(Future<void> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.catchError((Object _) {});
    return next;
  }
}
