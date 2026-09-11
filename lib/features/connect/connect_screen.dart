import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/platform/platform_info.dart';
import '../../design_system/design_system.dart';
import '../../session/adapter_discovery.dart';
import '../../session/obd_session.dart';

/// SPEC §5.2 — Connect.
///
/// Finds adapters, connects to one, and shows the seven handshake steps by
/// name while it happens. Everything that can stop a scan (§9.1) has its
/// own message and its own remedy; none of them is a spinner.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    super.key,
    required this.session,
    required this.discovery,
    this.onConnected,
    this.onDemoMode,
    this.platform = PlatformInfo.current,
  });

  final ObdSession session;
  final AdapterDiscovery discovery;

  /// Called once the car is answering, so the shell can show the Dashboard.
  final VoidCallback? onConnected;

  /// §11.1 — "Try it without an adapter". Required for store review, not a
  /// nicety: a reviewer has no car.
  final VoidCallback? onDemoMode;

  final PlatformInfo platform;

  /// §5.2 — the compatibility gate appears after this long with nothing
  /// found, and explains *why* rather than offering "try again".
  static const gateAfter = Duration(seconds: 15);

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  List<Adapter> _adapters = const [];
  DiscoveryProblem _problem = DiscoveryProblem.none;
  StreamSubscription<List<Adapter>>? _adaptersSub;
  StreamSubscription<DiscoveryProblem>? _problemSub;
  Timer? _gateTimer;
  bool _gateReached = false;

  /// The adapter a connect is running against, so its row can show the
  /// progress rather than a modal covering the list.
  Adapter? _connecting;

  /// Whether the link was already live at the last notification, so
  /// [_onSession] can tell a new connection from a state change inside
  /// one that is already up.
  bool _wasLive = false;

  @override
  void initState() {
    super.initState();
    // Seeded from the current state so re-entering an already-connected
    // screen does not read as a fresh connection and bounce straight out.
    _wasLive = widget.session.isLive;
    widget.session.addListener(_onSession);
    _adaptersSub = widget.discovery.adapters.listen((a) {
      if (mounted) setState(() => _adapters = a);
    });
    _problemSub = widget.discovery.problem.listen((p) {
      if (mounted) setState(() => _problem = p);
    });
    _startScan();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _adaptersSub?.cancel();
    _problemSub?.cancel();
    _gateTimer?.cancel();
    unawaited(widget.discovery.stop());
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {});
    final live = widget.session.isLive;
    if (live) _connecting = null;
    // Only the *edge* into a live link hands the user on. Calling this on
    // every notification while live drags them back to the Dashboard from
    // whatever tab they are on, because the session flips between
    // connected and degraded whenever a PID stops answering — which a
    // diagnostic scan does several times.
    if (live && !_wasLive) widget.onConnected?.call();
    _wasLive = live;
  }

  void _startScan() {
    setState(() {
      _gateReached = false;
      _problem = DiscoveryProblem.none;
    });
    unawaited(widget.discovery.start());
    _gateTimer?.cancel();
    _gateTimer = Timer(ConnectScreen.gateAfter, () {
      if (mounted) setState(() => _gateReached = true);
    });
  }

  Future<void> _connect(Adapter adapter) async {
    setState(() => _connecting = adapter);
    await widget.discovery.stop();
    final ok = await widget.session.connect(
      widget.discovery.transportFor(adapter),
    );
    if (!mounted) return;
    setState(() => _connecting = null);
    if (!ok) _startScan(); // back to the list, with the reason on screen
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final session = widget.session;

    return ListView(
      physics: adaptiveScrollPhysics(context),
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        if (session.isLive)
          _ConnectedCard(session: session)
        else if (session.state == SessionState.handshaking ||
            session.state == SessionState.connecting)
          _Handshake(session: session, adapter: _connecting)
        else ...[
          if (session.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x16),
              child: _Problem(
                tone: Tell.red,
                title: 'That adapter did not answer',
                body: session.lastError!,
              ),
            ),
          if (_problem != DiscoveryProblem.none)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x16),
              child: _problemCard(_problem),
            ),
          _AdapterList(
            adapters: _adapters,
            onTap: _connect,
            // §9.1: with the radio off or the permission refused there is
            // nothing to wait for, so we must not claim to be looking.
            scanning:
                widget.discovery.isScanning &&
                _problem == DiscoveryProblem.none,
          ),
          // The gate is about *scanning* finding nothing. The Wi-Fi
          // endpoints are offered unconditionally — they do not advertise,
          // so there is nothing to discover — and counting them would make
          // the list never empty and the gate dead code.
          if (_gateReached &&
              !_adapters.any((a) => a.kind != AdapterKind.wifi)) ...[
            const SizedBox(height: Space.x16),
            _CompatibilityGate(platform: widget.platform),
          ],
        ],
        const SizedBox(height: Space.x24),
        SizedBox(height: 1, child: ColoredBox(color: t.hairline)),
        const SizedBox(height: Space.x16),
        // §11.1 — a reviewer has no car, and neither does someone whose
        // adapter has not arrived yet.
        if (widget.onDemoMode != null && !session.isLive)
          GhostButton(
            label: 'Try it without an adapter',
            onPressed: widget.onDemoMode,
          ),
      ],
    );
  }

  Widget _problemCard(DiscoveryProblem p) => switch (p) {
    DiscoveryProblem.bluetoothOff => const _Problem(
      tone: Tell.amber,
      title: 'Bluetooth is off',
      body: 'Turn Bluetooth on to find your adapter.',
    ),
    DiscoveryProblem.bluetoothDenied => _Problem(
      tone: Tell.amber,
      title: 'Torque needs Bluetooth access',
      body:
          'It is only used to reach the adapter plugged into your car. '
          'Nothing is sent anywhere.',
      actionLabel: 'Allow',
      onAction: _startScan,
    ),
    DiscoveryProblem.bluetoothDeniedForever => const _Problem(
      tone: Tell.amber,
      title: 'Bluetooth access is turned off for Torque',
      body: 'Open Settings and allow Bluetooth to find your adapter.',
    ),
    DiscoveryProblem.locationOff => const _Problem(
      tone: Tell.amber,
      title: 'Turn on location services',
      body:
          'On this version of Android, Bluetooth scanning finds nothing at '
          'all unless location services are on. Torque never reads your '
          'location.',
    ),
    DiscoveryProblem.unsupported => const _Problem(
      tone: Tell.red,
      title: 'This device has no Bluetooth',
      body: 'A Wi-Fi adapter will still work.',
    ),
    DiscoveryProblem.none => const SizedBox.shrink(),
  };
}

