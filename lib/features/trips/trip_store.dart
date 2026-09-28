import '../../data/db/app_database.dart' show TripSessionRow;
import '../../data/db/tables.dart' show TripEnd;
import '../../data/repositories/trip_repository.dart';
import '../../data/trips/trip_csv.dart';
import '../../data/trips/trip_sink.dart';
import '../../data/trips/trip_stats.dart';
import 'trip_plan.dart';

/// A trip being written: its row's identity, the file it goes to, and
/// where recorded time picks up — 0 for a new trip, the file's own last t
/// for a resumed one, so t never runs backwards and the free plan's 2:00
/// counts the whole trip.
class OpenTrip {
  OpenTrip({
    required this.id,
    required this.vehicleId,
    required this.startedAt,
    required this.sink,
    this.baseT = 0,
    this.seed,
  });

  final String id;
  final String vehicleId;
  final DateTime startedAt;
  final TripSink sink;
  final int baseT;

  /// What the file already held, so a resumed trip's figures carry on.
  final TripTotals? seed;
}

/// Everything the recorder asks of disk, behind one seam: the widget tests
/// run it in memory, where the fake clock allows no file I/O.
abstract interface class TripStore {
  Future<OpenTrip> start({
    required String vehicleId,
    required DateTime startedAt,
  });

  /// Summarises the file and saves the figures. Null when the row is gone.
  Future<TripSessionRow?> finish(
    OpenTrip trip,
    TripEnd end, {
    required DateTime now,
  });

  /// Closes the file and deletes the row and the file: for a trip whose
  /// car, or whose data, is being deleted.
  Future<void> discard(OpenTrip trip);

  Future<TripSessionRow?> resumable(String vehicleId, {required DateTime now});

  /// Null when the trip cannot be continued; it then stays saved as it was.
  Future<OpenTrip?> resume(String tripId, {required DateTime now});

  Future<void> retention();
}

/// The real store: rows through [TripRepository], samples through a
/// [FileTripSink] on the root isolate (§B.31), and every summary read back
/// from the file itself in `Isolate.run`, so the figures saved are the
/// ones the file can prove.
class DbTripStore implements TripStore {
  DbTripStore(this.trips, {this.summarize = summarizeTripFile});

  final TripRepository trips;
  final TripSummarizer summarize;

  @override
  Future<OpenTrip> start({
    required String vehicleId,
    required DateTime startedAt,
  }) async {
    // Nothing of the recorder's own is open when it starts; a row that is
    // open is a trip whose save failed earlier this run. Closed from its
    // file now — left open, every Record failed until the next launch.
    if (await trips.openTrip() != null) {
      await trips.closeInterrupted(summarize: summarize);
    }
    final row = await trips.start(vehicleId: vehicleId, now: startedAt);
    final TripSink sink;
    try {
      sink = await FileTripSink.open(trips.fileOf(row));
    } catch (_) {
      await trips.delete(row.id, evenIfOpen: true);
      rethrow;
    }
    return OpenTrip(
      id: row.id,
      vehicleId: vehicleId,
      startedAt: row.startedAt,
      sink: sink,
    );
  }

  @override
  Future<TripSessionRow?> finish(
    OpenTrip trip,
    TripEnd end, {
    required DateTime now,
  }) async {
    final row = await trips.byId(trip.id);
    if (row == null) return null;
    final summary = await summarize(
      trips.fileOf(row).path,
      startedAtMs: row.startedAt.millisecondsSinceEpoch,
      nowMs: now.millisecondsSinceEpoch,
    );
    return trips.finish(trip.id, end: end, summary: summary);
  }

  @override
  Future<void> discard(OpenTrip trip) async {
    try {
      await trip.sink.close();
    } catch (_) {
      // Already closed, or the disk is gone: the delete is what matters.
    }
    await trips.delete(trip.id, evenIfOpen: true);
  }

  @override
  Future<TripSessionRow?> resumable(
    String vehicleId, {
    required DateTime now,
  }) => trips.resumable(vehicleId, now: now, within: TripPlan.resumeWithin);

  @override
  Future<OpenTrip?> resume(String tripId, {required DateTime now}) async {
    final row = await trips.byId(tripId);
    if (row == null) return null;
    final file = trips.fileOf(row);
    final summary = await summarize(
      file.path,
      startedAtMs: row.startedAt.millisecondsSinceEpoch,
      nowMs: now.millisecondsSinceEpoch,
    );
    if (await trips.reopen(tripId, now: now) == null) return null;
    final TripSink sink;
    try {
      sink = await FileTripSink.open(file, truncateTo: summary.committedBytes);
    } catch (_) {
      // Reopened but unwritable: saved again exactly as it was.
      await trips.finish(
        tripId,
        end: row.endReason ?? TripEnd.appKilled,
        summary: summary,
      );
      return null;
    }
    return OpenTrip(
      id: row.id,
      vehicleId: row.vehicleId,
      startedAt: row.startedAt,
      sink: sink,
      baseT: summary.endT,
      seed: summary.totals,
    );
  }

  @override
  Future<void> retention() async {
    await trips.enforceRetention();
  }
}
