import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../data/db/app_database.dart';
import '../../design_system/design_system.dart';
import '../../models/enums.dart';
import '../../protocol/vin_reader.dart';
import '../../session/obd_session.dart';
import '../session_banner.dart';
import 'distance.dart';
import 'dtc_history_screen.dart';
import 'garage_controller.dart';
import 'vehicle_form_screen.dart';
import 'vehicle_identity.dart';

/// Where the rest of the garage lives until its own slices land. Each is
/// a builder for a screen the caller owns; a null one is not offered.
class GarageLinks {
  const GarageLinks({
    this.maintenance,
    this.reminders,
    this.fuel,
    this.trips,
    this.reports,
  });

  final WidgetBuilder? maintenance;
  final WidgetBuilder? reminders;
  final WidgetBuilder? fuel;
  final WidgetBuilder? trips;
  final WidgetBuilder? reports;
}

/// SPEC §5.5 — the Garage: the vehicles.
///
/// The primary vehicle is the card; everything recorded hangs off it. The
/// VIN is masked here because it identifies the car and, through it, the
/// owner. A vehicle with none is allowed (§9.6 — pre-2008 cars never
/// answer Mode 09), and says so instead of showing a blank.
class GarageScreen extends StatefulWidget {
  const GarageScreen({
    super.key,
    required this.controller,
    required this.session,
    this.unit = DistanceUnit.km,
    this.temperature = TemperatureUnit.celsius,
    this.isPro = false,
    this.links = const GarageLinks(),
    this.onConnect,
    this.adapterName,
    this.onUpgrade,
  });

  final GarageController controller;
  final ObdSession session;
  final DistanceUnit unit;

  /// For the freeze frames kept in diagnostic history.
  final TemperatureUnit temperature;

  /// §7.2: one vehicle free, unlimited on Pro.
  final bool isPro;
  final GarageLinks links;
  final VoidCallback? onConnect;
  final String? adapterName;

  /// SPEC §7.3 — the second vehicle is a paywall trigger. Opens it.
  final VoidCallback? onUpgrade;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  GarageController get _c => widget.controller;

