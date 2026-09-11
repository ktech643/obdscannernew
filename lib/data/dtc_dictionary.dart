import '../protocol/dtc_decoder.dart';

/// How bad a code is, as the dictionary rates it. Absent when the code is
/// not in the dictionary — which is not the same as "mild" (hard rule 7).
enum DtcSeverity { low, medium, high }

/// One dictionary entry. The shape of a `dtc.sqlite` row (§4.6).
///
/// Every field here comes from the bundled database. Nothing on this class
/// is derived, inferred or guessed: if the code is not in the database
/// there is no `DtcDefinition` for it, and the UI says so.
class DtcDefinition {
  const DtcDefinition({
    required this.code,
    required this.title,
    this.description,
    this.severity,
    this.system,
    this.commonCauses = const [],
  });

  final String code;

  /// The one-line meaning, e.g. "Cylinder 1 misfire detected".
  final String title;
  final String? description;
  final DtcSeverity? severity;

  /// The vehicle system, e.g. "Ignition". Not the P/C/B/U letter — that is
  /// structural and comes from [DtcText.systemName].
  final String? system;
  final List<String> commonCauses;
}

/// Lookup over the bundled definition database.
///
/// SPEC §4.6 specifies `assets/db/dtc.sqlite` (FTS5). That asset needs a
/// licensed, verified source and is **not** generated here — see §6.1's
/// "not built here" note. Until it lands the app runs on
/// [EmptyDtcDictionary], which is why every caller must handle a null
/// definition as an ordinary outcome rather than an error.
abstract interface class DtcDictionary {
  /// The entry for [code], or null when the database has no row for it.
  /// Never a fabricated entry, and never a nearest match.
  Future<DtcDefinition?> lookup(String code);
}

/// No definitions at all. The honest default until the licensed database
/// ships: every code renders through [DtcText], which says what is known
/// from the code's structure and nothing more.
class EmptyDtcDictionary implements DtcDictionary {
  const EmptyDtcDictionary();

  @override
  Future<DtcDefinition?> lookup(String code) async => null;
}

/// A dictionary backed by a map. Used by tests, and by the asset loader
/// once it exists.
class InMemoryDtcDictionary implements DtcDictionary {
  InMemoryDtcDictionary(Iterable<DtcDefinition> entries)
    : _byCode = {for (final e in entries) e.code.toUpperCase(): e};

  final Map<String, DtcDefinition> _byCode;

  @override
  Future<DtcDefinition?> lookup(String code) async =>
      _byCode[code.toUpperCase()];
}

/// The words the UI puts on a code.
///
/// This is the whole of hard rule 7 in one place: what can be said about a
/// code with no dictionary entry is exactly what SAE J2012 defines
/// structurally — which system the first letter names, and whether the
/// second digit makes it manufacturer-specific. Everything else is a
/// definition, and definitions come from the database or not at all.
class DtcText {
  const DtcText._();

  /// §5.4 — every DTC detail ends with this. Verbatim.
  static const disclaimer =
      'A code points to a symptom, not always the cause. '
      "A mechanic's diagnosis may differ.";

  /// §4.6 — the required wording for P1xxx/P3xxx and their C/B/U siblings.
  static const manufacturerSpecific =
      'Manufacturer-specific code — meaning varies by make.';

  /// The system the first letter names. Structural, from the standard.
  static String systemName(String code) => switch (code.isEmpty ? '' : code[0]) {
    'P' => 'Powertrain',
    'C' => 'Chassis',
    'B' => 'Body',
    'U' => 'Network',
    _ => 'Unknown system',
  };

  /// What the row under the code says.
  ///
  /// With a definition, its title. Without one, the truth: manufacturer
  /// codes have no generic meaning at all, and a generic code we have no
  /// row for is named as missing rather than described.
  static String describe(RawDtc dtc, DtcDefinition? def) {
    if (def != null) return def.title;
    if (dtc.isManufacturerSpecific) return manufacturerSpecific;
    return '${systemName(dtc.code)} code — no definition available offline.';
  }

  /// The status word §5.4 puts at the end of a row.
  static String statusWord(DtcMode mode) => switch (mode) {
    DtcMode.stored => 'Stored',
    DtcMode.pending => 'Pending',
    DtcMode.permanent => 'Permanent',
  };

  /// The sentence explaining what that status means for the driver.
  static String statusMeaning(DtcMode mode) => switch (mode) {
    DtcMode.stored =>
      'Confirmed by the ECU. This is the kind of code that turns on the '
          'Check Engine light.',
    DtcMode.pending =>
      'Seen once, not yet confirmed. If it happens again on the next '
          'drive cycle it becomes stored; if it does not, it clears itself.',
    DtcMode.permanent =>
      'Set by emissions monitoring. A scan tool cannot clear this one — '
          'it goes away when the ECU has seen the fault stay fixed.',
  };
}
