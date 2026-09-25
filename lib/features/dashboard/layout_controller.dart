import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/clock.dart';
import '../../data/ids.dart';
import '../../data/repositories/layout_repository.dart';
import '../../design_system/widgets/gauge_tile.dart' show GaugeVariant;
import '../../session/gauge_catalog.dart';
import 'dashboard_layout.dart';
import 'speed_gate.dart';

/// SPEC §5.3 — the Dashboard's layouts: whose they are, which is shown,
/// what the plan lets through, and every edit.
///
/// It is the one writer of layout rows and the one caller of
/// `ObdSession.setVisible` (through [publish]): the plan's cap, the §8.4
/// Speed reading while editing and Demo Mode's exemption live here, where
/// a test can drive them without a widget. It notifies on layout, edit,
/// plan, owner and moving changes — never per sample (hard rule 3).
///
/// Every edit is saved as it is made — one full row, queued behind the
/// last — so there is no draft to lose and no Cancel. There is no stream
/// on the table: anything else that writes it must call [reload].
class DashboardLayoutController extends ChangeNotifier {
  DashboardLayoutController({
    LayoutRepository? repository,
    required void Function(Set<String> pids) publish,
    this.moving,
    List<LayoutTile>? defaults,
    DateTime Function()? now,
  }) : _repo = repository,
       _publishTo = publish,
       defaults =
           defaults ??
           [for (final p in GaugeCatalog.defaultLayout) LayoutTile(p)],
       _now = now ?? utcNow {
    moving?.addListener(_onMoving);
  }

  final LayoutRepository? _repo;
  final void Function(Set<String>) _publishTo;

  /// §8.4's gate: the phone's own car is moving.
  final ValueListenable<bool>? moving;
  final DateTime Function() _now;

  /// What a car with no stored layout starts from.
  final List<LayoutTile> defaults;

  static const undoDepth = 20;

  LayoutTarget _target = const LoadingTarget();
  int _epoch = 0;
  bool _loaded = false;
  bool _isPro = false;
  bool _editing = false;
  bool _saveError = false;
  bool _disposed = false;
  List<DashboardLayout> _layouts = const [];
  final _undo =
      <
        ({String layoutId, List<LayoutTile> before, String verb, String label})
      >[];
  LayoutEvent? _lastEvent;
  int _eventSerial = 0;
  Set<String>? _published;
  Future<void> _writes = Future.value();
  int _pending = 0;

  // ---------------------------------------------------------------- inputs

  /// Whose Dashboard to show. The same owner again only refreshes what the
  /// header shows (a renamed car, a new support list); another loads its
  /// layouts, ends edit mode, and makes every [LayoutRef] from before stale.
  void setTarget(LayoutTarget t) {
    if (t.key == _target.key) {
      final old = _target;
      _target = t;
      if (old is VehicleTarget &&
          t is VehicleTarget &&
          (old.nickname != t.nickname ||
              old.fuelType != t.fuelType ||
              old.row.supportedPidsJson != t.row.supportedPidsJson)) {
        _notify();
      }
      return;
    }
    _epoch++;
    if (_editing) _end(EndReason.targetChanged);
    _undo.clear();
    _target = t;
    _loaded = false;
    _layouts = const [];
    _published = null;
    _notify();
    _load();
  }

  /// The plan, read live: bought through a door, the cap lifts on the
  /// screen already open.
  bool get isPro => _isPro;
  set isPro(bool v) {
    if (v == _isPro) return;
    _isPro = v;
    _publish();
    _notify();
  }

  void _onMoving() {
    if ((moving?.value ?? false) && _editing && _target is VehicleTarget) {
      _end(EndReason.moving);
      _publish();
    }
    _notify();
  }

  // ----------------------------------------------------------------- state

  LayoutTarget get target => _target;
  bool get loaded => _loaded;
  bool get editing => _editing;
  bool get saveError => _saveError;
  LayoutEvent? get lastEvent => _lastEvent;
  int get eventSerial => _eventSerial;

  /// Oldest first, as the Layouts sheet lists them.
  List<DashboardLayout> get layouts => List.unmodifiable(_layouts);

  /// The latest chosen; the greater id on a tie. Null only before a load.
  DashboardLayout? get active {
    DashboardLayout? best;
    for (final l in _layouts) {
      if (best == null) {
        best = l;
        continue;
      }
      final c = l.selectedAt.compareTo(best.selectedAt);
      if (c > 0 || (c == 0 && l.id.compareTo(best.id) > 0)) best = l;
    }
    return best;
  }

  /// Every tile stored on the active layout — held ones included.
  List<LayoutTile> get tiles => active?.tiles ?? const [];
  List<LayoutTile> get shown => LayoutPlan.shown(tiles, isPro: _isPro);
  List<LayoutTile> get held => LayoutPlan.held(tiles, isPro: _isPro);

