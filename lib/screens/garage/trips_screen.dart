import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/garage_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/scaffold.dart';

/// J2 — the trip list, including an interrupted trip and a Pro-locked one.
/// Neither is hidden: data the user recorded stays visible.
class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EntitlementProvider>();
    return Screen(
      title: 'Trip recordings',
      backLabel: 'Garage',
      onBack: () => Navigator.of(context).pop(),
      children: [
        for (final t in GarageProvider.trips)
          AppListRow(
            title: t.name,
            subtitle: t.locked
                ? '${t.when} · locked — 2-min cap on Free'
                : t.interrupted
                ? '${t.when} · ${t.distanceKm} km · interrupted, app backgrounded'
                : '${t.when} · ${t.distanceKm} km · ${t.minutes} min · '
                      'avg ${t.avgSpeed.toStringAsFixed(0)} km/h',
            trailing: t.locked && !e.isPro ? const Badge('PRO') : null,
            chevron: !t.locked,
            onTap: t.locked
                ? null
                : () => Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => TripDetailScreen(trip: t),
                    ),
                  ),
          ),
        const SizedBox(height: 18),
        Text(
          'Free keeps your last 3 trips. Pro keeps them all and lifts the '
          '2-minute recording cap.',
          style: Type.footnote,
        ),
      ],
    );
  }
}

/// J3 — trip detail: a speed chart, the tri-stat, and any codes that appeared
/// during the drive with the distance at which they did.
class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) => Screen(
    title: trip.name,
    backLabel: 'Trips',
    onBack: () => Navigator.of(context).pop(),
    footer: ScreenFooter(
      children: [
        Row(
          children: [
            Expanded(child: SecondaryButton('Export CSV', onPressed: () {})),
            const SizedBox(width: 10),
            Expanded(
              child: GhostButton('Delete', color: T.fault, onPressed: () {}),
            ),
          ],
        ),
      ],
    ),
    children: [
      TriStat([
        (value: '${trip.distanceKm}', label: 'km', tone: Tone.ink),
        (value: '92', label: 'max km/h', tone: Tone.ink),
        (value: '3.2', label: 'min idle', tone: Tone.ink),
      ]),
      const SizedBox(height: 20),
      Blueprint(
        height: 150,
        child: CustomPaint(painter: _SpeedTracePainter(), size: Size.infinite),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('START', style: Type.sectionHeading),
          Text('SPEED', style: Type.sectionHeading),
          Text('END', style: Type.sectionHeading),
        ],
      ),
      const SectionHeading('Codes seen during this trip'),
      AppListRow(
        title: 'P0133 went pending at 6.1 km',
        severityBar: T.cautionBorder,
        titleStyle: Type.rowPrimary,
      ),
    ],
  );
}

class _SpeedTracePainter extends CustomPainter {
  static const _samples = [
    0.0,
    12,
    28,
    41,
    38,
    52,
    61,
    58,
    44,
    30,
    46,
    63,
    71,
    68,
    55,
    40,
    26,
    34,
    49,
    62,
    74,
    80,
    76,
    64,
    48,
    33,
    20,
    9,
    4,
    0,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = T.neutral300
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var i = 0; i < _samples.length; i++) {
      final x = size.width * i / (_samples.length - 1);
      final y = size.height * (1 - _samples[i] / 92);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = T.accent700
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
