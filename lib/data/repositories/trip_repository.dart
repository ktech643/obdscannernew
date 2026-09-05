import 'dart:io';

import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../ids.dart';

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
/// The recorder writes the CSV (from its own isolate, per §1.4); this class
/// owns the rows and the files' lifetime, never their contents.
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

  /// Creates the row, then the file with [header]. The row goes first: a
  /// file without a row is a leak nothing can find, while a row without a
  /// file is visible and cleaned up. If the file can't be written the row
  /// is removed again.
  Future<TripSessionRow> start({
    required String vehicleId,
    String? name,
    String header = 'ts_ms,pid,value\n',
    DateTime? now,
  }) async {
    final at = utc(now ?? utcNow());
    final id = newId();
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
    try {
      final f = await files.create(id);
      await f.writeAsString(header);
    } catch (_) {
      await (_db.delete(_t)..where((s) => s.id.equals(id))).go();
      rethrow;
    }
    return (await byId(id))!;
  }

  /// Ends the trip and records what the file now holds.
  Future<void> finish(
    String id, {
    double? distanceKm,
    double? avgSpeedKph,
    double? maxSpeedKph,
    int? sampleCount,
    bool interrupted = false,
    DateTime? now,
  }) async {
    final row = await byId(id);
    if (row == null) return;
    final f = files.tryResolve(row.samplesFilePath);
    final bytes = f != null && await f.exists() ? await f.length() : 0;
    await (_db.update(_t)..where((s) => s.id.equals(id))).write(
      TripSessionsCompanion(
        endedAt: Value(utc(now ?? utcNow())),
        distanceKm: Value(distanceKm),
        avgSpeedKph: Value(avgSpeedKph),
        maxSpeedKph: Value(maxSpeedKph),
        sampleCount: sampleCount == null
            ? const Value.absent()
            : Value(sampleCount),
        fileBytes: Value(bytes),
        interrupted: Value(interrupted),
      ),
    );
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

  /// Row and file together. A file that is already gone is not an error.
  Future<void> delete(String id) async {
    final row = await byId(id);
    if (row == null) return;
    await _deleteFile(files.tryResolve(row.samplesFilePath));
    await (_db.delete(_t)..where((s) => s.id.equals(id))).go();
  }

  Future<void> _deleteFile(File? f) async {
    if (f == null) return;
    try {
      await f.delete();
    } on FileSystemException {
      // Already gone, or vanished between our look and our delete.
    }
  }

  /// Every trip file for a vehicle — call before deleting the vehicle, since
  /// the row cascade can't reach the filesystem.
  Future<void> deleteAllFor(String vehicleId) async {
    for (final row in await recent(vehicleId)) {
      await delete(row.id);
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

  /// Sessions still open on launch didn't end cleanly. Close them so the
  /// list is honest and the next recording doesn't inherit one.
  Future<int> closeInterrupted({DateTime? now}) async {
    final open = await (_db.select(_t)..where((s) => s.endedAt.isNull())).get();
    for (final row in open) {
      await finish(row.id, interrupted: true, now: now);
    }
    return open.length;
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
        await delete(row.id);
        removed.add(row.id);
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
