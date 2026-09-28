import 'package:flutter/material.dart' show IconData, Icons;

import '../../data/db/tables.dart' show TripEnd;
import '../../design_system/tokens.dart' show Tell;
import 'trip_format.dart';
import 'trip_plan.dart';
import 'trip_recorder.dart';

/// Which ink the strip's first word takes.
enum StripInk { primary, secondary, tone }

/// A line under the word. Dimmed while a recording is paused: figures
/// that are not moving must not look live (hard rule 4).
class StripLine {
  const StripLine(this.text, {this.dimmed = false});
  final String text;
  final bool dimmed;
}

enum StripActionKind { record, stop, resume, notNow, addVehicle }

class StripAction {
  const StripAction(this.kind, this.label, {this.icon, this.semanticLabel});
  final StripActionKind kind;
  final String label;
  final IconData? icon;
  final String? semanticLabel;
}

/// Everything the trip strip shows for one state: every word it says is
/// here, so the copy can be read — and tested — as a table.
class StripContent {
  const StripContent({
    required this.word,
    this.glyph,
    this.tone = Tell.none,
    this.ink = StripInk.primary,
    this.timer,
    this.lines = const [],
    this.capDoor = false,
    this.actions = const [],
    this.stacked = false,
    required this.spoken,
  });

  final IconData? glyph;
  final Tell tone;
  final String word;
  final StripInk ink;

  /// The meter: `18:05`, or `1:42 of 2:00` on the free plan.
  final String? timer;
  final List<StripLine> lines;

  /// The word is the §7.3 door: a tap opens it, nothing else does.
  final bool capDoor;
  final List<StripAction> actions;

  /// Laid out as a column whatever the width: the offer's two choices.
  final bool stacked;

  /// The one thing a screen reader hears for the status.
  final String spoken;
}

const _gauges = 'Records distance, speed and the gauges on screen.';
const _freeLine = 'The free plan records 2 minutes per trip.';
const _inGarage = "It's in the Garage under Trip recordings.";

/// The strip for [v] — or null, when the Dashboard's own states (a
/// skeleton, "Not connected", the banner) already say what there is to say.
StripContent? stripContentFor(
  TripView v,
  TripReading? reading, {
  required bool editing,
  required bool electric,
  required bool canUpgrade,
  required bool canAddVehicle,
  required TripFormat fmt,
}) {
  if (!v.launched || v.latched || v.owner is OwnerLoading) return null;
  if (editing && !v.open) return null;
  switch (v.phase) {
    case RecorderPhase.starting:
      return const StripContent(
        word: 'Starting the recording…',
        spoken: 'Starting the recording…',
      );
    case RecorderPhase.ending:
      return const StripContent(
        word: 'Saving the trip…',
        spoken: 'Saving the trip…',
      );
    case RecorderPhase.recording:
      return v.hold == null
          ? _recording(v, reading, fmt)
          : _paused(v, reading, fmt);
    case RecorderPhase.idle:
      break;
  }

  final owner = v.owner;
  final ownerId = switch (owner) {
    OwnerPending(:final vehicleId) => vehicleId,
    OwnerVehicle(:final vehicleId) => vehicleId,
    _ => null,
  };
  final r = v.result;
  final result =
      r != null && (r.end == TripEnd.otherVehicle || r.vehicleId == ownerId)
      ? r
      : null;
  final door = canUpgrade && !electric;

  switch (owner) {
    case OwnerLoading():
      return null;
    case OwnerDemo():
      if (!v.live) return null;
      return const StripContent(
        glyph: Icons.info_outline,
        ink: StripInk.secondary,
        word: "Demo Mode doesn't record trips.",
        spoken: "Demo Mode doesn't record trips.",
      );
    case OwnerNone():
      if (v.live) {
        return canAddVehicle
            ? const StripContent(
                word: 'Trips are saved for each car.',
                actions: [
                  StripAction(
                    StripActionKind.addVehicle,
                    'Add your car',
                    icon: Icons.add,
                  ),
                ],
                spoken: 'Trips are saved for each car.',
              )
            : const StripContent(
                word: 'Add your car in the Garage to record trips.',
                spoken: 'Add your car in the Garage to record trips.',
              );
      }
      return result == null ? null : _idle(v, result, fmt, door, record: false);
    case OwnerPending():
      if (v.live) {
        return const StripContent(
          word: 'Checking which car this is…',
          spoken: 'Checking which car this is…',
        );
      }
      return result == null ? null : _idle(v, result, fmt, door, record: false);
    case OwnerVehicle():
      final offer = v.offer;
      if (v.live && offer != null) return _offer(v, offer, fmt);
      if (v.live) return _idle(v, result, fmt, door, record: true);
      return result == null ? null : _idle(v, result, fmt, door, record: false);
  }
}

