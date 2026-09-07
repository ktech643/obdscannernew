import 'elm_session.dart';
import 'response_parser.dart';

/// One rung of the protocol ladder.
class ObdProtocol {
  const ObdProtocol(this.number, this.name, {this.slowInit = false});

  /// The `ATSPn` argument, and what `ATDPN` reports back.
  final int number;
  final String name;

  /// K-line protocols take seconds to initialise. Giving them a CAN-sized
  /// timeout is why so many apps declare an older car "unsupported".
  final bool slowInit;

  Duration get probeTimeout =>
      slowInit ? const Duration(seconds: 12) : const Duration(seconds: 5);
}

/// The result of bringing a session up.
class HandshakeResult {
  const HandshakeResult({
    required this.ok,
    this.protocol,
    this.adapterIdentity,
    this.batteryVolts,
    this.failedAtStep,
    this.status,
    this.headersUnavailable = false,
    this.echoActive = false,
    this.supportFrames = const [],
  });

  final bool ok;
  final ObdProtocol? protocol;
  final String? adapterIdentity;
  final double? batteryVolts;

  /// 1–7, for the "Setting up — step n of 7" progress the user sees.
  final int? failedAtStep;
  final ElmStatus? status;

  final bool headersUnavailable;
  final bool echoActive;

  /// The raw frames of the `0100` probe that proved the car is listening.
  ///
  /// Two things depend on these. They *are* the first support bitmask, so a
  /// caller never has to ask `0100` a second time — one fewer round trip on
  /// every connect, and the reason a recorded session only ever contains
  /// one. And because the shape of a `4100` reply is known, they are also
  /// the one sample against which a caller can work out how wide this
  /// adapter's headers actually are, rather than trusting that `ATH1` did
  /// what it said.
  final List<String> supportFrames;
}

/// Brings an ELM327 session up and finds the vehicle's protocol.
class ProtocolNegotiator {
  /// Frames of the successful `0100`, handed back in the result.
  List<String> _supportFrames = const [];

  ProtocolNegotiator(this._session);

  final ElmSession _session;

  /// SPEC §4.2, ordered by how likely each is to be the answer. CAN 11-bit
  /// 500k covers roughly 99% of vehicles built since 2008, so it is tried
  /// first and everything else is a fallback.
  static const ladder = <ObdProtocol>[
    ObdProtocol(6, 'ISO 15765-4 CAN 11-bit 500k'),
    ObdProtocol(7, 'ISO 15765-4 CAN 29-bit 500k'),
    ObdProtocol(8, 'ISO 15765-4 CAN 11-bit 250k'),
    ObdProtocol(9, 'ISO 15765-4 CAN 29-bit 250k'),
    ObdProtocol(5, 'ISO 14230-4 KWP fast init'),
    ObdProtocol(4, 'ISO 14230-4 KWP 5-baud', slowInit: true),
    ObdProtocol(3, 'ISO 9141-2', slowInit: true),
    ObdProtocol(1, 'SAE J1850 PWM'),
    ObdProtocol(2, 'SAE J1850 VPW'),
  ];

  /// The seven steps the user sees as progress.
  static const steps = <({String command, String label})>[
    (command: 'ATZ', label: 'Reset adapter'),
    (command: 'ATE0', label: 'Echo off'),
    (command: 'ATL0', label: 'Linefeeds off'),
    (command: 'ATS0', label: 'Spaces off'),
    (command: 'ATH1', label: 'Headers on'),
    (command: 'ATSP0', label: 'Find the protocol'),
    (command: '0100', label: 'Talk to the engine computer'),
  ];