  /// §8.4: the phone's own car is moving. Demo Mode is not the phone's car.
  bool get gated => _target is VehicleTarget && (moving?.value ?? false);

  bool get canUndo => _undo.isNotEmpty;

  /// "Undo remove Coolant".
  String? get undoLabel =>
      _undo.isEmpty ? null : 'Undo ${_undo.last.verb} ${_undo.last.label}';

  LayoutRef get ref => LayoutRef(_epoch, active?.id ?? '');

  /// What is asked of the car: the tiles the plan shows, and Speed while
  /// the phone's own car is being edited, for §8.4's gate.
  Set<String> get visiblePids => {
    for (final t in shown) t.pid,
    if (_editing && _target is VehicleTarget) SpeedGate.pid,
  };

  /// The queued writes, done. With none queued, a future of the caller's
  /// own zone — the chain's last one may belong to another (a test's fake
  /// clock), where awaiting it from outside would never return.
  Future<void> get idle => _pending == 0 ? Future.value() : _writes;

  // ----------------------------------------------------------- edit mode

  EditOutcome beginEditing() {
    if (_target is NoVehicleTarget) return EditOutcome.noVehicle;
    if (!_loaded || _target is LoadingTarget) return EditOutcome.notLoaded;
    if (gated) return EditOutcome.moving;
    if (_editing) return EditOutcome.done;
    _editing = true;
    _event(const LayoutEvent(LayoutEventKind.entered));
    _publish();
    _notify();
    return EditOutcome.done;
  }

  void endEditing([EndReason reason = EndReason.done]) {
    if (!_editing) return;
    _end(reason);
    _publish();
    _notify();
  }

  void _end(EndReason reason) {
    _editing = false;
    _undo.clear();
    _event(LayoutEvent(LayoutEventKind.ended, reason: reason));
  }

  /// Ends edit mode, writes again whatever failed, and waits for every
  /// write — Delete all data calls this before the wipe.
  Future<void> settle() async {
    endEditing(EndReason.settled);
    final a = active;
    if (_saveError && a != null && a.saved) _save(a);
    await idle;
  }

  /// Read the owner's layouts again — after anything else wrote them.
  Future<void> reload() {
    _epoch++;
    return _load();
  }

  // ------------------------------------------------------ tile operations

  EditOutcome? _check(LayoutRef r) {
    if (r.epoch != _epoch || r.layoutId != active?.id) return EditOutcome.stale;
    if (!_editing) return EditOutcome.notEditing;
    return null;
  }

  EditOutcome move(LayoutRef r, String pid, int toIndex) {
    if (_check(r) case final no?) return no;
    final list = [...tiles];
    final from = list.indexWhere((t) => t.pid == pid);
    if (from < 0) return EditOutcome.stale;
    final to = toIndex.clamp(0, shown.length - 1);
    if (from == to) return EditOutcome.done;
    final t = list.removeAt(from);
    list.insert(to, t);
    _apply(
      list,
      LayoutEvent(
        LayoutEventKind.moved,
        label: GaugeCatalog.labelFor(pid),
        position: to + 1,
        count: LayoutPlan.shown(list, isPro: _isPro).length,
      ),
      verb: 'move',
      label: GaugeCatalog.labelFor(pid),
    );
    return EditOutcome.done;
  }

  EditOutcome moveBy(LayoutRef r, String pid, int delta) {
    final i = tiles.indexWhere((t) => t.pid == pid);
    return move(r, pid, i < 0 ? 0 : i + delta);
  }

  EditOutcome moveToEdge(LayoutRef r, String pid, {required bool first}) =>
      move(r, pid, first ? 0 : shown.length - 1);

  EditOutcome replace(LayoutRef r, String pid, String newPid) {
    if (_check(r) case final no?) return no;
    if (tiles.any((t) => t.pid == newPid)) return EditOutcome.duplicate;
    final i = tiles.indexWhere((t) => t.pid == pid);
    if (i < 0) return EditOutcome.stale;
    final list = [...tiles];
    list[i] = list[i].withPid(newPid);
    _apply(
      list,
      LayoutEvent(
        LayoutEventKind.replaced,
        label: GaugeCatalog.labelFor(pid),
        other: GaugeCatalog.labelFor(newPid),
      ),
      verb: 'change',
      label: GaugeCatalog.labelFor(pid),
    );
    return EditOutcome.done;
  }

