/// A number as a person types it, in either convention (§9.7: comma-decimal
/// locales): `1,234.56` and `1.234,56`, `42,50` and `42.50`, `1 042,50`.
///
/// Both marks present: the last one is the decimal point and the other
/// groups thousands — `1.234,56` was read as 1.23456 before, a cost a
/// thousand times too small with no error shown. One mark, more than once:
/// it groups (`1.234.567`). One mark, once, before one or two digits: it
/// is the decimal point. One mark, once, before exactly three digits is
/// the only real ambiguity — `1.234` is 1234 in Germany and 1.234 in
/// England — and [threeDecimalsPlausible] settles it by what the number
/// is: a pump shows litres to three places, so for litres it is a decimal
/// point; no price or reading here has three decimals, so for those it
/// groups.
///
/// Null when it is not a number. `Infinity`, `NaN`, exponents and signs
/// other than one leading minus are not numbers here, though
/// `double.tryParse` accepts them.
double? parseTypedNumber(String raw, {required bool threeDecimalsPlausible}) {
  // Spaces, including the no-break and narrow no-break spaces French and
  // Swiss formatting put between thousands.
  var s = raw.trim().replaceAll(RegExp(r'[\s  ]'), '');
  final negative = s.startsWith('-');
  if (negative) s = s.substring(1);
  if (s.isEmpty || !RegExp(r'^[0-9.,]+$').hasMatch(s)) return null;
  if (!RegExp(r'[0-9]').hasMatch(s)) return null;

  final comma = s.contains(','), dot = s.contains('.');
  String digits;
  if (comma && dot) {
    final decimal = s.lastIndexOf(',') > s.lastIndexOf('.') ? ',' : '.';
    final group = decimal == ',' ? '.' : ',';
    if (decimal.allMatches(s).length != 1) return null;
    final i = s.indexOf(decimal);
    if (s.substring(i).contains(group)) return null;
    final whole = s.substring(0, i);
    if (!_grouped(whole, group)) return null;
    digits = '${whole.replaceAll(group, '')}.${s.substring(i + 1)}';
  } else if (comma || dot) {
    final mark = comma ? ',' : '.';
    final parts = s.split(mark);
    if (parts.length > 2) {
      if (!_grouped(s, mark)) return null;
      digits = s.replaceAll(mark, '');
    } else {
      final whole = parts[0], fraction = parts[1];
      final groups =
          fraction.length == 3 &&
          whole.isNotEmpty &&
          whole.length <= 3 &&
          whole != '0' &&
          !threeDecimalsPlausible;
      digits = groups ? '$whole$fraction' : '$whole.$fraction';
    }
  } else {
    digits = s;
  }
  if (digits.startsWith('.')) digits = '0$digits';
  if (digits.endsWith('.')) digits = '${digits}0';
  final v = double.tryParse(digits);
  if (v == null || !v.isFinite) return null;
  return negative ? -v : v;
}

/// Groups as a person writes them: one to three digits, then threes
/// (`1,234,567`) — or twos then a final three, the lakh grouping of India
/// and Pakistan (`1,23,456`).
bool _grouped(String s, String mark) {
  if (!s.contains(mark)) return true;
  final parts = s.split(mark);
  if (parts.first.isEmpty || parts.first.length > 3) return false;
  final rest = parts.skip(1).toList();
  if (rest.last.length != 3) return false;
  return rest.every((p) => p.length == 3) ||
      rest.take(rest.length - 1).every((p) => p.length == 2);
}
