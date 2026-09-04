import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'obd_transport.dart';

/// A paired Bluetooth Classic device, as Android Settings sees it.
class PairedDevice {
  const PairedDevice({
    required this.name,
    required this.address,
    required this.bonded,
  });

  final String name;
  final String address;
  final bool bonded;

  factory PairedDevice.fromMap(Map<Object?, Object?> m) => PairedDevice(
    name: (m['name'] as String?) ?? '',
    address: (m['address'] as String).toUpperCase(),
    // BluetoothDevice.BOND_BONDED == 12
    bonded: (m['bondState'] as int?) == 12,
  );
}

/// Why a native call failed, in terms the UI can act on.
enum SppFailure {
  /// No Bluetooth adapter on this device.
  unsupported,

  /// Bluetooth is turned off — prompt to enable, never spin.
  bluetoothOff,

  /// `BLUETOOTH_CONNECT` not granted (API 31+). Prompt for it.
  permission,

  /// The adapter is not paired in Android Settings. Show the three-step
  /// pairing card; never attempt to pair in-app.
  notPaired,

  /// The address is not a valid Bluetooth MAC. A persisted id has gone bad;
  /// retrying will never help.
  badAddress,

  /// The socket couldn't be opened. Usually: adapter unpowered, out of range,
  /// or claimed by another app. Retrying can help.
  io,

  /// Not on Android, the module is shut down, or a call arrived in the
  /// wrong state.
  state,
}

class SppException implements Exception {
  const SppException(this.failure, this.message);
  final SppFailure failure;
  final String message;

  @override
  String toString() => 'SppException(${failure.name}: $message)';

  static SppException fromPlatform(PlatformException e) =>
      SppException(switch (e.code) {
        'unsupported' => SppFailure.unsupported,
        'off' => SppFailure.bluetoothOff,
        'permission' => SppFailure.permission,
        'unpaired' => SppFailure.notPaired,
        'argument' => SppFailure.badAddress,
        'io' => SppFailure.io,
        _ => SppFailure.state,
      }, e.message ?? e.code);
}