  EditOutcome setVariant(LayoutRef r, String pid, GaugeVariant v) {
    if (_check(r) case final no?) return no;
    final i = tiles.indexWhere((t) => t.pid == pid);
    if (i < 0) return EditOutcome.stale;
    if (tiles[i].variant == v) return EditOutcome.done;
    final list = [...tiles];
    list[i] = list[i].withVariant(v);
    _apply(
      list,
      LayoutEvent(
        LayoutEventKind.restyled,
        label: GaugeCatalog.labelFor(pid),
        other: v.name,
      ),
      verb: 'restyle',
      label: GaugeCatalog.labelFor(pid),
    );
    return EditOutcome.done;
  }

  /// §7.3's "7th gauge tile" door: counted on stored tiles.
  EditOutcome add(LayoutRef r, String pid) {
    if (_check(r) case final no?) return no;
    if (!LayoutPlan.canAddTile(tiles.length, isPro: _isPro)) {
      return EditOutcome.needsPro;
    }
    if (tiles.any((t) => t.pid == pid)) return EditOutcome.duplicate;
    final list = [...tiles, LayoutTile(pid)];
    _apply(
      list,
      LayoutEvent(
        LayoutEventKind.added,
        label: GaugeCatalog.labelFor(pid),
        position: list.length,
        count: LayoutPlan.shown(list, isPro: _isPro).length,
      ),
      verb: 'add',
      label: GaugeCatalog.labelFor(pid),
    );
    return EditOutcome.done;
  }

  /// Never the last tile: an empty visible set would bring back the
  /// session's default six under a layout the user emptied.
  EditOutcome remove(LayoutRef r, String pid) {
    if (_check(r) case final no?) return no;
    if (tiles.length == 1) return EditOutcome.lastTile;
    final i = tiles.indexWhere((t) => t.pid == pid);
    if (i < 0) return EditOutcome.stale;
    final before = {for (final t in shown) t.pid};
    final list = [...tiles]..removeAt(i);
    final after = LayoutPlan.shown(list, isPro: _isPro);
    final revealed = after.where((t) => !before.contains(t.pid)).firstOrNull;
    _apply(
      list,
      LayoutEvent(
        LayoutEventKind.removed,
        label: GaugeCatalog.labelFor(pid),
        revealed: revealed == null ? null : GaugeCatalog.labelFor(revealed.pid),
      ),
      verb: 'remove',
      label: GaugeCatalog.labelFor(pid),
    );
    return EditOutcome.done;
  }

  /// Never gated by the plan: it restores a state the user had.
  EditOutcome undo() {
    if (!_editing) return EditOutcome.notEditing;
    if (_undo.isEmpty) return EditOutcome.done;
    final e = _undo.removeLast();
    if (e.layoutId != active?.id) {
      _undo.clear();
      _notify();
      return EditOutcome.stale;
    }
    _apply(
      e.before,
      LayoutEvent(LayoutEventKind.undone, label: e.label, other: e.verb),
    );
    return EditOutcome.done;
  }

  void _apply(
    List<LayoutTile> list,
    LayoutEvent event, {
    String? verb,
    String? label,
  }) {
    final a = active!;
    if (verb != null) {
      _undo.add((layoutId: a.id, before: a.tiles, verb: verb, label: label!));
      if (_undo.length > undoDepth) _undo.removeAt(0);
    }
    final next = a.copyWith(tiles: list, saved: _persists);
    _replaceLayout(next);
    _event(event);
    _publish();
    _notify();
    _save(next);
  }

  // ---------------------------------------------------- layout operations

  EditOutcome? _checkLayout(LayoutRef r) {
    if (_target is NoVehicleTarget) return EditOutcome.noVehicle;
    if (!_loaded) return EditOutcome.notLoaded;
    if (r.epoch != _epoch || r.layoutId != active?.id) return EditOutcome.stale;
    return null;
  }

  static String? _validName(String raw) {
    final n = raw.trim();
    return n.isEmpty || n.length > DashboardLayout.nameMax ? null : n;
  }

  /// A copy of the one shown, selected. The second is a Pro door.
  EditOutcome createLayout(LayoutRef r, String name) {
    if (_checkLayout(r) case final no?) return no;
    final n = _validName(name);
    if (n == null) return EditOutcome.invalidName;
    if (!LayoutPlan.canHaveAnotherLayout(_layouts.length, isPro: _isPro)) {
      return EditOutcome.needsPro;
    }
    final a = active!;
    if (!a.saved && _persists) {
      final saved = a.copyWith(saved: true);
      _replaceLayout(saved);
      _save(saved);
    }
    final now = _now();
    final copy = DashboardLayout(
      id: newId(),
      vehicleId: a.vehicleId,
      name: n,
      tiles: a.tiles,
      createdAt: now,
      selectedAt: now,
      saved: _persists,
    );
    _layouts = [..._layouts, copy];
    _undo.clear();
    _event(LayoutEvent(LayoutEventKind.switched, label: n));
    _publish();
    _notify();
    _save(copy);
    return EditOutcome.done;
  }

