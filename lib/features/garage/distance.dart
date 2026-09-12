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
    final v = fromKm(km, unit).round();
    final s = v.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return v < 0 ? '-$out' : out.toString();
  }

  /// `142,380`, `142380`, `142 380`, `142380.5` — and the comma-decimal
  /// form `142380,5` when there is exactly one comma followed by one or
  /// two digits (§9.7). Null when it is not a number.
  static double? parse(String raw) {
    var s = raw.trim().replaceAll(' ', '');
    final commaDecimal = RegExp(r'^\d+,\d{1,2}$');
    if (commaDecimal.hasMatch(s)) {
      s = s.replaceFirst(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
    return double.tryParse(s);
  }
}
