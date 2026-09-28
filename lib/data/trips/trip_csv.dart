import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../db/tables.dart';
import 'trip_stats.dart';

/// The trip CSV, version 1: the grammar the recorder writes and the one
/// reader that turns a file back into figures. Pure Dart plus `dart:io`,
/// so the reader runs inside `Isolate.run` (§9.3: isolates for pure
/// computation only).
///
/// `trips/<id>.csv` is US-ASCII, LF only, no BOM, no quoting, so a string's
/// length is its byte count:
///
/// ```text
/// #torque-trip,1                  format and version (TripRepository.start)
/// t_ms,pid,value                  column names (also start)
/// #segment,<t_ms>,<utc_ms>        first line of every segment
/// <t_ms>,<pid>,<value>            one sample
/// #sync,<t_ms>,<utc_ms>           before every fsync
/// #end,<t_ms>,<utc_ms>,<reason>   the recorder ended it; reason is a TripEnd
/// ```
///
/// `t_ms` is recorded time on a monotonic clock — a DST change or a clock
/// set by hand never moves it (§9.7) — and continues across a Resume. The
/// anchors map it to wall-clock time: `utc_ms` is UTC epoch ms taken at
/// that `t`. `value` is `double.toString()` in the registry's own metric
/// unit — locale-free, so a comma decimal can never split a row — and
/// empty when the car sent no value (hard rule 5).
///
/// Data rows never go back in time, Resume included. Anchors may: the
/// recorder syncs through a hold and then ends — or a Resume starts — at
/// the last row, which is older than those syncs. So an anchor only has to
/// be no older than the last row before it.
abstract final class TripCsv {
  static const version = 1;
  static const magic = '#torque-trip,$version';
  static const columns = 't_ms,pid,value';

  /// What [TripRepository.start] writes and fsyncs before anything else.
  static const header = '$magic\n$columns\n';

  /// The rows a Resume must continue after. [TripStats]' chains break here.
  static const segmentTag = '#segment';
  static const syncTag = '#sync';
  static const endTag = '#end';

  /// A PidBus key the file accepts: Mode 01 + PID, four uppercase hex
  /// digits (`010D`). Anything else is never written and never read.
  static bool isPid(String pid) {
    if (pid.length != 4) return false;
    for (var i = 0; i < 4; i++) {
      final c = pid.codeUnitAt(i);
      if (!(c >= 0x30 && c <= 0x39) && !(c >= 0x41 && c <= 0x46)) return false;
    }
    return true;
  }

  /// One sample. A null or non-finite value is an empty field — never `0`,
  /// `0.0` or `null`, each of which would read back as a reading.
  static String row(int t, String pid, double? v) =>
      v == null || !v.isFinite ? '$t,$pid,\n' : '$t,$pid,$v\n';

  static String segment(int t, DateTime at) =>
      '$segmentTag,$t,${at.millisecondsSinceEpoch}\n';

  static String sync(int t, DateTime at) =>
      '$syncTag,$t,${at.millisecondsSinceEpoch}\n';

  static String end(int t, DateTime at, TripEnd reason) =>
      '$endTag,$t,${at.millisecondsSinceEpoch},${reason.name}\n';

  /// The figures [content] holds. [startedAtMs] is the row's start, used
  /// when no anchor exists; [nowMs] caps the end time.
  static TripFileSummary summarize(
    String content, {
    required int startedAtMs,
    required int nowMs,
  }) {
    final p = _Parser()..feed(content);
    return p.finish(
      fileBytes: content.length,
      startedAtMs: startedAtMs,
      nowMs: nowMs,
    );
  }

  /// [summarize] over the file at [path], read in [chunkBytes] pieces so a
  /// three-hour trip never has to fit in one string twice. Throws a
  /// [FileSystemException] when the file cannot be read.
  static TripFileSummary summarizeFileSync(
    String path, {
    required int startedAtMs,
    required int nowMs,
    int chunkBytes = 64 * 1024,
  }) {
    final raf = File(path).openSync();
    try {
      final p = _Parser();
      final buf = Uint8List(chunkBytes);
      var total = 0;
      while (true) {
        final n = raf.readIntoSync(buf);
        if (n <= 0) break;
        total += n;
        // latin1, not ascii: one char per byte whatever a damaged file
        // holds, so offsets stay byte offsets and nothing throws.
        p.feed(latin1.decode(Uint8List.sublistView(buf, 0, n)));
      }
      return p.finish(fileBytes: total, startedAtMs: startedAtMs, nowMs: nowMs);
    } finally {
      raf.closeSync();
    }
  }
}

/// What a trip file says. [committedBytes] is the offset just past the last
/// LF: whatever follows it is a line torn by a kill mid-write, which is
/// never a sample and is cut off before the file is appended to again.
class TripFileSummary {
  const TripFileSummary({
    required this.version,
    required this.committedBytes,
    required this.fileBytes,
    required this.rows,
    required this.malformed,
    required this.endT,
    required this.end,
    required this.endedAtUtc,
    required this.totals,
  });

  /// 1 for a file this reader knows; 0 for anything else, which yields no
  /// rows and no figures — never a misread.
  final int version;
  final int committedBytes;
  final int fileBytes;
  final int rows;

  /// Lines that broke the grammar and were skipped.
  final int malformed;

  /// Recorded time at the end: the `#end` line's `t`, else the last row's,
  /// else the last anchor's, else 0. A Resume continues from here.
  final int endT;