/// The connection that exists, with what it actually negotiated.
class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({required this.session});
  final ObdSession session;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final volts = session.batteryVolts;
    return RaisedSurface(
      padding: const EdgeInsets.all(Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.adapterIdentity ?? 'Connected',
                  style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const TelltaleChip(tone: Tell.green, label: 'Connected'),
            ],
          ),
          const SizedBox(height: Space.x12),
          ValueList(
            rows: [
              ValueRow('Protocol', session.protocol?.name),
              ValueRow(
                'Battery',
                volts == null ? null : '${volts.toStringAsFixed(1)} V',
                tone: volts == null
                    ? Tell.none
                    : (volts < 12.2 ? Tell.amber : Tell.green),
                reason: 'The adapter did not report a voltage',
              ),
              ValueRow(
                'Live PIDs',
                session.supportedPids.isEmpty
                    ? null
                    : '${session.supportedPids.length} available',
                reason: 'This car reported none',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The seven steps, named. A spinner says "wait"; this says what for.
class _Handshake extends StatelessWidget {
  const _Handshake({required this.session, this.adapter});
  final ObdSession session;
  final Adapter? adapter;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RaisedSurface(
      padding: const EdgeInsets.all(Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            adapter == null
                ? 'Connecting…'
                : 'Connecting to ${adapter!.displayName}',
            style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Space.x16),
          StepProgress(
            steps: const [
              'Waking the adapter',
              'Turning off echo',
              'Turning off line feeds',
              'Turning off spaces',
              'Turning on headers',
              'Finding the protocol',
              'Talking to the engine',
            ],
            current: session.progressStep,
          ),
        ],
      ),
    );
  }
}

class _AdapterList extends StatelessWidget {
  const _AdapterList({
    required this.adapters,
    required this.onTap,
    required this.scanning,
  });

