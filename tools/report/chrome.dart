/// Headless Chrome as the typesetter, and a reader for the PDF it writes.
///
/// Chrome shapes Devanagari conjuncts with HarfBuzz and lays out paged media
/// with real @page rules, which is why it is the renderer and not a Dart PDF
/// package. The reader exists because Chrome offers no way to ask "which page
/// did that heading land on": the contents page needs the answer, and so does
/// the check that no fallback font crept in.
library;

import 'dart:convert';
import 'dart:io';

const String defaultChrome =
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

/// Prints [html] to [pdf]. Throws if Chrome fails or writes nothing.
Future<void> printToPdf({
  required String chrome,
  required File html,
  required File pdf,
}) async {
  if (!File(chrome).existsSync()) {
    throw StateError(
      'Chrome not found at $chrome. Pass --chrome with the path to a Chrome '
      'or Chromium binary.',
    );
  }
  // A throwaway profile so a Chrome the owner already has open cannot
  // swallow this run into its own window.
  final Directory profile = await Directory.systemTemp.createTemp(
    'kundlisaar_chrome_',
  );
  try {
    if (pdf.existsSync()) pdf.deleteSync();
    final ProcessResult result = await Process.run(chrome, <String>[
      '--headless=new',
      '--disable-gpu',
      '--no-sandbox',
      '--no-first-run',
      '--no-default-browser-check',
      '--user-data-dir=${profile.path}',
      '--no-pdf-header-footer',
      '--generate-pdf-document-outline',
      '--virtual-time-budget=30000',
      '--print-to-pdf=${pdf.path}',
      html.uri.toString(),
    ]).timeout(const Duration(minutes: 3));
    if (!pdf.existsSync() || pdf.lengthSync() == 0) {
      throw StateError(
        'Chrome wrote no PDF (exit ${result.exitCode}).\n${result.stderr}',
      );
    }
  } finally {
    try {
      profile.deleteSync(recursive: true);
    } catch (_) {
      // The profile is scratch space; a locked file is not worth failing for.
    }
  }
}

/// What can be learned from the structure of a PDF Chrome wrote.
class PdfFacts {
  const PdfFacts({
    required this.pageCount,
    required this.destinationPage,
    required this.fonts,
    required this.bytes,
  });

  final int pageCount;

  /// Named destination (an element id) to its one-based page number.
  final Map<String, int> destinationPage;

  /// Base names of the embedded fonts, subset prefixes removed.
  final Set<String> fonts;
  final int bytes;
}

/// Skia writes page tree nodes, named destinations and font descriptors as
/// plain dictionaries, so they can be read without a PDF library.
PdfFacts inspectPdf(File pdf) {
  final List<int> raw = pdf.readAsBytesSync();
  final String text = latin1.decode(raw, allowInvalid: true);

  final Map<int, List<int>> kidsOf = <int, List<int>>{};
  final Set<int> childNodes = <int>{};
  final RegExp node = RegExp(
    r'(\d+) 0 obj\s*<<[^>]*?/Type /Pages[^>]*?/Kids \[([^\]]*)\]',
  );
  for (final RegExpMatch m in node.allMatches(text)) {
    final List<int> kids = RegExp(
      r'(\d+) 0 R',
    ).allMatches(m.group(2)!).map((RegExpMatch k) => int.parse(k.group(1)!)).toList();
    kidsOf[int.parse(m.group(1)!)] = kids;
    childNodes.addAll(kids);
  }
  final List<int> roots = kidsOf.keys
      .where((int id) => !childNodes.contains(id))
      .toList();

  final List<int> pages = <int>[];
  void walk(int id) {
    final List<int>? kids = kidsOf[id];
    if (kids == null) {
      pages.add(id);
      return;
    }
    kids.forEach(walk);
  }

  if (roots.isNotEmpty) walk(roots.first);
  final Map<int, int> pageNumber = <int, int>{
    for (int i = 0; i < pages.length; i++) pages[i]: i + 1,
  };

  final Map<String, int> destinations = <String, int>{};
  for (final RegExpMatch m in RegExp(
    r'/([A-Za-z0-9_.\-]+) \[(\d+) 0 R /XYZ',
  ).allMatches(text)) {
    final int? page = pageNumber[int.parse(m.group(2)!)];
    if (page != null) destinations[m.group(1)!] = page;
  }

  final Set<String> fonts = <String>{
    for (final RegExpMatch m in RegExp(
      r'/BaseFont /[A-Z]{6}\+([^\s/\]>]+)',
    ).allMatches(text))
      m.group(1)!,
  };

  return PdfFacts(
    pageCount: pages.length,
    destinationPage: destinations,
    fonts: fonts,
    bytes: raw.length,
  );
}
