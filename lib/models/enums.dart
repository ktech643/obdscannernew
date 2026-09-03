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

enum Entitlement { free, pro }

enum ProSource { direct, family }

enum ScanPhase { idle, running, result }

enum AdState { none, banner, rewardedOffered, rewardedPlaying }

enum AccountStatus { signedOut, signedIn, pendingVerification }

enum SyncStatus { off, synced, paused, conflict }

enum MonitorState { complete, notComplete, notSupported }

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
