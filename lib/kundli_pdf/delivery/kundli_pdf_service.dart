import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import '../../engine/astro/ayanamsa.dart';
import '../../engine/jyotish/chart.dart';
import '../kundli_pdf.dart';

/// The finished book, as bytes.
class KundliPdfFile {
  const KundliPdfFile({
    required this.bytes,
    required this.pageCount,
    required this.fileName,
  });

  final Uint8List bytes;
  final int pageCount;
  final String fileName;
}

/// Reads the four bundled faces the book uses from the app's assets.
Future<KundliPdfFontBytes> loadKundliPdfFonts() async {
  Future<Uint8List> read(String name) async {
    final ByteData d = await rootBundle.load('assets/fonts/$name');
    return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
  }

  final List<Uint8List> f = await Future.wait(<Future<Uint8List>>[
    read('Mukta-Regular.ttf'),
    read('Mukta-SemiBold.ttf'),
    read('TiroDevanagariHindi-Regular.ttf'),
    read('YatraOne-Regular.ttf'),
  ]);
  return KundliPdfFontBytes(
    regular: f[0],
    semiBold: f[1],
    tiro: f[2],
    yatra: f[3],
  );
}

/// What crosses to the background isolate and back: plain data only.
Future<(Uint8List, int)> _inIsolate(KundliPdfRequest req) async {
  final KundliPdfResult r = await buildKundliPdf(req);
  return (r.bytes, r.pageCount);
}

/// A name that is safe in a file system and still readable.
String kundliPdfFileName(String personName, DateTime now) {
  final String cleaned = personName
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
  final String base = cleaned.isEmpty ? 'kundli' : cleaned;
  final String stamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return 'KundliSaar_${base}_$stamp.pdf';
}

/// Makes the password-protected PDF for one chart. The work happens on this
/// device and nothing is sent anywhere. Where the platform has background
/// isolates the whole book is made in one, so the screen stays alive; in the
/// browser, which has none, it is made on the main thread in sections with a
/// breath between them, and [onStage] says where it is.
Future<KundliPdfFile> makeKundliPdf({
  required BirthData birth,
  required Ayanamsa ayanamsa,
  required DateTime now,
  void Function(String stage)? onStage,
}) async {
  onStage?.call('फ़ॉन्ट तैयार हो रहे हैं');
  final KundliPdfFontBytes fonts = await loadKundliPdfFonts();
  final KundliPdfRequest req = KundliPdfRequest(
    birth: birth,
    ayanamsa: ayanamsa,
    now: now,
    fonts: fonts,
    password: kundliPdfPassword,
  );
  Uint8List bytes;
  int pages;
  if (kIsWeb) {
    final KundliPdfResult r = await buildKundliPdf(
      req,
      onStage: (KundliPdfStage s, String detail) => onStage?.call(detail),
      yieldToUi: () => Future<void>.delayed(Duration.zero),
    );
    bytes = r.bytes;
    pages = r.pageCount;
  } else {
    onStage?.call('कुंडली बन रही है');
    final (Uint8List, int) r = await compute(_inIsolate, req);
    bytes = r.$1;
    pages = r.$2;
  }
  return KundliPdfFile(
    bytes: bytes,
    pageCount: pages,
    fileName: kundliPdfFileName(birth.name, now),
  );
}
