import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../providers/connection_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';

/// B3 — the compatibility gate. Full screen, no tab bar. This is where a user
/// with the wrong hardware finds out, in words, why nothing will ever work.
class CompatibilityGate extends StatelessWidget {
  const CompatibilityGate({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.read<ConnectionProvider>();
    return Screen(
      footer: ScreenFooter(
        divider: false,
        children: [
          PrimaryButton(
            'Check my adapter',
            onPressed: () => Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const AdapterCompatibilityList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SecondaryButton('Scan again', onPressed: c.startScan),
          const SizedBox(height: 8),
          GhostButton(
            'Set up Wi-Fi instead',
            onPressed: () => Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const WifiSetupScreen(),
              ),
            ),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 8),
        Text('No adapters found', style: Type.screenTitle),
        const SizedBox(height: 12),
        Text(
          'We scanned for 15 seconds. Three things to check:',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 20),
        const NumberedFact(1, 'The adapter is plugged in and its light is on'),
        const NumberedFact(
          2,
          "The ignition is switched on — the engine doesn't need to be running",
        ),
        const NumberedFact(3, 'Your adapter supports Bluetooth LE or Wi-Fi'),
        const SizedBox(height: 6),
        const NoteBlock(
          "Classic Bluetooth adapters can't work with any iPhone app. If yours "
          "pairs in iPhone Settings, that's the type you have — Apple gives apps "
          'no access to it. Pairing there does not help.',
          tone: Tone.fault,
        ),
      ],
    );
  }
}

/// B5 — the bundled adapter list, grouped by what will actually happen. No
/// network lookup: the list ships inside the app and grows as Torque
/// fingerprints adapters the user connects.
class AdapterCompatibilityList extends StatefulWidget {
  const AdapterCompatibilityList({super.key});

  @override
  State<AdapterCompatibilityList> createState() =>
      _AdapterCompatibilityListState();
}

class _AdapterCompatibilityListState extends State<AdapterCompatibilityList> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.toLowerCase();
    final all = ConnectionProvider.compatibilityList
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q))
        .toList();

    Widget group(String heading, AdapterRating rating) {
      final rows = all.where((a) => a.rating == rating).toList();
      if (rows.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(heading),
          for (final a in rows)
            AppListRow(
              title: a.name,
              subtitle: a.detail,
              severityBar: switch (a.rating) {
                AdapterRating.knownGood => T.pass,
                AdapterRating.limited => T.cautionBorder,
                AdapterRating.blocked => T.fault,
              },
              trailing: TelltaleChip(
                a.badge,
                tone: switch (a.rating) {
                  AdapterRating.knownGood => Tone.pass,
                  AdapterRating.limited => Tone.caution,
                  AdapterRating.blocked => Tone.fault,
                },
              ),
            ),
        ],
      );
    }

    return Screen(
      title: 'Check my adapter',
      backLabel: 'Connect',
      onBack: () => Navigator.of(context).pop(),
      children: [
        Field(
          label: 'Search',
          hint: 'Adapter name',
          controller: _query,
          onChanged: (_) => setState(() {}),
          trailing: const Icn(Lu.search, size: 16, color: T.neutral600),
        ),
        group('Known good · Bluetooth LE', AdapterRating.knownGood),
        group('Works with limits', AdapterRating.limited),
        group('Cannot work on iPhone', AdapterRating.blocked),
        const SizedBox(height: 18),
        Text(
          'This list ships inside the app. No lookup leaves your iPhone, and it '
          'grows as Torque fingerprints adapters you connect.',
          style: Type.footnote,
        ),
      ],
    );
  }
}

/// H1 — Wi-Fi setup. The "no internet" reassurance matters: an adapter's own
/// network genuinely has no route out, and users read that as a broken setup.
class WifiSetupScreen extends StatefulWidget {
  const WifiSetupScreen({super.key});

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final _host = TextEditingController(text: '192.168.0.10');
  final _port = TextEditingController(text: '35000');

  static const _common = [
    '192.168.0.10:35000',
    '192.168.4.1:35000',
    '192.168.1.5:35000',
  ];

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Screen(
    title: 'Wi-Fi adapter',
    backLabel: 'Connect',
    onBack: () => Navigator.of(context).pop(),
    footer: ScreenFooter(
      children: [
        PrimaryButton(
          'Test connection',
          onPressed: () => context.read<ConnectionProvider>().connect(),
        ),
      ],
    ),
    children: [
      Row(
        children: [
          Expanded(
            child: Field(label: 'Host', controller: _host),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Field(label: 'Port', controller: _port),
          ),
        ],
      ),
      const SectionHeading('Common addresses'),
      for (final a in _common)
        AppListRow(
          title: a,
          titleStyle: Type.mono.copyWith(fontSize: 14),
          onTap: () {
            final parts = a.split(':');
            setState(() {
              _host.text = parts[0];
              _port.text = parts[1];
            });
          },
        ),
      const SizedBox(height: 18),
      const NoteBlock(
        "Your adapter's Wi-Fi doesn't provide internet. That's normal — "
        'Torque works fully offline once connected.',
      ),
      const SizedBox(height: 14),
      AppListRow(
        title: 'Not joined to an adapter network',
        subtitle: 'Open Wi-Fi Settings',
        leading: const Icn(Lu.wifi, size: 18, color: T.cautionText),
        chevron: true,
        onTap: () {},
      ),
    ],
  );
}

