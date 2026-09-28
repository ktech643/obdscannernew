import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/features/trips/trip_recorder.dart';
import 'package:torque_obd2/session/obd_session.dart' show SessionState;

import 'support.dart';

/// SPEC §B.32 — what the adversarial review of slice 17 confirmed in the
/// recorder, each pinned where it was found.
void main() {
  const android = FakePlatform(isAndroid: true);

  RecorderRig rig({PlatformInfo platform = android, bool isPro = false}) {
    final r = RecorderRig(platform: platform, isPro: isPro);
    addTearDown(r.dispose);
    return r;
  }

  /// A second of driving: a Speed reading, then the tick.
  Future<void> drive(RecorderRig r, [int seconds = 1]) async {
    for (var i = 0; i < seconds; i++) {
      r.link.publish('010D', 36);
      await r.tick();
    }
  }

  group('★ a trip that ends while the Android service starts', () {
    test(
      '★ from onResumed: no background polling, no service left up',
      () async {
        // Permission granted in Settings; back in the app the service starts
        // — and the trip ends (2:00, a give-up, Stop) during that round trip.
        // The end funnel had run; setRecording(true) came after it, and the
        // car was polled in the background with nothing recording.
        final r = rig();
        r.background.notifications = false;
        await r.recorder.start();
        await drive(r, 2);
        expect(r.link.recordingCalls.last, isFalse, reason: 'no service yet');

        r.background.notifications = true;
        r.background.startGate = Completer<void>();
        final resumed = r.recorder.onResumed();
        await RecorderRig.settle();
        final stopped = r.recorder.stop();
        await RecorderRig.settle();
        r.background.startGate!.complete();
        await resumed;
        await stopped;
        await RecorderRig.settle();

        expect(r.recorder.view.phase, RecorderPhase.idle);
        expect(r.link.recordingCalls.last, isFalse);
        expect(
          r.background.running,
          isFalse,
          reason: 'the service was stopped',
        );
      },
    );

    test(
      '★ from Record: no timer, no event and no service after the end',
      () async {
        final r = rig();
        r.background.startGate = Completer<void>();
        final starting = r.recorder.start();
        await RecorderRig.settle();
        final events = r.recorder.eventSerial;
        // The link gives up while the service comes up.
        r.link.set(SessionState.disconnected, error: 'Could not reconnect');
        await RecorderRig.settle();
        r.background.startGate!.complete();
        await starting;
        await RecorderRig.settle();

        expect(r.recorder.view.phase, RecorderPhase.idle);
        expect(r.link.recordingCalls.last, isFalse);
        expect(r.background.running, isFalse);
        expect(
          r.recorder.lastEvent?.kind,
          TripEventKind.ended,
          reason: 'no "started" after the end',
        );
        expect(r.recorder.eventSerial, events + 1);
      },
    );
  });

  group('★ Resume trip? is offered only while it can be taken', () {
    /// A trip that lost its link and gave up, then a new live edge.
    Future<String> lostTrip(RecorderRig r) async {
      await r.recorder.start();
      await drive(r, 30);
      r.link.set(SessionState.lost, reconnecting: true);
      r.link.set(SessionState.disconnected, error: 'Could not reconnect');
      await RecorderRig.settle();
      final id = r.store.rows.keys.single;
      expect(r.store.rows[id]!.endReason, TripEnd.linkLost);
      return id;
    }

    Future<void> reconnect(RecorderRig r, Duration later) async {
      r.clock.advance(later);
      r.link.set(SessionState.connected);
      await RecorderRig.settle();
    }

    test('★ an offer left on the strip past 30 minutes is gone, and Resume '
        'refuses it', () async {
      final r = rig(isPro: true);
      await lostTrip(r);
      await reconnect(r, const Duration(minutes: 5));
      expect(r.recorder.view.offer, isNotNull);

      // Still connected, the offer untouched for three hours.
      r.clock.advance(const Duration(hours: 3));
      r.link.set(SessionState.connected); // any change redraws the strip
      await RecorderRig.settle();
      expect(r.recorder.view.offer, isNull);
      await r.recorder.resume();
      expect(r.recorder.view.phase, RecorderPhase.idle);
    });

    test(
      '★ a later connect with nothing to offer clears the old offer',
      () async {
        // Within the window, so only the re-query can clear it: the trip was
        // deleted from the Garage, and the next connect finds nothing.
        final r = rig(isPro: true);
        final id = await lostTrip(r);
        await reconnect(r, const Duration(minutes: 5));
        expect(r.recorder.view.offer, isNotNull);
        r.store.rows.remove(id);
        r.store.sinks.remove(id);
        r.link.set(SessionState.disconnected);
        await reconnect(r, const Duration(minutes: 5));
        expect(r.recorder.view.offer, isNull);
      },
    );

    test('★ a trip deleted in the Garage is not "saved as it was"', () async {
      final r = rig(isPro: true);
      final id = await lostTrip(r);
      await reconnect(r, const Duration(minutes: 5));
      expect(r.recorder.view.offer?.tripId, id);
      // Garage › Trip recordings › Delete trip.
      r.store.rows.remove(id);
      r.store.sinks.remove(id);

      await r.recorder.resume();
      await RecorderRig.settle();
      expect(r.recorder.view.phase, RecorderPhase.idle);
      expect(r.recorder.view.result?.kind, TripResultKind.resumeGone);
      expect(r.recorder.view.offer, isNull);
    });
  });

  test('★ Pro bought mid-trip, then lapsed: the trip is not cut, and no '
      '#end lands behind its rows', () async {
    final r = rig(platform: const FakePlatform(isAndroid: false));
    await r.recorder.start();
    await drive(r, 60);
    r.recorder.isPro = true;
    await drive(r, 240);
    // A refund, or the store revoking a sandbox purchase.
    r.recorder.isPro = false;
    await drive(r, 2);
    expect(r.recorder.view.phase, RecorderPhase.recording);

    await r.recorder.stop();
    await RecorderRig.settle();
    final row = r.store.rows.values.single;
    expect(row.endReason, TripEnd.stopped);
    expect(r.sink.content, isNot(contains('#end,120000,')));
    expect(row.recordedMs, greaterThan(300000));
  });

  test('a trip whose save failed does not block the next Record', () async {
    // The row stays open for the launch pass; one open trip at a time made
    // every Record fail with "Try again" until the app was relaunched.
    final r = rig(platform: const FakePlatform(isAndroid: false));
    await r.recorder.start();
    await drive(r, 3);
    r.store.failFinish = StateError('disk full');
    await r.recorder.stop();
    await RecorderRig.settle();
    expect(r.recorder.view.result?.kind, TripResultKind.summaryPending);

    await r.recorder.start();
    await RecorderRig.settle();
    expect(r.recorder.view.phase, RecorderPhase.recording);
    expect(
      r.store.rows.values.where((row) => row.endedAt == null),
      hasLength(1),
      reason: 'the orphan closed from its file; only the new one open',
    );
  });

  test(
    '★ a pause that changed kind ends as a pause, not as its last kind',
    () async {
      // Eight minutes waiting for the link, two with the ignition off: ended
      // as "the ignition was off for 10 minutes".
      final r = rig(
        platform: const FakePlatform(isAndroid: false),
        isPro: true,
      );
      await r.recorder.start();
      await drive(r, 5);
      r.link.set(SessionState.lost, reconnecting: true);
      await r.tick(8 * 60);
      r.link.set(SessionState.ignitionOff);
      await r.tick(2 * 60 + 1);
      await RecorderRig.settle();
      expect(r.store.rows.values.single.endReason, TripEnd.heldTooLong);
    },
  );

  test('★ a car that reports no Speed is not promised distance before '
      'Record', () {
    final r = RecorderRig(
      platform: const FakePlatform(isAndroid: false),
      supported: {'010C', '0105'},
    );
    addTearDown(r.dispose);
    expect(r.recorder.view.phase, RecorderPhase.idle);
    expect(r.recorder.view.speedMissing, isTrue);
  });

  test('★ Record then Stop with no reading saves no trip', () async {
    // Kept, a 0 s trip took one of the free plan's last three; the launch
    // pass deletes the same empty file.
    final r = rig(platform: const FakePlatform(isAndroid: false));
    await r.recorder.start();
    await r.tick();
    await r.recorder.stop();
    await RecorderRig.settle();
    expect(r.store.rows, isEmpty);
    expect(r.store.discarded, hasLength(1));
    expect(r.recorder.view.result?.kind, TripResultKind.nothingRecorded);
  });
}