StripContent _recording(TripView v, TripReading? r, TripFormat fmt) {
  final lines = [
    if (v.speedMissing)
      const StripLine(
        "This car doesn't report speed, so distance isn't recorded.",
      ),
    ?_figures(r, fmt),
    ?_caveat(v.caveat),
  ];
  return StripContent(
    glyph: Icons.fiber_manual_record,
    tone: Tell.blue,
    ink: StripInk.tone,
    word: 'Recording',
    timer: r == null ? null : _timer(r, fmt),
    lines: lines,
    actions: const [_stop],
    spoken: [
      'Recording, ${_spokenElapsed(r, fmt)}.',
      ?_spokenFigures(r, fmt),
      ?_caveat(v.caveat)?.text,
    ].join(' '),
  );
}

StripContent _paused(TripView v, TripReading? r, TripFormat fmt) {
  final reason = switch (v.hold!) {
    TripHold.link => 'Waiting for the car to reconnect.',
    TripHold.ignitionOff =>
      'The ignition is off. The trip ends if it stays off for 10 minutes.',
    TripHold.identity => 'Checking which car this is before recording more.',
    TripHold.background => 'Paused while Torque is in the background.',
  };
  final figures = _figures(r, fmt);
  return StripContent(
    glyph: Icons.pause_circle_outline,
    word: 'Paused',
    timer: r == null ? null : _timer(r, fmt),
    lines: [
      StripLine(reason),
      if (figures != null) StripLine(figures.text, dimmed: true),
      ?_caveat(v.caveat),
    ],
    actions: const [_stop],
    spoken: [
      'Paused, ${_lower(reason)}',
      if (r != null) '${fmt.spokenDuration(r.elapsedMs)} recorded.',
      ?_spokenFigures(r, fmt),
    ].join(' '),
  );
}

/// Idle: the last result for this car, or "Not recording", and Record
/// when a recording can start.
StripContent _idle(
  TripView v,
  TripResult? result,
  TripFormat fmt,
  bool door, {
  required bool record,
}) {
  final lines = <StripLine>[];
  final String word;
  IconData? glyph;
  var tone = Tell.none;
  var ink = StripInk.primary;
  var capDoor = false;
  if (result == null) {
    word = 'Not recording';
    ink = StripInk.secondary;
    lines.add(const StripLine(_gauges));
  } else {
    word = resultSentence(result, fmt);
    if (_failed(result)) {
      glyph = Icons.warning_amber_outlined;
      tone = Tell.amber;
    }
    capDoor = door && result.end == TripEnd.freeCap;
    final figures = _resultFigures(result, fmt);
    if (figures != null) lines.add(StripLine(figures));
    if (result.kind == TripResultKind.saved &&
        const {
          TripEnd.stopped,
          TripEnd.disconnected,
          TripEnd.notification,
        }.contains(result.end)) {
      lines.add(const StripLine(_inGarage));
    }
  }
  if (record) {
    if (!v.isPro) lines.add(const StripLine(_freeLine));
    final caveat = _caveat(v.caveat);
    if (caveat != null) lines.add(caveat);
  }
  return StripContent(
    glyph: glyph,
    tone: tone,
    ink: ink,
    word: word,
    lines: lines,
    capDoor: capDoor,
    actions: record
        ? const [
            StripAction(
              StripActionKind.record,
              'Record',
              icon: Icons.fiber_manual_record_outlined,
              semanticLabel: 'Record a trip',
            ),
          ]
        : const [],
    spoken: [word, for (final l in lines) l.text].join(' '),
  );
}

