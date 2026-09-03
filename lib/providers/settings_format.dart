import '../models/enums.dart';
import 'app_providers.dart';

/// Formatting that depends on the user's unit and currency choices.
///
/// Kept as an extension on [SettingsProvider] so every screen formats the same
/// way, and so unit conversion happens in exactly one place.
extension SettingsFormat on SettingsProvider {
  /// Thousands-separated integer, e.g. `142,380`.
  static String group(num v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  /// A distance held in km, rendered in the user's unit.
  String formatDistance(double km) {
    final v = distance == DistanceUnit.km ? km : km * 0.621371;
    return '${group(v)} ${distance.label}';
  }

  String formatSpeed(double kmh) {
    final v = distance == DistanceUnit.km ? kmh : kmh * 0.621371;
    return '${v.toStringAsFixed(0)} ${distance.speedLabel}';
  }

  /// A temperature held in °C, rendered in the user's unit.
  String formatTemperature(double celsius) {
    final v = temperature == TemperatureUnit.celsius
        ? celsius
        : celsius * 9 / 5 + 32;
    return '${v.toStringAsFixed(0)} ${temperature.label}';
  }

  String get currencySymbol => switch (currency.split(' ').first) {
    'GBP' => '£',
    'USD' => r'$',
    'EUR' => '€',
    _ =>
      currency.length > 4 ? currency.substring(currency.length - 1) : currency,
  };

  String formatMoney(double amount) =>
      '$currencySymbol${amount.toStringAsFixed(2)}';
}