  int? _overdue;
  int? _snapshots;
  String? _countedFor;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    widget.session.addListener(_onChange);
  }

  @override
  void didUpdateWidget(GarageScreen old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      _c.addListener(_onChange);
    }
    if (old.session != widget.session) {
      old.session.removeListener(_onChange);
      widget.session.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    widget.session.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// The two counts on the card are read from the database once per
  /// (vehicle, odometer, list, revision) — the revision is the
  /// controller's word that a snapshot or reminder changed, which is how a
  /// scan on another tab reaches a card that never left the tab stack.
  Future<void> _count(VehicleRow v) async {
    final key = '${v.id}:${v.odometerKm}:${_c.all.length}:${_c.revision}';
    if (_countedFor == key) return;
    _countedFor = key;
    final overdue = await _c.overdueCount(v.id, odometerKm: v.odometerKm);
    final snapshots = await _c.snapshotCount(v.id);
    if (!mounted) return;
    setState(() {
      _overdue = overdue;
      _snapshots = snapshots;
    });
  }

  Future<void> _push(WidgetBuilder builder) => Navigator.of(context)
      .push(PageRouteBuilder<void>(pageBuilder: (ctx, _, _) => builder(ctx)));

  Future<void> _add() async {
    if (!widget.isPro && _c.hasVehicle) {
      await showAdaptiveAlert(
        context,
        title: 'One vehicle on the free plan',
        message:
            'Adding a second vehicle is part of Pro. The one you have keeps '
            'everything it has recorded.',
        actions: [
          AdaptiveAlertAction(label: 'Not now', onPressed: () {}),
          if (widget.onUpgrade != null)
            AdaptiveAlertAction(
              label: 'See Pro',
              isDefault: true,
              onPressed: widget.onUpgrade!,
            ),
        ],
      );
      return;
    }
    // A VIN the car just reported saves typing 17 characters — offered
    // only when it is not already somebody's.
    final read = _c.lastIdentity;
    final prefill = read != null && read.kind == IdentityKind.unknown
        ? read.vin
        : null;
    final saved = await Navigator.of(context).push<VehicleRow>(
      PageRouteBuilder<VehicleRow>(
        pageBuilder: (_, _, _) => VehicleFormScreen(
          controller: _c,
          prefillVin: prefill,
          unit: widget.unit,
        ),
      ),
    );
    if (saved != null && mounted) {
      _countedFor = null;
      AdaptiveHaptics.light();
    }
  }

  Future<void> _edit(VehicleRow v) async {
    await Navigator.of(context).push<VehicleRow>(
      PageRouteBuilder<VehicleRow>(
        pageBuilder: (_, _, _) =>
            VehicleFormScreen(controller: _c, existing: v, unit: widget.unit),
      ),
    );
    _countedFor = null;
  }

  Future<void> _delete(VehicleRow v) => showAdaptiveAlert(
    context,
    title: 'Delete ${v.nickname}?',
    message:
        'Every service record, reminder, fill-up, diagnostic snapshot and '
        'trip recorded for it goes too. This cannot be undone.',
    actions: [
      AdaptiveAlertAction(label: 'Keep', onPressed: () {}, isDefault: true),
      AdaptiveAlertAction(
        label: 'Delete',
        destructive: true,
        onPressed: () => _c.delete(v.id),
      ),
    ],
  );

  Future<void> _vehicleActions(VehicleRow v) => showAdaptiveSheet<void>(
    context,
    builder: (ctx) => _VehicleSheet(
      vehicle: v,
      onMakePrimary: v.isPrimary
          ? null
          : () {
              Navigator.of(ctx).pop();
              _c.setPrimary(v.id);
            },
      onEdit: () {
        Navigator.of(ctx).pop();
        _edit(v);
      },
      onDelete: () {
        Navigator.of(ctx).pop();
        _delete(v);
      },
    ),
  );

  @override
  Widget build(BuildContext context) => BannerHost(
    banner: bannerFor(
      widget.session,
      onConnect: widget.onConnect,
      adapterName: widget.adapterName,
    ),
    child: _body(context),
  );

  Widget _body(BuildContext context) {
    if (!_c.loaded) {
      return const Padding(
        padding: EdgeInsets.all(Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 180, height: 26),
            SizedBox(height: Space.x8),
            Skeleton(width: 240),
            SizedBox(height: Space.x8),
            Skeleton(width: 140),
          ],
        ),
      );
    }

    final primary = _c.primary;
    if (primary == null) {
      return EmptyStateView(
        title: 'No vehicle yet',
        why:
            'Scans, trips and service history are kept per vehicle. Add '
            'the car this adapter lives in — the VIN is optional, and a '
            'connected car fills it in itself.',
        icon: Icons.directions_car_outlined,
        actionLabel: 'Add a vehicle',
        onAction: _add,
      );
    }
    _count(primary);

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.x48),
      children: [
        _VehicleCard(
          vehicle: primary,
          unit: widget.unit,
          identity: _c.lastIdentity,
          live: widget.session.isLive,
          onTap: () => _vehicleActions(primary),
        ),
        ListSection(title: 'This vehicle'),
        ListRow(
          title: 'Diagnostic history',
          value: _snapshots == null
              ? null
              : '$_snapshots scan${_snapshots == 1 ? '' : 's'}',
          enabled: _c.dtcs != null,
          onTap: _c.dtcs == null
              ? null
              : () => _push(
                  (_) => DtcHistoryScreen(
                    vehicle: primary,
                    dtcs: _c.dtcs!,
                    distance: widget.unit,
                    temperature: widget.temperature,
                  ),
                ),
        ),
        if (widget.links.maintenance != null)
          ListRow(
            title: 'Maintenance log',
            onTap: () => _push(widget.links.maintenance!),
          ),
        if (widget.links.reminders != null)
          ListRow(
            title: 'Reminders',
            value: _overdue == null
                ? null
                : _overdue == 0
                ? 'None overdue'
                : '$_overdue overdue',
            tone: (_overdue ?? 0) > 0 ? Tell.amber : Tell.none,
            onTap: () => _push(widget.links.reminders!),
          ),
        // An electric car has no fuel to log (§5.5); a hybrid does.
        if (widget.links.fuel != null &&
            primary.fuelType != VehicleFuel.electric)
          ListRow(title: 'Fuel log', onTap: () => _push(widget.links.fuel!)),
        if (widget.links.trips != null)
          ListRow(
            title: 'Trip recordings',
            onTap: () => _push(widget.links.trips!),
          ),
        if (widget.links.reports != null)
          ListRow(
            title: 'Reports · PDF and CSV',
            trailing: widget.isPro
                ? null
                : const TelltaleChip(tone: Tell.none, label: 'Pro'),
            onTap: () => _push(widget.links.reports!),
          ),
        ListSection(title: 'Vehicles'),
        for (final v in _c.others)
          ListRow(
            title: v.nickname,
            value: _title(v),
            onTap: () => _vehicleActions(v),
          ),
        ListRow(
          title: 'Add a vehicle',
          trailing: widget.isPro || !_c.hasVehicle
              ? null
              : const TelltaleChip(tone: Tell.none, label: 'Pro'),
          onTap: _add,
        ),
      ],
    );
  }
}

