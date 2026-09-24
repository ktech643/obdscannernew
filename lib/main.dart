import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/db/open.dart';
import 'monetization/revenuecat_service.dart';
import 'providers/persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iPhone, portrait only — the layout is drawn against a 390-wide frame and
  // the gauge grid has no landscape design.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Storage opens before the first frame: the app is local-first, so the
  // stored state *is* the state.
  final store = await Persistence.open();
  // The Drift database backs the diagnostic history. It is opened here
  // rather than lazily because §9.5's reconciliation — a clear the app
  // died in the middle of — has to be answerable on the first frame.
  final db = openAppDatabase();
  // Trip files and, later, attachments go on disk under the app's own
  // documents directory — never as blobs in the database (Part 6).
  final docsDir = await getApplicationDocumentsDirectory();
  // Shares are staged under the temporary directory and swept from it by
  // "Delete all data"; opened here so the erase never needs a plugin call.
  final tempDir = await getTemporaryDirectory();
  // RevenueCat configures before runApp so a purchase that completed while
  // the app was dead reconciles on the first frame (SPEC §7.5). No-op when
  // the SDK keys are absent.
  final billing = RevenueCatService();
  await billing.configure();
  runApp(
    TorqueApp(
      store: store,
      billing: billing,
      db: db,
      docsDir: docsDir,
      tempDir: tempDir,
    ),
  );
}
