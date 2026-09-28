import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/platform/platform_info.dart';
import '../transport/obd_transport.dart';
import '../transport/spp_transport.dart';
import '../transport/wifi_transport.dart';

/// How an adapter is reached. Mirrors [TransportKind] but is a UI concern:
/// the Connect screen groups by this.
enum AdapterKind { ble, spp, wifi }

/// What the bundled compatibility list says about an adapter. No lookup ever
/// leaves the device (AC-14) — the list is compiled in, and anything not on
/// it is [unknown] rather than assumed bad.
enum AdapterRating {
  /// Verified working by the project.
  knownGood,

  /// Works, with caveats worth showing before the user buys into it.
  limited,

  /// Known not to work at all.
  blocked,

  /// Not on the list. Most adapters, most of the time.
  unknown,
}

/// One connectable adapter.
@immutable
class Adapter {
  const Adapter({
    required this.id,
    required this.name,
    required this.kind,
    this.rssi,
    this.rating = AdapterRating.unknown,
    this.detail,
  });

  /// Stable across scans and across launches, so a remembered adapter can
  /// be matched again: `ble:<device id>`, `spp:<MAC>`, `wifi:<host>:<port>`.
  final String id;

  /// What the adapter advertises. Empty for the ones that advertise nothing
  /// — the spec's "Other devices", sorted by signal.
  final String name;
  final AdapterKind kind;

  /// BLE only. Null elsewhere; absence is not a weak signal.
  final int? rssi;
  final AdapterRating rating;

  /// A short line under the name: the caveat for a limited adapter, or the
  /// host and port for Wi-Fi.
  final String? detail;

  bool get isAnonymous => name.trim().isEmpty;

  String get displayName => isAnonymous ? 'Unnamed device' : name;

  @override
  bool operator ==(Object other) => other is Adapter && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Why a scan cannot produce results. Each one has a different remedy, and
/// SPEC §9.1 is explicit that none of them may be shown as a spinner.
enum DiscoveryProblem {
  none,

  /// The radio is off. Prompt to enable; never spin.
  bluetoothOff,

  /// Runtime permission refused, but askable again with a rationale.
  bluetoothDenied,

  /// Refused permanently — the only route left is the system settings page.
  bluetoothDeniedForever,

  /// Android ≤30 only: `startScan` silently returns nothing with location
  /// services off. No error, no callback. Detect it *before* scanning.
  locationOff,

  /// No Bluetooth hardware at all.
  unsupported,
}

/// Finds adapters. An interface because the real one needs a radio: tests
/// and Demo Mode use [FakeAdapterDiscovery], and the Connect screen cannot
/// tell the difference.
abstract interface class AdapterDiscovery {
  /// Everything found so far, re-emitted as the list grows.
  Stream<List<Adapter>> get adapters;

  /// Emits when something blocks the scan. [DiscoveryProblem.none] clears.
  Stream<DiscoveryProblem> get problem;

  /// True while a scan is running.
  bool get isScanning;

  /// How long the current scan has been running, for the §5.2 compatibility
  /// gate at 15 s with nothing found.
  Duration get elapsed;

  Future<void> start();
  Future<void> stop();

  /// The transport for [adapter], ready to hand to `ObdSession.connect`.
  ObdTransport transportFor(Adapter adapter);

  void dispose();
}

/// The bundled compatibility list. Matched on a lower-cased substring of the
/// advertised name, because clones vary the suffix and the case.
///
/// This is deliberately short. Claiming to have verified an adapter that
/// nobody tested would be worse than saying nothing, so everything absent
/// is [AdapterRating.unknown] and gets no badge at all.
class AdapterCompatibility {
  AdapterCompatibility._();

  static const _entries =
      <({String match, AdapterRating rating, String? detail})>[
        (match: 'obdlink', rating: AdapterRating.knownGood, detail: null),
        (match: 'vgate', rating: AdapterRating.knownGood, detail: null),
        (match: 'icar pro', rating: AdapterRating.knownGood, detail: null),
        (match: 'veepeak', rating: AdapterRating.knownGood, detail: null),
        (
          match: 'konnwei',
          rating: AdapterRating.limited,
          detail: 'Slower than most — expect a reduced refresh rate',
        ),
        (
          match: 'elm327 v2.1',
          rating: AdapterRating.limited,
          detail:
              'Firmware version is often faked; some commands may be missing',
        ),
      ];