/// "2014 Volkswagen Golf GTD", or null when none of that is known — the
/// fuel has its own row, and repeating it here read as a mistake.
String? _title(VehicleRow v) {
  final parts = [
    if (v.year != null) '${v.year}',
    if (v.make.isNotEmpty) v.make,
    if (v.model.isNotEmpty) v.model,
    if (v.trim.isNotEmpty) v.trim,
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.unit,
    required this.identity,
    required this.live,
    required this.onTap,
  });

  final VehicleRow vehicle;
  final DistanceUnit unit;
  final IdentityVerdict? identity;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = vehicle;
    final odometer = v.odometerKm == null
        ? null
        : '${Distance.display(v.odometerKm!, unit)} ${unit.label}';
    final odometerWhen = v.odometerUpdatedAt == null
        ? null
        : _ago(v.odometerUpdatedAt!);

    // Only while connected does the garage know the car on the wire is
    // this one; after that it is a record, and says nothing about now.
    final onWire =
        live &&
        identity != null &&
        (identity!.kind == IdentityKind.primary ||
            identity!.kind == IdentityKind.attached);

    return Semantics(
      button: true,
      onTap: onTap,
      label: [
        v.nickname,
        if (v.isPrimary) 'primary',
        ?_title(v),
        ?odometer,
        v.vin == null ? 'no VIN on record' : 'VIN on record',
        if (v.vinUnverified) 'VIN unverified',
      ].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x16,
              Space.gutter,
              0,
            ),
            child: RaisedSurface(
              padding: const EdgeInsets.all(Space.x16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          v.nickname,
                          style: TorqueType.titleLg.copyWith(
                            color: t.inkPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.x8),
                      if (onWire)
                        const TelltaleChip(tone: Tell.green, label: 'Connected')
                      else if (v.isPrimary)
                        const TelltaleChip(tone: Tell.none, label: 'Primary'),
                    ],
                  ),
                  if (_title(v) != null) ...[
                    const SizedBox(height: Space.x4),
                    Text(
                      _title(v)!,
                      style: TorqueType.body.copyWith(color: t.inkSecondary),
                    ),
                  ],
                  const SizedBox(height: Space.x16),
                  ValueList(
                    rows: [
                      ValueRow('Odometer', odometer, reason: 'Not entered yet'),
                      if (odometerWhen != null) ValueRow('Read', odometerWhen),
                      ValueRow('Fuel', v.fuelType.label),
                      if (v.plate != null) ValueRow('Plate', v.plate),
                      ValueRow(
                        'VIN',
                        v.vin == null ? null : VinReader.mask(v.vin!),
                        tone: v.vinUnverified ? Tell.amber : Tell.none,
                        reason: 'The car has not reported one',
                      ),
                    ],
                  ),
                  if (v.vinUnverified) ...[
                    const SizedBox(height: Space.x8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Tell.amber.glyph, size: 14, color: t.tellAmber),
                        const SizedBox(width: Space.x4),
                        Expanded(
                          child: Text(
                            // Typed or read, the card cannot tell — and
                            // must not claim a re-read that never happened.
                            'This VIN failed its check digit. It is kept as '
                            'recorded and not used to decode the car.',
                            style: TorqueType.meta.copyWith(
                              color: t.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "3 days ago" — coarse on purpose; an odometer is not read to the minute.
String _ago(DateTime at) {
  final d = DateTime.now().difference(at.toLocal());
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  if (d.inDays < 30) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  final months = (d.inDays / 30).floor();
  return '$months month${months == 1 ? '' : 's'} ago';
}

class _VehicleSheet extends StatelessWidget {
  const _VehicleSheet({
    required this.vehicle,
    required this.onMakePrimary,
    required this.onEdit,
    required this.onDelete,
  });

  final VehicleRow vehicle;
  final VoidCallback? onMakePrimary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x24,
          Space.gutter,
          Space.x16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              vehicle.nickname,
              style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
            ),
            const SizedBox(height: Space.x16),
            if (onMakePrimary != null) ...[
              PrimaryButton(label: 'Make primary', onPressed: onMakePrimary),
              const SizedBox(height: Space.x8),
            ],
            GhostButton(label: 'Edit', onPressed: onEdit),
            GhostButton(label: 'Delete…', onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
