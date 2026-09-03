import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../providers/connection_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';
import 'compatibility_screens.dart';

/// Flow B — Connect. One screen covering B1 (scanning, empty), B2 (connected
/// with results) and B4 (the 7-step handshake), driven by [ConnectionStatus].
class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionProvider>();

    if (!c.bluetoothOn || c.bluetoothDenied) {
      return const BluetoothStateScreen();
    }
    if (c.status == ConnectionStatus.unsupported) {
      return const CompatibilityGate();
    }
    if (c.status == ConnectionStatus.handshaking) {
      return const HandshakeScreen();
    }

    return Screen(
      title: 'Connect',
      children: [
        if (c.status == ConnectionStatus.scanning) ...[
          _ScanningHeader(seconds: c.scanSeconds, onStop: c.stopScan),
          const SectionHeading('Nearby adapters', topPadding: 24),
          const EmptyState(
            headline: 'Nothing found yet',
            why: 'Make sure your adapter is plugged in and the ignition is on.',
          ),
        ] else if (c.isLive) ...[
          _CurrentConnection(c: c),
          const SectionHeading('Nearby adapters'),
          for (final a in ConnectionProvider.nearbyAdapters)
            _AdapterRow(adapter: a),
        ] else ...[
          const SizedBox(height: 4),
          PrimaryButton(
            'Scan for adapters',
            onPressed: c.startScan,
            icon: Lu.search,
          ),
          const SectionHeading('Nearby adapters'),
          const EmptyState(
            headline: 'Nothing found yet',
            why: 'Make sure your adapter is plugged in and the ignition is on.',
          ),
        ],
        const SizedBox(height: 18),
        AppListRow(
          title: 'Wi-Fi adapter',
          subtitle: 'Set up by IP address',
          leading: const Icn(Lu.wifi, size: 18, color: T.accent),
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const WifiSetupScreen())),
        ),
        AppListRow(
          title: 'Other devices (7)',
          leading: const Icn(Lu.bluetooth, size: 18, color: T.neutral600),
          chevron: true,
          onTap: () {},
        ),
        if (c.isLive)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Sorted by signal strength. Most of the devices in that list '
              "aren't OBD2 adapters — walk toward your car and watch the bars "
              'climb.',
              style: Type.footnote,
            ),
          ),
        const SizedBox(height: 16),
        GhostButton(
          "Can't find your adapter?",
          onPressed: () =>
              Navigator.of(context)
                  .push(_route(const AdapterCompatibilityList())),
        ),
      ],
    );
  }
}

Route<void> _route(Widget child) =>
    PageRouteBuilder(pageBuilder: (_, _, _) => child);

/// B1's header. A 2px accent line sweeps under the title — never a spinner,
/// because a spinner promises resolution this state cannot guarantee.
class _ScanningHeader extends StatelessWidget {
  const _ScanningHeader({required this.seconds, required this.onStop});

  final int seconds;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Searching for adapters — $seconds s',
              style: Type.rowPrimary16,
            ),
          ),
          InlineAction('Stop', onPressed: onStop),
        ],
      ),
      const SizedBox(height: 6),
      const _SweepLine(),
    ],
  );
}

class _SweepLine extends StatefulWidget {
  const _SweepLine();

  @override
  State<_SweepLine> createState() => _SweepLineState();
}

