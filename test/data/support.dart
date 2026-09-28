import 'dart:io';

import 'package:drift/native.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/data/trips/trip_csv.dart';
import 'package:torque_obd2/models/enums.dart';

/// A fresh in-memory database with foreign keys on, exactly as the app
/// opens it. Every test gets its own.
AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

/// A scratch directory for trip files, deleted by the caller.
Future<Directory> scratchDir() =>
    Directory.systemTemp.createTemp('torque_test_');

/// A fixed clock so ordering assertions don't race the wall clock.
final t0 = DateTime.utc(2026, 9, 5, 12);

DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

Future<VehicleRow> golf(AppDatabase db, {String? vin, DateTime? now}) =>
    VehicleRepository(db).create(
      nickname: 'Golf',
      fuel: VehicleFuel.petrol,
      vin: vin ?? 'WVWZZZ1KZBW000001',
      make: 'Volkswagen',
      model: 'Golf',
      year: 2011,
      odometerKm: 120000,
      now: now ?? t0,
    );

/// A trip file as the recorder writes it: the header, `#segment,0,<start>`,
/// one speed row every [stepMs] from 0 to [toMs], and a `#sync` after every
/// [syncEveryMs] of rows, stamped from an honest wall clock. [kph] gives
/// each row's speed from its t; 36 km/h (10 m/s) when absent.
String driveCsv(
  DateTime start, {
  required int toMs,
  double? Function(int t)? kph,
  int stepMs = 1000,
  int syncEveryMs = 5000,
}) {
  final b = StringBuffer(TripCsv.header)..write(TripCsv.segment(0, start));
  for (var t = 0; t <= toMs; t += stepMs) {
    b.write(TripCsv.row(t, '010D', kph == null ? 36.0 : kph(t)));
    if (t > 0 && t % syncEveryMs == 0) {
      b.write(TripCsv.sync(t, start.add(Duration(milliseconds: t))));
    }
  }
  return b.toString();
}