/// H2 — Bluetooth off vs. permission denied. Two distinct cards, because the
/// fix is different. Never a spinner in either state: it would never resolve.
class BluetoothStateScreen extends StatelessWidget {
  const BluetoothStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionProvider>();
    return Screen(
      title: 'Connect',
      children: [
        if (!c.bluetoothOn)
          const _StateCard(
            icon: Lu.bluetooth,
            title: 'Bluetooth is off',
            body:
                'Torque needs Bluetooth on to reach BLE adapters. '
                "It's only ever used to talk to your adapter.",
          ),
        if (c.bluetoothDenied) ...[
          const SizedBox(height: 14),
          const _StateCard(
            icon: Lu.lock,
            title: 'Bluetooth access denied',
            body:
                "You said no once, and iOS won't ask again. Torque can't scan "
                'for adapters without it.',
            tone: Tone.fault,
          ),
        ],
        const SizedBox(height: 18),
        SecondaryButton('Open Settings', onPressed: () {}),
        const SizedBox(height: 14),
        GhostButton(
          'Set up Wi-Fi instead',
          onPressed: () => Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const WifiSetupScreen(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Restoring the working state is a developer affordance kept in the
        // build so the flow can be exercised without a device.
        GhostButton(
          'Bluetooth is on again',
          color: T.neutral700,
          onPressed: () => c.setBluetooth(on: true, denied: false),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.tone = Tone.caution,
  });

  final String icon;
  final String title;
  final String body;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == Tone.fault ? T.fault : T.cautionText;
    return Blueprint(
      borderColor: tone == Tone.fault ? T.fault : T.cautionBorder,
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icn(icon, size: 22, color: color),
          const SizedBox(height: 12),
          Text(title, style: Type.cardTitle.copyWith(color: color)),
          const SizedBox(height: 7),
          Text(body, style: Type.bodyMuted),
        ],
      ),
    );
  }
}

/// H3 — connection lost. The reconnect ladder is shown, so the wait has a
/// visible shape rather than being an indefinite spinner.
class ConnectionLostBanner extends StatelessWidget {
  const ConnectionLostBanner({
    super.key,
    required this.attempt,
    this.onReconnect,
  });

  final int attempt;
  final VoidCallback? onReconnect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BlueprintCard(
        children: [
          Text('Reconnect ladder', style: Type.rowPrimary),
          const SizedBox(height: 11),
          Row(
            children: [
              for (
                var i = 0;
                i < ConnectionProvider.reconnectLadder.length;
                i++
              )
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 4 ? 0 : 6),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: i < attempt ? T.accent700 : T.divider,
                        width: 1,
                      ),
                      color: i < attempt ? T.accentTint : null,
                    ),
                    child: Text(
                      '${ConnectionProvider.reconnectLadder[i]}s'.replaceAll(
                        '.0',
                        '',
                      ),
                      style: Type.chip(
                        i < attempt ? T.accent700 : T.neutral600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            'Then every 15 s for 2 minutes, then stop and show a manual '
            'Reconnect button.',
            style: Type.footnote,
          ),
        ],
      ),
      const SizedBox(height: 14),
      SecondaryButton('Reconnect now', onPressed: onReconnect),
    ],
  );
}

/// H4 — running under macOS compatibility mode. No adapter is reachable, so
/// the app says exactly which half of itself still works.
class MacCompatScreen extends StatelessWidget {
  const MacCompatScreen({super.key, this.onOpenGarage});

  final VoidCallback? onOpenGarage;

  @override
  Widget build(BuildContext context) => Screen(
    title: 'Running on a Mac',
    footer: ScreenFooter(
      children: [PrimaryButton('Open Garage', onPressed: onOpenGarage)],
    ),
    children: [
      Text(
        'Torque needs an iPhone and an OBD2 adapter to read a car — neither '
        'is reachable in compatibility mode here.',
        style: Type.body16Muted,
      ),
      const SectionHeading('Still available'),
      const _AvailabilityRow('Your Garage — vehicles, service history', true),
      const _AvailabilityRow('Past reports and saved snapshots', true),
      const _AvailabilityRow('Live data and new diagnostic scans', false),
    ],
  );
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow(this.label, this.available);

  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) => AppListRow(
    title: label,
    leading: Icn(
      available ? Lu.circleCheck : Lu.circleX,
      size: 17,
      color: available ? T.passText : T.neutral500,
    ),
    titleStyle: Type.rowPrimary.copyWith(
      color: available ? T.text : T.neutral700,
    ),
  );
}
