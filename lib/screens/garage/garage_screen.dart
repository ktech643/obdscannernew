import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/diagnostics_provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/settings_format.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/chrome.dart';
import '../../widgets/scaffold.dart';
import '../diagnostics/readiness_screen.dart';
import 'fuel_log_screen.dart';
import 'maintenance_screen.dart';
import 'reminders_screen.dart';
import 'reports_screen.dart';
import 'trips_screen.dart';

Route<void> _route(Widget child) =>
    PageRouteBuilder(pageBuilder: (_, _, _) => child);

/// E1 — vehicle overview. Photo, masked VIN, and the health/codes/overdue
/// tri-stat, then everything else about this vehicle as plain rows.
class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GarageProvider>();
    final dx = context.watch<DiagnosticsProvider>();
    final e = context.watch<EntitlementProvider>();
    final s = context.watch<SettingsProvider>();
    final v = g.active;

    return Screen(
      title: 'Garage',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PhotoPlaceholder(size: 84),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          v.nickname,
                          style: Type.cardTitleLg,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (v.isPrimary) const Badge('Primary'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(v.title, style: Type.rowSecondary),
                  const SizedBox(height: 4),
                  Text(
                    '${s.formatDistance(v.odometerKm)} · updated today',
                    style: Type.rowSecondary,
                  ),
                  const SizedBox(height: 4),
                  // The VIN is masked by default. It identifies the car and,
                  // through it, the owner.
                  Text(
                    'VIN ${s.maskVin ? v.maskedVin : v.vin}',
                    style: Type.mono.copyWith(color: T.neutral700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TriStat([
          (
            value: '${dx.healthScore}',
            label: 'Health',
            tone: dx.healthScore >= 85 ? Tone.pass : Tone.caution,
          ),
          (
            value: '${dx.codes.length}',
            label: 'Codes',
            tone: dx.codes.isEmpty ? Tone.ink : Tone.fault,
          ),
          (
            value: '${g.overdueCount}',
            label: 'Overdue',
            tone: g.overdueCount == 0 ? Tone.ink : Tone.caution,
          ),
        ]),
        const SectionHeading('This vehicle'),
        AppListRow(
          title: 'Maintenance log',
          value: '${g.recordCount} records',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const MaintenanceScreen())),
        ),
        AppListRow(
          title: 'Reminders',
          value: g.overdueCount > 0 ? '${g.overdueCount} overdue' : 'None due',
          valueStyle: g.overdueCount > 0
              ? Type.rowPrimary.copyWith(color: T.cautionText)
              : null,
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const RemindersScreen())),
        ),
        AppListRow(
          title: 'Fuel log',
          value: '${g.lifetimeConsumption} L/100 km',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const FuelLogScreen())),
        ),
        AppListRow(
          title: 'Saved diagnostic snapshots',
          value: '${DiagnosticsProvider.snapshots.length}',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const SnapshotHistoryScreen())),
        ),
        AppListRow(
          title: 'Trip recordings',
          value: '${GarageProvider.trips.length}',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const TripListScreen())),
        ),
        AppListRow(
          title: 'Reports · PDF and CSV',
          trailing: e.isPro ? null : const Badge('PRO'),
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const ReportsScreen())),
        ),
        const SectionHeading('Vehicles'),
        for (final other in g.vehicles.where((x) => x.id != v.id))
          AppListRow(
            title: other.nickname,
            subtitle: other.title,
            chevron: true,
          ),
        AppListRow(
          title: 'Add a vehicle',
          trailing: e.isPro ? null : const Badge('PRO'),
          chevron: true,
          onTap: () {},
        ),
      ],
    );
  }
}
