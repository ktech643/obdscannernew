import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/platform/platform_info.dart';
import 'obd_transport.dart';

/// One known GATT layout. ELM327 BLE clones ship at least five.
class GattProfile {
  const GattProfile({
    required this.name,
    required this.service,
    required this.write,
    required this.notify,
  });

  final String name;
  final Guid service;
  final Guid write;
  final Guid notify;
}

/// The wire between the phone and a BLE adapter.
///
/// Everything here is about surviving clones: probing five GATT layouts and
/// then guessing, chunking writes to whatever MTU the link actually has, and
/// not trusting the plugin's disconnect callback to fire.
class BleTransport implements ObdTransport {
  BleTransport(this._device, {this._platform = PlatformInfo.current});

  final BluetoothDevice _device;
  final PlatformInfo _platform;

  /// SPEC §3.2 — probed in order, first match wins.
  static final profiles = <GattProfile>[
    GattProfile(
      name: 'A · generic FFF0',
      service: Guid('fff0'),
      write: Guid('fff2'),
      notify: Guid('fff1'),
    ),
    GattProfile(
      name: 'B · HM-10 FFE0',
      service: Guid('ffe0'),
      write: Guid('ffe1'),
      notify: Guid('ffe1'),
    ),
    GattProfile(
      name: 'C · Vgate iCar Pro 18F0',
      service: Guid('18f0'),
      write: Guid('2af1'),
      notify: Guid('2af0'),
    ),
    GattProfile(
      name: 'D · Nordic UART',
      service: Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E'),
      write: Guid('6E400002-B5A3-F393-E0A9-E50E24DCCA9E'),
      notify: Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E'),
    ),
    GattProfile(
      name: 'E · OBDLink CX',
      service: Guid('E7810A71-73AE-499D-8C15-FAA9AEF0C3F2'),
      write: Guid('BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F'),
      notify: Guid('BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F'),
    ),
  ];

  /// Advertised names that are probably an adapter. Permissive on purpose —
  /// the unfiltered "Other devices" list catches the rest, and a false
  /// positive costs one failed handshake while a false negative costs a
  /// user who can't find their adapter at all.
  static final adapterNamePattern = RegExp(
    r'OBD|ELM|VLINK|V-LINK|VGATE|ICAR|VEEPEAK|KONNWEI|OBDLINK|LELINK|CARISTA|'
    r'ANCEL|VIECAR|IOS-VLINK|SCAN|AUTOPHIX|THINKDIAG|NEXAS',
    caseSensitive: false,
  );

  static bool looksLikeAdapter(String name) =>
      name.isNotEmpty && adapterNamePattern.hasMatch(name);

  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  bool _writeWithoutResponse = false;
  int _maxWriteLength = 20;
  GattProfile? _matchedProfile;

  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _stateSub;
  final _inbound = StreamController<List<int>>.broadcast();
  final _state = StreamController<TransportState>.broadcast();

  /// Which layout the adapter turned out to have, for the fingerprint cache.
  String? get matchedProfileName => _matchedProfile?.name;

  @override
  TransportKind get kind => TransportKind.ble;

  /// On Android this is the MAC, stable across apps. On iOS it is an opaque
  /// per-app identifier that can change after an adapter brown-out — which is
  /// why the reconnect ladder re-scans by advertised name as well.
  @override
  String get id => 'ble:${_device.remoteId.str}';

  @override
  String get displayName => _device.platformName.isEmpty
      ? 'OBD Adapter (${_device.remoteId.str.substring(0, 8)}…)'
      : _device.platformName;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  Stream<List<int>> get inbound => _inbound.stream;

  @override
  int get maxWriteLength => _maxWriteLength;

