import '../../data/db/app_database.dart';
import '../../protocol/vin_reader.dart';

/// What the VIN read on connect says about *which car this is*.
enum IdentityKind {
  /// The car did not answer Mode 09. Common before 2008, and never a
  /// reason to block anything (§9.6): the primary vehicle stands.
  noVin,

  /// The VIN is the primary vehicle's VIN.
  primary,

  /// The primary vehicle had no VIN on record and this one is now
  /// attached to it. Not a mismatch — there was nothing to mismatch.
  attached,

  /// The VIN belongs to a *different* vehicle in the garage. §9.6: prompt
  /// before recording anything.
  other,

  /// A VIN the garage has never seen. Either a new car or the wrong
  /// primary; the user decides before anything is recorded.
  unknown,
}

/// The verdict, with what it was based on.
class IdentityVerdict {
  const IdentityVerdict(this.kind, {this.vin, this.trusted = true, this.match});

  final IdentityKind kind;

  /// The VIN as read, when there was one.
  final String? vin;

  /// Whether the check digit passed. §9.6: a VIN that fails it is stored
  /// flagged and never decoded, but it is still *compared* — an exact
  /// 17-character match against a garage row is evidence either way.
  final bool trusted;

  /// The garage row the VIN belongs to, for [IdentityKind.other].
  final VehicleRow? match;

  /// Whether the user has to be asked before a scan or trip is recorded.
  bool get needsPrompt =>
      kind == IdentityKind.other || kind == IdentityKind.unknown;

  @override
  String toString() =>
      'IdentityVerdict($kind, vin: $vin, trusted: $trusted, '
      'match: ${match?.nickname})';
}

/// SPEC §9.6 — "two vehicles, one adapter: compare VIN on connect, prompt
/// on mismatch before recording."
///
/// Pure. [read] is the final read after the re-read-once rule has been
/// applied by the caller; this only judges what it is handed against
/// what the garage holds.
IdentityVerdict resolveIdentity({
  required VinResult? read,
  required VehicleRow? primary,
  required List<VehicleRow> garage,
}) {
  if (read == null) return const IdentityVerdict(IdentityKind.noVin);

  final vin = read.vin;
  final trusted = read.checkDigitValid;

  if (primary == null) {
    return IdentityVerdict(IdentityKind.unknown, vin: vin, trusted: trusted);
  }
  if (primary.vin == vin) {
    return IdentityVerdict(IdentityKind.primary, vin: vin, trusted: trusted);
  }

  // The rest of the garage before anything is attached. A primary with no
  // VIN on record is not evidence that *this* car is the primary: when the
  // VIN is already on another vehicle, that vehicle is the one on the wire.
  // Checking the primary's blank first gave the other car's VIN to the
  // primary — two rows with one VIN, scans filed under the wrong car, and
  // the real primary judged a stranger the next time it connected.
  //
  // Several rows may share a VIN (§9.8 allows a duplicate, with a warning);
  // the garage's own order puts the primary first, so the first non-primary
  // match is the one to name.
  for (final row in garage) {
    if (row.id != primary.id && row.vin == vin) {
      return IdentityVerdict(
        IdentityKind.other,
        vin: vin,
        trusted: trusted,
        match: row,
      );
    }
  }
  if (primary.vin == null) {
    return IdentityVerdict(IdentityKind.attached, vin: vin, trusted: trusted);
  }
  return IdentityVerdict(IdentityKind.unknown, vin: vin, trusted: trusted);
}
