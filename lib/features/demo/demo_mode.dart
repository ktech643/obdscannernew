import 'package:flutter/services.dart' show rootBundle;

import '../../session/adapter_discovery.dart';
import '../../transport/mock_transport.dart';
import '../../transport/obd_trace.dart';

/// SPEC §11.1 — "Try it without an adapter".
///
/// Required for store review, not a nicety: a reviewer has no car and no
/// adapter, and an app that shows nothing without one gets rejected as
/// non-functional. It is also the honest answer for someone whose adapter
/// has not arrived yet.
///
/// The data is a **recorded session**, replayed through exactly the same
/// transport, protocol engine and session the real thing uses — so what a
/// reviewer sees is what a car produces, not a mock-up. Values hold steady
/// once the recording runs out; nothing here invents a number.
class DemoMode {
  DemoMode._();

  /// A healthy 2014 Civic on CAN. Chosen because every gauge in the default
  /// layout has a real reading in it.
  static const trace = 'assets/traces/clean_can.obdtrace';

  static const adapter = Adapter(
    id: 'demo:clean_can',
    name: 'Demo car',
    kind: AdapterKind.wifi,
    rating: AdapterRating.knownGood,
    detail: 'A recorded 2014 Honda Civic — no adapter needed',
  );

  /// Discovery that offers exactly one "adapter": the recording.
  static Future<AdapterDiscovery> discovery() async {
    final parsed = ObdTrace.parse(await rootBundle.loadString(trace));
    return FakeAdapterDiscovery(
      results: const [adapter],
      // Real time, so the handshake steps are legible rather than a blur.
      transportBuilder: (_) => MockTransport(parsed, speed: 4),
    );
  }
}
