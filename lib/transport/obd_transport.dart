/// The transport abstraction.
///
/// Pure Dart by design: the protocol engine talks to this and nothing else, so
/// the whole of `lib/protocol/` can be unit-tested on the VM with no device,
/// no plugin, and no car. Swapping `flutter_blue_plus` for something else
/// costs one file, not a rewrite.
library;

enum TransportKind { ble, spp, wifi, mfi, mock }

enum TransportState { disconnected, connecting, connected, failed }

/// What a given transport can and can't do, so callers don't branch on
/// platform. BLE on Android negotiates MTU; on iOS it doesn't. Wi-Fi holds a
/// link in the background; BLE on iOS needs a background mode to.
class TransportCapabilities {
  const TransportCapabilities({
    required this.supportsMtuNegotiation,
    required this.supportsBackgroundHold,
    required this.typicalRttMs,
  });

  final bool supportsMtuNegotiation;
  final bool supportsBackgroundHold;

  /// Seeds the scheduler's budget before any real round trip is measured.
  final int typicalRttMs;

  static const ble = TransportCapabilities(
    supportsMtuNegotiation: true,
    supportsBackgroundHold: true,
    typicalRttMs: 90,
  );
  static const spp = TransportCapabilities(
    supportsMtuNegotiation: false,
    supportsBackgroundHold: true,
    typicalRttMs: 60,
  );
  static const wifi = TransportCapabilities(
    supportsMtuNegotiation: false,
    supportsBackgroundHold: true,
    typicalRttMs: 40,
  );
  static const mock = TransportCapabilities(
    supportsMtuNegotiation: false,
    supportsBackgroundHold: false,
    typicalRttMs: 1,
  );
}

abstract interface class ObdTransport {
  TransportKind get kind;

  /// Stable across reconnects and, where the platform allows, across installs.
  /// The reconnect ladder re-scans by this, not by a plugin handle — on iOS a
  /// peripheral identifier can change after an adapter brown-out.
  String get id;

  String get displayName;

  Stream<TransportState> get state;

  /// Raw bytes, in arrival order. No framing, no parsing — that is the
  /// session's job.
  Stream<List<int>> get inbound;

  /// Largest single write the link accepts. BLE starts at 20 bytes until MTU
  /// is negotiated, so every write must be chunked against this.
  int get maxWriteLength;

  TransportCapabilities get capabilities;

  Future<void> connect({Duration timeout});

  /// Implementations must chunk internally against [maxWriteLength].
  Future<void> write(List<int> bytes);

  Future<void> disconnect();
}