StripContent _offer(TripView v, ResumeOffer offer, TripFormat fmt) {
  final at = fmt.clock(offer.endedAt);
  final lines = [
    StripLine(switch (offer.end) {
      TripEnd.linkLost =>
        'The connection was lost at $at. The trip is saved up to then.',
      _ =>
        'Torque closed while recording at $at. The trip is saved up to then.',
    }),
    ?_line([
      if (offer.distanceKm case final km?) fmt.distance(km),
      if (offer.recordedMs case final ms?) fmt.duration(ms),
    ]),
    if (!v.isPro)
      StripLine(
        '${fmt.timer(TripPlan.freeMs - (offer.recordedMs ?? 0))} left on '
        'the free plan.',
      ),
  ];
  return StripContent(
    glyph: Icons.history,
    word: 'Resume trip?',
    lines: lines,
    stacked: true,
    actions: const [
      StripAction(
        StripActionKind.resume,
        'Resume',
        icon: Icons.fiber_manual_record_outlined,
        semanticLabel: 'Resume the trip',
      ),
      StripAction(StripActionKind.notNow, 'Not now'),
    ],
    spoken: ['Resume trip?', for (final l in lines) l.text].join(' '),
  );
}

const _stop = StripAction(
  StripActionKind.stop,
  'Stop',
  icon: Icons.stop,
  semanticLabel: 'Stop recording',
);

bool _failed(TripResult r) =>
    r.kind == TripResultKind.startFailed ||
    r.kind == TripResultKind.resumeFailed ||
    r.end == TripEnd.storageFull ||
    r.end == TripEnd.writeFailed;

/// How a recording ended, in one sentence — the strip's word, and what is
/// announced after "Recording stopped."
String resultSentence(TripResult r, TripFormat fmt) {
  final at = r.savedUpTo == null ? null : fmt.clock(r.savedUpTo!);
  String upTo(String stopped) => at == null
      ? '$stopped Trip saved.'
      : '$stopped The trip is saved up to $at.';
  switch (r.kind) {
    case TripResultKind.startFailed:
      return r.outOfSpace
          ? "Couldn't start recording — this phone is out of storage."
          : "Couldn't start recording. Try again.";
    case TripResultKind.resumeFailed:
      return "Couldn't resume the trip. It stays saved as it was.";
    case TripResultKind.summaryPending:
      return 'The trip is on this phone. Its summary is saved the next time '
          'Torque opens.';
    case TripResultKind.saved:
      break;
  }
  return switch (r.end) {
    TripEnd.notification => 'Stopped from the notification. Trip saved.',
    TripEnd.freeCap =>
      "Stopped at 2 minutes, the free plan's limit. Trip saved.",
    TripEnd.linkLost => upTo('Stopped — the connection was lost.'),
    TripEnd.ignitionOff =>
      'Stopped — the ignition was off for 10 minutes. Trip saved.',
    TripEnd.otherVehicle =>
      r.nickname == null
          ? 'Stopped — another car answered. Trip saved.'
          : 'Stopped — another car answered. The trip is saved under '
                '${r.nickname}.',
    TripEnd.heldTooLong => 'Stopped after 10 minutes paused. Trip saved.',
    TripEnd.storageFull => upTo('Stopped — this phone is out of storage.'),
    TripEnd.writeFailed => upTo("Stopped — the trip file couldn't be written."),
    _ => 'Trip saved.',
  };
}

