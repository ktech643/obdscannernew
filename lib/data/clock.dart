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
