import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/share_file.dart';

/// The share sheet gets a real file, and the file does not outlive the
/// sheet. share_plus's own staging left every export it was ever handed
/// in the temporary directory, VINs and all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('torque_share_');
    addTearDown(() => temp.deleteSync(recursive: true));
  });

  /// Answers the platform side and records what it was given, checking
  /// the file is really there at the moment the sheet would open.
  List<Map<Object?, Object?>> platformHeard({bool existsDuring = true}) {
    final calls = <Map<Object?, Object?>>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map<Object?, Object?>;
      calls.add({...args, 'method': call.method});
      final paths = (args['paths'] as List).cast<String>();
      expect(
        File(paths.single).existsSync(),
        existsDuring,
        reason: 'the file exists while the sheet is up',
      );
      return '';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  test(
    '★ the file is under our directory during the share, and gone after',
    () async {
      final heard = platformHeard();
      await ShareFile.text(
        '{"vehicles":[{"vin":"1HGBH41JXMN109186"}]}',
        fileName: 'torque-backup-2026-09-24.json',
        mimeType: 'application/json',
        subject: 'Torque backup',
        temp: temp,
      );
      expect(heard, hasLength(1));
      final path = (heard.single['paths'] as List).cast<String>().single;
      expect(path, startsWith('${temp.path}/${ShareFile.directoryName}/'));
      expect(path, endsWith('torque-backup-2026-09-24.json'));
      expect(
        File(path).existsSync(),
        isFalse,
        reason: 'deleted after the sheet',
      );
      expect(
        Directory('${temp.path}/${ShareFile.directoryName}').listSync(),
        isEmpty,
      );
    },
  );

  test('the popover anchor reaches the platform', () async {
    final heard = platformHeard();
    await ShareFile.text(
      'log',
      fileName: 'torque-diagnostics-log.txt',
      mimeType: 'text/plain',
      subject: 'Torque diagnostics log',
      origin: const Rect.fromLTWH(10, 20, 300, 44),
      temp: temp,
    );
    final args = heard.single;
    expect(args['originX'], 10);
    expect(args['originY'], 20);
    expect(args['originWidth'], 300);
    expect(args['originHeight'], 44);
  });

  test('a sheet that throws still leaves no file behind', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'no-origin',
        message: 'iPad wants an anchor',
      );
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await expectLater(
      ShareFile.text(
        'x',
        fileName: 'f.txt',
        mimeType: 'text/plain',
        subject: 's',
        temp: temp,
      ),
      throwsA(isA<PlatformException>()),
    );
    expect(
      Directory('${temp.path}/${ShareFile.directoryName}').listSync(),
      isEmpty,
    );
  });

  test('deleteAll clears everything under the temporary directory', () async {
    File('${temp.path}/${ShareFile.directoryName}/a.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('a');
    File('${temp.path}/share_plus/b.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('b');
    File('${temp.path}/3f2a9c0e-uuid/torque-backup.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('c');
    await ShareFile.deleteAll(temp: temp);
    expect(temp.listSync(), isEmpty);
  });

  test('deleteAll on a directory that does not exist is a no-op', () async {
    await expectLater(
      ShareFile.deleteAll(temp: Directory('${temp.path}/nope')),
      completes,
    );
  });
}
