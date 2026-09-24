import 'package:flutter/services.dart';

/// SPEC §5.6 "Keep screen on" — the screen stays awake while a live link is
/// up and the setting is on, and only then.
///
/// One method channel, one method: `setKeepAwake(bool)`. iOS sets
/// `UIApplication.isIdleTimerDisabled`; Android sets `FLAG_KEEP_SCREEN_ON`
/// on the window. That is the whole of the platform's part; *when* is
/// decided here in Dart, where the link state is. An earlier version stored
/// the preference and nothing read it.
///
/// Idempotent: the platform hears only a change of answer. The caller
/// re-applies on every rebuild, and a platform round trip per frame would
/// be waste. A missing native side — a test, a platform without one — is a
/// no-op: the screen staying on is a convenience, never something to fail a
/// session over.
class ScreenWake {
  ScreenWake({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('ktc.torque/screen');

  final MethodChannel _channel;

  /// The platform starts with the screen free to sleep — iOS's idle timer
  /// running, no window flag on Android — so that is the answer already
  /// given, and the first one worth sending is `true`.
  bool? _last = false;

  /// The last answer sent; false until the first.
  bool? get isAwake => _last;

  Future<void> set(bool on) async {
    if (_last == on) return;
    _last = on;
    try {
      await _channel.invokeMethod<void>('setKeepAwake', on);
    } on MissingPluginException {
      // No native side here.
    } on PlatformException {
      // The platform refused; say it again next time the answer changes.
      _last = null;
    }
  }
}
