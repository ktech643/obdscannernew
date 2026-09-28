import 'package:flutter/foundation.dart';

import '../../domain/pid_sample.dart';
import '../../session/obd_session.dart';
import '../../transport/obd_transport.dart' show TransportKind;

/// What the recorder needs of the live link, and no more — so a test can
/// drive every state the session has without a transport or a clock.
abstract interface class TripLink implements Listenable {
  SessionState get state;

  /// True from the moment a link is lost until the reconnect ladder either
  /// wins or gives up; a failed rung's `disconnected` is not the end.
  bool get reconnecting;

  /// Why the link went down; null when the user disconnected.
  String? get lastError;
  Set<String> get supportedPids;
  TransportKind? get transportKind;
  PidBus get bus;

  /// Hard rule 9: whether the session may keep polling in the background.
  void setRecording(bool value);
}

class SessionTripLink implements TripLink {
  SessionTripLink(this.session);
  final ObdSession session;

  @override
  SessionState get state => session.state;

  @override
  bool get reconnecting => session.reconnecting;

  @override
  String? get lastError => session.lastError;

  @override
  Set<String> get supportedPids => session.supportedPids;

  @override
  TransportKind? get transportKind => session.transportKind;

  @override
  PidBus get bus => session.bus;

  @override
  void setRecording(bool value) => session.setRecording(value);

  @override
  void addListener(VoidCallback listener) => session.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      session.removeListener(listener);
}
