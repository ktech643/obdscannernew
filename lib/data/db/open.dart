import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

/// Opens the app's database file in the platform's private data directory.
/// Kept apart from [AppDatabase] so the database class itself, and every
/// test of it, stays free of the Flutter plugin.
AppDatabase openAppDatabase() => AppDatabase(_open());

QueryExecutor _open() => driftDatabase(name: 'torque_obd2');