  final List<Adapter> adapters;
  final void Function(Adapter) onTap;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (adapters.isEmpty) {
      return Row(
        children: [
          if (scanning) ...[
            const AdaptiveLoading(size: 16),
            const SizedBox(width: Space.x12),
          ],
          Text(
            scanning ? 'Looking for adapters…' : 'No adapters found',
            style: TorqueType.body.copyWith(color: t.inkSecondary),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in adapters) _AdapterRow(adapter: a, onTap: onTap),
      ],
    );
  }
}

class _AdapterRow extends StatelessWidget {
  const _AdapterRow({required this.adapter, required this.onTap});
  final Adapter adapter;
  final void Function(Adapter) onTap;

  static const _kindLabel = {
    AdapterKind.ble: 'Bluetooth LE',
    AdapterKind.spp: 'Bluetooth',
    AdapterKind.wifi: 'Wi-Fi',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final detail = adapter.detail ?? _kindLabel[adapter.kind]!;
    return Semantics(
      button: true,
      onTap: () => onTap(adapter),
      label: [
        adapter.displayName,
        _kindLabel[adapter.kind]!,
        if (adapter.rating == AdapterRating.knownGood) 'Known good',
        if (adapter.rating == AdapterRating.limited) 'Limited',
        if (adapter.rssi != null) 'signal ${adapter.rssi} decibels',
      ].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () => onTap(adapter),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.min + 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.hairline, width: 1)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.x12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  adapter.displayName,
                                  style: TorqueType.body.copyWith(
                                    color: t.inkPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (adapter.rating ==
                                  AdapterRating.knownGood) ...[
                                const SizedBox(width: Space.x8),
                                const TelltaleChip(
                                  tone: Tell.green,
                                  label: 'Known good',
                                ),
                              ] else if (adapter.rating ==
                                  AdapterRating.limited) ...[
                                const SizedBox(width: Space.x8),
                                const TelltaleChip(
                                  tone: Tell.amber,
                                  label: 'Limited',
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: Space.x4),
                          Text(
                            detail,
                            style: TorqueType.meta.copyWith(
                              color: t.inkSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (adapter.rssi != null) ...[
                      const SizedBox(width: Space.x8),
                      _Signal(rssi: adapter.rssi!),
                    ],
                    const SizedBox(width: Space.x8),
                    Icon(Icons.chevron_right, size: 20, color: t.inkTertiary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four bars. The number is spoken for a screen reader rather than drawn,
/// because "three bars" means nothing without a scale.
class _Signal extends StatelessWidget {
  const _Signal({required this.rssi});
  final int rssi;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // -50 or better is excellent, -90 is unusable.
    final strength = ((rssi + 100) / 12.5).clamp(0, 4).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++) ...[
          SizedBox(
            width: 3,
            height: 4.0 + i * 3,
            child: ColoredBox(
              color: i < strength ? t.inkSecondary : t.surfacePanel,
            ),
          ),
          if (i < 3) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

/// SPEC §5.2 — shown only after a full scan with nothing found, and
/// platform-branched. Never "try again" without saying why.
class _CompatibilityGate extends StatelessWidget {
  const _CompatibilityGate({required this.platform});
  final PlatformInfo platform;

  @override
  Widget build(BuildContext context) => _Problem(
    tone: Tell.amber,
    title: "Can't find your adapter?",
    body: platform.isAndroid
        ? 'Most cheap adapters use classic Bluetooth, which has to be '
              'paired in Android Settings first. The PIN is usually 1234 or '
              '0000. Once it is paired it will appear in this list.'
        : 'iPhone can only reach Bluetooth LE and Wi-Fi adapters. A classic '
              'Bluetooth adapter — the cheap kind sold for Android — cannot '
              'work, even after pairing it in Settings. That is an Apple '
              'platform rule, not a Torque limitation.',
  );
}

class _Problem extends StatelessWidget {
  const _Problem({
    required this.tone,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final Tell tone;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RaisedSurface(
      padding: const EdgeInsets.all(Space.x16),
      color: t.surfacePanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(tone.glyph, size: 16, color: t.tell(tone)),
              const SizedBox(width: Space.x8),
              Expanded(
                child: Text(
                  title,
                  style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x8),
          Text(body, style: TorqueType.body.copyWith(color: t.inkSecondary)),
          if (actionLabel != null) ...[
            const SizedBox(height: Space.x12),
            PrimaryButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}
