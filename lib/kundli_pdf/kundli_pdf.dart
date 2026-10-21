/// The full kundli as a password-protected PDF, made on the device.
///
/// How it is put together:
///
///  * `text/` sets Hindi. The `pdf` package places one glyph per character and
///    knows nothing of conjuncts, reph or the left-hand vowel sign, so this
///    folder carries its own OpenType reader, a GSUB/GPOS engine and a
///    Devanagari shaper (the "dev2" model), and writes each syllable as one
///    code of a subset TrueType font embedded in the file, with a ToUnicode map
///    so the text can still be searched and copied. The shaper is held to
///    HarfBuzz glyph for glyph in `test/kundli_pdf/shaping_test.dart`.
///  * `design/` is the look: the page ornament drawn as vector paths, the
///    charts, and the small set of widgets every section is built from.
///  * `content/` is what the book says. Every section reads what the engine
///    already computes (`KundliPdfData`) and prints it; nothing is computed
///    here, and nothing the engine's honesty rules keep out is printed
///    (`honesty.dart`).
///  * `crypto/` encrypts the file itself (AES-256, standard security handler
///    revision 6), because the `pdf` package has the hook but no
///    implementation.
///  * `delivery/` runs the build (in a background isolate where there is one),
///    and hands the bytes to the share sheet or, in the browser, to a download.
///
/// The password is one constant, in `kundli_pdf_password.dart`, and is a
/// placeholder gate, not real secrecy.
library;

import 'dart:typed_data';

// ignore_for_file: implementation_imports

import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/format/array.dart';
import 'package:pdf/src/pdf/format/string.dart';
import 'package:pdf/src/pdf/obj/formxobject.dart';
import 'package:pdf/widgets.dart' as pw;

import '../engine/astro/ayanamsa.dart';
import '../engine/jyotish/chart.dart';
import 'content/data.dart';
import 'content/sections_charts.dart';
import 'content/sections_front.dart';
import 'content/sections_phala.dart';
import 'content/sections_rest.dart';
import 'crypto/pdf_aes256.dart';
import 'design/kit.dart';
import 'design/ornament.dart';
import 'design/palette.dart';
import 'text/shaped_font.dart';

export 'kundli_pdf_password.dart';

/// The raw bytes of the four bundled faces the book is set in.
class KundliPdfFontBytes {
  const KundliPdfFontBytes({
    required this.regular,
    required this.semiBold,
    required this.tiro,
    required this.yatra,
  });

  final Uint8List regular;
  final Uint8List semiBold;
  final Uint8List tiro;
  final Uint8List yatra;
}

/// What to make a book of.
class KundliPdfRequest {
  const KundliPdfRequest({
    required this.birth,
    required this.ayanamsa,
    required this.now,
    required this.fonts,
    required this.password,
    this.encrypt = true,
    this.recordDrawn = false,
  });

  final BirthData birth;
  final Ayanamsa ayanamsa;

  /// The moment the "now" parts (running dasha, transits, the year's varshphal)
  /// are read for.
  final DateTime now;
  final KundliPdfFontBytes fonts;

  /// The user password the file is encrypted with.
  final String password;

  /// Always true in the app; the tests also build an open copy to read.
  final bool encrypt;

  /// Keep every word that was drawn, for the tests.
  final bool recordDrawn;
}

class KundliPdfResult {
  const KundliPdfResult({
    required this.bytes,
    required this.pageCount,
    required this.elapsed,
    required this.engineTime,
    required this.ledger,
    required this.remedyLedger,
    required this.omitted,
    required this.missingCodes,
    required this.drawnWords,
    required this.drawnByFont,
    required this.data,
    required this.encryption,
    required this.sectionPages,
  });

  final Uint8List bytes;
  final int pageCount;
  final Duration elapsed;

  /// How much of [elapsed] went on the astronomy and the readings.
  final Duration engineTime;

  /// Every string set on a page, as the sections wrote it.
  final List<String> ledger;

  /// The remedy lines among them.
  final List<String> remedyLedger;

  /// Pieces left out because they carried a word the book never prints.
  final List<String> omitted;

  /// Code points no face had a glyph for.
  final Set<int> missingCodes;

  /// Every word as it was drawn (only when asked for).
  final List<String> drawnWords;

  /// The same, by the face that drew it (keyed by its PostScript name).
  final Map<String, Set<String>> drawnByFont;

  final KundliPdfData data;
  final PdfAes256Encryption? encryption;

