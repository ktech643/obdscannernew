import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart' show TripSessionRow;
import '../../data/repositories/trip_repository.dart';
import '../../data/trips/trip_csv.dart';
import '../../platform/background_service.dart';

/// What the launch pass did, for the log and for tests.
class TripLaunchReport {
  const TripLaunchReport({
    this.closed = const [],
    this.orphanFiles = 0,
    this.missingFiles = 0,
    this.removed = const [],
    this.fgsStopped = false,
  });

  final List<TripSessionRow> closed;
  final int orphanFiles;
  final int missingFiles;
  final List<String> removed;
  final bool fgsStopped;
}

/// Once per process, before anything can record: tidy what a previous run
/// left behind. Started from `main()` and not awaited, so the first frame
/// does not wait for it; Record does.
///
/// The order matters, and each step runs even if the one before failed:
/// 0. A "Recording trip" notification with no recorder behind it — a hot
///    restart, a crashed engine — is taken down.
/// 1. Every trip still open is closed from its own file (§9.2 "on relaunch
///    mark .interrupted"): at its last durable sample, with the figures the
///    file can prove. First, because retention skips open trips — a crashed
///    trip would otherwise never be reclaimed — and one still open would
///    make the next Record refuse.
/// 2. Files with no row are deleted, rows whose file is gone are zeroed
///    (§6.1 "reconcileFiles() at launch").
/// 3. Retention: 30 days, then 200 MB least-recently-opened (Part 6), over
///    closed trips whose sizes are now honest.
Future<TripLaunchReport> runTripLaunchPass(
  TripRepository trips, {
  BackgroundService? background,
  DateTime? now,
  TripSummarizer summarize = summarizeTripFile,
}) async {
  var fgsStopped = false;
  var closed = const <TripSessionRow>[];
  var orphanFiles = 0;
  var missingFiles = 0;
  var removed = const <String>[];
  try {
    if (background != null && await background.isRunning()) {
      await background.stopRecording();
      fgsStopped = true;
    }
  } catch (e) {
    debugPrint('trip launch: stopping a stale service failed: $e');
  }
  try {
    closed = await trips.closeInterrupted(now: now, summarize: summarize);
  } catch (e) {
    debugPrint('trip launch: closing interrupted trips failed: $e');
  }
  try {
    final r = await trips.reconcileFiles();
    orphanFiles = r.orphanFiles;
    missingFiles = r.missingFiles;
  } catch (e) {
    debugPrint('trip launch: reconciling trip files failed: $e');
  }
  try {
    removed = await trips.enforceRetention(now: now);
  } catch (e) {
    debugPrint('trip launch: retention failed: $e');
  }
  return TripLaunchReport(
    closed: closed,
    orphanFiles: orphanFiles,
    missingFiles: missingFiles,
    removed: removed,
    fgsStopped: fgsStopped,
  );
}