  @override
  TransportCapabilities get capabilities => TransportCapabilities(
    supportsMtuNegotiation: _platform.supportsMtuNegotiation,
    supportsBackgroundHold: true,
    typicalRttMs: 90,
  );

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) async {
    _emitState(TransportState.connecting);
    try {
      await _device.connect(
        timeout: timeout,
        autoConnect: false,
        license: License.free,
      );

      _stateSub = _device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _emitState(TransportState.disconnected);
        }
      });

      await _negotiateMtu();

      final services = await _device.discoverServices();
      if (!await _bindProfile(services)) {
        await _device.disconnect();
        _emitState(TransportState.failed);
        throw StateError(
          'No usable GATT characteristics on $displayName — '
          'not an ELM327-compatible adapter',
        );
      }

      _emitState(TransportState.connected);
    } catch (_) {
      _emitState(TransportState.failed);
      rethrow;
    }
  }

  /// Android must ask for a larger MTU or it stays at 20 bytes forever. iOS
  /// negotiates automatically and throws on the request.
  Future<void> _negotiateMtu() async {
    if (_platform.supportsMtuNegotiation) {
      try {
        await _device.requestMtu(247);
        // Some stacks report the new MTU before it is actually in effect.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } catch (_) {
        // A clone that refuses stays at its default. Not fatal.
      }
    }
    // ATT header overhead is 3 bytes.
    _maxWriteLength = (_device.mtuNow - 3).clamp(20, 244);
  }

  /// Probes the known layouts, then falls back to any notify/write pair.
  Future<bool> _bindProfile(List<BluetoothService> services) async {
    for (final profile in profiles) {
      final service = services
          .where((s) => s.uuid == profile.service)
          .firstOrNull;
      if (service == null) continue;

      final write = _find(service, profile.write);
      final notify = _find(service, profile.notify);
      if (write == null || notify == null) continue;

      if (await _bind(write, notify)) {
        _matchedProfile = profile;
        return true;
      }
    }

    // Generic fallback: any service with one notify and one write
    // characteristic. If it answers ATI like an ELM327, it is one.
    for (final service in services) {
      final notify = service.characteristics
          .where((c) => c.properties.notify)
          .firstOrNull;
      final write = service.characteristics
          .where((c) => c.properties.write || c.properties.writeWithoutResponse)
          .firstOrNull;
      if (notify == null || write == null) continue;
      if (await _bind(write, notify)) {
        _matchedProfile = GattProfile(
          name: 'generic · ${service.uuid.str}',
          service: service.uuid,
          write: write.uuid,
          notify: notify.uuid,
        );
        return true;
      }
    }
    return false;
  }

  static BluetoothCharacteristic? _find(BluetoothService s, Guid uuid) =>
      s.characteristics.where((c) => c.uuid == uuid).firstOrNull;

  Future<bool> _bind(
    BluetoothCharacteristic write,
    BluetoothCharacteristic notify,
  ) async {
    try {
      await notify.setNotifyValue(true);
    } catch (_) {
      return false;
    }
    _writeChar = write;
    _notifyChar = notify;
    _writeWithoutResponse = write.properties.writeWithoutResponse;
    await _notifySub?.cancel();
    _notifySub = notify.onValueReceived.listen(_inbound.add);
    return true;
  }

  /// Chunked to the negotiated MTU. On Android GATT permits one outstanding
  /// operation, so every chunk is awaited; without-response writes still need
  /// a small gap or the stack silently drops them.
  @override
  Future<void> write(List<int> bytes) async {
    final char = _writeChar;
    if (char == null) return;

    for (var i = 0; i < bytes.length; i += _maxWriteLength) {
      final end = i + _maxWriteLength < bytes.length
          ? i + _maxWriteLength
          : bytes.length;
      await char.write(
        bytes.sublist(i, end),
        withoutResponse: _writeWithoutResponse,
      );
      if (_platform.isAndroid && _writeWithoutResponse) {
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
    }
  }

  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _stateSub?.cancel();
    _stateSub = null;
    try {
      await _notifyChar?.setNotifyValue(false);
    } catch (_) {}
    await _device.disconnect();
    _emitState(TransportState.disconnected);
  }

  void _emitState(TransportState s) {
    if (!_state.isClosed) _state.add(s);
  }

  Future<void> dispose() async {
    await disconnect();
    await _inbound.close();
    await _state.close();
  }
}