  /// The page each section starts on.
  final Map<String, int> sectionPages;
}

enum KundliPdfStage { computing, composing, writing }

const PdfPageFormat _a4 = PdfPageFormat.a4;

/// A form object every page draws. dart_pdf registers a form in a page's
/// resources under a name with no leading slash, which is not a valid
/// dictionary key, while the content stream refers to it as `/X<n>`. The pages
/// are painted before any object is prepared and this form is created before
/// the pages, so by the time it is prepared the pages know about it and are
/// not yet written: it gives their keys the slash.
class _SharedForm extends PdfFormXObject {
  _SharedForm(super.document);

  @override
  void prepare() {
    super.prepare();
    for (final PdfPage page in pdfDocument.pdfPageList.pages) {
      for (final String key in page.xObjects.keys.toList()) {
        if (!key.startsWith('/')) {
          page.xObjects['/$key'] = page.xObjects.remove(key)!;
        }
      }
    }
  }
}

/// Builds the whole book. Pure Dart: it runs unchanged on the phone, in the
/// browser and in a test, and in a background isolate where there is one.
Future<KundliPdfResult> buildKundliPdf(
  KundliPdfRequest req, {
  void Function(KundliPdfStage stage, String detail)? onStage,
  Future<void> Function()? yieldToUi,
}) async {
  final Stopwatch clock = Stopwatch()..start();
  Future<void> breathe() async => yieldToUi == null ? null : await yieldToUi();

  onStage?.call(KundliPdfStage.computing, 'कुंडली की गणना');
  await breathe();
  final Stopwatch engine = Stopwatch()..start();
  final KundliPdfData d = await KundliPdfData.compute(
    req.birth,
    ayanamsa: req.ayanamsa,
    now: req.now,
    breathe: yieldToUi,
  );
  engine.stop();

  final ShapedFont regular = ShapedFont(ShapedFace(req.fonts.regular))
    ..recordDrawn = req.recordDrawn;
  final ShapedFont semi = ShapedFont(ShapedFace(req.fonts.semiBold))
    ..recordDrawn = req.recordDrawn;
  final ShapedFont serif = ShapedFont(ShapedFace(req.fonts.tiro))
    ..recordDrawn = req.recordDrawn;
  final ShapedFont display = ShapedFont(ShapedFace(req.fonts.yatra))
    ..recordDrawn = req.recordDrawn;
  final PdfFonts fonts = PdfFonts(
    regular: regular,
    semi: semi,
    serif: serif,
    display: display,
  );
  final SectionPages pages = SectionPages();
  final Kit kit = Kit(fonts: fonts, pages: pages);

  final String name = req.birth.name;
  final pw.Document doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: regular,
      bold: semi,
      italic: regular,
      boldItalic: semi,
    ),
    title: 'जन्म पत्रिका — $name',
    author: 'कुंडलीसार',
    creator: 'कुंडलीसार',
    subject: 'वैदिक जन्म पत्रिका',
    producer: 'कुंडलीसार',
  );

  // The faint ornament is drawn once into a form object, and every page
  // between the first and the last paints that same object.
  final PdfFormXObject watermark = _SharedForm(doc.document);
  watermark.params['/BBox'] = PdfArray.fromNum(<num>[
    0,
    0,
    _a4.width,
    _a4.height,
  ]);
  Ornament.paintWatermark(
    PdfGraphics(
      PdfPage(pw.Document().document, pageFormat: _a4),
      watermark.buf,
    ),
    _a4.width,
    _a4.height,
  );

  // The language of the book, for readers that speak it aloud.
  doc.document.catalog.params['/Lang'] = PdfString.fromString('hi-IN');

  pw.PageTheme middle(String title) => pw.PageTheme(
    pageFormat: _a4,
    margin: const pw.EdgeInsets.fromLTRB(58, 70, 58, 66),
    buildBackground: (pw.Context c) => pw.FullPage(
      ignoreMargins: true,
      child: pw.CustomPaint(
        painter: (PdfGraphics g, PdfPoint s) =>
            g.drawXObject(watermark, 0, 0, w: s.x, h: s.y),
      ),
    ),
    buildForeground: (pw.Context c) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(
        children: <pw.Widget>[
          pw.Positioned(
            left: 58,
            right: 58,
            top: 40,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text(
                  'जन्म पत्रिका · $name',
                  style: kit.style(serif, 8.6, color: Pal.inkSoft, spacing: 1),
                ),
                pw.Text(
                  title,
                  style: kit.style(serif, 8.6, color: Pal.maroon, spacing: 1),
                ),
              ],
            ),
          ),
          pw.Positioned(
            left: 58,
            right: 58,
            top: 56,
            child: pw.Container(height: 0.5, color: Pal.rule),
          ),
          pw.Positioned(
            left: 0,
            right: 0,
            bottom: 38,
            child: pw.Center(
              child: pw.Text(
                '${c.pageNumber}',
                style: kit.style(regular, 9, color: Pal.inkSoft, spacing: 1),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  pw.PageTheme full(double emblemFromTop) => pw.PageTheme(
    pageFormat: _a4,
    margin: pw.EdgeInsets.zero,
    buildBackground: (pw.Context c) => pw.FullPage(
      ignoreMargins: true,
      child: pw.CustomPaint(
        painter: (PdfGraphics g, PdfPoint s) =>
            Ornament.paintFull(g, s.x, s.y, emblemY: s.y - emblemFromTop),
      ),
    ),
  );

  Future<void> add(
    String title,
    List<pw.Widget> Function() children, {
    String? detail,
  }) async {
    onStage?.call(KundliPdfStage.composing, detail ?? title);
    await breathe();
    doc.addPage(
      pw.MultiPage(
        pageTheme: middle(title),
        build: (pw.Context c) => flow(children()),
      ),
    );
  }

  onStage?.call(KundliPdfStage.composing, 'आवरण');
  await breathe();
  doc.addPage(
    pw.Page(pageTheme: full(232), build: (pw.Context c) => coverPage(kit, d)),
  );

  await add('विषय-सूची', () => contentsPage(kit, d));
  await add('जन्म विवरण', () => birthSection(kit, d));
  await add('लग्न कुंडली और वर्ग कुंडलियाँ', () => chartsSection(kit, d));
  await add('ग्रह स्थिति', () => planetsSection(kit, d));
  await add('पंचांग', () => panchangSection(kit, d));
  await add('षड्बल', () => shadbalaSection(kit, d));
  await add('अष्टकवर्ग', () => ashtakaSection(kit, d));
  await add('विंशोत्तरी दशा', () => dashaSection(kit, d));
  await add('जीवन फलादेश', () => timelineSection(kit, d));
  await add('दशा फल', () => dashaPhalaSection(kit, d));
  await add('भाव फल', () => bhavaSection(kit, d));
  await add('ग्रह फल', () => grahaSection(kit, d));
  await add('योग और दोष', () => yogaSection(kit, d));
  await add('दो मत', () => matbhedSection(kit, d));
  await add('गोचर', () => gocharSection(kit, d));
  await add('वर्षफल', () => varshphalSection(kit, d));
  await add('सुदर्शन चक्र', () => sudarshanSection(kit, d));
  await add('अन्य विधियाँ', () => otherSection(kit, d));
  await add('उपाय', () => upayaSection(kit, d));

  onStage?.call(KundliPdfStage.composing, 'समापन');
  await breathe();
  doc.addPage(
    pw.Page(pageTheme: full(232), build: (pw.Context c) => closingPage(kit, d)),
  );

  onStage?.call(KundliPdfStage.writing, 'फ़ाइल बन रही है');
  await breathe();
  PdfAes256Encryption? encryption;
  if (req.encrypt) {
    encryption = PdfAes256Encryption(doc.document, userPassword: req.password);
    doc.document.encryption = encryption;
  }
  final PdfStream out = PdfStream();
  await doc.write(out);
  final Uint8List bytes = out.output();
  clock.stop();

  final Set<int> missing = <int>{};
  final List<String> words = <String>[];
  final Map<String, Set<String>> byFont = <String, Set<String>>{};
  for (final ShapedFont f in fonts.all) {
    for (final ShapedPdfFont b in f.built) {
      missing.addAll(b.missing);
      words.addAll(b.drawn);
      byFont.putIfAbsent(f.fontName, () => <String>{}).addAll(b.drawn);
    }
  }

  return KundliPdfResult(
    bytes: bytes,
    pageCount: doc.document.pdfPageList.pages.length,
    elapsed: clock.elapsed,
    engineTime: engine.elapsed,
    ledger: kit.ledger,
    remedyLedger: kit.remedyLedger,
    omitted: kit.omitted,
    missingCodes: missing,
    drawnWords: words,
    drawnByFont: byFont,
    data: d,
    encryption: encryption,
    sectionPages: Map<String, int>.of(pages.byId),
  );
}
