import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../../data/ids.dart';
import '../../data/repositories/vehicle_repository.dart' show VehicleRowX;
import '../../design_system/widgets/gauge_tile.dart' show GaugeVariant;
import '../../models/enums.dart' show VehicleFuel;
import '../../session/gauge_catalog.dart';

/// SPEC §5.3 — what a Dashboard layout is, with no widgets: the types the
/// layout controller and its tests work in.

/// One gauge on a layout: which reading, drawn how. The PID is the tile's
/// identity — its key, its place in the polled set, its undo entry — so a
/// layout holds each PID at most once.
@immutable
class LayoutTile {
  const LayoutTile(this.pid, [this.variant = GaugeVariant.numeric]);
  final String pid;
  final GaugeVariant variant;

  LayoutTile withVariant(GaugeVariant v) => LayoutTile(pid, v);
  LayoutTile withPid(String p) => LayoutTile(p, variant);

  @override
  bool operator ==(Object other) =>
      other is LayoutTile && other.pid == pid && other.variant == variant;

  @override
  int get hashCode => Object.hash(pid, variant);

  @override
  String toString() => 'LayoutTile($pid, ${variant.name})';
}

/// The most tiles a stored layout carries — the SQL CHECK's bound, and a
/// guard against a hostile backup (§9.8).
const maxLayoutTiles = 64;

/// `[{"pid":"010C","variant":"arc"}, …]`, in grid order. Variants by name
/// (§6.1: append, never reorder).
String encodeTiles(List<LayoutTile> tiles) => jsonEncode([
  for (final t in tiles) {'pid': t.pid, 'variant': t.variant.name},
]);

/// Never throws. What cannot be read is left out: text that is not JSON or
/// not a list gives nothing; an entry without a string PID is skipped; a
/// PID this build does not gauge is dropped; a second copy of a PID loses
/// to the first (two tiles would share a key); an unknown style is a
/// number. At most [maxLayoutTiles].
List<LayoutTile> decodeTiles(String? json) {
  if (json == null) return const [];
  Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (raw is! List) return const [];
  final known = GaugeCatalog.gaugeable.toSet();
  final seen = <String>{};
  final out = <LayoutTile>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final pid = e['pid'];
    if (pid is! String || !known.contains(pid) || !seen.add(pid)) continue;
    final name = e['variant'];
    final variant =
        GaugeVariant.values.where((v) => v.name == name).firstOrNull ??
        GaugeVariant.numeric;
    out.add(LayoutTile(pid, variant));
    if (out.length == maxLayoutTiles) break;
  }
  return out;
}

/// One named layout. [saved] is false for a vehicle's defaults that have
/// not been edited yet — held in memory, written on the first edit.
@immutable
class DashboardLayout {
  DashboardLayout({
    required this.id,
    required this.vehicleId,
    required this.name,
    required List<LayoutTile> tiles,
    required this.createdAt,
    required this.selectedAt,
    required this.saved,
    this.storedTiles,
  }) : assert(tiles.isNotEmpty, 'a layout keeps at least one tile'),
       tiles = List.unmodifiable(tiles);

  factory DashboardLayout.defaults({
    String? vehicleId,
    required List<LayoutTile> tiles,
    required DateTime now,
  }) => DashboardLayout(
    id: newId(),
    vehicleId: vehicleId,
    name: defaultName,
    tiles: tiles,
    createdAt: now,
    selectedAt: now,
    saved: false,
  );

  /// A row's layout. A row whose readings this build knows none of shows
  /// [fallback] under the row's own id and name, and writes nothing until
  /// it is edited.
  factory DashboardLayout.fromRow(
    DashboardLayoutRow r, {
    required List<LayoutTile> fallback,
  }) {
    final tiles = decodeTiles(r.tilesJson);
    return DashboardLayout(
      id: r.id,
      vehicleId: r.vehicleId,
      name: r.name,
      tiles: tiles.isEmpty ? fallback : tiles,
      createdAt: r.createdAt,
      selectedAt: r.selectedAt,
      saved: true,
      storedTiles: r.tilesJson,
    );
  }

  static const defaultName = 'Main';
  static const nameMax = 40;

  final String id;
  final String? vehicleId;
  final String name;
  final List<LayoutTile> tiles;
  final DateTime createdAt;
  final DateTime selectedAt;
  final bool saved;

  /// The row's own tile list, written back as it was until a tile is
  /// edited. Readings a later build added, which this one cannot decode —
  /// or a list it could not read at all, shown here as the defaults — are
  /// not lost to a rename or a switch.
  final String? storedTiles;

  DashboardLayout copyWith({
    String? name,
    List<LayoutTile>? tiles,
    DateTime? selectedAt,
    bool? saved,
  }) => DashboardLayout(
    id: id,
    vehicleId: vehicleId,
    name: name ?? this.name,
    tiles: tiles ?? this.tiles,
    createdAt: createdAt,
    selectedAt: selectedAt ?? this.selectedAt,
    saved: saved ?? this.saved,
    storedTiles: tiles == null ? storedTiles : null,
  );

