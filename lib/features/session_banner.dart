import 'package:flutter/widgets.dart';

import '../core/platform/platform_info.dart';
import '../design_system/design_system.dart';
import '../session/obd_session.dart';

/// SPEC §2.1 — the global connection banner, one mapping for every tab.
///
/// The table in the spec is reproduced literally here so no screen invents
/// its own wording. `connected` returns null: a healthy link says nothing,
/// which is the monochrome-when-healthy rule applied to chrome.
ConnectionBanner? bannerFor(
  ObdSession session, {
  VoidCallback? onConnect,
  String? adapterName,
  PlatformInfo platform = PlatformInfo.current,
}) {
  switch (session.state) {
    case SessionState.disconnected:
      return ConnectionBanner(
        message: 'Not connected — tap to connect',
        actionLabel: onConnect == null ? null : 'Connect',
        onAction: onConnect,
      );
    case SessionState.connecting:
      return ConnectionBanner(
        message: adapterName == null
            ? 'Connecting…'
            : 'Connecting to $adapterName…',
        tone: Tell.blue,
        busy: true,
      );
    case SessionState.handshaking:
      return ConnectionBanner(
        message:
            'Setting up — step ${session.progressStep + 1} of '
            '${session.totalSteps}',
        tone: Tell.blue,
        busy: true,
      );
    case SessionState.connected:
      // Hidden. The protocol and adapter live on the Connect screen.
      return null;
    case SessionState.degraded:
      return const ConnectionBanner(
        message: 'Weak link — some data may be missing',
        tone: Tell.amber,
      );
    case SessionState.ignitionOff:
      return const ConnectionBanner(
        message: 'Turn the ignition to ON',
        tone: Tell.amber,
      );
    case SessionState.lost:
      return ConnectionBanner(
        message: 'Connection lost — reconnecting (${session.reconnectAttempt})',
        tone: Tell.red,
        busy: true,
      );
    case SessionState.unsupported:
      return ConnectionBanner(
        message:
            "This adapter isn't supported on "
            '${platform.isAndroid ? 'Android' : 'iPhone'}',
        tone: Tell.red,
        actionLabel: onConnect == null ? null : 'Change',
        onAction: onConnect,
      );
  }
}
