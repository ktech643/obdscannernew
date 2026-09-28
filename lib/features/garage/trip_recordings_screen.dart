import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/trip_repository.dart';
import '../../design_system/design_system.dart';
import '../../models/enums.dart';
import '../trips/trip_format.dart';
import '../trips/trip_plan.dart';

/// Garage › Trip recordings — one car's trips, newest first, straight off
/// the database.
///
/// §7.2 "last 3 trips": on the free plan the three newest are shown in
/// full and every earlier one is held — listed by its date, its figures
/// kept back, still deletable, never deleted (§7.5). No door opens here:
/// holding is not a §7.3 trigger, and a door is only ever opened by a tap
/// on it. The trip being recorded cannot be deleted from under the
/// recorder.
class TripRecordingsScreen extends StatefulWidget {
  const TripRecordingsScreen({
    super.key,
    required this.trips,
    required this.vehicle,
    this.unit = DistanceUnit.km,
    this.isPro = false,
    this.delete,
    this.touch,
  });

  final TripRepository trips;

  /// The car whose Garage row was tapped — not whichever is primary now.
  final VehicleRow vehicle;
  final DistanceUnit unit;
  final bool isPro;

  /// Seams, so a widget test does no file I/O under the fake clock.
  final Future<bool> Function(String id)? delete;
  final Future<void> Function(String id)? touch;

  @override
  State<TripRecordingsScreen> createState() => _TripRecordingsScreenState();
}

class _TripRecordingsScreenState extends State<TripRecordingsScreen> {
  late Stream<List<TripSessionRow>> _rows = _watch();

  Stream<List<TripSessionRow>> _watch() =>
      widget.trips.watchRecent(widget.vehicle.id);