  /// On the free plan only the layout shown is open; the rest are kept.
  EditOutcome select(LayoutRef r, String id) {
    if (_checkLayout(r) case final no?) return no;
    if (id == active!.id) return EditOutcome.done;
    if (!_isPro) return EditOutcome.needsPro;
    if (gated) return EditOutcome.moving;
    final i = _layouts.indexWhere((l) => l.id == id);
    if (i < 0) return EditOutcome.stale;
    final chosen = _layouts[i].copyWith(selectedAt: _now());
    _replaceLayout(chosen);
    _undo.clear();
    _event(LayoutEvent(LayoutEventKind.switched, label: chosen.name));
    _publish();
    _notify();
    _save(chosen);
    return EditOutcome.done;
  }

  /// The user's own words, on any plan.
  EditOutcome rename(LayoutRef r, String id, String name) {
    if (_checkLayout(r) case final no?) return no;
    final n = _validName(name);
    if (n == null) return EditOutcome.invalidName;
    final i = _layouts.indexWhere((l) => l.id == id);
    if (i < 0) return EditOutcome.stale;
    final next = _layouts[i].copyWith(name: n, saved: _persists);
    _replaceLayout(next);
    _notify();
    _save(next);
    return EditOutcome.done;
  }

  /// The one shown, never the only one; the last chosen of the rest is
  /// shown next.
  EditOutcome deleteLayout(LayoutRef r, String id) {
    if (_checkLayout(r) case final no?) return no;
    if (id != active!.id) return EditOutcome.stale;
    if (_layouts.length == 1) return EditOutcome.lastTile;
    final gone = active!;
    _layouts = [
      for (final l in _layouts)
        if (l.id != gone.id) l,
    ];
    _undo.clear();
    _event(LayoutEvent(LayoutEventKind.switched, label: active!.name));
    _publish();
    _notify();
    final repo = _repo;
    if (repo != null && gone.saved && _target is VehicleTarget) {
      _queue(() => repo.delete(gone.id), vehicleId: gone.vehicleId);
    }
    return EditOutcome.done;
  }

  // -------------------------------------------------------------- inside

  /// Only a vehicle's layouts are written, and only with a repository.
  bool get _persists => _repo != null && _target is VehicleTarget;

  void _replaceLayout(DashboardLayout next) =>
      _layouts = [for (final l in _layouts) l.id == next.id ? next : l];

  Future<void> _load() async {
    final epoch = _epoch;
    final t = _target;
    DashboardLayout fresh(String? vehicleId) => DashboardLayout.defaults(
      vehicleId: vehicleId,
      tiles: defaults,
      now: _now(),
    );
    switch (t) {
      case LoadingTarget():
        return;
      case NoVehicleTarget() || DemoTarget():
        _layouts = [fresh(null)];
      case VehicleTarget():
        final repo = _repo;
        if (repo == null) {
          _layouts = [fresh(t.id)];
        } else {
          List<DashboardLayout> read;
          try {
            final rows = await repo.forVehicle(t.id);
            read = [
              for (final r in rows)
                DashboardLayout.fromRow(r, fallback: defaults),
            ];
          } on Object {
            read = const [];
          }
          if (_disposed || epoch != _epoch) return;
          _layouts = read.isEmpty ? [fresh(t.id)] : read;
        }
    }
    _loaded = true;
    _publish();
    _notify();
  }

  void _save(DashboardLayout l) {
    final repo = _repo;
    if (repo == null || !l.saved || l.vehicleId == null) return;
    if (_target is! VehicleTarget) return;
    final row = l.toRow();
    _queue(() => repo.save(row), vehicleId: row.vehicleId);
  }

  void _queue(Future<void> Function() write, {required String? vehicleId}) {
    _pending++;
    _writes = _writes.then((_) async {
      try {
        await write();
        if (_saveError && _ownerId == vehicleId) {
          _saveError = false;
          _notify();
        }
      } on Object {
        // A car deleted under a queued save: its foreign key refused it,
        // and it is not this Dashboard's any more.
        if (_disposed || _ownerId != vehicleId) return;
        _saveError = true;
        _event(const LayoutEvent(LayoutEventKind.saveFailed));
        _notify();
      } finally {
        _pending--;
      }
    });
  }

  String? get _ownerId => switch (_target) {
    VehicleTarget(:final id) => id,
    _ => null,
  };

  void _event(LayoutEvent e) {
    _lastEvent = e;
    _eventSerial++;
  }

  void _publish() {
    if (!_loaded || _disposed) return;
    final pids = visiblePids;
    if (_published != null && setEquals(pids, _published)) return;
    _published = pids;
    _publishTo(pids);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    moving?.removeListener(_onMoving);
    super.dispose();
  }
}
