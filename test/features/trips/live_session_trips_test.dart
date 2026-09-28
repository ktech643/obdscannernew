import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/features/live_tabs.dart';
import 'package:torque_obd2/features/trips/trip_recorder.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/session/obd_session.dart';

import '../../data/support.dart' show memoryDb;
import 'support.dart';

/// The trip recorder as `LiveSession` wires it. Each piece was tested only
/// through a copy of its wiring (the review of slice 17): here, removing any
/// one line from `LiveSession` fails its test.
void main() {
  Future<void> lifecycle(AppLifecycleState state) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'flutter/lifecycle',
            const StringCodec().encodeMessage(state.toString()),
            (_) {},
          );

  tearDown(() => lifecycle(AppLifecycleState.resumed));

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  /// A session with the Golf in the garage, over fakes; the garage read.
  Future<(LiveSession, FakeBackgroundService)> live(
    WidgetTester tester, {
    PlatformInfo platform = const FakePlatform(isAndroid: false),
    Future<void>? launch,
  }) async {
    await lifecycle(AppLifecycleState.resumed);
    final db = memoryDb();
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
    );
    await VehicleRepository(db)
        .create(nickname: 'The Golf', fuel: VehicleFuel.petrol);
    final background = FakeBackgroundService();
    final session = LiveSession(
      session: ObdSession(timeScale: 0.05),
      vehicles: VehicleRepository(db),
      platform: platform,
      background: background,
      tripStore: FakeTripStore(),
      tripClock: ManualTripClock(),
      tripLaunch: launch,
    );
    addTearDown(session.dispose);
    await pumpUntil(tester, () => session.garage!.loaded);
    return (session, background);
  }

  testWidgets('★ the plan reaches the recorder', (tester) async {
    // Only through applySettings: missed, a Pro user's trips stopped at 2:00.
    final (session, _) = await live(tester);
    expect(session.recorder!.isPro, isFalse);
    session.applySettings(autoReconnect: true, haptics: true, isPro: true);
    expect(session.recorder!.isPro, isTrue);
  });

  testWidgets('★ nothing is recorded under a car before it is identified', (
    tester,
  ) async {
    // §9.6: the primary is not yet the car on the wire — no VIN has been
    // judged against it — so Record is not offered for it.
    final (session, _) = await live(tester);
    final r = session.recorder!;
    expect(r.view.owner, isA<OwnerPending>());
    expect(r.refusal, RecordRefusal.checkingIdentity);
  });

  testWidgets('★ deleting a car lets go of its trip first', (tester) async {
    final (session, _) = await live(tester);
    expect(session.garage!.beforeDelete, session.recorder!.releaseVehicle);
  });

  testWidgets('★ back in front on Android, the recorder hears it', (
    tester,
  ) async {
    // Notification permission granted in Settings is read on the resume —
    // the only way the service starts for a trip already recording.
    final (_, background) = await live(
      tester,
      platform: const FakePlatform(isAndroid: true),
    );
    background.calls.clear();
    await lifecycle(AppLifecycleState.paused);
    await lifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(background.calls, contains('hasNotificationPermission'));
  });

  testWidgets('★ Record waits for the launch pass', (tester) async {
    // Before it, a trip the last run left open could still be closing.
    final pass = Completer<void>();
    final (session, _) = await live(tester, launch: pass.future);
    expect(session.recorder!.refusal, RecordRefusal.notLaunched);
    pass.complete();
    await tester.pump();
    await tester.pump();
    expect(session.recorder!.refusal, isNot(RecordRefusal.notLaunched));
  });
}