/// What is announced for [e], once. Never per tick or per sample.
String? announcementFor(TripEvent e, TripFormat fmt, {required bool freePlan}) {
  switch (e.kind) {
    case TripEventKind.started:
      return freePlan
          ? 'Recording started. The free plan records 2 minutes.'
          : 'Recording started.';
    case TripEventKind.resumed:
      return 'Recording resumed.';
    case TripEventKind.paused:
      return switch (e.hold) {
        TripHold.link => 'Recording paused. Waiting for the car to reconnect.',
        TripHold.ignitionOff => 'Recording paused. The ignition is off.',
        TripHold.identity =>
          'Recording paused while checking which car this is.',
        TripHold.background || null => null,
      };
    case TripEventKind.continued:
      return 'Recording again.';
    case TripEventKind.ended:
      final r = e.result;
      if (r == null) return 'Recording stopped.';
      if (r.end == TripEnd.freeCap) {
        return "Recording stopped at 2 minutes, the free plan's limit. "
            'Trip saved.';
      }
      if (r.kind != TripResultKind.saved) return resultSentence(r, fmt);
      return 'Recording stopped. ${resultSentence(r, fmt)}';
    case TripEventKind.startFailed:
    case TripEventKind.resumeFailed:
      final r = e.result;
      return r == null ? null : resultSentence(r, fmt);
  }
}

String _timer(TripReading r, TripFormat fmt) => r.capMs == null
    ? fmt.timer(r.elapsedMs)
    : '${fmt.timer(r.elapsedMs)} of ${fmt.timer(r.capMs!)}';

String _spokenElapsed(TripReading? r, TripFormat fmt) {
  if (r == null) return fmt.spokenDuration(0);
  final cap = r.capMs;
  return cap == null
      ? fmt.spokenDuration(r.elapsedMs)
      : '${fmt.spokenDuration(r.elapsedMs)} of ${fmt.spokenDuration(cap)}';
}

StripLine? _figures(TripReading? r, TripFormat fmt) {
  if (r == null) return null;
  return _line([
    if (r.distanceKm case final km?) fmt.distance(km),
    if (r.avgSpeedKph case final v?) 'avg ${fmt.speed(v)}',
    if (r.fuelUsedL case final l?) '${fmt.litres(l)} used (estimated)',
  ]);
}

String? _spokenFigures(TripReading? r, TripFormat fmt) {
  if (r == null) return null;
  final parts = [
    if (r.distanceKm case final km?) fmt.spokenDistance(km),
    if (r.avgSpeedKph case final v?) 'average ${fmt.spokenSpeed(v)}',
    if (r.fuelUsedL case final l?) '${fmt.spokenLitres(l)} used, estimated',
  ];
  return parts.isEmpty ? null : '${parts.join(', ')}.';
}

String? _resultFigures(TripResult r, TripFormat fmt) {
  if (r.kind != TripResultKind.saved) return null;
  return _line([
    if (r.distanceKm case final km?) fmt.distance(km),
    if (r.recordedMs case final ms?) fmt.duration(ms),
    if (r.avgSpeedKph case final v?) 'avg ${fmt.speed(v)}',
    if (r.fuelUsedL case final l?) '${fmt.litres(l)} used (estimated)',
  ])?.text;
}

StripLine? _line(List<String> parts) =>
    parts.isEmpty ? null : StripLine(parts.join(' · '));

StripLine? _caveat(TripCaveat? c) => switch (c) {
  TripCaveat.wifiInBackground => const StripLine(
    'Over Wi-Fi, recording pauses while Torque is in the background.',
  ),
  TripCaveat.notificationsOff => const StripLine(
    'Notifications are off for Torque. This phone needs one to keep '
    'recording in the background, so recording pauses there.',
  ),
  TripCaveat.serviceRefused => const StripLine(
    "This phone didn't let Torque keep recording in the background, so "
    'recording pauses there.',
  ),
  null => null,
};

String _lower(String s) => s[0].toLowerCase() + s.substring(1);
