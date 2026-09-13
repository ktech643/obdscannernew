import 'dart:collection';

/// One thing said to the adapter, or heard back.
///
/// SPEC §10.4: timestamp, direction, raw, parsed, latency. The raw text is
/// kept exactly as it went over the wire, prompt and all, because the point
/// of the log is to see what a clone actually did — a cleaned-up version is
/// worth nothing to the person reading it.
class ProtocolEvent {
  const ProtocolEvent({
    required this.at,
    required this.outbound,
    required this.raw,
    this.parsed,
    this.latencyMs,
  });

  final DateTime at;

  /// True for a command, false for the reply.
  final bool outbound;

  /// The command as written (without its `\r`), or the reply as received.
  final String raw;

  /// What the parser made of a reply — a status word, a decoded value — or
  /// null for a command and for a reply nobody decoded.
  final String? parsed;

  /// Reply only: command written → prompt seen.
  final int? latencyMs;

  @override
  String toString() =>
      '${outbound ? '→' : '←'} $raw'
      '${parsed == null ? '' : '  ($parsed)'}'
      '${latencyMs == null ? '' : '  ${latencyMs}ms'}';
}

/// SPEC §10.4 — the in-app diagnostics log. "This is your entire support
/// infrastructure."
///
/// A ring of the last [capacity] events. Pure Dart, no Flutter: it is fed
/// from inside the protocol layer, and it holds *only* what went over the
/// wire — nothing here is generated, summarised or guessed. A log that
/// showed events which never happened would be worse than no log, which is
/// exactly what the earlier screen did.
///
/// Rendering masks the VIN (§10.4) unless the caller opts out, and does so
/// in the *raw* text too: a Mode 09 reply carries the VIN as hex-encoded
/// ASCII, so a text search for the VIN would miss it while a mechanic with
/// a hex table would not.
class ProtocolLog {
  ProtocolLog({this.capacity = 500}) : assert(capacity > 0);

  final int capacity;
  final ListQueue<ProtocolEvent> _events = ListQueue();

  int _dropped = 0;

  /// Oldest first.
  List<ProtocolEvent> get events => List.unmodifiable(_events);
  int get length => _events.length;
  bool get isEmpty => _events.isEmpty;

  /// How many events fell off the front since the last [clear]. Shown, so
  /// a log that starts mid-conversation is not read as the whole of it.
  int get dropped => _dropped;

