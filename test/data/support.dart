import 'dart:io';

import 'package:drift/native.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
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
