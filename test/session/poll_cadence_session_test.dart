import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/session/gauge_catalog.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §5.3 — `ObdSession.cadence`: how long each polled reading waits
/// between answers, which is what a tile's staleness is measured against.
///
/// Found on the iOS simulator against `tool/trace_server.dart` replaying
/// `trip_drive_can`: start a trip recording, which puts Fuel rate beside
/// the six default tiles, and Load, Throttle and Battery read "0 s ago" at
/// 40 % continuously while their values changed on every answer.
void main() {
  const six = ['010C', '010D', '0105', '0104', '0111', '0142'];
  const criticals = {'010C', '010D'};

  late ObdTrace tripDrive;
  late ObdTrace cleanCan;
  setUpAll(() {
    ObdTrace read(String name) =>
        ObdTrace.parse(File('assets/traces/$name.obdtrace').readAsStringSync());
    tripDrive = read('trip_drive_can');
    cleanCan = read('clean_can');
  });

  ObdSession sessionAt(double timeScale) {
    final s = ObdSession(timeScale: timeScale);
    addTearDown(() async {
      await s.disconnect();
      s.dispose();
    });
    return s;
  }

  Future<void> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
    required String reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('Timed out: $reason');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// What the Dashboard's tile for [pid] would say right now: the same
  /// spec, sample and cadence it is built from, judged at the wall clock.
  GaugeState tileState(ObdSession s, String pid) => GaugeTile.stateFor(
    GaugeCatalog.specFor(pid)!,
    s.bus.of(pid).value,
    DateTime.now(),
    expectedInterval: s.cadence.of(pid).value,
  );

  test('★ on a 45 ms adapter, recording a trip, no tile that is being '
      'answered reads stale — and every one still does once the answers '
      'stop', () async {
    // Real time: the recorded replies take 80–95 ms, so at 2× a reply
    // takes about 45 ms — the trace server's pace. Staleness is judged
    // against the wall clock, so nothing here may be compressed.
    final session = sessionAt(1.0);
    final transport = MockTransport(tripDrive, speed: 2);
    final polled = [...six, '015E']; // a recording adds Fuel rate
    final watched = [
      for (final p in polled)
        if (!criticals.contains(p)) p,
    ];
    session.setVisible(polled.toSet());
    expect(await session.connect(transport), isTrue);

    // The handshake's slow replies (a 900 ms SEARCHING) leave the RTT
    // window within a second of polling; only then is the budget tight.
    await waitFor(
      () =>
          (session.p95Rtt ?? 999) < 80 &&
          polled.every((p) => session.bus.of(p).value?.value != null),
      reason: 'every reading answered, at the adapter\'s own pace',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      session.scheduler.maxPidsPerCycle,
      lessThanOrEqualTo(2),
      reason: 'RPM and Speed fill the budget, and the rest take turns',
    );

    final stale = <String>[];
    final answers = {for (final p in watched) p: <DateTime>{}};
    final until = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(until)) {
      for (final pid in watched) {
        answers[pid]!.add(session.bus.of(pid).value!.at);
        if (tileState(session, pid) == GaugeState.stale) {
          final age = DateTime.now().difference(session.bus.of(pid).value!.at);
          stale.add(
            '$pid at ${age.inMilliseconds} ms, '
            'cadence ${session.cadence.of(pid).value?.inMilliseconds} ms',
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    for (final pid in watched) {
      expect(
        answers[pid]!.length,
        greaterThanOrEqualTo(3),
        reason: '$pid is being answered',
      );
    }
    expect(stale, isEmpty, reason: 'updating normally is not stale');

    // Hard rule 4 holds: the adapter falls silent, and every tile passes
    // through stale before it gives up to "No data" at 5 s.
    transport.dropNext = 1 << 30;
    final seenStale = <String>{};
    final gone = <String>{};
    final deadline = DateTime.now().add(const Duration(seconds: 7));
    while (gone.length < watched.length && DateTime.now().isBefore(deadline)) {
      for (final pid in watched) {
        if (gone.contains(pid)) continue;
        switch (tileState(session, pid)) {
          case GaugeState.stale:
            seenStale.add(pid);
          case GaugeState.unavailable:
            gone.add(pid);
          default:
            break;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(gone, containsAll(watched), reason: 'no answers, no data');
    expect(seenStale, containsAll(watched), reason: 'stale before absent');
  });

  test('★ every reading the session polls has a cadence, and nothing '
      'else does', () async {
    final session = sessionAt(0.05);
    session.setVisible(six.toSet());
    expect(await session.connect(MockTransport(cleanCan, speed: 100)), isTrue);
    await waitFor(
      () => six.every((p) => session.cadence.of(p).value != null),
      reason: 'a cadence for each tile',
    );
    expect(session.cadence.of('015E').value, isNull, reason: 'not polled');
    expect(
      session.cadence.of('010C').value!,
      lessThan(session.cadence.of('0105').value!),
      reason: 'RPM is asked every cycle, Coolant every other',
    );
  });

  test('★ a session that stops asking leaves no cadence behind', () async {
    // Left in place, the last link's cadence would judge the next link's
    // first samples: a slow adapter's seconds, and a hang read as live.
    final session = sessionAt(0.05);
    session.setVisible(six.toSet());
    expect(await session.connect(MockTransport(cleanCan, speed: 100)), isTrue);
    await waitFor(
      () => session.cadence.of('0105').value != null,
      reason: 'a cadence',
    );

    session.setBackgrounded(true); // nothing recording: polling stops
    await waitFor(
      () => six.every((p) => session.cadence.of(p).value == null),
      reason: 'no cadence while nothing is asked',
    );

    session.setBackgrounded(false);
    await waitFor(
      () => session.cadence.of('0105').value != null,
      reason: 'asked again',
    );
    // The loop clears it as it ends, on its next wake: before a new link's
    // loop can start, which waits for this one.
    await session.disconnect();
    await waitFor(
      () => six.every((p) => session.cadence.of(p).value == null),
      reason: 'no cadence after a disconnect',
    );
  });
}
