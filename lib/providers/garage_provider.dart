import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/models.dart';

/// Vehicles, service history, reminders, fuel and trips.
///
/// All of this is local-first and works with no adapter plugged in at all.
class GarageProvider extends ChangeNotifier {
  final List<Vehicle> _vehicles = [
    const Vehicle(
      id: 'golf',
      nickname: 'The Golf',
      year: 2014,
      make: 'Volkswagen',
      model: 'Golf',
      trim: 'GTD',
      fuel: VehicleFuel.diesel,
      odometerKm: 142380,
      vin: 'WVWZZZ1KZAW681234',
      isPrimary: true,
    ),
  ];

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  Vehicle get active =>
      _vehicles.firstWhere((v) => v.isPrimary, orElse: () => _vehicles.first);

  final List<ServiceRecord> _records = [
    ServiceRecord(
      id: 'r1',
      title: 'Coil pack, cylinder 1',
      date: DateTime(2026, 9, 2),
      odometerKm: 142380,
      cost: 142.50,
      vendor: "Marek's",
      fixedCode: 'P0301',
    ),
    ServiceRecord(
      id: 'r2',
      title: 'Coolant flush',
      date: DateTime(2026, 9, 1),
      odometerKm: 142100,
      cost: 68.00,
      vendor: 'Halfords',
    ),
    ServiceRecord(
      id: 'r3',
      title: 'Tyre rotation',
      date: DateTime(2026, 6, 14),
      odometerKm: 136940,
      cost: 25.00,
    ),
    ServiceRecord(
      id: 'r4',
      title: 'Air filter',
      date: DateTime(2026, 6, 14),
      odometerKm: 136940,
      cost: 18.99,
    ),
    ServiceRecord(
      id: 'r5',
      title: 'Engine oil & filter',
      date: DateTime(2026, 2, 3),
      odometerKm: 128050,
      cost: 94.00,
      vendor: "Marek's",
    ),
  ];

  List<ServiceRecord> get records => List.unmodifiable(_records);

  /// Free keeps ten records. The count is shown, never enforced silently.
  int get freeRecordCeiling => 10;
  int get recordCount => 9;

  double get yearTotal => 348.49;

  /// Grouped newest month first, matching the log's layout.
  Map<String, List<ServiceRecord>> get recordsByMonth {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final out = <String, List<ServiceRecord>>{};
    final sorted = List.of(_records)..sort((a, b) => b.date.compareTo(a.date));
    for (final r in sorted) {
      out
          .putIfAbsent('${months[r.date.month - 1]} ${r.date.year}', () => [])
          .add(r);
    }
    return out;
  }

  static const serviceTypes = [
    'Engine oil & filter',
    'Tyres',
    'Brakes',
    'Filters',
    'Battery',
    'Coolant',
    'Timing belt',
    'Repair',
    'Custom',
  ];

  // ------------------------------------------------------------ reminders
  static const reminders = <Reminder>[
    Reminder(
      title: 'Engine oil & filter',
      detail: 'Overdue by 4,380 km · due at 138,000 km',
      overdue: true,
    ),
    Reminder(title: 'MOT / inspection', detail: 'In 11 weeks · 21 Nov 2026'),
    Reminder(
      title: 'Brake fluid',
      detail: 'In 8 months · time-based, not mileage',
    ),
    Reminder(
      title: 'Timing belt',
      detail: 'In 57,620 km · due at 200,000 km',
      critical: true,
    ),
    Reminder(title: 'Cabin filter', detail: 'Paused', paused: true),
  ];

  bool _notificationsEnabled = false;
  bool get notificationsEnabled => _notificationsEnabled;

  void enableNotifications() {
    _notificationsEnabled = true;
    notifyListeners();
  }

  int get overdueCount => reminders.where((r) => r.overdue).length;

  // ----------------------------------------------------------------- fuel
  static final fuelEntries = <FuelEntry>[
    FuelEntry(
      date: _d(2026, 8, 28),
      odometerKm: 141890,
      litres: 48.20,
      cost: 67.02,
      consumption: 5.2,
    ),
    // Recorded, but excluded from the lifetime figure — including part fills
    // is the most common way fuel logs lie.
    FuelEntry(
      date: _d(2026, 8, 14),
      odometerKm: 140960,
      litres: 22.00,
      cost: 30.58,
      partFill: true,
    ),
    FuelEntry(
      date: _d(2026, 8, 2),
      odometerKm: 140020,
      litres: 51.40,
      cost: 71.44,
      consumption: 5.6,
    ),
    FuelEntry(
      date: _d(2026, 7, 19),
      odometerKm: 139100,
      litres: 49.80,
      cost: 69.22,
      consumption: 5.4,
    ),
    FuelEntry(
      date: _d(2026, 7, 4),
      odometerKm: 138180,
      litres: 50.10,
      cost: 69.64,
      consumption: 5.3,
    ),
  ];

  static DateTime _d(int y, int m, int d) => DateTime(y, m, d);

  double get lifetimeConsumption => 5.4;
  double get bestConsumption => 5.1;
  double get worstConsumption => 6.3;
  double get costPerKm => 0.09;

  // ---------------------------------------------------------------- trips
  static const trips = <Trip>[
    Trip(
      id: 't1',
      name: 'Morning commute',
      when: 'Today',
      distanceKm: 12.4,
      minutes: 18,
      avgSpeed: 41,
    ),
    Trip(
      id: 't2',
      name: 'A-road run',
      when: '2 Sep',
      distanceKm: 34.1,
      minutes: 41,
      avgSpeed: 50,
    ),
    Trip(
      id: 't3',
      name: 'Evening drive',
      when: '30 Aug',
      distanceKm: 8.2,
      minutes: 14,
      avgSpeed: 35,
      interrupted: true,
    ),
    Trip(
      id: 't4',
      name: 'School run',
      when: '28 Aug',
      distanceKm: 4.1,
      minutes: 9,
      avgSpeed: 27,
      locked: true,
    ),
  ];

  // -------------------------------------------------------------- actions
  void addRecord(ServiceRecord record) {
    _records.add(record);
    notifyListeners();
  }

  void deleteRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