  final List<void Function()> _listeners = [];

  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);

  void _notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void add(ProtocolEvent e) {
    if (_events.length == capacity) {
      _events.removeFirst();
      _dropped++;
    }
    _events.addLast(e);
    _notify();
  }

  void command(String raw, {DateTime? at}) =>
      add(ProtocolEvent(at: at ?? DateTime.now(), outbound: true, raw: raw));

  void reply(String raw, {String? parsed, int? latencyMs, DateTime? at}) => add(
    ProtocolEvent(
      at: at ?? DateTime.now(),
      outbound: false,
      raw: raw,
      parsed: parsed,
      latencyMs: latencyMs,
    ),
  );

  void clear() {
    _events.clear();
    _dropped = 0;
    _notify();
  }

  // ------------------------------------------------------------ rendering

  /// The log as plain text, for Copy and Share.
  ///
  /// [vin] is the VIN to mask, when one is known; with [includeVin] the
  /// text goes out whole. Masking replaces the middle of the VIN with dots
  /// wherever it appears — as ASCII, and as the hex bytes a Mode 09 reply
  /// actually contains.
  String render({String? vin, bool includeVin = false, String? header}) {
    final lines = <String>[
      ?header,
      if (_dropped > 0) '… $_dropped earlier events not kept',
      for (final e in _events) _line(e),
    ];
    var text = lines.join('\n');
    if (vin != null && !includeVin) text = maskVinIn(text, vin);
    return text;
  }

  static String _line(ProtocolEvent e) {
    final t = e.at.toLocal();
    final stamp =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${(t.millisecond ~/ 100)}';
    final raw = e.raw.replaceAll('\r', '⏎').replaceAll('\n', '');
    return '$stamp  ${e.outbound ? '→' : '←'}  $raw'
        '${e.parsed == null ? '' : '  · ${e.parsed}'}'
        '${e.latencyMs == null ? '' : '  ${e.latencyMs} ms'}';
  }

  /// `1HGBH41JXMN109186` → `1HG••••••••••9186`, applied to the plain text
  /// and to its hex encoding, spaced or unspaced, upper or lower case.
  ///
  /// A window that touches the disclosed prefix or suffix — the whole VIN,
  /// or a fragment of it that happens to include those characters — is
  /// allowed to keep just those; a window entirely inside the masked
  /// interior is always fully masked.
  ///
  /// **Every distinct hex-byte run gets exactly one answer, decided
  /// before any text is touched.** Different positions in the VIN can
  /// hex-encode to the identical byte run — this happens whenever the VIN
  /// has a repeated ≥3-character substring and one copy sits next to the
  /// disclosed prefix or suffix while another sits entirely in the masked
  /// interior — and a text-replace cannot tell which physical occurrence
  /// it is looking at. An earlier version let whichever window's replace
  /// ran first win, which on a fragmented reply (a K-line frame can carry
  /// as few as three VIN characters between its headers) let real interior
  /// digits survive. Fixed by resolving every run's answer in one map
  /// first: if two positions that produce the same bytes disagree on the
  /// answer, the ambiguous run is masked in full — over-masking a few
  /// bytes is the side to be wrong on; a partial reveal is not.
  static String maskVinIn(String text, String vin) {
    if (vin.length < 8) return text;
    final masked =
        '${vin.substring(0, 3)}${'•' * (vin.length - 7)}'
        '${vin.substring(vin.length - 4)}';
    var out = text.replaceAll(vin, masked);

    // The hex form: each character as two hex digits, optionally separated
    // by single spaces, and possibly split across ISO-TP frame boundaries
    // where a header and PCI byte sit between fragments.
    final hexChars = [
      for (final c in vin.codeUnits) c.toRadixString(16).padLeft(2, '0'),
    ];
    final n = vin.length;

    // key: the exact hex bytes of a candidate run, joined with no
    // separator — the run's identity, independent of how it is written in
    // the text. value: the single settled reveal/mask pattern for it.
    final settled = <String, List<String>>{};

    bool sameAnswer(List<String> a, List<String> b) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    // Mask every run of ≥ 3 consecutive VIN characters' hex bytes. Three,
    // because a legacy 4-byte K-line frame can carry as few as three VIN
    // characters between its headers; one or two would clobber unrelated
    // bytes that merely share a value with a character.
    for (var len = n; len >= 3; len--) {
      for (var start = 0; start + len <= n; start++) {
        if (start < 3 && start + len <= 3) continue; // the kept prefix alone
        if (start >= n - 4) continue; // the kept suffix alone
        final key = hexChars.sublist(start, start + len).join();
        final answer = [
          for (var i = 0; i < len; i++)
            (start + i < 3 || start + i >= n - 4) ? hexChars[start + i] : '••',
        ];
        final existing = settled[key];
        settled[key] = existing == null || sameAnswer(existing, answer)
            ? answer
            : List.filled(len, '••'); // two positions disagree — mask both
      }
    }

    for (final entry in settled.entries) {
      final run = [for (var i = 0; i < entry.key.length; i += 2) entry.key.substring(i, i + 2)];
      for (final sep in const [' ', '']) {
        final needle = run.join(sep);
        final repl = entry.value.join(sep);
        out = out.replaceAll(needle, repl);
        out = out.replaceAll(needle.toUpperCase(), repl.toUpperCase());
      }
    }
    return out;
  }
}
