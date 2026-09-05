/// The state vocabulary from the handoff's "State management" section.
///
/// Rule 1 from the spec governs every model in this folder: **distinguish
/// `null` from `0` everywhere.** Values are `double?` / `String?`, never a
/// sentinel like `-1`. Zero RPM on a hybrid in EV mode is a *valid reading*;
/// missing data is not.
library;

enum ConnectionStatus {
  disconnected,
  scanning,
  connecting,
  handshaking,
  connected,
  degraded,
  ignitionOff,
  lost,
  unsupported,
}

/// A gauge tile is live, showing a known-old value, or has nothing to show.
enum TileState {
  live,

  /// Past 2× the expected interval. Fades to 42% and shows its age.
  stale,

  /// Past 5 s, or the PID answered with no data. Shows `—`.
  unavailable,

  /// The vehicle or adapter does not support this PID at all.
  unsupported,
}

/// Semantic tone. Never carried by colour alone — every tone ships with a
/// glyph *and* a word.
enum Tone { ink, caution, fault, pass }

/// How a gauge tile draws its value.
///
/// All five share one component and one set of props — the treatment changes
/// what is drawn beside the numeral, never whether there is one. **Every
/// variant prints the number in figures**: the dial is a second reading of the
/// same value, never the only one.
enum TileType {
  /// Full ~270° speedo with a needle and tick marks.
  dial,

  /// 180° sweep, no needle.
  arc,

  /// Seven segments filled to the current position.
  bar,

  /// A sparkline over the recent sample window.
  trace,

  /// The numeral alone over its range bar — the system default.
  figure,
}

extension TileTypeX on TileType {
  String get label => switch (this) {
    TileType.dial => 'Dial',
    TileType.arc => 'Arc',
    TileType.bar => 'Bar',
    TileType.trace => 'Trace',
    TileType.figure => 'Figure',
  };

  /// Dials and arcs need vertical room the flat treatments don't. A grid sizes
  /// every row to the tallest type it contains, so rows stay aligned when tile
  /// types are mixed.
  double get tileHeight => switch (this) {
    TileType.dial => 172,
    TileType.arc => 152,
    _ => 124,
  };

  /// Whether the numeral sits inside the graphic (dial, arc) or above it.
  bool get numeralInsideGraphic =>
      this == TileType.dial || this == TileType.arc;
}

enum Entitlement { free, pro }

enum ProSource { direct, family }

enum ScanPhase { idle, running, result }

enum AdState { none, banner, rewardedOffered, rewardedPlaying }

enum AccountStatus { signedOut, signedIn, pendingVerification }

enum SyncStatus { off, synced, paused, conflict }

enum MonitorState { complete, notComplete, notSupported }

/// What a garage entry records. Stored by name — never reorder, only append.
enum ServiceType { maintenance, repair, inspection, tyres, other }

enum DtcStatus { stored, pending, permanent }

enum DtcSeverity { severe, moderate, minor, unknown }

enum Transport { bluetoothLe, wifi, bluetoothClassic }

/// How an adapter is rated in the bundled compatibility list. No lookup ever
/// leaves the device.
enum AdapterRating { knownGood, limited, blocked }

enum DistanceUnit { km, mi }

enum TemperatureUnit { celsius, fahrenheit }

enum VehicleFuel { petrol, diesel, hybrid, electric }

extension DistanceUnitX on DistanceUnit {
  String get label => this == DistanceUnit.km ? 'km' : 'mi';
  String get speedLabel => this == DistanceUnit.km ? 'km/h' : 'mph';
}

extension TemperatureUnitX on TemperatureUnit {
  String get label => this == TemperatureUnit.celsius ? '°C' : '°F';
}
