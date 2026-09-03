import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
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
  runApp(TorqueApp(store: store));
}
