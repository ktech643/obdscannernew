import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

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
  final Uuid service;
  final Uuid write;
  final Uuid notify;
}

/// The wire between the phone and a BLE adapter.
///
/// Built on `flutter_reactive_ble` — BSD-3, no license clause, no build-time
/// network call. Everything here is about surviving clones: probing five GATT
/// layouts and then guessing, chunking writes to whatever MTU the link
/// actually has, and not trusting the plugin's disconnect event to fire.
class BleTransport implements ObdTransport {
  BleTransport({
    required this.deviceId,
    required this._name,
    FlutterReactiveBle? ble,
    this._platform = PlatformInfo.current,
  }) : _ble = ble ?? FlutterReactiveBle();

  /// On Android this is the MAC, stable across apps. On iOS it is an opaque
  /// per-app identifier that can change after an adapter brown-out — which is
  /// why the reconnect ladder re-scans by advertised name as well.
  final String deviceId;
  final String _name;
  final FlutterReactiveBle _ble;
  final PlatformInfo _platform;

  /// SPEC §3.2 — probed in order, first match wins.
  static final profiles = <GattProfile>[
    GattProfile(
      name: 'A · generic FFF0',
      service: Uuid.parse('fff0'),
      write: Uuid.parse('fff2'),
      notify: Uuid.parse('fff1'),
    ),
    GattProfile(
      name: 'B · HM-10 FFE0',
      service: Uuid.parse('ffe0'),
      write: Uuid.parse('ffe1'),
      notify: Uuid.parse('ffe1'),
    ),
    GattProfile(
      name: 'C · Vgate iCar Pro 18F0',
      service: Uuid.parse('18f0'),
      write: Uuid.parse('2af1'),
      notify: Uuid.parse('2af0'),
    ),
    GattProfile(
      name: 'D · Nordic UART',
      service: Uuid.parse('6E400001-B5A3-F393-E0A9-E50E24DCCA9E'),
      write: Uuid.parse('6E400002-B5A3-F393-E0A9-E50E24DCCA9E'),
      notify: Uuid.parse('6E400003-B5A3-F393-E0A9-E50E24DCCA9E'),
    ),
    GattProfile(
      name: 'E · OBDLink CX',
      service: Uuid.parse('E7810A71-73AE-499D-8C15-FAA9AEF0C3F2'),
      write: Uuid.parse('BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F'),
      notify: Uuid.parse('BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F'),
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

  /// Scan with **no service filter** on both platforms — many clones don't
  /// advertise their service UUID at all. Callers filter by name in Dart.
  static Stream<DiscoveredDevice> scan(FlutterReactiveBle ble) =>
      ble.scanForDevices(withServices: const [], scanMode: ScanMode.lowLatency);

  QualifiedCharacteristic? _writeChar;
  bool _writeWithoutResponse = false;
  int _maxWriteLength = 20;
  GattProfile? _matchedProfile;

  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<List<int>>? _notifySub;
  final _inbound = StreamController<List<int>>.broadcast();
  final _state = StreamController<TransportState>.broadcast();

  /// Which layout the adapter turned out to have, for the fingerprint cache.
  String? get matchedProfileName => _matchedProfile?.name;

  @override
  TransportKind get kind => TransportKind.ble;

  @override
  String get id => 'ble:$deviceId';

  @override
  String get displayName => _name.isEmpty
      ? 'OBD Adapter (${deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId}…)'
      : _name;

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
    final connected = Completer<void>();

    _connection = _ble
        .connectToDevice(id: deviceId, connectionTimeout: timeout)
        .listen(
          (update) {
            switch (update.connectionState) {
              case DeviceConnectionState.connected:
                if (!connected.isCompleted) connected.complete();
              case DeviceConnectionState.disconnected:
                if (!connected.isCompleted) {
                  connected.completeError(
                    StateError('$displayName disconnected before setup'),
                  );
                }
                _emitState(TransportState.disconnected);
              case DeviceConnectionState.connecting:
              case DeviceConnectionState.disconnecting:
                break;
            }
          },
          onError: (Object e) {
            if (!connected.isCompleted) connected.completeError(e);
            _emitState(TransportState.failed);
          },
        );

    try {
      await connected.future.timeout(timeout);
      await _negotiateMtu();

      await _ble.discoverAllServices(deviceId);
      final services = await _ble.getDiscoveredServices(deviceId);
      if (!await _bindProfile(services)) {
        await disconnect();
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
  /// negotiates automatically and the request is a no-op there.
  Future<void> _negotiateMtu() async {
    if (!_platform.supportsMtuNegotiation) return;
    try {
      final mtu = await _ble.requestMtu(deviceId: deviceId, mtu: 247);
      // ATT header overhead is 3 bytes.
      _maxWriteLength = (mtu - 3).clamp(20, 244);
      // Some stacks report the new MTU before it is actually in effect.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } catch (_) {
      // A clone that refuses stays at its default. Not fatal.
    }
  }

  /// Probes the known layouts, then falls back to any notify/write pair.
  Future<bool> _bindProfile(List<Service> services) async {
    for (final profile in profiles) {
      final service = services
          .where((s) => s.id == profile.service)
          .firstOrNull;
      if (service == null) continue;

      final write = _find(service, profile.write);
      final notify = _find(service, profile.notify);
      if (write == null || notify == null) continue;

      if (await _bind(service, write, notify)) {
        _matchedProfile = profile;
        return true;
      }
    }

    // Generic fallback: any service with one notifiable and one writable
    // characteristic. If it answers ATI like an ELM327, it is one — the
    // negotiator's handshake is the real test.
    for (final service in services) {
      final notify = service.characteristics
          .where((c) => c.isNotifiable)
          .firstOrNull;
      final write = service.characteristics
          .where((c) => c.isWritableWithResponse || c.isWritableWithoutResponse)
          .firstOrNull;
      if (notify == null || write == null) continue;
      if (await _bind(service, write, notify)) {
        _matchedProfile = GattProfile(
          name: 'generic · ${service.id}',
          service: service.id,
          write: write.id,
          notify: notify.id,
        );
        return true;
      }
    }
    return false;
  }

  static Characteristic? _find(Service s, Uuid uuid) =>
      s.characteristics.where((c) => c.id == uuid).firstOrNull;

  Future<bool> _bind(
    Service service,
    Characteristic write,
    Characteristic notify,
  ) async {
    final notifyQc = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: service.id,
      characteristicId: notify.id,
    );
    final writeQc = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: service.id,
      characteristicId: write.id,
    );

    try {
      await _notifySub?.cancel();
      _notifySub = _ble
          .subscribeToCharacteristic(notifyQc)
          .listen(
            _inbound.add,
            onError: (_) => _emitState(TransportState.disconnected),
          );
    } catch (_) {
      return false;
    }

    _writeChar = writeQc;
    _writeWithoutResponse = write.isWritableWithoutResponse;
    return true;
  }

  /// Chunked to the negotiated MTU. On Android GATT permits one outstanding
  /// operation, so every chunk is awaited; without-response writes still need
  /// a small gap or the stack silently drops them.
  @override
  Future<void> write(List<int> bytes) async {
    final qc = _writeChar;
    if (qc == null) return;

    for (var i = 0; i < bytes.length; i += _maxWriteLength) {
      final end = i + _maxWriteLength < bytes.length
          ? i + _maxWriteLength
          : bytes.length;
      final chunk = bytes.sublist(i, end);
      if (_writeWithoutResponse) {
        await _ble.writeCharacteristicWithoutResponse(qc, value: chunk);
        if (_platform.isAndroid) {
          await Future<void>.delayed(const Duration(milliseconds: 8));
        }
      } else {
        await _ble.writeCharacteristicWithResponse(qc, value: chunk);
      }
    }
  }

  /// Cancelling the connection stream is how reactive_ble disconnects.
  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    _writeChar = null;
    await _connection?.cancel();
    _connection = null;
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
