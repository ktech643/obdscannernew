/// The `.obdtrace` format — a recorded conversation with a real adapter.
///
/// This is the backbone of the whole test strategy. A trace gives you:
/// * the protocol engine tested end to end with no device and no car
/// * deterministic CI on every commit
/// * a support workflow — a user emails a trace, you replay their exact
///   failure locally
/// * Demo Mode for store review, driven by the same code path as a real car
///
/// ```
/// # torque.obdtrace v1
/// # vehicle: 2014 Honda Civic 1.8 petrol
/// # adapter: Vgate iCar Pro BLE 4.0
/// # protocol: 6 (ISO 15765-4 CAN 11/500)
/// T+0000  > ATZ
/// T+0983  < ELM327 v1.5\r\r>
/// ```
library;

enum TraceDirection { request, response }

class TraceEvent {
  const TraceEvent({
    required this.offset,
    required this.direction,
    required this.payload,
  });

  /// Milliseconds since the start of the recording.
  final Duration offset;
  final TraceDirection direction;

  /// Unescaped. `\r` in the file is a real carriage return here.
  final String payload;

  bool get isRequest => direction == TraceDirection.request;
}

class ObdTrace {
  const ObdTrace({
    required this.events,
    this.vehicle,
    this.adapter,
    this.protocol,
    this.notes,
  });

  final List<TraceEvent> events;
  final String? vehicle;
  final String? adapter;
  final String? protocol;
  final String? notes;

  /// Requests in the order they were recorded.
  List<String> get commands => [
    for (final e in events)
      if (e.isRequest) e.payload,
  ];

  /// Command → every reply it received, in recording order.
  ///
  /// A command sent N times gets its Nth recorded answer, then holds the last
  /// one. That is what lets a trace say "the second 010C returned LV RESET"
  /// or "0100 failed once, then succeeded" — and lets a polling loop run past
  /// the end of the recording on a stable value.
  Map<String, List<String>> get repliesByCommand {
    final map = <String, List<String>>{};
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (!event.isRequest) continue;
      final next = i + 1 < events.length ? events[i + 1] : null;
      if (next == null || next.isRequest) continue; // unanswered
      map.putIfAbsent(normalise(event.payload), () => []).add(next.payload);
    }
    return map;
  }

  /// The recorded gap between each send and its reply, parallel to
  /// [repliesByCommand], so replay reproduces the adapter's real latency.
  Map<String, List<Duration>> get latenciesByCommand {
    final map = <String, List<Duration>>{};
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (!event.isRequest) continue;
      final next = i + 1 < events.length ? events[i + 1] : null;
      if (next == null || next.isRequest) continue;
      map
          .putIfAbsent(normalise(event.payload), () => [])
          .add(next.offset - event.offset);
    }
    return map;
  }

  /// Commands the adapter never answered — a timeout in the recording.
  Set<String> get unansweredCommands => {
    for (var i = 0; i < events.length; i++)
      if (events[i].isRequest &&
          (i + 1 >= events.length || events[i + 1].isRequest))
        normalise(events[i].payload),
  };

  static String normalise(String command) =>
      command.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');

  static final _eventPattern = RegExp(r'^T\+(\d+)\s+([<>])\s?(.*)$');

  static ObdTrace parse(String source) {
    final events = <TraceEvent>[];
    String? vehicle, adapter, protocol, notes;

    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        final body = line.substring(1).trim();
        final colon = body.indexOf(':');
        if (colon < 0) continue;
        final key = body.substring(0, colon).trim().toLowerCase();
        final value = body.substring(colon + 1).trim();
        switch (key) {
          case 'vehicle':
            vehicle = value;
          case 'adapter':
            adapter = value;
          case 'protocol':
            protocol = value;
          case 'notes':
            notes = value;
        }
        continue;
      }

      final match = _eventPattern.firstMatch(line);
      if (match == null) continue;

      events.add(
        TraceEvent(
          offset: Duration(milliseconds: int.parse(match.group(1)!)),
          direction: match.group(2) == '>'
              ? TraceDirection.request
              : TraceDirection.response,
          payload: unescape(match.group(3)!),
        ),
      );
    }

    return ObdTrace(
      events: events,
      vehicle: vehicle,
      adapter: adapter,
      protocol: protocol,
      notes: notes,
    );
  }

  /// `\r`, `\n` and `\\` in the file become real characters.
  static String unescape(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (s[i] != r'\' || i + 1 >= s.length) {
        out.write(s[i]);
        continue;
      }
      i++;
      switch (s[i]) {
        case 'r':
          out.write('\r');
        case 'n':
          out.write('\n');
        case '\\':
          out.write(r'\');
        default:
          out
            ..write(r'\')
            ..write(s[i]);
      }
    }
    return out.toString();
  }

  static String escape(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('\r', r'\r').replaceAll('\n', r'\n');
}
