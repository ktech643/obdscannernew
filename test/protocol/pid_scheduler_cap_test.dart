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
}