  /// Runs the handshake.
  ///
  /// [cachedProtocol] skips negotiation when this vehicle has connected
  /// before — it cuts reconnect from ~20 s to ~3 s and is the single biggest
  /// perceived-speed win in the app.
  Future<HandshakeResult> handshake({
    int? cachedProtocol,
    void Function(int step, String label)? onProgress,
  }) async {
    var echoActive = false;
    var headersUnavailable = false;

    // Step 1 — ATZ. Some adapters need up to a second of silence first, so
    // the delay escalates rather than being a fixed guess.
    var reset = await _resetWithEscalatingDelay();
    if (reset == null) {
      return const HandshakeResult(
        ok: false,
        failedAtStep: 1,
        status: ElmStatus.timeout,
      );
    }
    onProgress?.call(1, steps[0].label);

    // Steps 2–5. Failures here are tolerable: the parser compensates.
    for (var i = 1; i <= 4; i++) {
      final response = await _session.send(steps[i].command);
      if (steps[i].command == 'ATE0' && !response.isOk) echoActive = true;
      if (steps[i].command == 'ATH1' && !response.isOk) {
        headersUnavailable = true;
      }
      onProgress?.call(i + 1, steps[i].label);
    }
    _session
      ..echoActive = echoActive
      ..headersUnavailable = headersUnavailable;

    // Step 6 — protocol. A cached number skips the search entirely.
    ObdProtocol? protocol;
    if (cachedProtocol != null) {
      final cached = ladder
          .where((p) => p.number == cachedProtocol)
          .firstOrNull;
      if (cached != null && await _probe(cached)) protocol = cached;
    }
    protocol ??= await _autoNegotiate(onProgress: onProgress);
    onProgress?.call(6, steps[5].label);

    if (protocol == null) {
      return HandshakeResult(
        ok: false,
        failedAtStep: 6,
        status: ElmStatus.noEcu,
        headersUnavailable: headersUnavailable,
        echoActive: echoActive,
      );
    }

    onProgress?.call(7, steps[6].label);

    // Opportunistic and non-blocking: a failure here doesn't fail the session.
    final volts = await _batteryVolts();

    return HandshakeResult(
      ok: true,
      protocol: protocol,
      adapterIdentity: reset.trim(),
      batteryVolts: volts,
      headersUnavailable: headersUnavailable,
      echoActive: echoActive,
      supportFrames: _supportFrames,
    );
  }

  /// Escalating pre-write delay. A fixed sleep is either too short for slow
  /// clones or wasted time for good adapters.
  Future<String?> _resetWithEscalatingDelay() async {
    for (final delayMs in [0, 250, 500, 1000]) {
      if (delayMs > 0) {
        await Future<void>.delayed(
          _session.scaled(Duration(milliseconds: delayMs)),
        );
      }
      final response = await _session.send(
        'ATZ',
        timeout: ElmSession.slowTimeout,
      );
      if (response.isOk && response.raw.trim().isNotEmpty) return response.raw;
    }
    // Last resort: a warm start, which some adapters accept when ATZ hangs.
    final warm = await _session.send('ATWS', timeout: ElmSession.slowTimeout);
    return warm.isOk && warm.raw.trim().isNotEmpty ? warm.raw : null;
  }

  /// `ATSP0` first; if auto-detect can't settle, walk the ladder explicitly.
  Future<ObdProtocol?> _autoNegotiate({
    void Function(int step, String label)? onProgress,
  }) async {
    await _session.send('ATSP0');
    if (await _probe(const ObdProtocol(0, 'auto'))) {
      final reported = await _session.send('ATDPN');
      final number = _parseProtocolNumber(reported.raw);
      return ladder.where((p) => p.number == number).firstOrNull ??
          const ObdProtocol(0, 'auto');
    }

    for (var i = 0; i < ladder.length; i++) {
      final candidate = ladder[i];
      onProgress?.call(6, 'Trying protocol ${i + 1} of ${ladder.length}');
      await _session.send('ATSP${candidate.number}');
      if (await _probe(candidate)) return candidate;
    }
    return null;
  }

  /// `0100` is the real connectivity test — everything before it only proves
  /// the adapter is alive, not that a car is listening.
  Future<bool> _probe(ObdProtocol protocol) async {
    final response = await _session.send(
      '0100',
      timeout: protocol.probeTimeout,
    );
    if (response.status == ElmStatus.searching) {
      // Negotiation is still running. Wait it out rather than queueing a
      // second command behind one that is still live.
      final retry = await _session.send(
        '0100',
        timeout: const Duration(seconds: 10),
      );
      return _accept(retry);
    }
    return _accept(response);
  }

  bool _accept(ElmResponse r) {
    if (!_isPositive(r)) return false;
    _supportFrames = r.frames;
    return true;
  }

  static bool _isPositive(ElmResponse r) =>
      r.isOk && r.frames.any((f) => f.contains('4100'));

  /// `ATDPN` returns e.g. `A6` (auto, protocol 6) or `6`.
  static int? _parseProtocolNumber(String raw) {
    final match = RegExp(r'A?([0-9A-C])').firstMatch(raw.trim().toUpperCase());
    if (match == null) return null;
    return int.tryParse(match.group(1)!, radix: 16);
  }

  Future<double?> _batteryVolts() async {
    final response = await _session.send('ATRV');
    final match = RegExp(r'(\d+\.?\d*)\s*V?').firstMatch(response.raw);
    if (match == null) return null;
    final volts = double.tryParse(match.group(1)!);
    // A reading outside this range is a misparse, not a car.
    if (volts == null || volts < 4 || volts > 32) return null;
    return volts;
  }
}
