import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/pid_scheduler.dart';

/// SPEC §5.3 — a tile is stale past twice its expected interval, and the
/// interval is how often *this* schedule asks for its PID: the tier, the
/// turns a tight budget makes the rest take, and how long a cycle runs.
///
/// Found on the simulator against `tool/trace_server.dart`: with RPM and
/// Speed critical on a 45 ms adapter, Load, Throttle and Battery were asked
/// about once a second and measured against the tier's 200 ms, so they
/// read "0 s ago" at 40 % for most of every second.
void main() {
  const layout = ['010C', '010D', '0105', '0104', '0111', '0142'];
  const highs = ['0105', '0104', '0111', '0142'];
  const floor = Duration(milliseconds: 100);
  const unavailable = Duration(seconds: 5);

  PidScheduler scheduler(Iterable<String> pids, {required int rtt}) =>
      PidScheduler()
        ..setSupported(pids.toSet())
        ..setVisible(pids.toSet())
        ..recordP95Rtt(rtt);

  /// The longest wait between two answers for each PID, found by running
  /// the real [PidScheduler.nextCycle] and timing it as the poll loop
  /// runs: a cycle takes the scheduler's own budget or its commands at
  /// [rtt] each, whichever is longer, and each answer lands [rtt] after
  /// the one before.
  Map<String, Duration> measured(PidScheduler s, {required int rtt}) {
    final floor = s.cycleBudget;
    final step = Duration(milliseconds: rtt);
    var start = Duration.zero;
    final last = <String, Duration>{};
    final longest = <String, Duration>{};
    for (var c = 0; c < 400; c++) {
      final asked = s.nextCycle();
      for (var k = 0; k < asked.length; k++) {
        final at = start + step * (k + 1);
        final before = last[asked[k]];
        if (before != null) {
          final gap = at - before;
          if (gap > (longest[asked[k]] ?? Duration.zero)) {
            longest[asked[k]] = gap;
          }
        }
        last[asked[k]] = at;
      }
      final spent = step * asked.length;
      start += spent > floor ? spent : floor;
    }
    return longest;
  }

  test('★ on a 45 ms adapter the high tier waits 940 ms, not 200', () {
    final s = scheduler(layout, rtt: 45);
    expect(s.maxPidsPerCycle, 2, reason: 'RPM and Speed fill the budget');

    final expected = s.expectedIntervals(floor: floor, rttMs: 45);

    // The criticals ride every cycle; a cycle with one more command runs
    // 135 ms, past the 100 ms floor.
    expect(expected['010C'], const Duration(milliseconds: 135));
    expect(expected['010D'], const Duration(milliseconds: 135));
    // The four highs share one slot every other cycle: each is asked once
    // in eight cycles, four of 135 ms and four of 100.
    for (final pid in highs) {
      expect(expected[pid], const Duration(milliseconds: 940), reason: pid);
    }
  });

  test('★ every gap the schedule really leaves is inside its interval', () {
    // A recording adds Fuel rate beside the six; slower adapters and a
    // longer layout make the rotation uneven.
    final layouts = {
      'six': layout,
      'six and Fuel rate': [...layout, '015E'],
      'thirteen': [
        ...layout,
        '015E',
        '010F',
        '012F',
        '010E',
        '0146',
        '0110',
        '0143',
      ],
    };
    for (final MapEntry(key: name, value: pids) in layouts.entries) {
      for (final rtt in [30, 45, 120, 300, 700]) {
        final s = scheduler(pids, rtt: rtt);
        final expected = s.expectedIntervals(floor: s.cycleBudget, rttMs: rtt);
        final gaps = measured(s, rtt: rtt);
        for (final MapEntry(key: pid, value: gap) in gaps.entries) {
          // Past 5 s a tile says "No data" whatever its interval, so a gap
          // that long only needs the tile not to dim before then.
          expect(
            expected[pid],
            greaterThanOrEqualTo(gap < unavailable ? gap : unavailable),
            reason: '$pid, $name at $rtt ms: a gap of $gap',
          );
        }
      }
    }
  });

  test('a PID the schedule does not ask for has no interval', () {
    final s = scheduler(layout, rtt: 45);
    s
      ..recordNoData('0142')
      ..recordNoData('0142')
      ..recordNoData('0142');
    final expected = s.expectedIntervals(floor: floor, rttMs: 45);
    expect(expected.containsKey('0142'), isFalse, reason: 'dropped');
    expect(expected.containsKey('015E'), isFalse, reason: 'never visible');
  });

  test('the answer follows its inputs, remembered or not', () {
    final s = scheduler(layout, rtt: 45)..setSupported({...layout, '015E'});
    final six = s.expectedIntervals(floor: floor, rttMs: 45);
    expect(
      identical(s.expectedIntervals(floor: floor, rttMs: 45), six),
      isTrue,
      reason: 'nothing changed, nothing recomputed',
    );

    s.setVisible({...layout, '015E'});
    final seven = s.expectedIntervals(floor: floor, rttMs: 45);
    expect(seven.keys, contains('015E'));
    expect(seven['0104'], greaterThan(six['0104']!));

    expect(
      s.expectedIntervals(floor: floor, rttMs: 300)['010C'],
      const Duration(milliseconds: 900),
      reason: 'a slower adapter, a longer cycle',
    );
    expect(
      s.expectedIntervals(floor: floor, rttMs: 45, maxPids: 12)['0104'],
      lessThan(seven['0104']!),
      reason: 'a larger budget, fewer turns to wait',
    );
    expect(
      s.expectedIntervals(floor: const Duration(seconds: 2), rttMs: 45)['010C'],
      const Duration(seconds: 2),
      reason: 'a background floor holds every cycle',
    );
  });
}