  /// The reason on a closing `#end` line — the app died after the recorder
  /// ended the trip and before its row was written. Null otherwise.
  final TripEnd? end;

  /// [endT] on the wall clock, mapped from the last anchor, so it is the
  /// moment of the last durable sample — not when the app next opened.
  /// Never before the start or after now.
  final DateTime endedAtUtc;
  final TripTotals totals;

  @override
  String toString() =>
      'TripFileSummary(v$version, $committedBytes/$fileBytes bytes, '
      'rows: $rows, malformed: $malformed, endT: $endT, end: $end, '
      'endedAt: $endedAtUtc, $totals)';
}

/// Summarises a trip file off the root isolate. Top-level, so the closure
/// captures only the path and two ints.
typedef TripSummarizer = Future<TripFileSummary> Function(
  String path, {
  required int startedAtMs,
  required int nowMs,
});

Future<TripFileSummary> summarizeTripFile(
  String path, {
  required int startedAtMs,
  required int nowMs,
}) => Isolate.run(
  () => TripCsv.summarizeFileSync(path, startedAtMs: startedAtMs, nowMs: nowMs),
);

/// Splits on LF itself. `LineSplitter` hands back the bytes after the last
/// LF as a line, and a torn `123,010D,6` would read as 6 km/h.
class _Parser {
  final _stats = TripStats();
  final _carry = StringBuffer();
  var _fed = 0;
  var _line = 0;
  var _version = 0;
  var _malformed = 0;

  /// Data rows (and segment starts) never go below this.
  var _rowFloor = 0;

  /// The last data row's t: no line after it may be older.
  int? _lastRowT;
  int? _anchorT;
  int? _anchorUtc;
  int? _endT;
  TripEnd? _end;

  void feed(String chunk) {
    _fed += chunk.length;
    var start = 0;
    while (true) {
      final lf = chunk.indexOf('\n', start);
      if (lf < 0) break;
      if (_carry.isEmpty) {
        _take(chunk.substring(start, lf));
      } else {
        _carry.write(chunk.substring(start, lf));
        _take(_carry.toString());
        _carry.clear();
      }
      start = lf + 1;
    }
    if (start < chunk.length) _carry.write(chunk.substring(start));
  }

  TripFileSummary finish({
    required int fileBytes,
    required int startedAtMs,
    required int nowMs,
  }) {
    // Whatever is in _carry had no LF: a torn line. It is not read.
    final committed = _fed - _carry.length;
    final known = _version == TripCsv.version;
    final totals = known ? _stats.totals : const TripTotals();
    final endT = !known ? 0 : _endT ?? _lastRowT ?? _anchorT ?? 0;
    var endedAt = known && _anchorT != null
        ? _anchorUtc! + (endT - _anchorT!)
        : startedAtMs + endT;
    if (endedAt > nowMs) endedAt = nowMs;
    if (endedAt < startedAtMs) endedAt = startedAtMs;
    return TripFileSummary(
      version: _version,
      committedBytes: committed,
      fileBytes: fileBytes,
      rows: totals.rows,
      malformed: known ? _malformed : 0,
      endT: endT,
      end: known ? _end : null,
      endedAtUtc: DateTime.fromMillisecondsSinceEpoch(endedAt, isUtc: true),
      totals: totals,
    );
  }

  void _take(String line) {
    _line++;
    if (_line == 1) {
      if (line == TripCsv.magic) _version = TripCsv.version;
      return;
    }
    if (_version != TripCsv.version) return;
    if (_line == 2 && line == TripCsv.columns) return;
    if (line.startsWith('#')) {
      _anchor(line);
    } else {
      _row(line);
    }
  }

  void _anchor(String line) {
    final f = line.split(',');
    final tag = f.first;
    if (tag != TripCsv.segmentTag &&
        tag != TripCsv.syncTag &&
        tag != TripCsv.endTag) {
      return; // Unknown '#' lines are skipped, not counted.
    }
    final isEnd = tag == TripCsv.endTag;
    final t = f.length == (isEnd ? 4 : 3) ? _uint(f[1]) : null;
    final utc = t == null ? null : _uint(f[2]);
    final reason = isEnd && utc != null
        ? TripEnd.values.asNameMap()[f[3]]
        : null;
    if (t == null ||
        utc == null ||
        (isEnd && reason == null) ||
        (_lastRowT != null && t < _lastRowT!)) {
      _malformed++;
      return;
    }
    _anchorT = t;
    _anchorUtc = utc;
    if (tag == TripCsv.segmentTag) {
      _stats.newSegment();
      _rowFloor = t;
      _end = null;
      _endT = null;
    } else if (isEnd) {
      _end = reason;
      _endT = t;
    }
  }

  void _row(String line) {
    final f = line.split(',');
    if (f.length != 3 || _end != null) {
      // Rows after '#end' with no new segment belong to no recording.
      _malformed++;
      return;
    }
    final t = _uint(f[0]);
    final pid = f[1];
    final raw = f[2];
    final v = raw.isEmpty ? null : double.tryParse(raw);
    if (t == null ||
        t < _rowFloor ||
        !TripCsv.isPid(pid) ||
        (raw.isNotEmpty && (v == null || !v.isFinite))) {
      _malformed++;
      return;
    }
    _rowFloor = t;
    _lastRowT = t;
    _stats.add(t, pid, v);
  }

  /// A base-10 integer ≥ 0 and nothing else: no sign, no space, no `0x`.
  static int? _uint(String s) {
    if (s.isEmpty || s.length > 15) return null;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return null;
    }
    return int.parse(s);
  }
}
