import '../../data/db/app_database.dart' show TripSessionRow;

/// SPEC §7.2 "Recording | 2 min, last 3 trips | Unlimited", and the few
/// limits a recording lives by.
///
/// Like `LayoutPlan`, these are read where they apply and never written
/// into what is stored: a trip longer than the free plan allows, or a
/// fourth trip, is kept and only held back from view (§7.5 "downgrade,
/// never delete data").
abstract final class TripPlan {
  /// The free plan records this much of each trip, in recorded time.
  static const freeMs = 120000;
  static const freeRecording = Duration(milliseconds: freeMs);

  /// The free plan shows this many of each car's trips, newest first.
  static const freeTrips = 3;

  /// How long a recording may wait — for the link, the ignition, an
  /// identity answer or the foreground — before it ends where it stopped.
  /// Long enough that a fuel stop stays one trip, short enough that a
  /// forgotten recording does not probe the car all night.
  static const maxHold = Duration(minutes: 10);

  /// How long after it stopped an interrupted trip is offered for resuming.
  static const resumeWithin = Duration(minutes: 30);

  /// What a recording always asks the car for, on top of the tiles: Speed
  /// for distance and average, Fuel rate for §4.3's estimated fuel used.
  static const channels = {'010D', '015E'};

  /// A trip stops at 2:00 only if it was free when it started (or resumed)
  /// and is free now: Pro bought mid-trip lifts the cap at once, and a
  /// lapse or a refund never cuts a trip already running.
  static bool capped(
    int tMs, {
    required bool proAtStart,
    required bool proNow,
  }) => !proAtStart && !proNow && tMs >= freeMs;

  /// The trips shown in full, from a list newest first.
  static List<TripSessionRow> shown(
    List<TripSessionRow> newestFirst, {
    required bool isPro,
  }) => isPro ? newestFirst : newestFirst.take(freeTrips).toList();

  /// Trips kept but shown only by date on the free plan.
  static List<TripSessionRow> held(
    List<TripSessionRow> newestFirst, {
    required bool isPro,
  }) => isPro ? const [] : newestFirst.skip(freeTrips).toList();

  /// A trip already at the free plan's 2:00 has nothing left to resume.
  static bool canResume(int? recordedMs, {required bool isPro}) =>
      isPro || (recordedMs ?? 0) < freeMs;
}