/// Bluetooth Classic over the `SppPlugin.kt` channel — Android only.
///
/// The Dart side is deliberately thin: it moves bytes and maps native error
/// codes to [SppFailure]. Framing, parsing, and every clone quirk live in
/// `ElmSession`, exactly as they do for BLE and Wi-Fi, so the engine cannot
/// tell which wire it is on.
class SppTransport implements ObdTransport {
  SppTransport({
    required String address,
    required this.name,
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : address = address.toUpperCase(),
       _method = methodChannel ?? defaultMethodChannel,
       _events = eventChannel ?? defaultEventChannel;

  static const defaultMethodChannel = MethodChannel('ktc.torque/spp');
  static const defaultEventChannel = EventChannel('ktc.torque/spp_stream');

  /// The MAC address, upper-cased: Android rejects lower-case hex, and the
  /// [id] built from it must be stable however it was persisted.
  final String address;

  /// As paired in Android Settings; may be empty for a nameless clone.
  final String name;
  final MethodChannel _method;
  final EventChannel _events;

  final _inbound = StreamController<List<int>>.broadcast();
  final _state = StreamController<TransportState>.broadcast();
  TransportState _current = TransportState.disconnected;

  /// Every connect() and disconnect() bumps this. A connect that resumes
  /// under a different generation was superseded and must not touch state.
  int _gen = 0;

  /// The native module holds exactly one RFCOMM link, and Flutter keeps one
  /// message handler per channel name — so there is one subscription for
  /// all instances, routed to whichever connected last. Connecting a second
  /// instance evicts the first: it sees `disconnected`, and its own
  /// disconnect() then touches nothing native.
  static StreamSubscription<dynamic>? _sharedSub;
  static SppTransport? _owner;

  bool get _isOwner => identical(_owner, this);

  static void _subscribe(EventChannel events) {
    _sharedSub ??= events.receiveBroadcastStream().listen(
      (e) => _owner?._onEvent(e),
      onError: (_) => _owner?._lost(),
      onDone: () {
        _sharedSub = null;
        _owner?._lost();
      },
    );
  }

  /// Detaches the field before awaiting, so a connect() that lands during
  /// the cancel creates a fresh subscription instead of adopting a dead one.
  static Future<void> _unsubscribe() async {
    final s = _sharedSub;
    _sharedSub = null;
    await s?.cancel();
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    await _unsubscribe();
    _owner = null;
  }

  // ------------------------------------------------------------- discovery

  static Future<bool> isSupported([MethodChannel? channel]) async {
    try {
      return await (channel ?? defaultMethodChannel).invokeMethod<bool>(
            'isSupported',
          ) ??
          false;
    } on MissingPluginException {
      // iOS, or a platform the plugin isn't registered on.
      return false;
    }
  }

  /// Devices paired in Android Settings. The app never pairs in-app — the
  /// PIN flow differs across OEMs and the spec forbids attempting it.
  static Future<List<PairedDevice>> listPaired([MethodChannel? channel]) async {
    try {
      final raw = await (channel ?? defaultMethodChannel)
          .invokeListMethod<Map<Object?, Object?>>('listPaired');
      return [for (final m in raw ?? const []) PairedDevice.fromMap(m)];
    } on PlatformException catch (e) {
      throw SppException.fromPlatform(e);
    } on MissingPluginException {
      return const [];
    }
  }

  // ------------------------------------------------------------- transport

  @override
  TransportKind get kind => TransportKind.spp;

  @override
  String get id => 'spp:$address';

  @override
  String get displayName =>
      name.isEmpty ? 'Bluetooth adapter · $address' : name;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  Stream<List<int>> get inbound => _inbound.stream;

  /// RFCOMM has no MTU concern at this layer — the stack segments. A modest
  /// chunk keeps a single write from blocking the io thread for long.
  @override
  int get maxWriteLength => 512;

  @override
  TransportCapabilities get capabilities => TransportCapabilities.spp;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 10)}) async {
    final gen = ++_gen;
    final previous = _owner;
    _owner = this;
    if (previous != null && !identical(previous, this)) previous._evict();
    _set(TransportState.connecting);

    // Subscribe before connecting so the first bytes can't be missed.
    _subscribe(_events);

    bool? ok;
    try {
      ok = await _method
          .invokeMethod<bool>('connect', {'address': address})
          .timeout(timeout);
    } on TimeoutException {
      // Native is still blocked in BluetoothSocket.connect(). Tell it to
      // stop, or a late success would leave a socket open with no listener.
      // Unless a newer connect() owns native now — then it is theirs.
      if (gen == _gen && _isOwner) _tellNativeToDisconnect();
      throw await _abandon(gen, null);
    } on PlatformException catch (e) {
      throw await _abandon(gen, SppException.fromPlatform(e));
    } on MissingPluginException {
      throw await _abandon(
        gen,
        const SppException(
          SppFailure.state,
          'Bluetooth Classic is not available on this platform',
        ),
      );
    }

    if (gen != _gen) {
      // A newer connect() or a disconnect() got in while we were waiting.
      // Whatever native did for us is theirs to own now.
      throw await _abandon(gen, null);
    }
    if (ok != true) {
      throw await _abandon(
        gen,
        const SppException(SppFailure.io, 'connect refused'),
      );
    }
    _set(TransportState.connected);
  }

  static const _superseded = SppException(
    SppFailure.state,
    'connect superseded',
  );

  /// Cleanup for a connect attempt that did not win, returning what it
  /// should throw. If the attempt is still current, the subscription is
  /// dropped, state goes to `failed`, and [error] is thrown (null means a
  /// timeout). If it was superseded by a newer connect() or a disconnect(),
  /// it must touch nothing — the subscription and state belong to the
  /// winner now — and reports only that it was superseded.
  Future<Object> _abandon(int gen, SppException? error) async {
    if (gen != _gen || !_isOwner) return _superseded;
    await _unsubscribe();
    // A connect() may have landed during the await; the state is theirs.
    if (gen != _gen || !_isOwner) return _superseded;
    _set(TransportState.failed);
    return error ?? TimeoutException('connect', null);
  }

  /// Another instance took the native link. This one is no longer
  /// connected, and any connect it has in flight is superseded.
  void _evict() {
    _gen++;
    _lost();
  }

  void _tellNativeToDisconnect() {
    unawaited(
      _method
          .invokeMethod<void>('disconnect')
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  void _onEvent(dynamic event) {
    if (event is Uint8List) {
      _inbound.add(event);
    } else if (event is List<int>) {
      _inbound.add(event);
    } else if (event is Map && event['event'] == 'disconnected') {
      _lost();
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (_current != TransportState.connected) return;
    // Chunked so one write never holds the native io thread for long; the
    // socket itself imposes no limit.
    for (var i = 0; i < bytes.length; i += maxWriteLength) {
      final end = i + maxWriteLength < bytes.length
          ? i + maxWriteLength
          : bytes.length;
      try {
        await _method.invokeMethod<void>('write', {
          'bytes': Uint8List.fromList(bytes.sublist(i, end)),
        });
      } on PlatformException catch (e) {
        final failure = SppException.fromPlatform(e);
        if (failure.failure == SppFailure.io) _lost();
        throw failure;
      }
    }
  }

  @override
  Future<void> disconnect() async {
    final gen = ++_gen;
    if (_isOwner) {
      await _unsubscribe();
      try {
        await _method.invokeMethod<void>('disconnect');
      } on PlatformException {
        // Already gone. The outcome is the same.
      } on MissingPluginException {
        // Not on Android.
      }
      if (_isOwner) _owner = null;
    }
    // Unless a connect() landed meanwhile — then the state is theirs.
    if (gen == _gen) _set(TransportState.disconnected);
  }

  void _lost() {
    if (_current == TransportState.disconnected) return;
    _set(TransportState.disconnected);
  }

  void _set(TransportState s) {
    _current = s;
    if (!_state.isClosed) _state.add(s);
  }

  Future<void> dispose() async {
    await disconnect();
    await _inbound.close();
    await _state.close();
  }
}
