import 'dart:io';

import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../ids.dart';
import '../trips/trip_csv.dart';

/// Where trip CSVs live: `<root>/trips/<id>.csv`, and nowhere else.
///
/// [root] is the documents directory, which also holds the database and,
/// later, photos and attachments. A stored path is data — after an import
/// it is *someone else's* data — so the only path this class will ever
/// resolve is the one shape it produces itself. Anything else is refused,
/// and `delete()` can never be pointed at the database file.
class TripFiles {
  TripFiles(this.root);
  final Directory root;

  static const dirName = 'trips';
  static final _shape = RegExp(r'^trips/[0-9a-f]{32}\.csv$');

  static String pathForId(String sessionId) => '$dirName/$sessionId.csv';

  String relativePathFor(String sessionId) => pathForId(sessionId);

  static bool isSafe(String relativePath) => _shape.hasMatch(relativePath);

  Directory get dir =>
      Directory('${root.path}${Platform.pathSeparator}$dirName');

  File resolve(String relativePath) {
    if (!isSafe(relativePath)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must be trips/<id>.csv',
      );
    }
    return File('${root.path}${Platform.pathSeparator}$relativePath');
  }

  /// [resolve], or null for a path that must not be touched.
  File? tryResolve(String relativePath) =>
      isSafe(relativePath) ? resolve(relativePath) : null;

  Future<File> create(String sessionId) async {
    final f = resolve(pathForId(sessionId));
    await f.parent.create(recursive: true);
    return f;
  }

  /// Every CSV in the trips directory, keyed by its relative path.
  Future<Map<String, File>> listAll() async {
    if (!await dir.exists()) return const {};
    final out = <String, File>{};
    await for (final e in dir.list()) {
      if (e is File) {
        final rel = '$dirName/${e.uri.pathSegments.last}';
        if (isSafe(rel)) out[rel] = e;
      }
    }
    return out;
  }
}

/// Trip sessions and their sample files, with the retention SPEC Part 6
/// requires: 30 days, 200 MB, least-recently-used first.
///
/// The recorder writes the CSV (on the root isolate, §B.31); this class
/// owns the rows and the files' lifetime, and reads a file back only
/// through [TripCsv]'s one reader.
///
/// `endedAt IS NULL` is the only marker of a trip still recording —
/// retention keys on it — and at most one row carries it: [start] and
/// [reopen] check inside a transaction, and the partial unique index
/// `idx_trip_one_open` refuses whatever gets past Dart. An open row keeps
/// `fileBytes` at its header's length until [finish]. There are no
/// checkpoints: the file is the source of truth, and after a kill
/// [closeInterrupted] reads the trip's end and figures from it.
class TripRepository {
  TripRepository(this._db, this.files);
  final AppDatabase _db;
  final TripFiles files;

  static const maxAge = Duration(days: 30);
  static const maxBytes = 200 * 1024 * 1024;

  $TripSessionsTable get _t => _db.tripSessions;

