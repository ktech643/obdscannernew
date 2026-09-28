import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/tables.dart';
import 'package:torque_obd2/data/trips/trip_csv.dart';
import 'package:torque_obd2/data/trips/trip_sink.dart';

import '../support.dart';

/// The real file on the other side of a [RandomAccessFile], except that its
/// [failOnWrite]th `writeFrom` does what a full disk does: the OS takes
/// part of the write, then refuses the rest with ENOSPC.
class _FillsUp implements RandomAccessFile {
  _FillsUp(this._real, {required this.failOnWrite, this.errno = 28});
  final RandomAccessFile _real;
  final int failOnWrite;
  final int errno;
  var _writes = 0;

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) async {
    if (++_writes != failOnWrite) {
      await _real.writeFrom(buffer, start, end);
      return this;
    }
    final stop = end ?? buffer.length;
    await _real.writeFrom(buffer, start, start + (stop - start) ~/ 2);
    throw FileSystemException(
      'writeFrom failed',
      _real.path,
      OSError('No space left on device', errno),
    );
  }

  @override
  Future<RandomAccessFile> truncate(int length) async {
    await _real.truncate(length);
    return this;
  }

  @override
  Future<RandomAccessFile> setPosition(int position) async {
    await _real.setPosition(position);
    return this;
  }

  @override
  Future<RandomAccessFile> flush() async {
    await _real.flush();
    return this;
  }

  @override
  Future<int> length() => _real.length();

  @override
  Future<int> position() => _real.position();

  @override
  Future<void> close() => _real.close();

  @override
  String get path => _real.path;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await scratchDir();
    file = File('${dir.path}/trip.csv');
    await file.writeAsString(TripCsv.header);
  });
  tearDown(() => dir.delete(recursive: true));

  String row(int t) => TripCsv.row(t, '010D', 60.0 + t / 1000);

  test('appends whole lines and counts what is committed', () async {
    final sink = await FileTripSink.open(file);
    expect(sink.committed, TripCsv.header.length);
    await sink.append(TripCsv.segment(0, t0));
    await sink.append(row(0) + row(1000));
    await sink.sync();
    await sink.close();
    final text = await file.readAsString();
    expect(
      text,
      '${TripCsv.header}${TripCsv.segment(0, t0)}${row(0)}${row(1000)}',
    );
    expect(sink.committed, text.length);
    await expectLater(sink.append(row(2000)), throwsStateError);
  });

  test('★ storage full rolls back to a whole line', () async {
    // §9.7 "storage full": the third append half-lands, then ENOSPC.
    final sink = await FileTripSink.open(
      file,
      opener: (f) async => _FillsUp(
        await f.open(mode: FileMode.writeOnlyAppend),
        failOnWrite: 3,
      ),
    );
    await sink.append(TripCsv.segment(0, t0));
    await sink.append(row(0) + row(1000));
    final committed = sink.committed;
    final chunk = row(2000) + row(3000) + row(4000);

    Object? failure;
    try {
      await sink.append(chunk);
    } catch (e) {
      failure = e;
    }
    expect(failure, isA<TripWriteFailure>());
    expect((failure! as TripWriteFailure).outOfSpace, isTrue);
    expect(sink.committed, committed);

    final after = await file.readAsString();
    expect(after.length, committed, reason: 'no torn row is left on disk');
    expect(after.endsWith('\n'), isTrue);

    // The sink is still usable at the committed end: the '#end' lands on
    // the next line, with no NUL gap where the half-write was.
    final end = TripCsv.end(
      1000,
      t0.add(const Duration(seconds: 1)),
      TripEnd.storageFull,
    );
    await sink.append(end);
    await sink.sync();
    await sink.close();
    final text = await file.readAsString();
    expect(text.contains('\u0000'), isFalse, reason: 'no NUL gap');
    expect(text, '$after$end');
    final s = TripCsv.summarize(
      text,
      startedAtMs: t0.millisecondsSinceEpoch,
      nowMs: t0.millisecondsSinceEpoch + 60000,
    );
    expect(s.malformed, 0);
    expect(s.rows, 2);
    expect(s.end, TripEnd.storageFull);
  });

  test('another write error is a write failure, not "storage full"', () async {
    final sink = await FileTripSink.open(
      file,
      opener: (f) async => _FillsUp(
        await f.open(mode: FileMode.writeOnlyAppend),
        failOnWrite: 1,
        errno: 5, // EIO
      ),
    );
    await expectLater(
      sink.append(row(0)),
      throwsA(
        isA<TripWriteFailure>().having(
          (e) => e.outOfSpace,
          'out of space',
          false,
        ),
      ),
    );
    await sink.close();
    expect(await file.readAsString(), TripCsv.header);
  });

  test('★ a held handle never re-creates a deleted file', () async {
    // Delete all data, or a vehicle delete, removes the CSV mid-recording.
    // Reopening in append mode for the next write would bring it back as an
    // orphan nothing lists.
    final sink = await FileTripSink.open(file);
    await sink.append(row(0));
    await file.delete();
    await sink.append(row(1000));
    await sink.sync();
    await sink.close();
    expect(await file.exists(), isFalse);
    expect(await dir.list().toList(), isEmpty);
  });

  test('★ open refuses a missing file', () async {
    // An append-mode open would create it: after an erase, a Resume or a
    // late start would leave an orphan behind.
    await file.delete();
    await expectLater(
      FileTripSink.open(file),
      throwsA(isA<FileSystemException>()),
    );
    expect(await file.exists(), isFalse);
  });

  test('★ one file operation at a time', () async {
    // RandomAccessFile throws "An async operation is currently pending" on
    // a second call before the first completes. The recorder's tick and a
    // lifecycle edge can both write without waiting for each other.
    final sink = await FileTripSink.open(file);
    final big = List.generate(2000, (i) => row(i * 100)).join();
    final all = Future.wait([
      sink.append(big),
      sink.append(row(200000)),
      sink.sync(),
      sink.append(row(200100)),
      sink.close(),
    ]);
    await all;
    expect(
      await file.readAsString(),
      '${TripCsv.header}$big${row(200000)}${row(200100)}',
    );
  });

  test(
    'a Resume truncates to the last whole line and continues there',
    () async {
      await file.writeAsString(
        '${row(0)}${row(1000)}12',
        mode: FileMode.append,
      );
      final whole = TripCsv.header.length + row(0).length + row(1000).length;
      final sink = await FileTripSink.open(file, truncateTo: whole);
      expect(sink.committed, whole);
      await sink.append(TripCsv.segment(1000, t0));
      await sink.close();
      expect(
        await file.readAsString(),
        '${TripCsv.header}${row(0)}${row(1000)}${TripCsv.segment(1000, t0)}',
      );
    },
  );
}
