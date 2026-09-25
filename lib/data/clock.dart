/// Every timestamp the data layer stores is UTC.
///
/// Dates go into SQLite as ISO-8601 text and are ordered and compared as
/// text. A local time carries its offset (`… +02:00`), so a table mixing
/// local and UTC rows — or two local rows across a DST change — no longer
/// sorts chronologically. SPEC §9.7: store UTC. Repositories normalise every
/// DateTime they write through [utc]; readers get UTC instants back.
DateTime utcNow() => DateTime.timestamp();

DateTime utc(DateTime d) => d.isUtc ? d : d.toUtc();

DateTime? utcOrNull(DateTime? d) => d == null ? null : utc(d);

// ------------------------------------------------------------ calendar days

/// A day on the calendar — a service date, a due date — as opposed to an
/// instant. Stored as UTC midnight of that day, so it names the same day
/// wherever the phone is: an instant (local midnight) read back after a
/// move west, or across a DST change, lands on the day before.
DateTime calendarDay(int year, int month, int day) =>
    DateTime.utc(year, month, day);

/// The calendar day a stored date names. Rows written as UTC midnight are
/// calendar days already; rows written before (local midnight, stored as
/// its instant) are read in the local zone, which is the day that was
/// picked unless the phone has since changed zone.
DateTime dayOf(DateTime stored) {
  final u = stored.toUtc();
  final midnight =
      u.hour == 0 &&
      u.minute == 0 &&
      u.second == 0 &&
      u.millisecond == 0 &&
      u.microsecond == 0;
  if (midnight) return DateTime.utc(u.year, u.month, u.day);
  final l = stored.toLocal();
  return DateTime.utc(l.year, l.month, l.day);
}

/// Today on the phone's calendar, as a [calendarDay]. [now] is read in
/// the local zone — a test's `DateTime(2026, 9, 25)` is 25 September.
DateTime today({DateTime? now}) {
  final l = (now ?? DateTime.now()).toLocal();
  return DateTime.utc(l.year, l.month, l.day);
}

/// [days] later on the calendar. Calendar arithmetic in UTC has no DST:
/// local midnight plus 183 × 24 h is 23:00 the day before once a clock
/// change falls in between.
DateTime addDays(DateTime day, int days) {
  final d = dayOf(day);
  return DateTime.utc(d.year, d.month, d.day + days);
}

/// Whole calendar days from [from] to [to]; negative when [to] is earlier.
int daysBetween(DateTime from, DateTime to) =>
    dayOf(to).difference(dayOf(from)).inDays;