class _SweepLineState extends State<_SweepLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This is the one place a repeating animation is allowed: it represents an
    // ongoing scan the user started, not a load.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      height: 2,
      child: LayoutBuilder(
        builder: (context, box) {
          if (reduceMotion) return Container(color: T.accent300);
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(
              children: [
                Container(color: T.neutral300),
                Positioned(
                  left: (box.maxWidth + 90) * _c.value - 90,
                  child: Container(width: 90, height: 2, color: T.accent),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// B2's current-connection card: transport and GATT profile, protocol,
/// firmware, battery volts, RSSI — everything needed to tell one adapter from
/// another in a car park.
class _CurrentConnection extends StatelessWidget {
  const _CurrentConnection({required this.c});

  final ConnectionProvider c;

  @override
  Widget build(BuildContext context) => BlueprintCard(
    children: [
      Row(
        children: [
          const TelltaleChip('Connected', tone: Tone.pass),
          const Spacer(),
          Text('${c.rssi} dBm', style: Type.rowSecondary),
        ],
      ),
      const SizedBox(height: 12),
      Text(c.adapterName, style: Type.cardTitleLg),
      const SizedBox(height: 12),
      ValueList([
        (label: 'Transport', value: c.transportLine),
        (label: 'Protocol', value: c.protocolLine),
        (label: 'Firmware', value: c.firmwareLine),
        (label: 'Battery', value: '${c.batteryVolts.toStringAsFixed(1)} V'),
        (label: 'Signal', value: '${c.rssi} dBm'),
      ]),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: SecondaryButton('Disconnect', onPressed: c.disconnect),
          ),
          const SizedBox(width: 10),
          Expanded(child: GhostButton('Adapter info', onPressed: () {})),
        ],
      ),
    ],
  );
}

class _AdapterRow extends StatelessWidget {
  const _AdapterRow({required this.adapter});

  final Adapter adapter;

  @override
  Widget build(BuildContext context) {
    final c = context.read<ConnectionProvider>();
    return AppListRow(
      title: adapter.name,
      subtitle: [
        adapter.transport == Transport.bluetoothLe ? 'Bluetooth LE' : 'Wi-Fi',
        if (adapter.rssi != null) '${adapter.rssi} dBm',
        if (adapter.subtitle != null) adapter.subtitle!,
      ].join(' · '),
      severityBar: switch (adapter.rating) {
        AdapterRating.knownGood => T.pass,
        AdapterRating.limited => T.cautionBorder,
        AdapterRating.blocked => T.fault,
      },
      // A known-bad fingerprint is called out before the user wastes 20 s on a
      // handshake that will disappoint them.
      trailing: adapter.rating == AdapterRating.limited
          ? const TelltaleChip('Limited adapter', tone: Tone.caution)
          : null,
      onTap: c.connect,
    );
  }
}

/// B4 — the handshake. Seven named steps, never a guessed percentage.
class HandshakeScreen extends StatelessWidget {
  const HandshakeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionProvider>();
    final steps = ConnectionProvider.handshakeSteps;
    return Screen(
      footer: ScreenFooter(
        divider: false,
        children: [GhostButton('Cancel', onPressed: c.disconnect)],
      ),
      children: [
        const SizedBox(height: 6),
        Text(
          'Setting up — step ${c.handshakeStep} of ${steps.length}',
          style: Type.subScreenTitle,
        ),
        const SizedBox(height: 8),
        Text(steps[c.handshakeStep - 1].label, style: Type.cardTitle),
        const SizedBox(height: 8),
        Text(
          'Older vehicles take longer to connect — this can take up to 20 seconds.',
          style: Type.bodyMuted,
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < steps.length; i++)
          _HandshakeStepRow(
            step: steps[i],
            done: i < c.handshakeStep - 1,
            current: i == c.handshakeStep - 1,
          ),
        const SizedBox(height: 22),
        // Caching the negotiated protocol per vehicle cuts reconnects from
        // ~20 s to ~3 s — the biggest perceived-speed win in the app.
        const NoteBlock(
          'The Golf connected on CAN 11-bit / 500 kbaud last time. We try that '
          'first — reconnects take about 3 seconds instead of 20.',
          title: 'Last known good',
        ),
      ],
    );
  }
}

class _HandshakeStepRow extends StatelessWidget {
  const _HandshakeStepRow({
    required this.step,
    required this.done,
    required this.current,
  });

  final ({String label, String cmd}) step;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? T.passText
        : current
        ? T.text
        : T.neutral500;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: const BoxDecoration(border: T.hairlineBottom),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: done
                ? const Icn(Lu.check, size: 14, color: T.passText)
                : current
                ? Container(width: 7, height: 7, color: T.accent)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.label,
              style: Type.rowPrimary.copyWith(
                color: color,
                fontWeight: current ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          Text(step.cmd, style: Type.mono.copyWith(color: T.neutral600)),
        ],
      ),
    );
  }
}
