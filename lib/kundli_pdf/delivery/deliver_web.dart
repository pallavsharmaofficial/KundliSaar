import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:web/web.dart' as web;

/// In the browser a download is an anchor with a `download` name pointed at a
/// blob made in memory; the file goes to the browser's downloads and nothing
/// goes to a server.
Future<void> deliverPdf({
  required Uint8List bytes,
  required String fileName,
  String? subject,
  Rect? origin,
}) async {
  final web.Blob blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(a);
  a.click();
  a.remove();
  // Give the browser a moment to start the download before the URL goes.
  await Future<void>.delayed(const Duration(seconds: 2));
  web.URL.revokeObjectURL(url);
}
