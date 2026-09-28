import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/tables.dart' show TripEnd;
import 'package:torque_obd2/design_system/tokens.dart' show Tell;
import 'package:torque_obd2/features/trips/trip_format.dart';
import 'package:torque_obd2/features/trips/trip_recorder.dart';
import 'package:torque_obd2/features/trips/trip_strip_content.dart';
import 'package:torque_obd2/models/enums.dart';

/// SPEC §5.3's trip strip, as words: every state the strip can be in and
/// every sentence it says, read from `stripContentFor` and
/// `announcementFor` as tables. The copy is the design's STRIP section
/// verbatim — a word changed here is a word changed in the car, where the
/// driver reads it at a glance, so any change to copy or to which state
/// wins must fail a row below.
void main() {
  const en = TripFormat(DistanceUnit.km, numberLocale: 'en_US', use24h: true);
  const golf = OwnerVehicle('golf', 'Golf');
  const bmw = OwnerVehicle('bmw', 'BMW');
  // A local wall time, so '14:32' reads the same under any TZ.
  final at1432 = DateTime(2026, 9, 28, 14, 32);

  const gauges = 'Records distance, speed and the gauges on screen.';
  const freeLine = 'The free plan records 2 minutes per trip.';
  const inGarage = "It's in the Garage under Trip recordings.";
  const wifi =
      'Over Wi-Fi, recording pauses while Torque is in the background.';
  const notificationsOff =
      'Notifications are off for Torque. This phone needs one to keep '
      'recording in the background, so recording pauses there.';
  const noSpeed = "This car doesn't report speed, so distance isn't recorded.";
  const serviceRefused =
      "This phone didn't let Torque keep recording in the background, so "
      'recording pauses there.';

  TripView view({
    bool launched = true,
    bool latched = false,
    RecorderPhase phase = RecorderPhase.idle,
    TripHold? hold,
    TripOwner owner = golf,
    bool live = true,
    TripCaveat? caveat,
    TripResult? result,
    ResumeOffer? offer,
    bool isPro = false,
    bool speedMissing = false,
  }) => TripView(
    launched: launched,
    latched: latched,
    phase: phase,
    hold: hold,
    owner: owner,
    live: live,
    caveat: caveat,
    result: result,
    offer: offer,
    isPro: isPro,
    speedMissing: speedMissing,
    tripVehicleId: phase == RecorderPhase.idle ? null : 'golf',
  );

  StripContent? content(
    TripView v, {
    TripReading? reading,
    bool editing = false,
    bool electric = false,
    bool canUpgrade = true,
    bool canAddVehicle = true,
  }) => stripContentFor(
    v,
    reading,
    editing: editing,
    electric: electric,
    canUpgrade: canUpgrade,
    canAddVehicle: canAddVehicle,
    fmt: en,
  );

  /// Every field of [c], so a row that differs anywhere says where.
  void expectStrip(
    StripContent? c, {
    required String word,
    IconData? glyph,
    Tell tone = Tell.none,
    StripInk ink = StripInk.primary,
    String? timer,
    List<String> lines = const [],
    List<String> dimmed = const [],
    bool capDoor = false,
    List<String> actions = const [],
    bool stacked = false,
    String? spoken,
    bool hear = true,
  }) {
    expect(c, isNotNull, reason: 'hidden, but should say "$word"');
    expect(c!.word, word);
    expect(c.glyph, glyph, reason: 'the glyph of "$word"');
    expect(c.tone, tone, reason: 'the tone of "$word"');
    expect(c.ink, ink, reason: 'the ink of "$word"');
    expect(c.timer, timer, reason: 'the meter of "$word"');
    expect([for (final l in c.lines) l.text], lines, reason: word);
    expect(
      [
        for (final l in c.lines)
          if (l.dimmed) l.text,
      ],
      dimmed,
      reason: 'dimmed lines of "$word"',
    );
    expect(c.capDoor, capDoor, reason: 'is "$word" the §7.3 door');
    expect(
      [for (final a in c.actions) a.label],
      actions,
      reason: 'the controls of "$word"',
    );
    expect(c.stacked, stacked, reason: 'is "$word" always stacked');
    if (!hear) return;
    expect(
      c.spoken,
      spoken ?? [word, ...lines].join(' '),
      reason: 'what a screen reader hears for "$word"',
    );
  }

  TripReading meter(
    int elapsedMs, {
    bool free = false,
    double? km,
    double? kph,
    double? litres,
    bool speed = true,
  }) => TripReading(
    elapsedMs: elapsedMs,
    capMs: free ? 120000 : null,
    distanceKm: km,
    avgSpeedKph: kph,
    fuelUsedL: litres,
    speedReported: speed,
  );

  // 18:04 of driving at 41 km/h: 12.4 km, 1.1 L at 3.6 L/h.
  const drove = 18 * 60000 + 4000;
  const figures = '12.4 km · 18 min · avg 41 km/h · 1.1 L used (estimated)';

  TripResult saved(TripEnd end) => TripResult(
    kind: TripResultKind.saved,
    vehicleId: 'golf',
    end: end,
    nickname: 'Golf',
    savedUpTo: at1432,
    recordedMs: drove,
    distanceKm: 12.4,
    avgSpeedKph: 41.2,
    fuelUsedL: 1.1,
  );

  TripResult failed(TripResultKind kind, {bool outOfSpace = false}) =>
      TripResult(kind: kind, vehicleId: 'golf', outOfSpace: outOfSpace);

  test('★ hidden while the Dashboard already says it, or nothing is '
      'known yet', () {
    // The first row is the launch pass: until an interrupted trip is
    // closed, Record could open a second trip beside it.
    final cases = <String, (TripView, bool)>{
      'the launch pass is not done': (view(launched: false), false),
      'not launched, with a result': (
        view(launched: false, result: saved(TripEnd.stopped)),
        false,
      ),
      'latched by Delete all data': (view(latched: true), false),
      'the garage is loading': (view(owner: const OwnerLoading()), false),
      'edit mode, idle': (view(), true),
      'edit mode, with a result': (view(result: saved(TripEnd.stopped)), true),
      'edit mode, while starting': (view(phase: RecorderPhase.starting), true),
      'not live, this car, nothing to report': (view(live: false), false),
      'not live, a result for another car': (
        view(live: false, owner: bmw, result: saved(TripEnd.stopped)),
        false,
      ),
      'not live, Demo': (view(live: false, owner: const OwnerDemo()), false),
      'not live, no car': (view(live: false, owner: const OwnerNone()), false),
      'not live, checking identity': (
        view(live: false, owner: const OwnerPending('golf')),
        false,
      ),
    };
    for (final MapEntry(key: name, value: (v, editing)) in cases.entries) {
      expect(content(v, editing: editing), isNull, reason: name);
    }
  });

  test('★ what cannot be recorded is said, never a dimmed Record '
      '(§B.26)', () {
    expectStrip(
      content(view(owner: const OwnerDemo())),
      glyph: Icons.info_outline,
      ink: StripInk.secondary,
      word: "Demo Mode doesn't record trips.",
    );
    // No car: the form that adds one, when there is a way to it.
    final noCar = content(view(owner: const OwnerNone()));
    expectStrip(
      noCar,
      word: 'Trips are saved for each car.',
      actions: ['Add your car'],
    );
    expect(noCar!.actions.single.kind, StripActionKind.addVehicle);
    expect(noCar.actions.single.icon, Icons.add);
    expectStrip(
      content(view(owner: const OwnerNone()), canAddVehicle: false),
      word: 'Add your car in the Garage to record trips.',
    );
    // The VIN is being read, or §9.6's question is open.
    expectStrip(
      content(view(owner: const OwnerPending('golf'))),
      word: 'Checking which car this is…',
    );
    // A statement wins over this car's result: the result is about a
    // trip, the statement about whether one can start.
    expectStrip(
      content(
        view(owner: const OwnerPending('golf'), result: saved(TripEnd.stopped)),
      ),
      word: 'Checking which car this is…',
    );
  });

  test('★ idle and ready: Free, Pro and the three caveats', () {
    final free = content(view());
    expectStrip(
      free,
      word: 'Not recording',
      ink: StripInk.secondary,
      lines: [gauges, freeLine],
      actions: ['Record'],
    );
    final record = free!.actions.single;
    expect(record.kind, StripActionKind.record);
    expect(record.icon, Icons.fiber_manual_record_outlined);
    expect(record.semanticLabel, 'Record a trip');

    expectStrip(
      content(view(isPro: true)),
      word: 'Not recording',
      ink: StripInk.secondary,
      lines: [gauges],
      actions: ['Record'],
    );
    for (final (caveat, line) in [
      (TripCaveat.wifiInBackground, wifi),
      (TripCaveat.notificationsOff, notificationsOff),
      (TripCaveat.serviceRefused, serviceRefused),
    ]) {
      expectStrip(
        content(view(caveat: caveat)),
        word: 'Not recording',
        ink: StripInk.secondary,
        lines: [gauges, freeLine, line],
        actions: ['Record'],
      );
    }
    // Another car's clean stop is not this car's to report.
    expectStrip(
      content(view(owner: bmw, result: saved(TripEnd.stopped))),
      word: 'Not recording',
      ink: StripInk.secondary,
      lines: [gauges, freeLine],
      actions: ['Record'],
    );
  });

  test('★ starting, recording, paused and ending', () {
    expectStrip(
      content(view(phase: RecorderPhase.starting)),
      word: 'Starting the recording…',
    );
    expectStrip(
      content(view(phase: RecorderPhase.ending)),
      word: 'Saving the trip…',
    );
    // Mid-trip, edit mode keeps the status and its Stop.
    expectStrip(
      content(view(phase: RecorderPhase.ending), editing: true),
      word: 'Saving the trip…',
    );

    // Free: the limit is on the meter before it is reached.
    final free = content(
      view(phase: RecorderPhase.recording),
      reading: meter(102000, free: true, km: 1.16, kph: 41),
    );
    expectStrip(
      free,
      glyph: Icons.fiber_manual_record,
      tone: Tell.blue,
      ink: StripInk.tone,
      word: 'Recording',
      timer: '1:42 of 2:00',
      lines: ['1.2 km · avg 41 km/h'],
      actions: ['Stop'],
      spoken:
          'Recording, 1 minute 42 seconds of 2 minutes. 1.2 kilometres, '
          'average 41 kilometres per hour.',
    );
    final stop = free!.actions.single;
    expect(stop.kind, StripActionKind.stop);
    expect(stop.icon, Icons.stop);
    expect(stop.semanticLabel, 'Stop recording');

    final pro = view(phase: RecorderPhase.recording, isPro: true);
    expectStrip(
      content(pro, reading: meter(18 * 60000 + 5000, km: 12.4, kph: 41.2)),
      glyph: Icons.fiber_manual_record,
      tone: Tell.blue,
      ink: StripInk.tone,
      word: 'Recording',
      timer: '18:05',
      lines: ['12.4 km · avg 41 km/h'],
      actions: ['Stop'],
      spoken:
          'Recording, 18 minutes 5 seconds. 12.4 kilometres, average 41 '
          'kilometres per hour.',
    );
    expectStrip(
      content(
        pro,
        reading: meter(3730000, km: 55.1, kph: 53.2, litres: 4.6),
        editing: true,
      ),
      glyph: Icons.fiber_manual_record,
      tone: Tell.blue,
      ink: StripInk.tone,
      word: 'Recording',
      timer: '1:02:10',
      lines: ['55.1 km · avg 53 km/h · 4.6 L used (estimated)'],
      actions: ['Stop'],
      spoken:
          'Recording, 1 hour 2 minutes 10 seconds. 55.1 kilometres, average '
          '53 kilometres per hour, 4.6 litres used, estimated.',
    );
    // Just started: each part appears once it has a value.
    expectStrip(
      content(
        view(phase: RecorderPhase.recording),
        reading: meter(0, free: true),
      ),
      glyph: Icons.fiber_manual_record,
      tone: Tell.blue,
      ink: StripInk.tone,
      word: 'Recording',
      timer: '0:00 of 2:00',
      actions: ['Stop'],
      spoken: 'Recording, 0 seconds of 2 minutes.',
    );
    // B.6 Partial: a car with no Speed.
    expectStrip(
      content(
        view(phase: RecorderPhase.recording, speedMissing: true),
        reading: meter(45000, free: true, speed: false),
      ),
      glyph: Icons.fiber_manual_record,
      tone: Tell.blue,
      ink: StripInk.tone,
      word: 'Recording',
      timer: '0:45 of 2:00',
      lines: [noSpeed],
      actions: ['Stop'],
      // What it says is the defect test's, at the end of this file.
      hear: false,
    );
    // The caveat is said during the recording too.
    expectStrip(
      content(
        view(
          phase: RecorderPhase.recording,
          caveat: TripCaveat.wifiInBackground,
        ),
        reading: meter(30000, free: true, km: 0.3, kph: 36),
      ),
      glyph: Icons.fiber_manual_record,
      tone: Tell.blue,
      ink: StripInk.tone,
      word: 'Recording',
      timer: '0:30 of 2:00',
      lines: ['0.3 km · avg 36 km/h', wifi],
      actions: ['Stop'],
      spoken:
          'Recording, 30 seconds of 2 minutes. 0.3 kilometres, average 36 '
          'kilometres per hour. $wifi',
    );

    // Paused: the meter keeps counting, the figures are dimmed (hard
    // rule 4: figures that are not moving must not look live).
    const sofar = '12.4 km · avg 41 km/h';
    for (final (hold, reason) in [
      (TripHold.link, 'Waiting for the car to reconnect.'),
      (
        TripHold.ignitionOff,
        'The ignition is off. The trip ends if it stays off for 10 minutes.',
      ),
      (TripHold.identity, 'Checking which car this is before recording more.'),
      (TripHold.background, 'Paused while Torque is in the background.'),
    ]) {
      expectStrip(
        content(
          view(phase: RecorderPhase.recording, hold: hold, isPro: true),
          reading: meter(18 * 60000 + 4000, km: 12.4, kph: 41.2),
        ),
        glyph: Icons.pause_circle_outline,
        word: 'Paused',
        timer: '18:04',
        lines: [reason, sofar],
        dimmed: [sofar],
        actions: ['Stop'],
        // A reason that says "Paused" already is not prefixed with it
        // again: VoiceOver read "Paused, paused while Torque is in the
        // background."
        spoken:
            '${reason.startsWith('Paused') ? reason : 'Paused, ${reason[0].toLowerCase()}${reason.substring(1)}'} 18 '
            'minutes 4 seconds recorded. 12.4 kilometres, average 41 '
            'kilometres per hour.',
      );
    }
    // The design's own example, and the free meter while paused.
    expectStrip(
      content(
        view(phase: RecorderPhase.recording, hold: TripHold.link),
        reading: meter(64000, free: true),
      ),
      glyph: Icons.pause_circle_outline,
      word: 'Paused',
      timer: '1:04 of 2:00',
      lines: ['Waiting for the car to reconnect.'],
      actions: ['Stop'],
      spoken:
          'Paused, waiting for the car to reconnect. 1 minute 4 seconds '
          'recorded.',
    );
    expect(
      content(
        view(phase: RecorderPhase.recording, hold: TripHold.link, isPro: true),
        reading: meter(18 * 60000 + 4000),
      )!.spoken,
      'Paused, waiting for the car to reconnect. 18 minutes 4 seconds '
      'recorded.',
    );
  });

  test('★ "Resume trip?" — why, how far, and what the free plan has '
      'left', () {
    ResumeOffer offer(TripEnd end, {int? ms, double? km}) => ResumeOffer(
      tripId: 't1',
      vehicleId: 'golf',
      end: end,
      endedAt: at1432,
      recordedMs: ms,
      distanceKm: km,
    );

    final killed = content(
      view(offer: offer(TripEnd.appKilled, ms: 90000, km: 1.0)),
    );
    expectStrip(
      killed,
      glyph: Icons.history,
      word: 'Resume trip?',
      lines: [
        'Torque closed while recording at 14:32. The trip is saved up to '
            'then.',
        '1.0 km · 1 min',
        '0:30 left on the free plan.',
      ],
      stacked: true,
      actions: ['Resume', 'Not now'],
    );
    final resume = killed!.actions.first;
    expect(resume.kind, StripActionKind.resume);
    expect(resume.icon, Icons.fiber_manual_record_outlined);
    expect(resume.semanticLabel, 'Resume the trip');
    expect(killed.actions.last.kind, StripActionKind.notNow);

    expectStrip(
      content(
        view(isPro: true, offer: offer(TripEnd.linkLost, ms: drove, km: 12.4)),
      ),
      glyph: Icons.history,
      word: 'Resume trip?',
      lines: [
        'The connection was lost at 14:32. The trip is saved up to then.',
        '12.4 km · 18 min',
      ],
      stacked: true,
      actions: ['Resume', 'Not now'],
    );
    // The design's spoken example: a Pro trip with nothing measured.
    expectStrip(
      content(view(isPro: true, offer: offer(TripEnd.appKilled))),
      glyph: Icons.history,
      word: 'Resume trip?',
      lines: [
        'Torque closed while recording at 14:32. The trip is saved up to '
            'then.',
      ],
      stacked: true,
      actions: ['Resume', 'Not now'],
      spoken:
          'Resume trip? Torque closed while recording at 14:32. The trip is '
          'saved up to then.',
    );
    // An offer is this car's question, asked before its old result.
    expect(
      content(
        view(
          offer: offer(TripEnd.linkLost, ms: 10000),
          result: saved(TripEnd.linkLost),
        ),
      )!.word,
      'Resume trip?',
    );
  });

  test('★ every result sentence, and where it shows', () {
    // (end, sentence, amber, in the Garage)
    final rows = <(TripEnd, String, bool, bool)>[
      (TripEnd.stopped, 'Trip saved.', false, true),
      (TripEnd.disconnected, 'Trip saved.', false, true),
      (
        TripEnd.notification,
        'Stopped from the notification. Trip saved.',
        false,
        true,
      ),
      (
        TripEnd.freeCap,
        "Stopped at 2 minutes, the free plan's limit. Trip saved.",
        false,
        false,
      ),
      (
        TripEnd.linkLost,
        'Stopped — the connection was lost. The trip is saved up to 14:32.',
        false,
        false,
      ),
      (
        TripEnd.ignitionOff,
        'Stopped — the ignition was off for 10 minutes. Trip saved.',
        false,
        false,
      ),
      (
        TripEnd.otherVehicle,
        'Stopped — another car answered. The trip is saved under Golf.',
        false,
        false,
      ),
      (
        TripEnd.heldTooLong,
        'Stopped after 10 minutes paused. Trip saved.',
        false,
        false,
      ),
      (
        TripEnd.storageFull,
        'Stopped — this phone is out of storage. The trip is saved up to '
            '14:32.',
        true,
        false,
      ),
      (
        TripEnd.writeFailed,
        "Stopped — the trip file couldn't be written. The trip is saved up "
            'to 14:32.',
        true,
        false,
      ),
    ];
    for (final (end, sentence, amber, garage) in rows) {
      final r = saved(end);
      expect(resultSentence(r, en), sentence, reason: end.name);
      expectStrip(
        content(view(result: r)),
        glyph: amber ? Icons.warning_amber_outlined : null,
        tone: amber ? Tell.amber : Tell.none,
        word: sentence,
        lines: [figures, if (garage) inGarage, freeLine],
        capDoor: end == TripEnd.freeCap,
        actions: ['Record'],
      );
      // Not live: still said, with no control.
      expectStrip(
        content(view(result: r, live: false, isPro: true)),
        glyph: amber ? Icons.warning_amber_outlined : null,
        tone: amber ? Tell.amber : Tell.none,
        word: sentence,
        lines: [figures, if (garage) inGarage],
        capDoor: end == TripEnd.freeCap,
      );
    }

    // "Another car answered" follows whoever is on the wire now.
    final other = saved(TripEnd.otherVehicle);
    for (final owner in [bmw, const OwnerNone()]) {
      expect(
        content(view(owner: owner, live: false, result: other))?.word,
        'Stopped — another car answered. The trip is saved under Golf.',
        reason: '$owner',
      );
    }
    expect(
      content(view(owner: bmw, result: other))!.actions.single.label,
      'Record',
    );

    // Nothing reached the file, or the database: amber, no figures.
    for (final (r, sentence, amber) in [
      (
        failed(TripResultKind.startFailed, outOfSpace: true),
        "Couldn't start recording — this phone is out of storage.",
        true,
      ),
      (
        failed(TripResultKind.startFailed),
        "Couldn't start recording. Try again.",
        true,
      ),
      (
        failed(TripResultKind.resumeFailed),
        "Couldn't resume the trip. It stays saved as it was.",
        true,
      ),
      (
        TripResult(
          kind: TripResultKind.summaryPending,
          vehicleId: 'golf',
          end: TripEnd.stopped,
        ),
        'The trip is on this phone. Its summary is saved the next time '
            'Torque opens.',
        false,
      ),
    ]) {
      expect(resultSentence(r, en), sentence);
      expectStrip(
        content(view(result: r)),
        glyph: amber ? Icons.warning_amber_outlined : null,
        tone: amber ? Tell.amber : Tell.none,
        word: sentence,
        lines: [freeLine],
        actions: ['Record'],
      );
    }
  });

  test('★ §7.3/§9.4 the 2-minute line is a door only with a way to Pro, '
      'never for an electric car', () {
    final capped = view(result: saved(TripEnd.freeCap));
    expect(content(capped)!.capDoor, isTrue);
    expect(content(capped, electric: true)!.capDoor, isFalse);
    expect(content(capped, canUpgrade: false)!.capDoor, isFalse);
    // Every other ending is a statement.
    for (final end in TripEnd.values.where((e) => e != TripEnd.freeCap)) {
      expect(
        content(view(result: saved(end)))!.capDoor,
        isFalse,
        reason: end.name,
      );
    }
  });

  test('★ each event is said once, in words (B.8)', () {
    String? say(TripEvent e, {bool free = true}) =>
        announcementFor(e, en, freePlan: free);

    expect(
      say(const TripEvent(TripEventKind.started)),
      'Recording started. The free plan records 2 minutes.',
    );
    expect(
      say(const TripEvent(TripEventKind.started), free: false),
      'Recording started.',
    );
    for (final free in [true, false]) {
      expect(
        say(const TripEvent(TripEventKind.resumed), free: free),
        'Recording resumed.',
      );
    }
    expect(
      say(const TripEvent(TripEventKind.paused, hold: TripHold.link)),
      'Recording paused. Waiting for the car to reconnect.',
    );
    expect(
      say(const TripEvent(TripEventKind.paused, hold: TripHold.ignitionOff)),
      'Recording paused. The ignition is off.',
    );
    expect(
      say(const TripEvent(TripEventKind.paused, hold: TripHold.identity)),
      'Recording paused while checking which car this is.',
    );
    // Only the app switcher can show a background pause: nothing to say.
    expect(
      say(const TripEvent(TripEventKind.paused, hold: TripHold.background)),
      isNull,
    );
    expect(say(const TripEvent(TripEventKind.continued)), 'Recording again.');

    for (final (end, said) in [
      (TripEnd.stopped, 'Recording stopped. Trip saved.'),
      (TripEnd.disconnected, 'Recording stopped. Trip saved.'),
      (
        TripEnd.notification,
        'Recording stopped. Stopped from the notification. Trip saved.',
      ),
      (
        TripEnd.freeCap,
        "Recording stopped at 2 minutes, the free plan's limit. Trip saved.",
      ),
      (
        TripEnd.linkLost,
        'Recording stopped. Stopped — the connection was lost. The trip is '
            'saved up to 14:32.',
      ),
      (
        TripEnd.ignitionOff,
        'Recording stopped. Stopped — the ignition was off for 10 minutes. '
            'Trip saved.',
      ),
      (
        TripEnd.otherVehicle,
        'Recording stopped. Stopped — another car answered. The trip is '
            'saved under Golf.',
      ),
      (
        TripEnd.heldTooLong,
        'Recording stopped. Stopped after 10 minutes paused. Trip saved.',
      ),
      (
        TripEnd.storageFull,
        'Recording stopped. Stopped — this phone is out of storage. The '
            'trip is saved up to 14:32.',
      ),
      (
        TripEnd.writeFailed,
        "Recording stopped. Stopped — the trip file couldn't be written. "
            'The trip is saved up to 14:32.',
      ),
    ]) {
      expect(
        say(TripEvent(TripEventKind.ended, result: saved(end))),
        said,
        reason: end.name,
      );
    }

    // A start that failed says its own sentence: nothing stopped.
    expect(
      say(
        TripEvent(
          TripEventKind.startFailed,
          result: failed(TripResultKind.startFailed, outOfSpace: true),
        ),
      ),
      "Couldn't start recording — this phone is out of storage.",
    );
    expect(
      say(
        TripEvent(
          TripEventKind.startFailed,
          result: failed(TripResultKind.startFailed),
        ),
      ),
      "Couldn't start recording. Try again.",
    );
    expect(
      say(
        TripEvent(
          TripEventKind.resumeFailed,
          result: failed(TripResultKind.resumeFailed),
        ),
      ),
      "Couldn't resume the trip. It stays saved as it was.",
    );
  });

  test('B.8 a trip whose summary waits for the next launch is still said '
      'to have stopped', () {
    // The design: every end is "Recording stopped. " and its sentence;
    // only a start failure says its sentence alone. Without the prefix a
    // screen-reader user hears "The trip is on this phone…" and is never
    // told the recording ended.
    expect(
      announcementFor(
        const TripEvent(
          TripEventKind.ended,
          result: TripResult(
            kind: TripResultKind.summaryPending,
            vehicleId: 'golf',
            end: TripEnd.stopped,
          ),
        ),
        en,
        freePlan: true,
      ),
      'Recording stopped. The trip is on this phone. Its summary is saved '
      'the next time Torque opens.',
    );
  });

  // The status block is one node whose label is `spoken`, over an
  // ExcludeSemantics: a sentence drawn but left out of `spoken` is one
  // VoiceOver and TalkBack never reach.
  test('B.8 a car with no Speed is told so aloud, not only on screen', () {
    final c = content(
      view(phase: RecorderPhase.recording, speedMissing: true),
      reading: meter(45000, free: true, speed: false),
    )!;
    expect(c.lines.map((l) => l.text), contains(noSpeed));
    expect(c.spoken, contains(noSpeed));
  });

  test('B.8 a caveat under a pause is said as well as shown', () {
    final c = content(
      view(
        phase: RecorderPhase.recording,
        hold: TripHold.background,
        caveat: TripCaveat.wifiInBackground,
      ),
      reading: meter(30000, free: true, km: 0.3, kph: 36),
    )!;
    expect(c.lines.map((l) => l.text), contains(wifi));
    expect(c.spoken, contains(wifi));
  });
}
