import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled Barlow faces and the Material icon font before any
/// test runs, so goldens render real glyphs rather than the Ahem boxes
/// flutter_test substitutes by default.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFonts();
  await testMain();
}

Future<void> _loadFonts() async {
  Future<void> load(String family, Iterable<String> paths) async {
    final loader = FontLoader(family);
    var any = false;
    for (final p in paths) {
      final f = File(p);
      if (!f.existsSync()) continue;
      any = true;
      loader.addFont(f.readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    if (any) await loader.load();
  }

  await load('Barlow', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Barlow-$w.ttf',
  ]);
  await load('BarlowCondensed', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/BarlowCondensed-$w.ttf',
  ]);

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    await load('MaterialIcons', [
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  }
}
