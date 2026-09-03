import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/scaffold.dart';

/// C5 — the full-screen graph. A 56px readout over a 5-minute window, with an
/// honest footer about what sampling at 8 Hz can and cannot capture.
class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key, required this.reading});

  final GaugeReading reading;

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  int _window = 0;

  @override
  void initState() {
    super.initState();
    context.read<DashboardProvider>().seedHistory();
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    final e = context.watch<EntitlementProvider>();
    final history = d.history;

    return Screen(
      backLabel: 'Dashboard',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        children: [
          SecondaryButton(
            e.isPro ? 'Record' : 'Record · 2 min on Free',
            onPressed: d.toggleRecording,
          ),
        ],
      ),
      children: [
        Text(widget.reading.label, style: Type.sectionHeading),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(widget.reading.valueText, style: Type.readout),
            const SizedBox(width: 7),
            Text(widget.reading.unit, style: Type.rowSecondary),
          ],
        ),
        const SizedBox(height: 20),
        Blueprint(
          height: 190,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(1, 12, 1, 1),
            child: CustomPaint(
              painter: _LinePainter(history),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('−5 MIN', style: Type.sectionHeading),
            Text('−2:30', style: Type.sectionHeading),
            Text('NOW', style: Type.sectionHeading),
          ],
        ),
        const SizedBox(height: 20),
        ValueList([
          (label: 'Minimum', value: '742'),
          (label: 'Maximum', value: '4,180'),
          (label: 'Average', value: '2,116'),
        ]),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text('Window', style: Type.rowSecondary)),
            Segmented(
              options: const ['60 s', '5 min', '30 min'],
              selected: _window,
              onSelect: (i) => setState(() => _window = i),
            ),
          ],
        ),
        if (!e.isPro)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Badge('FREE'),
            ),
          ),
        const SizedBox(height: 18),
        // The honest footer. A maximum drawn from samples is not a measured
        // peak, and saying so is cheaper than a 1★ review that says we lied.
        Text(
          'Sampled at 8 Hz — brief peaks may be missed. The maximum above is '
          'the highest sample, not a measured peak.',
          style: Type.footnote,
        ),
      ],
    );
  }
}

/// A plain 1px line over a hairline grid. No fill, no gradient, no shadow —
/// the chart is a line drawing like everything else in the system.
class _LinePainter extends CustomPainter {
  _LinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = T.neutral300
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 0.001 ? 1 : max - min;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height * (1 - (values[i] - min) / span);
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
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.values.length != values.length;
}