  /// Only a vehicle's layout becomes a row.
  DashboardLayoutRow toRow() => DashboardLayoutRow(
    id: id,
    vehicleId: vehicleId!,
    name: name,
    tilesJson: storedTiles ?? encodeTiles(tiles),
    createdAt: createdAt,
    selectedAt: selectedAt,
  );
}

/// Whose Dashboard is on screen. Only a change of [key] loads another.
sealed class LayoutTarget {
  const LayoutTarget();
  String get key;
}

/// The garage has not been read yet: nothing is shown or published, so the
/// defaults are never pushed over a car whose layout says otherwise.
final class LoadingTarget extends LayoutTarget {
  const LoadingTarget();
  @override
  String get key => 'loading';
}

/// No vehicle in the garage: the defaults, and nothing saved.
final class NoVehicleTarget extends LayoutTarget {
  const NoVehicleTarget();
  @override
  String get key => 'none';
}

/// Demo Mode: edits live in memory only — the demo never records against
/// the real garage (§B.20).
final class DemoTarget extends LayoutTarget {
  const DemoTarget();
  @override
  String get key => 'demo';
}

final class VehicleTarget extends LayoutTarget {
  VehicleTarget(this.row);
  final VehicleRow row;

  String get id => row.id;
  String get nickname => row.nickname;
  VehicleFuel get fuelType => row.fuelType;

  /// What the car reported last time — for the picker while offline.
  Set<String> get cachedSupport => row.supportedPids.toSet();

  @override
  String get key => 'v:${row.id}';
}

/// SPEC §9.4 "Full EV: block the paywall" — a car recorded as electric, or
/// one whose reported readings say it has no engine to measure. [live] is
/// this connection's answer; with none yet, what the car said last time.
/// Shared by the grid's doors and the trip strip's, so the two can never
/// disagree about the same car.
bool looksElectric(LayoutTarget target, Set<String> live) {
  if (target is VehicleTarget && target.fuelType == VehicleFuel.electric) {
    return true;
  }
  final pids = live.isNotEmpty
      ? live
      : target is VehicleTarget
      ? target.cachedSupport
      : const <String>{};
  return GaugeCatalog.looksFullyElectric(pids);
}

/// Captured when a sheet or a gesture begins; an operation carrying one
/// from before a change of car or layout is refused as stale.
@immutable
class LayoutRef {
  const LayoutRef(this.epoch, this.layoutId);
  final int epoch;
  final String layoutId;

  @override
  bool operator ==(Object other) =>
      other is LayoutRef && other.epoch == epoch && other.layoutId == layoutId;

  @override
  int get hashCode => Object.hash(epoch, layoutId);
}

/// SPEC §7.2 — "Live gauges: 6 tiles, 1 layout · Unlimited, named layouts".
///
/// Enforced where tiles are read, never by trimming what is stored: on the
/// free plan a layout shows and polls its first six; the rest are held —
/// kept, not drawn, not polled — so a Pro layout survives a lapse whole
/// (§7.5 "never delete data").
abstract final class LayoutPlan {
  static const freeTiles = 6;
  static const freeLayouts = 1;

  static List<LayoutTile> shown(
    List<LayoutTile> tiles, {
    required bool isPro,
  }) => isPro || tiles.length <= freeTiles
      ? tiles
      : tiles.take(freeTiles).toList(growable: false);

  static List<LayoutTile> held(List<LayoutTile> tiles, {required bool isPro}) =>
      isPro || tiles.length <= freeTiles
      ? const []
      : tiles.skip(freeTiles).toList(growable: false);

  /// Counts the tiles *stored*, not shown: the default six are six, so a
  /// free user's first Add is §7.3's "7th gauge tile".
  static bool canAddTile(int stored, {required bool isPro}) =>
      isPro || stored < freeTiles;

  static bool canHaveAnotherLayout(int count, {required bool isPro}) =>
      isPro || count < freeLayouts;
}

/// What an edit came to. Anything but [done] changed nothing.
enum EditOutcome {
  done,
  stale,
  notEditing,
  notLoaded,
  noVehicle,
  moving,
  needsPro,
  lastTile,
  duplicate,
  invalidName,
  nameTooLong,
}

/// Why edit mode ended.
enum EndReason { done, back, hidden, moving, targetChanged, settled }

enum LayoutEventKind {
  entered,
  moved,
  removed,
  added,
  replaced,
  restyled,
  undone,
  ended,
  switched,
  saveFailed,
}

/// What just happened, for the status line and the screen reader. The
/// words are the UI's; the controller is tested on these.
@immutable
class LayoutEvent {
  const LayoutEvent(
    this.kind, {
    this.label,
    this.other,
    this.position,
    this.count,
    this.reason,
    this.revealed,
  });

  final LayoutEventKind kind;

  /// The gauge acted on ("Coolant"), or the layout switched to.
  final String? label;

  /// The gauge it became, for a replace; the verb undone, for an undo.
  final String? other;

  /// 1-based position after a move or an add, and the count shown.
  final int? position;
  final int? count;
  final EndReason? reason;

  /// A held gauge brought into view by a removal on the free plan.
  final String? revealed;
}
