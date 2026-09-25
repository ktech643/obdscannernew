import '../../core/typed_number.dart';
import '../../models/enums.dart';

/// Kilometres on disk, the user's unit on screen. Nothing else in the
/// garage converts.
class Distance {
  const Distance._();

  static const kmPerMile = 1.609344;

  static double toKm(double value, DistanceUnit unit) =>
      unit == DistanceUnit.km ? value : value * kmPerMile;

  static double fromKm(double km, DistanceUnit unit) =>
      unit == DistanceUnit.km ? km : km / kmPerMile;

  /// Whole units with thousands separators: `142,380`.
  static String display(double km, DistanceUnit unit) {
    // `round()` throws on Infinity and NaN; a row that somehow carries one
    // shows the unavailable dash rather than taking the Garage down.
    if (!km.isFinite) return '—';
    final v = fromKm(km, unit).round();
    final s = v.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return v < 0 ? '-$out' : out.toString();
  }

  /// `142,380`, `142380`, `142 380`, `142.380`, `142380,5`,
  /// `142.380,5` — either convention (§9.7), by [parseTypedNumber]'s rules:
  /// a reading has no three-decimal form, so one mark before exactly three
  /// digits groups thousands. Null when it is not a number.
  static double? parse(String raw) =>
      parseTypedNumber(raw, threeDecimalsPlausible: false);

  /// Past this above the car's reading, a typed reading is likelier a
  /// slip than a drive — and a reading higher than the car's moves the
  /// car's odometer, which nothing later moves back down.
  static const jumpKm = 50000.0;

  /// A caution, not a refusal, for a reading far above the car's.
  static String? jumpCaution(double? km, double? carKm, DistanceUnit unit) {
    if (km == null || carKm == null || km - carKm <= jumpKm) return null;
    return '${display(km - carKm, unit)} ${unit.label} more than the car\'s '
        'last reading of ${display(carKm, unit)} — check it before saving. '
        'The car\'s odometer moves to it.';
  }
}
