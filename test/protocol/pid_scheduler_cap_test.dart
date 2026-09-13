import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/pid_scheduler.dart';

/// SPEC §5.6 "Polling rate" — the user's ceiling on the adaptive rate.
void main() {
  test('Auto is the default and the adaptation runs to 10 Hz', () {
    final s = PidScheduler();
    expect(s.maxHz, isNull);
    s.recordP95Rtt(100);
    expect(s.targetHz, 10);
  });

  test('★ a ceiling holds through every path that raises the rate', () {
    final s = PidScheduler()..maxHz = 4;
    expect(s.targetHz, 4, reason: 'applies at once');
    s.recordP95Rtt(100);
    expect(s.targetHz, 4, reason: 'a fast adapter does not lift it');
    s.recordP95Rtt(700);
    expect(s.targetHz, 2, reason: 'a slow one still drops below it');
    for (var i = 0; i < 50; i++) {
      s.relax();
    }
    expect(s.targetHz, 4, reason: 'relaxing climbs back only to the ceiling');
    s.onBufferFull();
    expect(s.targetHz, 2);
    s.reset();
    expect(s.targetHz, 4, reason: 'a reset keeps the user\'s ceiling');
  });

  test('lifting the ceiling lets the next measurement climb again', () {
    final s = PidScheduler()..maxHz = 2;
    s.recordP95Rtt(100);
    expect(s.targetHz, 2);
    s.maxHz = null;
    expect(s.targetHz, 2, reason: 'no measurement yet, nothing invented');
    s.recordP95Rtt(100);
    expect(s.targetHz, 10);
  });

  test('the ceiling is clamped to what the protocol can do', () {
    final s = PidScheduler()..maxHz = 50;
    expect(s.maxHz, 10);
    s.maxHz = 0;
    expect(s.maxHz, 1);
  });

  group('★ hasRecovered — the thing a backoff has to clear against', () {
    // An adversarial-review find: ObdSession's BUFFER FULL backoff used to
    // clear on `targetHz >= 10` literally. With a ceiling below 10 the
    // rate can never reach 10 again, so that check could never pass and
    // the backoff latched for the rest of the connection — the scheduler's
    // own rate recovered to its ceiling just fine, but nothing downstream
    // ever noticed because it was watching for the wrong number.
    test('Auto: only literal 10 counts as recovered', () {
      final s = PidScheduler();
      expect(s.hasRecovered, isTrue, reason: 'starts at 10 by default');
      s.onBufferFull();
      expect(s.hasRecovered, isFalse);
      s.recordP95Rtt(700);
      expect(s.targetHz, 2);
      expect(s.hasRecovered, isFalse);
      s.recordP95Rtt(100);
      expect(s.targetHz, 10);
      expect(s.hasRecovered, isTrue);
    });

    test('a ceiling below 10: recovered means "back at the ceiling"', () {
      final s = PidScheduler()..maxHz = 4;
      expect(s.hasRecovered, isTrue, reason: 'already at the ceiling');
      s.onBufferFull();
      expect(s.targetHz, 2);
      expect(s.hasRecovered, isFalse);
      // Climbing to literal 10 is impossible under this ceiling; the old
      // literal-10 check would stay false forever from here.
      for (var i = 0; i < 50; i++) {
        s.relax();
      }
      expect(s.targetHz, 4, reason: 'back at the ceiling, not at 10');
      expect(s.hasRecovered, isTrue);
    });
  });
}
