import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/ids.dart';
import 'package:torque_obd2/data/repositories/trip_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/data/trips/trip_csv.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/garage/trip_recordings_screen.dart';
import 'package:torque_obd2/models/enums.dart';

/// SPEC §5.5 Garage › Trip recordings, §7.2 "last 3 trips" and §7.5
/// "downgrade, never delete data", on a real in-memory database.
///
/// Rows are inserted straight into the table, never through
/// `TripRepository.start`, and the delete goes through the screen's seam:
/// the fake clock allows no file I/O, and this screen only reads rows.
/// Every fixture is a trip the recorder could have saved — a free trip is
/// at most 2:00 of recorded time, an open trip has no figures yet (there
/// are no checkpoints), and an interrupted one says why.
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late VehicleRow golf;
  late VehicleRow civic;

  /// Everything opened inside the test body, under its fake clock: a
  /// database opened on the real clock and used under the fake one
  /// deadlocks on drift's lock.
  Future<void> seed() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
    );
    // Never touched: the screen resolves no file, and delete is a seam.
    trips = TripRepository(db, TripFiles(Directory('no-io-under-fake-clock')));
    final vehicles = VehicleRepository(db);
    golf = await vehicles.create(
      nickname: 'The Golf',
      fuel: VehicleFuel.petrol,
    );
    civic = await vehicles.create(
      nickname: 'The Civic',
      fuel: VehicleFuel.petrol,
    );
  }

  /// A trip as the recorder leaves it. Ended: [recordedMs] of recorded time
  /// covering [km] (average from the two, top speed a little above it),
  /// [fuelL] when the car sent a fuel rate. [open]: the row a recording
  /// holds — no end, no figures, the header's bytes.
  Future<TripSessionRow> addTrip(
    VehicleRow car,
    DateTime startedAt, {
    bool open = false,
    double? km,
    int recordedMs = 100000,
    double? fuelL,
    TripEnd end = TripEnd.stopped,
  }) async {
    final id = newId();
    final avg = km == null ? null : km / (recordedMs / 3600000);
    await db
        .into(db.tripSessions)
        .insert(
          TripSessionsCompanion.insert(
            id: id,
            vehicleId: car.id,
            startedAt: startedAt,
            lastOpenedAt: startedAt,
            samplesFilePath: TripFiles.pathForId(id),
            endedAt: Value(
              open ? null : startedAt.add(Duration(milliseconds: recordedMs)),
            ),
            distanceKm: Value(open ? null : km),
            avgSpeedKph: Value(open ? null : avg),
            maxSpeedKph: Value(open || avg == null ? null : avg + 9),
            fuelUsedL: Value(open ? null : fuelL),
            recordedMs: Value(open ? null : recordedMs),
            sampleCount: Value(open ? 0 : recordedMs ~/ 500),
            fileBytes: Value(
              open ? TripCsv.header.length : recordedMs ~/ 500 * 14,
            ),
            interrupted: Value(!open && end.interrupted),
            endReason: Value(open ? null : end),
          ),
        );
    return (await trips.byId(id))!;
  }

  /// Long enough for a sheet's entry and exit, so a finder never sees the
  /// one being left.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  /// Unmount so the drift stream is cancelled, and elapse its cancel timer
  /// inside the test.
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Every id the screen asked to delete. The seam removes the row as the
  /// repository would (the file half needs real I/O), so the list follows.
  late List<String> deleted;
  Future<bool> deleteRow(String id) async {
    deleted.add(id);
    await (db.delete(db.tripSessions)..where((t) => t.id.equals(id))).go();
    return true;
  }

  Future<void> pumpList(
    WidgetTester tester, {
    VehicleRow? vehicle,
    bool isPro = false,
    Future<void> Function(String id)? touch,
    bool Function(String id)? isRecording,
  }) async {
    deleted = [];
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MaterialApp(
          theme: torqueTheme(),
          debugShowCheckedModeBanner: false,
          home: TripRecordingsScreen(
            trips: trips,
            vehicle: vehicle ?? golf,
            isPro: isPro,
            delete: deleteRow,
            touch: touch,
            isRecording: isRecording,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  const held = 'Kept — the free plan shows the last 3 trips.';
  const heldSheet =
      'The free plan shows the last 3 trips for each car. This one is '
      'kept, not deleted.';
  const freeFootnote =
      'The free plan shows the last 3 trips for each car. Earlier ones are '
      'kept, not deleted.';
  const retention =
      'Trips are kept for 30 days. Past 200 MB, the ones opened least '
      'recently go first.';

  /// Five of the Golf's free trips, oldest first — 1.1 km to 1.5 km, so
  /// each one's figures say which trip it is — and three of the Civic's,
  /// all newer than any of the Golf's. Counted over every car, the Civic's
  /// three would be "the last 3" and the Golf would show none in full.
  Future<List<TripSessionRow>> fiveAndThree() async {
    final day = DateTime.utc(2026, 9, 20, 8);
    final mine = [
      for (var i = 0; i < 5; i++)
        await addTrip(
          golf,
          day.add(Duration(hours: i)),
          km: 1.1 + i / 10,
          fuelL: 0.1,
        ),
    ];
    for (var i = 0; i < 3; i++) {
      await addTrip(civic, day.add(Duration(days: 1, hours: i)), km: 0.6);
    }
    return mine;
  }

  group('★ §7.2 last 3 trips, per car', () {
    testWidgets('★ §7.2 last 3 trips per car, held not gone (§7.5)', (
      tester,
    ) async {
      await seed();
      final mine = await fiveAndThree();
      await pumpList(tester);

      // The three newest, in full.
      for (final km in ['1.5 km', '1.4 km', '1.3 km']) {
        expect(
          find.textContaining('$km · 1 min · avg'),
          findsOneWidget,
          reason: '$km is one of the last 3',
        );
      }
      // The two oldest: listed under their own heading, by date, with no
      // figures — held, not trimmed.
      expect(find.text('Earlier trips'), findsOneWidget);
      expect(find.text(held), findsNWidgets(2));
      expect(find.textContaining('1.2 km'), findsNothing);
      expect(find.textContaining('1.1 km'), findsNothing);
      // Another car's trips are neither listed nor counted.
      expect(find.textContaining('0.6 km'), findsNothing);
      expect(find.text(freeFootnote), findsOneWidget);
      expect(find.text('See Pro'), findsNothing, reason: 'never unasked');

      // A held trip opens by its date only, and can still be deleted.
      await tester.tap(find.text(held).last);
      await settle(tester);
      expect(find.text('Started'), findsOneWidget);
      expect(find.text(heldSheet), findsOneWidget);
      expect(find.text('Distance'), findsNothing, reason: 'figures held');
      expect(find.text('Delete trip'), findsOneWidget, reason: 'deletable');
      Navigator.of(tester.element(find.text(heldSheet))).pop();
      await settle(tester);

      // Nothing was deleted to make it so.
      expect(await trips.recent(golf.id), hasLength(5));
      expect(deleted, isEmpty);

      // Pro: all five, in full, and no held section.
      await drain(tester);
      await pumpList(tester, isPro: true);
      for (final r in mine) {
        expect(
          find.textContaining(
            '${r.distanceKm!.toStringAsFixed(1)} km · 1 min · avg',
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Earlier trips'), findsNothing);
      expect(find.text(held), findsNothing);
      expect(find.text(freeFootnote), findsNothing);
      expect(find.textContaining('0.6 km'), findsNothing);
      await drain(tester);
    });

    testWidgets('the other car\'s list is its own three', (tester) async {
      await seed();
      await fiveAndThree();
      await pumpList(tester, vehicle: civic);
      expect(find.textContaining('0.6 km · 1 min'), findsNWidgets(3));
      expect(find.text('Earlier trips'), findsNothing);
      expect(find.text(held), findsNothing);
      await drain(tester);
    });
  });

  group('★ the trip being recorded', () {
    testWidgets('★ the trip being recorded cannot be deleted', (tester) async {
      await seed();
      await addTrip(golf, DateTime.utc(2026, 9, 20, 8), km: 1.1);
      final open = await addTrip(
        golf,
        DateTime.utc(2026, 9, 20, 9),
        open: true,
      );
      await pumpList(tester);

      // Hard rule 11: a glyph and a word, in blue — informational, never a
      // fault colour.
      final word = find.text('Recording');
      expect(word, findsOneWidget);
      final t = tester.element(word).tokens;
      expect(tester.widget<Text>(word).style?.color, t.tellBlue);
      final glyph = find.descendant(
        of: find.ancestor(of: word, matching: find.byType(Row)).first,
        matching: find.byType(Icon),
      );
      expect(glyph, findsOneWidget, reason: 'the glyph beside the word');
      expect(tester.widget<Icon>(glyph).icon, Tell.blue.glyph);
      expect(tester.widget<Icon>(glyph).color, t.tellBlue);

      await tester.tap(word);
      await settle(tester);
      expect(
        find.text('Recording now. Stop it on the Dashboard to delete it.'),
        findsOneWidget,
      );
      expect(find.text('Delete trip'), findsNothing);
      expect(find.byType(DestructiveButton), findsNothing);
      expect(deleted, isEmpty);
      expect((await trips.byId(open.id))?.endedAt, isNull, reason: 'kept');
      await drain(tester);
    });
  });

  group('★ retention\'s least-recently-opened order', () {
    testWidgets('★ opening a trip calls touch()', (tester) async {
      await seed();
      final mine = await fiveAndThree();
      await pumpList(tester);
      final before = {
        for (final r in await trips.recent(golf.id)) r.id: r.lastOpenedAt,
      };

      // The newest, shown in full, then the oldest, held: opening either
      // is opening it, and moves it back in the 200 MB queue.
      await tester.tap(find.textContaining('1.5 km'));
      await settle(tester);
      Navigator.of(tester.element(find.text('Delete trip'))).pop();
      await settle(tester);
      await tester.tap(find.text(held).last);
      await settle(tester);

      final after = {
        for (final r in await trips.recent(golf.id)) r.id: r.lastOpenedAt,
      };
      final newest = mine.last.id, oldest = mine.first.id;
      expect(after[newest], isNot(before[newest]), reason: 'opened');
      expect(after[newest]!.isUtc, isTrue);
      expect(after[oldest], isNot(before[oldest]), reason: 'opened, held');
      for (final r in mine.sublist(1, 4)) {
        expect(after[r.id], before[r.id], reason: 'not opened');
      }
      await drain(tester);
    });

    testWidgets('★ the sheet\'s figures sit inside its margins', (
      tester,
    ) async {
      // Flush to the sheet's edge, "2 min 0 s" and "34 km/h" were cut off
      // on the simulator: every other ValueList sits in a padded card.
      await seed();
      await fiveAndThree();
      await pumpList(tester);
      await tester.tap(find.textContaining('1.5 km'));
      await settle(tester);
      final sheet = tester.getRect(find.byType(BottomSheet));
      final figures = tester.getRect(find.byType(ValueList));
      expect(figures.left, sheet.left + Space.gutter);
      expect(figures.right, sheet.right - Space.gutter);
      Navigator.of(tester.element(find.text('Delete trip'))).pop();
      await settle(tester);
      await drain(tester);
    });

    testWidgets('the row is touched before its sheet opens', (tester) async {
      await seed();
      final mine = await fiveAndThree();
      final touched = <String>[];
      bool? sheetUp;
      await pumpList(
        tester,
        touch: (id) async {
          touched.add(id);
          sheetUp = find.byType(DestructiveButton).evaluate().isNotEmpty;
        },
      );
      await tester.tap(find.textContaining('1.4 km'));
      await settle(tester);
      expect(touched, [mine[3].id], reason: 'that trip, once');
      expect(sheetUp, isFalse, reason: 'touched first, then opened');
      expect(find.text('Delete trip'), findsOneWidget);
      await drain(tester);
    });
  });

  group('what a row and its sheet say', () {
    testWidgets('fuel is always "(estimated)", and absent is said', (
      tester,
    ) async {
      await seed();
      await addTrip(golf, DateTime.utc(2026, 9, 20, 8), km: 1.1);
      await addTrip(golf, DateTime.utc(2026, 9, 20, 9), km: 1.2, fuelL: 0.1);
      await pumpList(tester);

      expect(
        find.text('1.2 km · 1 min · avg 43 km/h · 0.1 L used (estimated)'),
        findsOneWidget,
      );
      // No fuel rate from the car: no fuel part at all — never "0.0 L".
      expect(find.text('1.1 km · 1 min · avg 40 km/h'), findsOneWidget);

      await tester.tap(find.textContaining('1.2 km'));
      await settle(tester);
      expect(find.text('Fuel used (estimated)'), findsOneWidget);
      expect(find.text('0.1 L'), findsOneWidget);
      expect(find.text('1 min 40 s'), findsOneWidget, reason: 'Recorded');
      expect(find.text('You stopped it'), findsOneWidget);
      Navigator.of(tester.element(find.text('0.1 L'))).pop();
      await settle(tester);

      await tester.tap(find.textContaining('1.1 km'));
      await settle(tester);
      expect(find.text('Fuel used (estimated)'), findsOneWidget);
      // Not "not reported by this car": the trip may simply have missed it.
      expect(find.text('Not recorded on this trip'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('interrupted trips say so; a capped one says the limit', (
      tester,
    ) async {
      await seed();
      final day = DateTime.utc(2026, 9, 20, 8);
      for (final (i, end) in [
        TripEnd.stopped,
        TripEnd.appKilled,
        TripEnd.linkLost,
        TripEnd.storageFull,
        TripEnd.writeFailed,
        TripEnd.ignitionOff,
      ].indexed) {
        await addTrip(golf, day.add(Duration(hours: i)), km: 1.0, end: end);
      }
      await addTrip(
        golf,
        day.add(const Duration(hours: 7)),
        km: 1.5,
        recordedMs: 120000,
        end: TripEnd.freeCap,
      );
      await pumpList(tester, isPro: true); // all seven in full
      expect(find.text('Interrupted'), findsNWidgets(4));
      expect(find.text('2-minute limit'), findsOneWidget);

      await tester.tap(find.text('2-minute limit'));
      await settle(tester);
      expect(find.text("The free plan's 2-minute limit"), findsOneWidget);
      expect(find.text('2 min'), findsOneWidget);
      Navigator.of(tester.element(find.text('2 min'))).pop();
      await settle(tester);

      await tester.tap(find.text('Interrupted').first);
      await settle(tester);
      expect(find.text('The trip file couldn\'t be written'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('delete takes two taps, calls the seam, and is said', (
      tester,
    ) async {
      await seed();
      final trip = await addTrip(golf, DateTime.utc(2026, 9, 20, 8), km: 1.1);
      await pumpList(tester);
      final handle = tester.ensureSemantics();
      tester.takeAnnouncements();

      await tester.tap(find.textContaining('1.1 km'));
      await settle(tester);
      await tester.tap(find.text('Delete trip'));
      await settle(tester);
      expect(deleted, isEmpty, reason: 'one tap arms it');
      expect(find.text('Tap again to delete this trip'), findsOneWidget);

      // Left armed, it disarms by itself.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Delete trip'), findsOneWidget);
      expect(deleted, isEmpty);

      await tester.tap(find.text('Delete trip'));
      await tester.pump();
      await tester.tap(find.text('Tap again to delete this trip'));
      await settle(tester);
      expect(deleted, [trip.id]);
      expect(find.text('Tap again to delete this trip'), findsNothing);
      expect(find.byType(DestructiveButton), findsNothing, reason: 'closed');
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Trip deleted.'),
      );
      expect(find.text('No trips yet'), findsOneWidget, reason: 'the list');
      handle.dispose();
      await drain(tester);
    });

    testWidgets('the footer states the retention, on either plan', (
      tester,
    ) async {
      await seed();
      await pumpList(tester);
      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.text(retention), findsOneWidget);
      expect(find.text(freeFootnote), findsOneWidget);
      await drain(tester);

      await pumpList(tester, isPro: true);
      expect(find.text(retention), findsOneWidget, reason: 'Pro too');
      expect(find.text(freeFootnote), findsNothing);
      await drain(tester);
    });
  });

  group('★ the review of slice 17: what an open or short trip says', () {
    /// A trip the recorder has reopened: Resume keeps the figures the file
    /// proved before the kill until the trip is saved again.
    Future<TripSessionRow> resumed() async {
      final r = await addTrip(golf, DateTime.utc(2026, 9, 28, 9), km: 3.2);
      await (db.update(db.tripSessions)..where((t) => t.id.equals(r.id))).write(
        const TripSessionsCompanion(endedAt: Value(null)),
      );
      return (await trips.byId(r.id))!;
    }

    testWidgets('★ the trip being recorded shows no figures from before', (
      tester,
    ) async {
      await seed();
      await resumed();
      await pumpList(tester, isRecording: (_) => true);
      // Beside "Recording", the pre-kill 3.2 km read as the live distance.
      expect(find.text('Recording'), findsOneWidget);
      expect(find.textContaining('3.2 km'), findsNothing);
      await tester.tap(find.text('Recording'));
      await settle(tester);
      // "Not reported by this car" under every figure, and "Samples 0".
      expect(find.text('Not reported by this car'), findsNothing);
      expect(find.text('Samples'), findsNothing);
      expect(find.text('Started'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('★ an open row nobody is recording is not "Recording"', (
      tester,
    ) async {
      // A trip whose save failed stays open until the next Record or
      // launch; the list called it "Recording" with nothing to Stop.
      await seed();
      await addTrip(golf, DateTime.utc(2026, 9, 28, 9), open: true);
      await pumpList(tester, isRecording: (_) => false);
      expect(find.text('Recording'), findsNothing);
      expect(find.text('Not finished'), findsOneWidget);
      await tester.tap(find.text('Not finished'));
      await settle(tester);
      expect(
        find.text(
          "This trip wasn't finished. It is saved the next time Torque "
          'records or opens.',
        ),
        findsOneWidget,
      );
      await drain(tester);
    });

    testWidgets('★ a short trip is too short to average, not unreported', (
      tester,
    ) async {
      // Speed came, but under the 10 s an average needs.
      await seed();
      final r = await addTrip(
        golf,
        DateTime.utc(2026, 9, 28, 9),
        km: 0.08,
        recordedMs: 8000,
      );
      await (db.update(db.tripSessions)..where((t) => t.id.equals(r.id))).write(
        const TripSessionsCompanion(avgSpeedKph: Value(null)),
      );
      await pumpList(tester);
      await tester.tap(find.textContaining('0.1 km'));
      await settle(tester);
      expect(find.text('Too short to average'), findsOneWidget);
      expect(find.text('Not reported by this car'), findsNothing);
      await drain(tester);
    });
  });
}