  TripFormat _format(BuildContext context) => TripFormat(
    widget.unit,
    numberLocale: Intl.canonicalizedLocale(
      View.of(context).platformDispatcher.locale.toString(),
    ),
    use24h: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  @override
  Widget build(BuildContext context) => Backlit(
    child: Builder(
      builder: (context) {
        final t = context.tokens;
        final fmt = _format(context);
        return Scaffold(
          backgroundColor: t.surfaceDeep,
          appBar: AdaptiveTopBar(title: 'Trip recordings'),
          body: StreamBuilder<List<TripSessionRow>>(
            stream: _rows,
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyStateView(
                  title: "Couldn't read the trips",
                  why: 'The list could not be read from this phone.',
                  tone: Tell.red,
                  actionLabel: 'Try again',
                  onAction: () => setState(() => _rows = _watch()),
                );
              }
              final rows = snap.data;
              if (rows == null) {
                return const Padding(
                  padding: EdgeInsets.all(Space.gutter),
                  child: Column(
                    children: [
                      Skeleton(height: 48),
                      SizedBox(height: Space.x8),
                      Skeleton(height: 48),
                    ],
                  ),
                );
              }
              final shown = TripPlan.shown(rows, isPro: widget.isPro);
              final held = TripPlan.held(rows, isPro: widget.isPro);
              final footnote = TorqueType.meta.copyWith(color: t.inkTertiary);
              return ListView(
                physics: adaptiveScrollPhysics(context),
                padding: const EdgeInsets.only(bottom: Space.x48),
                children: [
                  if (rows.isEmpty)
                    const EmptyStateView(
                      title: 'No trips yet',
                      why:
                          'Record a trip from the Dashboard while the car is '
                          'connected. Trips stay on this phone.',
                      icon: Icons.route_outlined,
                    )
                  else ...[
                    ListSection(title: widget.vehicle.nickname),
                    for (final r in shown) _shownRow(context, r, fmt),
                    if (held.isNotEmpty) ...[
                      const ListSection(title: 'Earlier trips'),
                      for (final r in held) _heldRow(context, r, fmt),
                    ],
                  ],
                  if (!widget.isPro)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.x16,
                        Space.gutter,
                        0,
                      ),
                      child: Text(
                        'The free plan shows the last ${TripPlan.freeTrips} '
                        'trips for each car. Earlier ones are kept, not '
                        'deleted.',
                        style: footnote,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.x8,
                      Space.gutter,
                      0,
                    ),
                    child: Text(
                      'Trips are kept for 30 days. Past 200 MB, the ones '
                      'opened least recently go first.',
                      style: footnote,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    ),
  );

  /// `28 Sep, 14:05` — a trip is a moment, not a calendar day.
  static String title(TripSessionRow r, TripFormat fmt) =>
      '${DateFormat('d MMM', 'en_US').format(r.startedAt.toLocal())}, '
      '${fmt.clock(r.startedAt)}';

  /// Recorded time; a row from before it was stored falls back to the
  /// span between start and end.
  static int? recordedMsOf(TripSessionRow r) =>
      r.recordedMs ?? r.endedAt?.difference(r.startedAt).inMilliseconds;

  Widget _shownRow(BuildContext context, TripSessionRow r, TripFormat fmt) {
    final open = r.endedAt == null;
    final ms = recordedMsOf(r);
    final parts = [
      if (r.distanceKm case final km?) fmt.distance(km),
      if (ms != null && !open) fmt.duration(ms),
      if (r.avgSpeedKph case final v?) 'avg ${fmt.speed(v)}',
      if (r.fuelUsedL case final l?) '${fmt.litres(l)} used (estimated)',
    ];
    final (value, tone) = open
        ? ('Recording', Tell.blue)
        : switch (r.endReason) {
            TripEnd.appKilled ||
            TripEnd.linkLost ||
            TripEnd.storageFull ||
            TripEnd.writeFailed => ('Interrupted', Tell.none),
            TripEnd.freeCap => ('2-minute limit', Tell.none),
            _ => r.interrupted ? ('Interrupted', Tell.none) : (null, Tell.none),
          };
    return ListRow(
      title: title(r, fmt),
      subtitle: parts.isEmpty ? null : parts.join(' · '),
      value: value,
      tone: tone,
      onTap: () => _open(context, r, fmt, held: false),
    );
  }

  Widget _heldRow(BuildContext context, TripSessionRow r, TripFormat fmt) =>
      ListRow(
        title: title(r, fmt),
        subtitle:
            'Kept — the free plan shows the last ${TripPlan.freeTrips} trips.',
        onTap: () => _open(context, r, fmt, held: true),
      );

  Future<void> _open(
    BuildContext context,
    TripSessionRow r,
    TripFormat fmt, {
    required bool held,
  }) async {
    // Opening a trip is what the least-recently-opened retention counts.
    await (widget.touch ?? (id) => widget.trips.touch(id))(r.id);
    if (!context.mounted) return;
    await showAdaptiveSheet<void>(
      context,
      builder: (sheet) => _TripSheet(
        row: r,
        fmt: fmt,
        held: held,
        onDelete: () async {
          await (widget.delete ?? (id) => widget.trips.delete(id))(r.id);
          if (!sheet.mounted) return;
          Navigator.of(sheet).pop();
          if (context.mounted) {
            AdaptiveAnnounce.polite(context, 'Trip deleted.');
          }
        },
      ),
    );
  }
}

class _TripSheet extends StatelessWidget {
  const _TripSheet({
    required this.row,
    required this.fmt,
    required this.held,
    required this.onDelete,
  });

  final TripSessionRow row;
  final TripFormat fmt;
  final bool held;
  final Future<void> Function() onDelete;

  static const _unreported = 'Not reported by this car';

  static String ended(TripEnd? e) => switch (e) {
    TripEnd.stopped => 'You stopped it',
    TripEnd.notification => 'Stopped from the notification',
    TripEnd.disconnected => 'The adapter was disconnected',
    TripEnd.freeCap => "The free plan's 2-minute limit",
    TripEnd.linkLost => 'The connection was lost',
    TripEnd.ignitionOff => 'The ignition was off for 10 minutes',
    TripEnd.otherVehicle => 'Another car answered',
    TripEnd.heldTooLong => 'Paused for 10 minutes',
    TripEnd.storageFull => 'The phone ran out of storage',
    TripEnd.writeFailed => "The trip file couldn't be written",
    TripEnd.appKilled => 'Torque closed while recording',
    null => '—',
  };

  /// `18 min 4 s`: the sheet has room for the seconds the list leaves out.
  static String exact(int ms) {
    final s = ms <= 0 ? 0 : ms ~/ 1000;
    if (s < 60) return '$s s';
    final min = '${s ~/ 60} min';
    if (s < 3600) return s % 60 == 0 ? min : '$min ${s % 60} s';
    return '${s ~/ 3600} h ${(s % 3600 ~/ 60).toString().padLeft(2, '0')} min';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final open = row.endedAt == null;
    final ms = _TripRecordingsScreenState.recordedMsOf(row);
    final note = TorqueType.meta.copyWith(color: t.inkSecondary);
    final title = _TripRecordingsScreenState.title(row, fmt);
    String? or(double? v, String Function(double) f) => v == null ? null : f(v);
    String? why(Object? v) => v == null ? _unreported : null;
    final rows = held
        ? [ValueRow('Started', title)]
        : [
            ValueRow('Recorded', ms == null || open ? null : exact(ms)),
            ValueRow(
              'Distance',
              or(row.distanceKm, fmt.distance),
              reason: why(row.distanceKm),
            ),
            ValueRow(
              'Average speed',
              or(row.avgSpeedKph, fmt.speed),
              reason: why(row.avgSpeedKph),
            ),
            ValueRow(
              'Top speed',
              or(row.maxSpeedKph, fmt.speed),
              reason: why(row.maxSpeedKph),
            ),
            ValueRow(
              'Fuel used (estimated)',
              or(row.fuelUsedL, fmt.litres),
              reason: why(row.fuelUsedL),
            ),
            ValueRow('Samples', '${row.sampleCount}'),
            ValueRow('Ended', open ? 'Recording now' : ended(row.endReason)),
          ];
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        physics: adaptiveScrollPhysics(context),
        padding: const EdgeInsets.only(bottom: Space.x16),
        children: [
          ListSection(title: title),
          // Inside the gutter, as every other ValueList sits in its card:
          // flush to the sheet's edge, the values were cut off.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: ValueList(rows: rows),
          ),
          if (held)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x16,
                Space.gutter,
                0,
              ),
              child: Text(
                'The free plan shows the last ${TripPlan.freeTrips} trips '
                'for each car. This one is kept, not deleted.',
                style: note,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: open
                ? Text(
                    'Recording now. Stop it on the Dashboard to delete it.',
                    style: note,
                  )
                : DestructiveButton(
                    label: 'Delete trip',
                    confirmLabel: 'Tap again to delete this trip',
                    onConfirmed: () => onDelete(),
                  ),
          ),
        ],
      ),
    );
  }
}
