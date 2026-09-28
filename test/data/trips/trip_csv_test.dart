import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:torque_obd2/data/db/tables.dart';
import 'package:torque_obd2/data/trips/trip_csv.dart';
import 'package:torque_obd2/protocol/pid_registry.dart';
import 'package:torque_obd2/session/gauge_catalog.dart';

import '../support.dart';

/// The trip CSV, version 1 — the grammar the recorder writes and the reader
/// that turns a file back into a row's figures after a kill (§9.2, AC-09).
void main() {
  final start = t0;
  final startMs = start.millisecondsSinceEpoch;
  final later = startMs + const Duration(hours: 14).inMilliseconds;

  /// [s] seconds after the start, on an honest wall clock.
  DateTime sec(int s) => start.add(Duration(seconds: s));

  TripFileSummary read(String content) =>
      TripCsv.summarize(content, startedAtMs: startMs, nowMs: later);

  test('the header is 30 bytes of ASCII', () {
    expect(TripCsv.header, '#torque-trip,1\nt_ms,pid,value\n');
    expect(TripCsv.header.length, 30);
  });

  test('★ a null is an empty field, never 0', () {
    // Hard rule 5: NO DATA is absence. '0', '0.0' or 'null' would each
    // read back as a reading (or, for 'null', as a malformed row).
    expect(TripCsv.row(12, '010D', null), '12,010D,\n');
    expect(TripCsv.row(12, '010D', double.nan), '12,010D,\n');
    expect(TripCsv.row(12, '010D', double.infinity), '12,010D,\n');
    expect(TripCsv.row(12, '010D', 0), '12,010D,0.0\n', reason: 'zero is');
    final s = read(
      '${TripCsv.header}${TripCsv.segment(0, start)}'
      '${TripCsv.row(0, '010D', 50)}${TripCsv.row(1000, '010D', null)}'
      '${TripCsv.row(2000, '010D', 50)}',
    );
    expect(s.rows, 3);
    expect(s.malformed, 0);
    expect(s.totals.distanceKm, 0.0, reason: 'nothing bridged over absence');
  });

  test('★ values are locale-free', () {
    // §9.7 comma-decimal locales: '1,010D,12,4' would be four fields.
    final was = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = was);
    Intl.defaultLocale = 'de_DE';
    expect(TripCsv.row(1, '010D', 12.4), '1,010D,12.4\n');
    expect(TripCsv.row(2, '015E', 1234.5), '2,015E,1234.5\n');
    // Round-trips exactly: the registry's decodes are not rounded on disk.
    const v = 12.941176470588236;
    final line = TripCsv.row(3, '0105', v);
    expect(double.parse(line.trim().split(',').last), v);
  });

  test('★ a torn last line is not a sample', () {
    // AC-09: a kill mid-write leaves '123,010D,6' where '123,010D,68.0'
    // was going. Read as a row it would be 6 km/h.
    const good = '${TripCsv.header}0,010D,68.0\n100,010D,68.0\n';
    final s = read('${good}123,010D,6');
    expect(s.rows, 2);
    expect(s.malformed, 0);
    expect(s.committedBytes, good.length);
    expect(s.fileBytes, good.length + '123,010D,6'.length);
    expect(s.totals.maxSpeedKph, 68.0);
    expect(s.endT, 100);
  });

  test('★ endedAt comes from the last anchor, not from now or the start', () {
    // §9.2/§9.7: the trip was killed at t = 90 s; the phone's clock was
    // set back a minute at 85 s, so the '#sync' there says so. The row's
    // end is that anchor plus 5 s of monotonic time — not the relaunch 14 h
    // later, and not startedAt + 90 s, which ignores the step.
    String file(Duration stepBack) {
      final b = StringBuffer(TripCsv.header)..write(TripCsv.segment(0, start));
      for (var t = 0; t <= 90000; t += 1000) {
        b.write(TripCsv.row(t, '010D', 36));
        if (t == 85000) {
          b.write(
            TripCsv.sync(
              t,
              start.add(Duration(milliseconds: t)).subtract(stepBack),
            ),
          );
        }
      }
      return b.toString();
    }

    final minute = read(file(const Duration(minutes: 1)));
    expect(minute.endT, 90000);
    expect(minute.endedAtUtc, start.add(const Duration(seconds: 30)));
    expect(minute.endedAtUtc.isUtc, isTrue);

    // An hour back maps before the start: clamped, never earlier.
    final hour = read(file(const Duration(hours: 1)));
    expect(hour.endedAtUtc, start);

    // And never after now.
    final early = TripCsv.summarize(
      file(Duration.zero),
      startedAtMs: startMs,
      nowMs: startMs + 60000,
    );
    expect(early.endedAtUtc, start.add(const Duration(minutes: 1)));
  });

  test('★ a version it does not know gives no figures', () {
    final s = read(
      '#torque-trip,2\nt_ms,pid,value\n#segment,0,$startMs\n'
      '0,010D,50.0\n1000,010D,50.0\n',
    );
    expect(s.version, 0);
    expect(s.rows, 0);
    expect(s.totals.distanceKm, isNull);
    expect(s.totals.maxSpeedKph, isNull);
    expect(s.endT, 0);
  });

  test('#end sets the reason; a later #segment clears it', () {
    final ended =
        '${driveCsv(start, toMs: 10000)}'
        '${TripCsv.end(10000, sec(10), TripEnd.linkLost)}';
    final s = read(ended);
    expect(s.end, TripEnd.linkLost);
    expect(s.endT, 10000);
    expect(s.endedAtUtc, start.add(const Duration(seconds: 10)));

    // Resumed: the segment starts at the old end and the reason is gone.
    final resumeAt = start.add(const Duration(minutes: 20));
    final resumed = read(
      '$ended${TripCsv.segment(10000, resumeAt)}'
      '${TripCsv.row(10500, '010D', 36)}${TripCsv.row(11500, '010D', 36)}',
    );
    expect(resumed.end, isNull);
    expect(resumed.endT, 11500);
    expect(resumed.rows, 13);
    expect(resumed.malformed, 0);
    expect(
      resumed.endedAtUtc,
      resumeAt.add(const Duration(milliseconds: 1500)),
    );
    // 10 s + 1 s at 36 km/h; the 20 minutes between are not a drive.
    expect(resumed.totals.distanceKm, closeTo(0.11, 1e-12));
  });

  test('rows after #end with no new segment are malformed', () {
    final s = read(
      '${driveCsv(start, toMs: 3000)}'
      '${TripCsv.end(3000, sec(3), TripEnd.stopped)}'
      '${TripCsv.row(4000, '010D', 36)}',
    );
    expect(s.rows, 4);
    expect(s.malformed, 1);
    expect(s.end, TripEnd.stopped);
  });

  test('an end at the last row after a hold\'s syncs is not malformed', () {
    // The link is lost at 3 s: the recorder keeps syncing through the hold
    // and gives up at its last row. '#end' is older than the syncs.
    final s = read(
      '${driveCsv(start, toMs: 3000)}'
      '${TripCsv.sync(5000, sec(5))}'
      '${TripCsv.sync(10000, sec(10))}'
      '${TripCsv.end(3000, sec(3), TripEnd.linkLost)}',
    );
    expect(s.malformed, 0);
    expect(s.end, TripEnd.linkLost);
    expect(s.endT, 3000);
    expect(s.endedAtUtc, start.add(const Duration(seconds: 3)));
  });

  test('what breaks the grammar is counted and skipped', () {
    final s = read(
      '${TripCsv.header}${TripCsv.segment(0, start)}'
      '1000,010D,50.0\n'
      '900,010D,50.0\n' // t went back
      '1100,0D,50.0\n' // not a PidBus key
      '1200,010d,50.0\n' // lower case
      '1300,010D,50,0\n' // four fields: a comma decimal
      '1400,010D,NaN\n' // not finite
      '-5,010D,50.0\n' // negative t
      '0x600,010D,50.0\n' // not base 10
      '#pause,1500\n' // unknown '#' line: skipped, not counted
      '#sync,x,1\n' // broken anchor
      '#end,1500,$startMs,exploded\n' // not a TripEnd
      '2000,010D,\n', // empty: a null, and fine
    );
    expect(s.rows, 2);
    expect(s.malformed, 9);
    expect(s.end, isNull);
    expect(s.endT, 2000);
  });

  test('every PID the app knows fits the file', () {
    for (final pid in {
      for (final d in PidRegistry.all) d.pid,
      ...GaugeCatalog.gaugeable,
      ...GaugeCatalog.defaultLayout,
      ...GaugeCatalog.pickerOrder,
    }) {
      expect(TripCsv.isPid(pid), isTrue, reason: pid);
      expect(RegExp(r'^[0-9A-F]{4}$').hasMatch(pid), isTrue, reason: pid);
    }
    for (final bad in ['0C', '010d', '010G', '0100 ', '01 0C', '']) {
      expect(TripCsv.isPid(bad), isFalse, reason: bad);
    }
  });

  group('the file reader', () {
    late Directory dir;
    setUp(() async => dir = await scratchDir());
    tearDown(() => dir.delete(recursive: true));

    test('reads what the string reader reads, across any chunking', () async {
      final content =
          '${driveCsv(start, toMs: 30000, kph: (t) => t % 7000 == 0 ? null : t / 1000)}'
          '31000,010D,6';
      final f = File('${dir.path}/a.csv')..writeAsStringSync(content);
      final whole = read(content);
      for (final chunk in [1, 2, 7, 29, 64 * 1024]) {
        final s = TripCsv.summarizeFileSync(
          f.path,
          startedAtMs: startMs,
          nowMs: later,
          chunkBytes: chunk,
        );
        expect(s.toString(), whole.toString(), reason: 'chunk $chunk');
        expect(s.committedBytes, content.length - '31000,010D,6'.length);
      }
    });

    test('summarizeTripFile runs the reader in an isolate', () async {
      final f = File('${dir.path}/b.csv')
        ..writeAsStringSync(driveCsv(start, toMs: 10000));
      final s = await summarizeTripFile(
        f.path,
        startedAtMs: startMs,
        nowMs: later,
      );
      expect(s.rows, 11);
      expect(s.totals.distanceKm, closeTo(0.1, 1e-12));
      expect(s.endedAtUtc, start.add(const Duration(seconds: 10)));
    });
  });
}
