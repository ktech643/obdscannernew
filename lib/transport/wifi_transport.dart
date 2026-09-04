import 'dart:async';
import 'dart:io';

import 'obd_transport.dart';

/// A Wi-Fi ELM327 over raw TCP. Pure `dart:io`, no plugin, shared verbatim
/// between iOS and Android.
///
/// The adapter runs its own access point with no route to the internet. On
/// iOS that means the phone may auto-switch back to a known network mid-
/// session; on Android the OS may route the app's traffic over cellular
/// while Wi-Fi carries the adapter. Both are handled above this layer — this
/// class only knows about the socket.
class WifiTransport implements ObdTransport {
  WifiTransport({this.host = defaultHost, this.port = defaultPort});

  static const defaultHost = '192.168.0.10';
  static const defaultPort = 35000;

  /// Endpoints to probe when the default doesn't answer. Different adapter
  /// vendors ship different defaults and none of them document it.
  static const alternates = <({String host, int port})>[
    (host: '192.168.0.10', port: 35000),
    (host: '192.168.4.1', port: 35000),
    (host: '192.168.0.10', port: 23),
    (host: '192.168.1.5', port: 35000),
  ];

  final String host;
  final int port;

  Socket? _socket;
  StreamSubscription<List<int>>? _sub;
  final _inbound = StreamController<List<int>>.broadcast();
  final _state = StreamController<TransportState>.broadcast();

  @override
  TransportKind get kind => TransportKind.wifi;

  @override
  String get id => 'wifi:$host:$port';

  @override
  String get displayName => 'Wi-Fi adapter · $host';

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  Stream<List<int>> get inbound => _inbound.stream;

  /// TCP has no MTU concern at this layer; the socket segments for us.
  @override
  int get maxWriteLength => 1024;

  @override
  TransportCapabilities get capabilities => TransportCapabilities.wifi;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 5)}) async {
    _emitState(TransportState.connecting);
    try {
      // A 5 s hard timeout. The single worst Wi-Fi experience is a user
      // staring at a spinner for a minute because their phone is still on
      // the home network.
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _sub = socket.listen(
        _inbound.add,
        onError: (_) => _lost(),
        onDone: _lost,
        cancelOnError: true,
      );
      _emitState(TransportState.connected);
    } on SocketException {
      _emitState(TransportState.failed);
      rethrow;
    } on TimeoutException {
      _emitState(TransportState.failed);
      rethrow;
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    final socket = _socket;
    if (socket == null) return;
    socket.add(bytes);
    await socket.flush();
  }

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _socket?.close();
    _socket = null;
    _emitState(TransportState.disconnected);
  }

  void _lost() {
    _socket = null;
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
