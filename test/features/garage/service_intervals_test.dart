import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/clock.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/service_repository.dart';
import 'package:torque_obd2/features/garage/fuel_log_screen.dart';
import 'package:torque_obd2/features/garage/service_intervals.dart';
import 'package:torque_obd2/models/enums.dart';

/// SPEC §5.5 — the intervals, the one "overdue" rule, money as typed, and
/// economy between full fill-ups only. Pure; no widgets, no database.
void main() {
  final now = DateTime.utc(2026, 9, 25, 12);

  ReminderRow reminder({
    DateTime? dueDate,
    double? dueKm,
    bool paused = false,
    DateTime? completedAt,
  }) => ReminderRow(
    id: 'r',
    vehicleId: 'v',
    title: 'Oil',
    dueDate: dueDate,
    dueOdometerKm: dueKm,
    critical: false,
    paused: paused,
    completedAt: completedAt,
    createdAt: DateTime.utc(2026),
  );

  group('★ reminderStatus — the one rule', () {
    test('past its date, or at or past its reading, is overdue', () {
      expect(
        reminderStatus(
          reminder(dueDate: now.subtract(const Duration(days: 1))),
          now: now,
        ),
        ReminderStatus.overdue,
      );
      expect(
        reminderStatus(reminder(dueKm: 150000), odometerKm: 150000, now: now),
        ReminderStatus.overdue,
        reason: 'at the reading is due',
      );
    });

    test('inside a month or 1,000 km is due soon', () {
      expect(
        reminderStatus(
          reminder(dueDate: now.add(const Duration(days: 29))),
          now: now,
        ),
        ReminderStatus.dueSoon,
      );
      expect(
        reminderStatus(reminder(dueKm: 150000), odometerKm: 149000, now: now),
        ReminderStatus.dueSoon,
      );
      expect(
        reminderStatus(reminder(dueKm: 150000), odometerKm: 148999, now: now),
        ReminderStatus.upcoming,
      );
    });

    test('a reading the car never gave cannot make anything due', () {
      expect(
        reminderStatus(reminder(dueKm: 150000), now: now),
        ReminderStatus.upcoming,
      );
    });

    test('paused and done are never overdue, however late', () {
      final late = now.subtract(const Duration(days: 400));
      expect(
        reminderStatus(reminder(dueDate: late, paused: true), now: now),
        ReminderStatus.paused,
      );
      expect(
        reminderStatus(
          reminder(dueDate: late, completedAt: now),
          now: now,
        ),
        ReminderStatus.done,
      );
    });
  });

  group('§5.5 presets', () {
    test('every interval the spec lists, and nothing it does not', () {
      final byTitle = {for (final p in ServicePreset.all) p.title: p};
      expect(byTitle['Oil and filter']!.everyKm, 10000);
      expect(byTitle['Oil and filter']!.everyMonths, 6);
      expect(byTitle['Tyre rotation']!.everyKm, 10000);
      expect(byTitle['Air filter']!.everyKm, 20000);
      expect(byTitle['Cabin filter']!.everyKm, 15000);
      expect(byTitle['Brake pads']!.everyKm, 40000);
      expect(byTitle['Brake fluid']!.everyMonths, 24);
      expect(byTitle['Coolant']!.everyKm, 60000);
      expect(byTitle['Transmission fluid']!.everyKm, 60000);
      expect(byTitle['Spark plugs (copper)']!.everyKm, 40000);
      expect(byTitle['Spark plugs (iridium or platinum)']!.everyKm, 100000);
      expect(byTitle['Battery']!.everyMonths, 48);
      expect(byTitle['Timing belt']!.everyKm, 100000);
      expect(byTitle['Timing belt']!.critical, isTrue);
      expect(byTitle['Inspection']!.everyMonths, 12);
      expect(ServicePreset.all, hasLength(13));
    });

    test('months survive the round trip through days', () {
      for (final m in [1, 6, 12, 24, 48, 120]) {
        expect(ServicePreset.monthsForDays(ServicePreset.daysForMonths(m)), m);
      }
    });

    test('the owner\'s-manual line is the spec\'s, word for word', () {
      expect(
        ServicePreset.manualNote,
        "Check your owner's manual — intervals vary by vehicle.",
      );
    });
  });

  group('Money', () {
    test('both decimal separators, and thousands either way', () {
      expect(Money.parse('42.50'), 42.5);
      expect(Money.parse('42,50'), 42.5);
      expect(Money.parse('1,042.50'), 1042.5);
      expect(Money.parse('1 042,50'), 1042.5);
      expect(Money.parse('1,042'), 1042, reason: 'three digits group');
      expect(Money.parse('£12'), 12);
    });

    test('not an amount is null — Infinity and NaN included', () {
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('Infinity'), isNull);
      expect(Money.parse('NaN'), isNull);
    });

    test('the setting\'s code, or USD for anything unreadable', () {
      expect(Money.codeOf('GBP £'), 'GBP');
      expect(Money.codeOf('JPY ¥'), 'JPY');
      expect(Money.codeOf('pounds'), 'USD');
    });

    test('shown with the currency\'s own decimals', () {
      expect(Money.format(42.5, 'GBP'), '£42.50');
      expect(Money.format(1200, 'JPY'), '¥1,200');
    });
  });

  group('★ due dates are calendar days', () {
    // As the app stores one now: UTC midnight of the day picked.
    final due = calendarDay(2026, 9, 27);

    test('★ on its due date it is due today, not overdue', () {
      // Compared as instants it was overdue from 00:00 on the 27th, and
      // cost the health score its −5 on the day it was due.
      for (final h in [0, 12, 23]) {
        final at = DateTime(2026, 9, 27, h, 59);
        expect(
          reminderStatus(reminder(dueDate: due), now: at),
          ReminderStatus.dueSoon,
          reason: '$h:59',
        );
        expect(reminderDaysLeft(reminder(dueDate: due), now: at), 0);
      }
      expect(
        reminderStatus(reminder(dueDate: due), now: DateTime(2026, 9, 28)),
        ReminderStatus.overdue,
      );
    });

    test('★ the day before, one day is left — at any hour', () {
      // Floored from an instant, the 26th said "today".
      for (final h in [0, 23]) {
        expect(
          reminderDaysLeft(
            reminder(dueDate: due),
            now: DateTime(2026, 9, 26, h, 1),
          ),
          1,
        );
      }
    });

    test('★ a calendar day reads as that day wherever the phone is', () {
      // Run under TZ=America/New_York the instant read back as the 24th.
      expect(formatDay(calendarDay(2026, 9, 25)), '25 Sep 2026');
    });

    test('a date written before (local midnight) reads as the day picked', () {
      final written = DateTime(2026, 9, 27).toUtc();
      expect(dayOf(written), calendarDay(2026, 9, 27));
      expect(formatDay(written), '27 Sep 2026');
    });

    test('★ days are added on the calendar, not in 24-hour blocks', () {
      // Local midnight + 183 × 24 h is 23:00 on the 26th in London.
      expect(addDays(calendarDay(2026, 9, 25), 183), calendarDay(2027, 3, 27));
      expect(
        daysBetween(calendarDay(2026, 3, 28), calendarDay(2026, 3, 30)),
        2,
      );
    });
  });

  group('★ §5.5 — economy between full fill-ups only', () {
    var seq = 0;
    FuelEntryRow fill(double km, double litres, {bool part = false}) =>
        FuelEntryRow(
          id: 'f${seq++}',
          vehicleId: 'v',
          date: DateTime.utc(2026, 9, 1).add(Duration(days: seq)),
          odometerKm: km,
          litres: litres,
          currencyCode: 'GBP',
          partFill: part,
        );

    test('★ a part fill is counted into the next full tank', () {
      final first = fill(10000, 40);
      final part = fill(10300, 10, part: true);
      final full = fill(10600, 30);
      final s = FuelSummary.of([first, part, full]);
      final byId = {for (final e in s.economy) e.entry.id: e.litresPer100Km};
      expect(byId[first.id], isNull, reason: 'nothing known before it');
      expect(byId[part.id], isNull, reason: 'the tank was not full');
      expect(byId[full.id], closeTo(40 / 600 * 100, 1e-9));
    });

    test('the average is weighted by distance, not by fill-up', () {
      final s = FuelSummary.of([
        fill(0, 50),
        fill(100, 10), // 10 L over 100 km
        fill(1100, 50), // 50 L over 1,000 km
      ]);
      expect(s.spanKm, 1100);
      expect(s.averageLitresPer100Km, closeTo(60 / 1100 * 100, 1e-9));
    });

    test('odometer order, whatever order they were added in', () {
      final a = fill(10000, 40);
      final c = fill(10600, 30);
      final b = fill(10300, 20); // an older receipt, added last
      final s = FuelSummary.of([a, c, b]);
      expect(s.economy.map((e) => e.entry.odometerKm), [10000, 10300, 10600]);
      expect(s.economy.last.litresPer100Km, closeTo(30 / 300 * 100, 1e-9));
    });

    test('no complete span, no average', () {
      expect(FuelSummary.of([fill(0, 40)]).averageLitresPer100Km, isNull);
      expect(
        FuelSummary.of([fill(0, 40), fill(0, 30)]).averageLitresPer100Km,
        isNull,
        reason: 'no distance between them',
      );
    });

    FuelEntryRow at(String id, double km, double litres, {bool part = false}) =>
        FuelEntryRow(
          id: id,
          vehicleId: 'v',
          date: calendarDay(2026, 9, 20),
          odometerKm: km,
          litres: litres,
          currencyCode: 'GBP',
          partFill: part,
        );

    FuelEconomy of(FuelSummary s, String id) =>
        s.economy.singleWhere((e) => e.entry.id == id);

    test('★ a part fill and the full one after it, at one reading on one '
        'day, in any order', () {
      // Logged the natural way — the part fill, then the top-up that
      // filled the tank — they tie on reading and day, and the list reads
      // newest first. The full tank came first and got 32 L, not 42.
      final start = at('m-start', 10000, 40);
      final part = at('z-part', 10600, 10, part: true);
      final full = at('a-full', 10600, 32);
      for (final order in [
        [start, part, full],
        [start, full, part],
        [full, part, start],
      ]) {
        final s = FuelSummary.of(order);
        expect(of(s, 'a-full').litresPer100Km, closeTo(42 / 600 * 100, 1e-9));
        expect(of(s, 'z-part').role, FuelSpanRole.partCounted);
      }
    });

    test('★ a second full tank at the same reading is a top-up; its litres '
        'go forward', () {
      final s = FuelSummary.of([
        at('a', 10000, 40),
        at('b', 10000, 2),
        at('c', 10500, 30),
      ]);
      expect(of(s, 'b').role, FuelSpanRole.toppedUp);
      expect(of(s, 'c').litresPer100Km, closeTo(32 / 500 * 100, 1e-9));
    });

    test('★ a part fill before the first full tank is not counted, and is '
        'not said to be', () {
      final s = FuelSummary.of([
        at('p', 9800, 10, part: true),
        at('a', 10000, 40),
        at('c', 10500, 30),
      ]);
      expect(of(s, 'p').role, FuelSpanRole.partBefore);
      expect(of(s, 'a').role, FuelSpanRole.starts);
      expect(of(s, 'c').litresPer100Km, closeTo(30 / 500 * 100, 1e-9));
    });

    test('miles users see both gallons', () {
      expect(formatEconomy(6.7, DistanceUnit.km), '6.7 L/100 km');
      final mi = formatEconomy(6.7, DistanceUnit.mi);
      expect(mi, contains('35.1 mpg US'));
      expect(mi, contains('42.2 mpg UK'));
    });
  });
}
