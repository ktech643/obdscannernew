import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands text to the platform share sheet as a file — and leaves nothing
/// behind.
///
/// share_plus materialises a data-backed `XFile` under the temporary
/// directory and never deletes it: after "Delete all data" a full export
/// of every vehicle with its VIN was still sitting in the app's sandbox,
/// behind a sheet that said everything was erased. So the file is written
/// here, under one directory this app owns, shared by path, and deleted
/// as soon as the sheet has returned — iOS reads it before the sheet
/// closes, Android copies it into share_plus's own cache first. What the
/// platform copied is swept by [deleteAll], which "Delete all data" calls.
///
/// [origin] matters on iPad, where the sheet is a popover that needs an
/// anchor; without one share_plus throws instead of presenting anything.
class ShareFile {
  ShareFile._();

  /// Our directory under the temporary directory.
  static const directoryName = 'torque-share';

  static Future<Directory> directory({Directory? temp}) async {
    final root = temp ?? await getTemporaryDirectory();
    return Directory('${root.path}/$directoryName');
  }

  static Future<void> text(
    String text, {
    required String fileName,
    required String mimeType,
    required String subject,
    Rect? origin,
    Directory? temp,
  }) async {
    final dir = await directory(temp: temp);
    await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    try {
      await file.writeAsString(text, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        subject: subject,
        sharePositionOrigin: origin,
      );
    } finally {
      try {
        await file.delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }

  /// Everything under the temporary directory — ours, the copies
  /// share_plus keeps on Android, and the per-share folders earlier
  /// versions of this app left through it. The temporary directory is the
  /// app's own; nothing the app needs lives there.
  static Future<void> deleteAll({Directory? temp}) async {
    final root = temp ?? await getTemporaryDirectory();
    if (!await root.exists()) return;
    await for (final entry in root.list()) {
      try {
        await entry.delete(recursive: true);
      } on FileSystemException {
        // One entry that will not go does not stop the rest.
      }
    }
  }

  /// The box of [context] in global coordinates — the popover's anchor.
  static Rect? originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
