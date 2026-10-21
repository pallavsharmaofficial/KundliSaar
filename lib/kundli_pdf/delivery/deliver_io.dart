import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands the finished file to the platform's share sheet, from which the
/// person can save it to Files, send it by any app, or print it.
Future<void> deliverPdf({
  required Uint8List bytes,
  required String fileName,
  String? subject,
  Rect? origin,
}) async {
  final Directory dir = await getTemporaryDirectory();
  await _purgeOld(dir);
  final File file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[
        XFile(file.path, mimeType: 'application/pdf', name: fileName),
      ],
      fileNameOverrides: <String>[fileName],
      subject: subject,
      sharePositionOrigin: origin,
    ),
  );
}

/// Earlier exports are only kept long enough for a share sheet to finish with
/// them.
Future<void> _purgeOld(Directory dir) async {
  try {
    final DateTime cutoff = DateTime.now().subtract(const Duration(days: 1));
    await for (final FileSystemEntity e in dir.list()) {
      if (e is File &&
          e.path.contains('KundliSaar_') &&
          e.path.endsWith('.pdf') &&
          (await e.lastModified()).isBefore(cutoff)) {
        await e.delete();
      }
    }
  } catch (_) {
    // Housekeeping must never stop an export.
  }
}