  static ({AdapterRating rating, String? detail}) rate(String name) {
    final lower = name.toLowerCase();
    for (final e in _entries) {
      if (lower.contains(e.match)) {
        return (rating: e.rating, detail: e.detail);
      }
    }
    return (rating: AdapterRating.unknown, detail: null);
  }
}

/// Discovery over the real radios: BLE scan, the Android paired list, and
/// the well-known Wi-Fi endpoints.
///
/// BLE scanning needs `flutter_reactive_ble` and therefore a device, so this
/// class is not exercised by the test suite — the Connect screen is tested
/// against [FakeAdapterDiscovery] and this is verified on hardware (§10.1).
class RealAdapterDiscovery implements AdapterDiscovery {
  RealAdapterDiscovery({this.platform = PlatformInfo.current, this.bleScan});

  final PlatformInfo platform;

  /// Injected so the BLE dependency stays at the edge: a stream of
  /// (id, name, rssi) as the radio reports them.
  final Stream<({String id, String name, int rssi})> Function()? bleScan;

  final _adapters = StreamController<List<Adapter>>.broadcast();
  final _problem = StreamController<DiscoveryProblem>.broadcast();
  final _found = <String, Adapter>{};
  StreamSubscription<({String id, String name, int rssi})>? _bleSub;
  DateTime? _startedAt;

  @override
  Stream<List<Adapter>> get adapters => _adapters.stream;

  @override
  Stream<DiscoveryProblem> get problem => _problem.stream;

  @override
  bool get isScanning => _startedAt != null;

  @override
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  @override
  Future<void> start() async {
    _startedAt = DateTime.now();
    _found.clear();
    _emit();

    // The paired list and the Wi-Fi endpoints are instant; only BLE scans.
    await _addPaired();
    _addWifi();

    final scan = bleScan;
    if (scan != null) {
      _bleSub = scan().listen((d) {
        final rated = AdapterCompatibility.rate(d.name);
        _put(
          Adapter(
            id: 'ble:${d.id}',
            name: d.name,
            kind: AdapterKind.ble,
            rssi: d.rssi,
            rating: rated.rating,
            detail: rated.detail,
          ),
        );
      }, onError: (Object e) => _problem.add(_classify(e)));
    }
  }

  Future<void> _addPaired() async {
    if (!platform.supportsBluetoothClassic) return;
    try {
      for (final d in await SppTransport.listPaired()) {
        final rated = AdapterCompatibility.rate(d.name);
        _put(
          Adapter(
            id: 'spp:${d.address}',
            name: d.name,
            kind: AdapterKind.spp,
            rating: rated.rating,
            detail: rated.detail ?? d.address,
          ),
        );
      }
    } on SppException catch (e) {
      _problem.add(switch (e.failure) {
        SppFailure.bluetoothOff => DiscoveryProblem.bluetoothOff,
        SppFailure.permission => DiscoveryProblem.bluetoothDenied,
        SppFailure.unsupported => DiscoveryProblem.unsupported,
        _ => DiscoveryProblem.none,
      });
    }
  }

  /// Development only: `--dart-define=TORQUE_DEV_WIFI=127.0.0.1:35000`
  /// offers one more endpoint — `tool/trace_server.dart` replaying a
  /// recorded car — so the real connect and recording paths can run on the
  /// iOS simulator. Never offered by a release build, define or not.
  static const _devWifi = String.fromEnvironment('TORQUE_DEV_WIFI');

  /// Wi-Fi adapters do not advertise. The well-known endpoints are offered
  /// unconditionally and proved by connecting — a "Test" that only opens a
  /// socket would be a second, differently-behaving connect path.
  void _addWifi() {
    final dev = _devWifi.lastIndexOf(':');
    if (!kReleaseMode && dev > 0) {
      final host = _devWifi.substring(0, dev);
      final port = _devWifi.substring(dev + 1);
      _put(
        Adapter(
          id: 'wifi:$host:$port',
          name: 'Trace server (development)',
          kind: AdapterKind.wifi,
          detail: '$host:$port',
        ),
      );
    }
    for (final e in WifiTransport.alternates) {
      _put(
        Adapter(
          id: 'wifi:${e.host}:${e.port}',
          name: 'Wi-Fi adapter',
          kind: AdapterKind.wifi,
          detail: '${e.host}:${e.port}',
        ),
      );
    }
  }

