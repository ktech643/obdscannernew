import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/models.dart';

/// Owns the adapter link: scanning, the 7-step handshake, degradation and the
/// reconnect ladder.
class ConnectionProvider extends ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  /// 1…7 while [status] is `handshaking`.
  int _handshakeStep = 1;
  int get handshakeStep => _handshakeStep;

  /// Attempt counter while [status] is `lost`, driving the reconnect ladder.
  int _lostAttempt = 0;
  int get lostAttempt => _lostAttempt;

  int _scanSeconds = 0;
  int get scanSeconds => _scanSeconds;

  Timer? _ticker;

  bool _bluetoothOn = true;
  bool get bluetoothOn => _bluetoothOn;

  bool _bluetoothDenied = false;
  bool get bluetoothDenied => _bluetoothDenied;

  bool _demoMode = false;
  bool get demoMode => _demoMode;

  /// The reconnect ladder, in seconds, then every 15 s for 2 minutes, then a
  /// manual Reconnect button.
  static const reconnectLadder = [0.5, 1, 2, 4, 8];

  // ------------------------------------------------------- current link
  String get adapterName => 'Vgate iCar Pro BLE';
  String get adapterAddress => 'E4:5F:01:9C';
  String get transportLine => 'Bluetooth LE · profile C';
  String get protocolLine => 'ISO 15765-4 CAN 11/500';
  String get firmwareLine => 'ELM327 v1.5';

  double _batteryVolts = 14.2;
  double get batteryVolts => _batteryVolts;

  int get rssi => -54;

  /// Polling rate. Drops to 2 Hz when the adapter is slow — the app tells the
  /// user rather than silently sampling less.
  int _hz = 8;
  int get hz => _hz;

  int _latencyMs = 118;
  int get latencyMs => _latencyMs;

  String get quietStripText =>
      'CAN 11/500 · ${_batteryVolts.toStringAsFixed(1)} V · $_hz Hz';

  /// The 7 handshake steps, shown by name — never a guessed percentage.
  static const handshakeSteps = <({String label, String cmd})>[
    (label: 'Reset adapter', cmd: 'ATZ'),
    (label: 'Echo off', cmd: 'ATE0'),
    (label: 'Linefeeds off', cmd: 'ATL0'),
    (label: 'Spaces off', cmd: 'ATS0'),
    (label: 'Headers on', cmd: 'ATH1'),
    (label: 'Find the protocol', cmd: 'ATSP0'),
    (label: 'Talk to the engine computer', cmd: '0100'),
  ];

  static const nearbyAdapters = <Adapter>[
    Adapter(
      name: 'OBDII',
      transport: Transport.bluetoothLe,
      rssi: -71,
      rating: AdapterRating.limited,
    ),
    Adapter(
      name: 'OBD Adapter (E4:5F:01:9C)',
      transport: Transport.bluetoothLe,
      rssi: -88,
      subtitle: 'no name advertised',
    ),
  ];

  /// Ships inside the app. No lookup ever leaves the iPhone.
  static const compatibilityList = <AdapterListing>[
    AdapterListing(
      'Vgate iCar Pro BLE 4.0',
      'Profile C · full AT set · Mode 06',
      'Verified',
      AdapterRating.knownGood,
    ),
    AdapterListing(
      'OBDLink CX',
      'Profile E · fastest tested · 10 Hz',
      'Verified',
      AdapterRating.knownGood,
    ),
    AdapterListing(
      'Veepeak BLE+',
      'Profile A · no Mode 06',
      'Verified',
      AdapterRating.knownGood,
    ),
    AdapterListing(
      'Generic "ELM327 v2.1" BLE clone',
      'Version string is fake · ~2 Hz · no Mode 06',
      'Limited',
      AdapterRating.limited,
    ),
    AdapterListing(
      'Any Bluetooth Classic / SPP ELM327',
      'Pairs in iOS Settings · no app access exists',
      'Blocked by iOS',
      AdapterRating.blocked,
    ),
    AdapterListing(
      'USB / K-line cable adapters',
      'No iPhone data path',
      'Blocked by iOS',
      AdapterRating.blocked,
    ),
  ];

  // ------------------------------------------------------------ commands
  void startScan() {
    _status = ConnectionStatus.scanning;
    _scanSeconds = 0;
    notifyListeners();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      _scanSeconds++;
      // A 2px accent line sweeps under the title while this runs — never a
      // spinner, because a spinner in a state that may not resolve is a lie.
      if (_scanSeconds >= 15) {
        t.cancel();
        _status = ConnectionStatus.unsupported;
      }
      notifyListeners();
    });
  }

  void stopScan() {
    _ticker?.cancel();
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  Future<void> connect() async {
    _ticker?.cancel();
    _status = ConnectionStatus.handshaking;
    _handshakeStep = 1;
    notifyListeners();
    for (var step = 1; step <= handshakeSteps.length; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
      _handshakeStep = step;
      notifyListeners();
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _status = ConnectionStatus.connected;
    _hz = 8;
    notifyListeners();
  }

  void disconnect() {
    _ticker?.cancel();
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  /// Slow adapter: drop the rate and say so rather than sampling silently.
  void degrade() {
    _status = ConnectionStatus.degraded;
    _hz = 2;
    _latencyMs = 640;
    notifyListeners();
  }

  void recover() {
    _status = ConnectionStatus.connected;
    _hz = 8;
    _latencyMs = 118;
    notifyListeners();
  }

  void lose() {
    _status = ConnectionStatus.lost;
    _lostAttempt = 3;
    notifyListeners();
  }

  void setBluetooth({bool? on, bool? denied}) {
    if (on != null) _bluetoothOn = on;
    if (denied != null) _bluetoothDenied = denied;
    notifyListeners();
  }

  void enterDemoMode() {
    _demoMode = true;
    _status = ConnectionStatus.connected;
    notifyListeners();
  }

  void exitDemoMode() {
    _demoMode = false;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  bool get isLive =>
      _status == ConnectionStatus.connected ||
      _status == ConnectionStatus.degraded;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
