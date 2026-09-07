/// A vendor battery-optimisation screen, decoded from the native side.
///
/// SPEC §9.3: Xiaomi/Oppo/Vivo/Huawei/Samsung/OnePlus and the HiOS brands all
/// kill foreground services regardless of Android policy. When the app detects
/// one of these on first background-recording attempt it offers a "Fix this"
/// card that opens the vendor screen; [component] and [action] are the raw
/// native intent parts surfaced so the UI can deep-link.
class BatteryOptimization {
  const BatteryOptimization({
    required this.package,
    required this.label,
    this.component,
    this.action,
  });

  /// The vendor package this screen lives in (e.g. `com.miui.securitycenter`).
  final String package;

  /// A human label like "Xiaomi — Autostart".
  final String label;

  /// The flattened `ComponentName` (`package/class`) if one was resolved.
  final String? component;

  /// A raw intent action if the vendor screen is reached by action instead.
  final String? action;

  factory BatteryOptimization.fromMap(Map<dynamic, dynamic> m) =>
      BatteryOptimization(
        package: m['package'] as String? ?? '',
        label: m['label'] as String? ?? '',
        component: m['component'] as String?,
        action: m['action'] as String?,
      );
}
