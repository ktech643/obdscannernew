import 'dart:io';

import '../../core/share_file.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/trip_repository.dart';
import '../../design_system/design_system.dart' show AdaptiveHaptics;
import '../../providers/persistence.dart';
import '../live_tabs.dart';

/// SPEC §5.6 "Delete all data" — everything this app keeps on the device.
///
/// An earlier version cleared the preferences and nothing else: every
/// vehicle, scan, service record and trip row stayed in the database, every
/// trip recording stayed on disk, and the providers already in memory kept
/// showing the old settings — behind a sheet that said all of it was erased.
///
/// In order, and each step only after the one before it has finished:
///
/// 1. The link to the car is closed, so no scan or identity check can write
///    a row after the wipe.
/// 2. Every row of every table ([AppDatabase.wipe], one transaction).
/// 3. Every trip recording on disk ([TripRepository.deleteAllFiles]).
/// 4. Every preference — except the Pro entitlement cache. A purchase
///    belongs to the user's store account, not to this device's data, and
///    dropping the cache would downgrade a paying user who deletes their
///    data while offline until the store is reachable again.
/// 5. The diagnostics log, which carries the VINs of every car it heard.
/// 6. The temporary directory: every export and log ever handed to the
///    share sheet was written there first, and the sheet does not take it
///    back. A full-VIN export surviving "erased" was the verification
///    review's one blocker.
/// 7. Process-wide state the providers do not own — the haptics switch —
///    back to its default, or the rebuilt onboarding would buzz (or not)
///    by the deleted user's setting.
///
/// A step that throws stops the rest and the error reaches the caller, so
/// the screen never says "erased" over a database that is still there.
/// Every step is idempotent, so trying again finishes the job.
///
/// Then [onErased] — the app rebuilds every provider from the now-empty
/// storage, so nothing read before the wipe survives in memory.
class EraseEverything {
  EraseEverything({
    required this.db,
    required this.trips,
    required this.store,
    required this.live,
    required this.tempDir,
    required this.onErased,
  });

  final AppDatabase db;
  final TripRepository trips;
  final Persistence store;
  final LiveSession live;

  /// The app's temporary directory — where shares are staged.
  final Directory tempDir;
  final void Function() onErased;

  /// The preferences that outlive a delete. Only the purchase cache.
  static const kept = [Keys.entitlementTier, Keys.entitlementVerifiedAt];

  Future<void> call() async {
    await live.stopDemo();
    await live.session.disconnect();

    await db.wipe();
    await trips.deleteAllFiles();

    final tier = store.getString(Keys.entitlementTier);
    final verifiedAt = store.getInt(Keys.entitlementVerifiedAt);
    await store.clear();
    if (tier != null) store.setString(Keys.entitlementTier, tier);
    if (verifiedAt != null) {
      store.setInt(Keys.entitlementVerifiedAt, verifiedAt);
    }

    live.log.clear();
    await ShareFile.deleteAll(temp: tempDir);
    AdaptiveHaptics.enabled = true;
    onErased();
  }
}