  Stream<List<TripSessionRow>> watchRecent(String vehicleId, {int? limit}) {
    final q = _db.select(_t)
      ..where((s) => s.vehicleId.equals(vehicleId))
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Future<List<TripSessionRow>> recent(String vehicleId, {int? limit}) {
    final q = _db.select(_t)
      ..where((s) => s.vehicleId.equals(vehicleId))
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  Future<TripSessionRow?> byId(String id) =>
      (_db.select(_t)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// The trip being recorded, if any.
  Future<TripSessionRow?> openTrip() =>
      (_db.select(_t)
            ..where((s) => s.endedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  /// Where [r]'s samples are. Throws for a path the app never writes.
  File fileOf(TripSessionRow r) => files.resolve(r.samplesFilePath);

  /// Creates the row, then the file with [header], fsynced. The row goes
  /// first: a file without a row is a leak nothing can find, while a row
  /// without a file is visible and cleaned up. If the file can't be written
  /// both go — the file too, which an earlier version left behind with half
  /// a header in it.
  ///
  /// Throws a [StateError] while another trip is recording.
  Future<TripSessionRow> start({
    required String vehicleId,
    String? name,
    String header = TripCsv.header,
    DateTime? now,
  }) async {
    final at = utc(now ?? utcNow());
    final id = newId();
    await _db.transaction(() async {
      if (await openTrip() != null) {
        throw StateError('A trip is already recording');
      }
      await _db
          .into(_t)
          .insert(
            TripSessionsCompanion.insert(
              id: id,
              vehicleId: vehicleId,
              name: Value(name),
              startedAt: at,
              lastOpenedAt: at,
              samplesFilePath: TripFiles.pathForId(id),
              fileBytes: Value(header.length),
            ),
          );
    });
    try {
      final f = await files.create(id);
      await f.writeAsString(header, flush: true);
    } catch (_) {
      await _deleteFile(files.resolve(TripFiles.pathForId(id)));
      await _deleteRow(id);
      rethrow;
    }
    return (await byId(id))!;
  }

  /// Ends the trip with what its file says. [summary] is [TripCsv]'s
  /// reading of that file — the same integrator the strip ran live — so the
  /// row, the strip and a relaunch agree. Every figure is written, nulls
  /// included: a car that sent no fuel rate has no fuel figure. Null when
  /// the row is gone.
  Future<TripSessionRow?> finish(
    String id, {
    required TripEnd end,
    required TripFileSummary summary,
  }) async {
    final row = await byId(id);
    if (row == null) return null;
    final f = files.tryResolve(row.samplesFilePath);
    final bytes = f != null && await f.exists() ? await f.length() : 0;
    final totals = summary.totals;
    await (_db.update(_t)..where((s) => s.id.equals(id))).write(
      TripSessionsCompanion(
        endedAt: Value(utc(summary.endedAtUtc)),
        distanceKm: Value(totals.distanceKm),
        avgSpeedKph: Value(totals.avgSpeedKph),
        maxSpeedKph: Value(totals.maxSpeedKph),
        fuelUsedL: Value(totals.fuelUsedL),
        recordedMs: Value(summary.endT),
        sampleCount: Value(summary.rows),
        fileBytes: Value(bytes),
        interrupted: Value(end.interrupted),
        endReason: Value(end),
      ),
    );
    return byId(id);
  }

  /// "Resume trip?" (§9.2): the same row records again. Only a trip the
  /// app or the link lost ([TripEndX.resumable]) — one someone stopped stays
  /// stopped — and only while no other trip records. Null when it may not.
  Future<TripSessionRow?> reopen(String id, {DateTime? now}) async {
    final at = utc(now ?? utcNow());
    final reopened = await _db.transaction(() async {
      final row = await byId(id);
      if (row == null || row.endedAt == null) return false;
      if (!(row.endReason?.resumable ?? false)) return false;
      if (await openTrip() != null) return false;
      await (_db.update(_t)..where((s) => s.id.equals(id))).write(
        TripSessionsCompanion(
          endedAt: const Value(null),
          interrupted: const Value(false),
          endReason: const Value(null),
          lastOpenedAt: Value(at),
        ),
      );
      return true;
    });
    return reopened ? byId(id) : null;
  }

  /// The trip "Resume trip?" may offer for [vehicleId]: its newest — an
  /// older one was followed by a drive of its own — and only if it ended
  /// the way a kill or a lost link ends it, between 0 and [within] before
  /// [now] (an end in the future is a clock set back, not a trip to
  /// continue), with its file still there to append to.
  Future<TripSessionRow?> resumable(
    String vehicleId, {
    required DateTime now,
    required Duration within,
  }) async {
    final newest = (await recent(vehicleId, limit: 1)).firstOrNull;
    final ended = newest?.endedAt;
    if (newest == null || ended == null) return null;
    if (!(newest.endReason?.resumable ?? false)) return null;
    final age = utc(now).difference(ended);
    if (age.isNegative || age > within) return null;
    final f = files.tryResolve(newest.samplesFilePath);
    if (f == null || !await f.exists()) return null;
    return newest;
  }

  /// Bumps the LRU clock — call when the user opens a trip.
  Future<void> touch(String id, {DateTime? now}) =>
      (_db.update(_t)..where((s) => s.id.equals(id))).write(
        TripSessionsCompanion(lastOpenedAt: Value(utc(now ?? utcNow()))),
      );

  Future<void> rename(String id, String? name) =>
      (_db.update(_t)..where((s) => s.id.equals(id))).write(
        TripSessionsCompanion(name: Value(name)),
      );

  /// Row and file together; true when a row went. A file that is already
  /// gone is not an error. The trip being recorded is refused: the
  /// recorder holds its file and would finish a row that no longer exists.
  /// [evenIfOpen] is for a vehicle delete, once the recorder has let go.
  Future<bool> delete(String id, {bool evenIfOpen = false}) async {
    final row = await byId(id);
    if (row == null) return false;
    if (row.endedAt == null && !evenIfOpen) return false;
    await _deleteFile(files.tryResolve(row.samplesFilePath));
    await _deleteRow(id);
    return true;
  }

  Future<void> _deleteRow(String id) =>
      (_db.delete(_t)..where((s) => s.id.equals(id))).go();

  Future<void> _deleteFile(File? f) async {
    if (f == null) return;
    try {
      await f.delete();
    } on FileSystemException {
      // Already gone, or vanished between our look and our delete.
    }
  }

  /// Every trip file for a vehicle — call before deleting the vehicle, since
  /// the row cascade can't reach the filesystem. The one being recorded
  /// goes too: the vehicle it belongs to is going.
  Future<void> deleteAllFor(String vehicleId) async {
    for (final row in await recent(vehicleId)) {
      await delete(row.id, evenIfOpen: true);
    }
  }

  /// Every trip file there is — the file half of "Delete all data".
  Future<void> deleteAllFiles() async {
    for (final f in (await files.listAll()).values) {
      await _deleteFile(f);
    }
  }

  /// Makes rows and files agree again. Files with no row (a wipe, a
  /// replace-import, a vehicle cascade) are deleted so the 200 MB cap means
  /// something; rows whose file is missing (a restore onto a new device) get
  /// `fileBytes = 0` so the cap isn't charged for phantoms. Run at launch.
  Future<({int orphanFiles, int missingFiles})> reconcileFiles() async {
    final onDisk = await files.listAll();
    final rows = await _db.select(_t).get();
    final byPath = {for (final r in rows) r.samplesFilePath: r};

    var orphans = 0;
    for (final entry in onDisk.entries) {
      if (!byPath.containsKey(entry.key)) {
        await _deleteFile(entry.value);
        orphans++;
      }
    }
    var missing = 0;
    for (final r in rows) {
      if (!onDisk.containsKey(r.samplesFilePath) && r.fileBytes != 0) {
        await (_db.update(_t)..where((s) => s.id.equals(r.id))).write(
          const TripSessionsCompanion(fileBytes: Value(0)),
        );
        missing++;
      }
    }
    return (orphanFiles: orphans, missingFiles: missing);
  }

  /// Rows still open at launch belong to a process that is gone — nothing
  /// records before the launch pass has run — and each is closed from its
  /// file: at its last durable sample, with the figures it recorded, never
  /// at the relaunch time (§9.2). An earlier version stamped `now` and
  /// nulled the figures, so a trip killed at 18:00 and found the next
  /// morning was 14 hours long and went nowhere.
  ///
  /// - No file, or no data rows in it: nothing was recorded, and the row
  ///   and the file go.
  /// - A torn last line is cut off with a fresh handle, so a Resume appends
  ///   after a whole line and `fileBytes` is what the reader read.
  /// - A file that ends `#end,…,<reason>` was ended by the recorder, which
  ///   died before writing the row: that reason stands. Otherwise the app
  ///   was killed ([TripEnd.appKilled]).
  ///
  /// Returns the rows it closed.
  Future<List<TripSessionRow>> closeInterrupted({
    DateTime? now,
    TripSummarizer summarize = summarizeTripFile,
  }) async {
    final nowMs = utc(now ?? utcNow()).millisecondsSinceEpoch;
    final open = await (_db.select(_t)..where((s) => s.endedAt.isNull())).get();
    final closed = <TripSessionRow>[];
    for (final row in open) {
      final f = files.tryResolve(row.samplesFilePath);
      if (f == null || !await f.exists()) {
        await delete(row.id, evenIfOpen: true);
        continue;
      }
      final TripFileSummary summary;
      try {
        summary = await summarize(
          f.path,
          startedAtMs: row.startedAt.millisecondsSinceEpoch,
          nowMs: nowMs,
        );
      } catch (_) {
        // A file that cannot be read is closed all the same, with no
        // figures: left open, it refused every Record until the next launch
        // (one open trip at a time), and the list called it "Recording".
        await (_db.update(_t)..where((s) => s.id.equals(row.id))).write(
          TripSessionsCompanion(
            endedAt: Value(row.startedAt),
            interrupted: const Value(true),
            endReason: const Value(TripEnd.appKilled),
          ),
        );
        final done = await byId(row.id);
        if (done != null) closed.add(done);
        continue;
      }
      if (summary.rows == 0) {
        await delete(row.id, evenIfOpen: true);
        continue;
      }
      if (summary.committedBytes < await f.length()) {
        final raf = await f.open(mode: FileMode.append);
        try {
          await raf.truncate(summary.committedBytes);
        } finally {
          await raf.close();
        }
      }
      final done = await finish(
        row.id,
        end: summary.end ?? TripEnd.appKilled,
        summary: summary,
      );
      if (done != null) closed.add(done);
    }
    return closed;
  }

  Future<int> totalBytes() async {
    final sum = _t.fileBytes.sum();
    final row = await (_db.selectOnly(_t)..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }

  /// SPEC Part 6 retention. Two passes: everything older than [maxAge]
  /// goes; then, while the total exceeds [maxBytes], the least recently
  /// opened goes. Returns the ids removed. Never touches a trip that is
  /// still recording, and one trip that won't delete doesn't stop the rest.
  Future<List<String>> enforceRetention({
    DateTime? now,
    Duration maxAge = maxAge,
    int maxBytes = maxBytes,
  }) async {
    final at = utc(now ?? utcNow());
    final removed = <String>[];

    Future<void> tryDelete(TripSessionRow row) async {
      try {
        if (await delete(row.id)) removed.add(row.id);
      } catch (_) {
        // Leave it for the next pass; the rest still get reclaimed.
      }
    }

    final cutoff = at.subtract(maxAge);
    final old =
        await (_db.select(_t)..where(
              (s) =>
                  s.startedAt.isSmallerThanValue(cutoff) &
                  s.endedAt.isNotNull(),
            ))
            .get();
    for (final row in old) {
      await tryDelete(row);
    }

    var total = await totalBytes();
    if (total > maxBytes) {
      final byLru =
          await (_db.select(_t)
                ..where((s) => s.endedAt.isNotNull())
                ..orderBy([(s) => OrderingTerm.asc(s.lastOpenedAt)]))
              .get();
      for (final row in byLru) {
        if (total <= maxBytes) break;
        final before = removed.length;
        await tryDelete(row);
        if (removed.length > before) total -= row.fileBytes;
      }
    }
    return removed;
  }
}