  void _put(Adapter a) {
    _found[a.id] = a;
    _emit();
  }

  void _emit() {
    if (_adapters.isClosed) return;
    _adapters.add(sortForDisplay(_found.values.toList()));
  }

  static DiscoveryProblem _classify(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('location')) return DiscoveryProblem.locationOff;
    if (s.contains('permission') || s.contains('denied')) {
      return DiscoveryProblem.bluetoothDenied;
    }
    if (s.contains('off') || s.contains('poweredoff')) {
      return DiscoveryProblem.bluetoothOff;
    }
    return DiscoveryProblem.none;
  }

  @override
  Future<void> stop() async {
    await _bleSub?.cancel();
    _bleSub = null;
    _startedAt = null;
  }

  @override
  ObdTransport transportFor(Adapter adapter) => buildTransport(adapter);

  @override
  void dispose() {
    unawaited(stop());
    _adapters.close();
    _problem.close();
  }
}

/// Named adapters first, then by signal, then anonymous ones last — the
/// §9.1 ordering, so the thing the user is looking for is at the top and
/// "Other devices" sinks.
List<Adapter> sortForDisplay(List<Adapter> adapters) {
  final out = [...adapters];
  out.sort((a, b) {
    if (a.isAnonymous != b.isAnonymous) return a.isAnonymous ? 1 : -1;
    final byRating = a.rating.index.compareTo(b.rating.index);
    if (a.rating != b.rating &&
        (a.rating == AdapterRating.knownGood ||
            b.rating == AdapterRating.knownGood)) {
      return byRating;
    }
    final ar = a.rssi, br = b.rssi;
    if (ar != null && br != null && ar != br) return br.compareTo(ar);
    if (ar != null && br == null) return -1;
    if (ar == null && br != null) return 1;
    return a.displayName.compareTo(b.displayName);
  });
  return out;
}

/// The transport for an [Adapter.id]. Kept free of the discovery object so
/// a remembered adapter can be reconnected without scanning first.
ObdTransport buildTransport(Adapter adapter) {
  final id = adapter.id;
  if (id.startsWith('spp:')) {
    return SppTransport(address: id.substring(4), name: adapter.name);
  }
  if (id.startsWith('wifi:')) {
    final parts = id.substring(5).split(':');
    return WifiTransport(
      host: parts.first,
      port: int.tryParse(parts.last) ?? WifiTransport.defaultPort,
    );
  }
  throw ArgumentError.value(id, 'adapter.id', 'no transport for this kind');
}

/// Discovery with a scripted result set. Used by the tests and by Demo
/// Mode, where there is no radio and the point is to show the flow.
class FakeAdapterDiscovery implements AdapterDiscovery {
  FakeAdapterDiscovery({
    this.results = const [],
    this.problemOnStart = DiscoveryProblem.none,
    this.transportBuilder,
  });

  final List<Adapter> results;
  final DiscoveryProblem problemOnStart;

  /// Lets a test hand back a `MockTransport` replaying a recorded car.
  final ObdTransport Function(Adapter)? transportBuilder;

  final _adapters = StreamController<List<Adapter>>.broadcast();
  final _problem = StreamController<DiscoveryProblem>.broadcast();
  bool _scanning = false;
  Duration _elapsed = Duration.zero;

  @override
  Stream<List<Adapter>> get adapters => _adapters.stream;

  @override
  Stream<DiscoveryProblem> get problem => _problem.stream;

  @override
  bool get isScanning => _scanning;

  @override
  Duration get elapsed => _elapsed;

  /// Moves the scan clock on, so a test can reach the 15 s gate without
  /// waiting 15 s.
  void advance(Duration d) => _elapsed += d;

  @override
  Future<void> start() async {
    _scanning = true;
    _elapsed = Duration.zero;
    if (problemOnStart != DiscoveryProblem.none) {
      // A blocked scan is not a running scan.
      _scanning = false;
      _problem.add(problemOnStart);
      return;
    }
    _adapters.add(sortForDisplay(results));
  }

  @override
  Future<void> stop() async => _scanning = false;

  @override
  ObdTransport transportFor(Adapter adapter) =>
      transportBuilder?.call(adapter) ?? buildTransport(adapter);

  @override
  void dispose() {
    _adapters.close();
    _problem.close();
  }
}
