import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/phaladesh.dart';
import 'package:kundlisaar/engine/jyotish/remedies.dart';
import 'package:kundlisaar/engine/jyotish/tajika_common.dart' as tajika;
import 'package:kundlisaar/engine/jyotish/yogas.dart';
import 'package:kundlisaar/kundli_pdf/crypto/pdf_aes256.dart';
import 'package:kundlisaar/kundli_pdf/honesty.dart';
import 'package:kundlisaar/kundli_pdf/kundli_pdf.dart';
import 'package:kundlisaar/kundli_pdf/text/ot_font.dart';

import '../engine/classical_test.dart' as classical;
import '../engine/phaladesh_test.dart' as engine;
import 'mini_pdf.dart';

KundliPdfFontBytes loadFonts() => KundliPdfFontBytes(
  regular: File('assets/fonts/Mukta-Regular.ttf').readAsBytesSync(),
  semiBold: File('assets/fonts/Mukta-SemiBold.ttf').readAsBytesSync(),
  tiro: File('assets/fonts/TiroDevanagariHindi-Regular.ttf').readAsBytesSync(),
  yatra: File('assets/fonts/YatraOne-Regular.ttf').readAsBytesSync(),
);

/// What a viewer sees with whitespace taken out, so that a sentence can be
/// looked for in text that was read back word by word.
String squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

class Built {
  Built(this.result, this.pdf, this.key, this.words);

  final KundliPdfResult result;
  final MiniPdf pdf;
  final Uint8List key;

  /// Every word of every page, read back out of the file.
  final List<String> words;

  late final String text = words.join(' ');
  late final String squashed = squash(text);

  /// The words of the pages from section [from] up to (not including) [to].
  List<String> wordsOfSections(String from, String to) {
    final int a = result.sectionPages[from]! - 1;
    final int b = result.sectionPages[to]! - 1;
    return <String>[
      for (int i = a; i < b; i++) ...pdf.pageWords(pdf.pages[i], fileKey: key),
    ];
  }
}

void main() {
  late List<Built> built;

  setUpAll(() async {
    // One chart for each of the twelve lagnas, the way the engine's own tests
    // sweep them, each made into a real, encrypted PDF and then opened again
    // with the password, as a viewer would.
    final List<Kundli> charts = engine.chartForEveryLagna();
    expect(charts.map((Kundli k) => k.lagnaRashi).toSet().length, 12);
    built = <Built>[];
    final KundliPdfFontBytes fonts = loadFonts();
    for (final Kundli k in charts) {
      final KundliPdfResult r = await buildKundliPdf(
        KundliPdfRequest(
          birth: k.birth,
          ayanamsa: Ayanamsa.lahiri,
          now: DateTime.utc(2026, 10, 21, 12),
          fonts: fonts,
          password: kundliPdfPassword,
        ),
      );
      final MiniPdf pdf = MiniPdf.parse(r.bytes);
      final Uint8List key = PdfAes256Encryption.fileKeyFromUser(
        pdf.hexEntry('/U'),
        pdf.hexEntry('/UE'),
        kundliPdfPassword,
      );
      final Map<PdfObj, Map<int, String>> cache = <PdfObj, Map<int, String>>{};
      final List<String> words = <String>[
        for (final PdfObj page in pdf.pages)
          ...pdf.pageWords(page, fileKey: key, cache: cache),
      ];
      built.add(Built(r, pdf, key, words));
    }
  });

  group('a real, valid PDF', () {
    test('every chart makes a PDF that opens', () {
      for (final Built b in built) {
        final MiniPdf pdf = b.pdf;
        final String lagna = b.result.data.kundli.lagnaRashi.name;
        expect(pdf.hasHeader, isTrue, reason: lagna);
        expect(pdf.hasEof, isTrue, reason: lagna);
        // startxref points at the cross-reference object.
        expect(
          pdf.text.substring(pdf.startXref).startsWith(RegExp(r'\d+ 0 obj')),
          isTrue,
          reason: '$lagna startxref',
        );
        // Every reference points at an object that exists.
        for (final RegExpMatch m in RegExp(r'(\d+) 0 R').allMatches(pdf.text)) {
          if (!pdf.objects.containsKey(int.parse(m.group(1)!))) {
            // A stream's bytes can hold anything; only dictionaries count.
            final bool inDict = pdf.objects.values.any(
              (PdfObj o) =>
                  RegExp('(?<![0-9])${m.group(1)} 0 R').hasMatch(o.dict),
            );
            expect(inDict, isFalse, reason: '$lagna dangling ${m.group(0)}');
          }
        }
        expect(pdf.pages.length, b.result.pageCount, reason: lagna);
      }
    });

    test('the page count is sane for a book of this kind', () {
      for (final Built b in built) {
        expect(
          b.result.pageCount,
          inInclusiveRange(60, 220),
          reason: b.result.data.kundli.lagnaRashi.name,
        );
      }
      // ignore: avoid_print
      print('pages: ${built.map((Built b) => b.result.pageCount).toList()}');
    });

    test('it takes seconds, not minutes', () {
      for (final Built b in built) {
        expect(b.result.elapsed.inSeconds, lessThan(40));
      }
      // ignore: avoid_print
      print(
        'ms: ${built.map((Built b) => b.result.elapsed.inMilliseconds).toList()}',
      );
    });
  });

  group('the file itself is encrypted', () {
    test('it carries an AES-256 standard security handler', () {
      for (final Built b in built) {
        final MiniPdf pdf = b.pdf;
        expect(pdf.trailer!.dict, contains('/Encrypt'));
        final String enc = pdf.encrypt!.dict;
        expect(enc, contains('/Filter/Standard'));
        expect(enc, contains('/V 5'));
        expect(enc, contains('/R 6'));
        expect(enc, contains('/Length 256'));
        expect(enc, contains('/AESV3'));
        expect(pdf.hexEntry('/U').length, 48);
        expect(pdf.hexEntry('/UE').length, 32);
        expect(pdf.hexEntry('/O').length, 48);
        expect(pdf.hexEntry('/OE').length, 32);
        expect(pdf.hexEntry('/Perms').length, 16);
      }
    });

    test('the right password opens it and the wrong ones are refused', () {
      for (final Built b in built) {
        final Uint8List u = b.pdf.hexEntry('/U');
        expect(
          PdfAes256Encryption.checksUserPassword(u, kundliPdfPassword),
          isTrue,
        );
        for (final String wrong in <String>[
          '',
          '13061997',
          '1306199',
          '130619960',
          'password',
          '13-06-1996',
          ' 13061996',
        ]) {
          expect(
            PdfAes256Encryption.checksUserPassword(u, wrong),
            isFalse,
            reason: '"$wrong"',
          );
        }
      }
    });

    test('with the right password every stream decrypts and inflates', () {
      final Built b = built.first;
      int streams = 0;
      for (final PdfObj o in b.pdf.objects.values) {
        if (!o.isStream || o.dict.contains('/Type/XRef')) continue;
        final Uint8List data = b.pdf.stream(o, fileKey: b.key);
        expect(data, isNotEmpty);
        streams++;
      }
      expect(streams, greaterThan(100));
    });

    test(
      'a wrong key turns the streams to rubbish, and none reads without one',
      () {
        final Built b = built.first;
        final Uint8List u = b.pdf.hexEntry('/U');
        final Uint8List wrongKey = PdfAes256Encryption.fileKeyFromUser(
          u,
          b.pdf.hexEntry('/UE'),
          '13061997',
        );
        final PdfObj content = b.pdf.contentsOf(b.pdf.pages[3]).first;
        expect(
          () => b.pdf.stream(content, fileKey: wrongKey),
          throwsA(anything),
        );
        // As stored, with no key at all, it is not a compressed stream either.
        expect(() => zlib.decode(content.raw!), throwsA(anything));
      },
    );

    test('nothing readable is left in the file', () {
      final Built b = built.first;
      // Every content stream, as stored, is neither a compressed stream nor
      // text: it only becomes one with the key.
      int checked = 0;
      for (final PdfObj o in b.pdf.objects.values) {
        if (!o.isStream || o.dict.contains('/Type/XRef')) continue;
        if (!o.dict.contains('/FlateDecode')) continue;
        expect(() => zlib.decode(o.raw!), throwsA(anything));
        checked++;
      }
      expect(checked, greaterThan(100));
      // The title of the book and the person's name are strings in the
      // document information; they are encrypted too.
      final String title = latin1.decode(utf8.encode('जन्म पत्रिका'));
      expect(b.pdf.text.contains(title), isFalse);
    });

    test('the password is written in one place only', () {
      final List<String> files = <String>[];
      for (final FileSystemEntity e in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (e is File &&
            e.path.endsWith('.dart') &&
            e.readAsStringSync().contains('13061996')) {
          files.add(e.path);
        }
      }
      expect(files, <String>['lib/kundli_pdf/kundli_pdf_password.dart']);
      final String source = File(
        'lib/kundli_pdf/kundli_pdf_password.dart',
      ).readAsStringSync();
      expect(source, contains('PLACEHOLDER GATE, NOT REAL SECRECY'));
      expect(source, contains('anyone with the APK'));
      expect(kundliPdfPassword, '13061996');
    });
  });

  group('the pages', () {
    test(
      'the first and last page are the full ornament; the ones between are the faint one',
      () {
        final RegExp path = RegExp(r'(?<![\w/.])(?:m|l|c|re)(?=\s)');
        for (final Built b in built) {
          final MiniPdf pdf = b.pdf;
          final List<PdfObj> pages = pdf.pages;
          int pathOps(int i) {
            int n = 0;
            for (final PdfObj c in pdf.contentsOf(pages[i])) {
              n += path
                  .allMatches(
                    String.fromCharCodes(pdf.stream(c, fileKey: b.key)),
                  )
                  .length;
            }
            return n;
          }

          final int first = pathOps(0);
          final int last = pathOps(pages.length - 1);
          int busiestMiddle = 0;
          final Set<int> shared = <int>{};
          for (int i = 1; i < pages.length - 1; i++) {
            busiestMiddle = busiestMiddle > pathOps(i)
                ? busiestMiddle
                : pathOps(i);
            final List<int> x = pdf.xobjectsOf(pages[i]);
            expect(
              x.length,
              1,
              reason: 'page ${i + 1} draws the watermark form',
            );
            shared.addAll(x);
          }
          // The ornament is drawn in full, in the page, on the first and last
          // pages, and only once as a form object that the pages between share.
          expect(shared.length, 1);
          expect(first, greaterThan(10000));
          expect(last, greaterThan(10000));
          expect(first, greaterThan(busiestMiddle * 4));
          expect(last, greaterThan(busiestMiddle * 4));
          expect(pdf.xobjectsOf(pages.first), isEmpty);
          expect(pdf.xobjectsOf(pages.last), isEmpty);
          expect(
            first,
            isNot(last),
            reason: 'the two end pages say different things',
          );
          expect(pdf.words(pages.first, b), isNot(pdf.words(pages.last, b)));
        }
      },
    );
  });

  group('Devanagari is embedded, not missing', () {
    test(
      'the faces carry real glyphs and a Unicode map that reads back as Hindi',
      () {
        for (final Built b in built.take(3)) {
          final MiniPdf pdf = b.pdf;
          final Set<PdfObj> fonts = <PdfObj>{
            for (final PdfObj p in pdf.pages) ...pdf.fontsOf(p).values,
          };
          expect(
            fonts.length,
            greaterThanOrEqualTo(4),
            reason: 'Mukta, Mukta SemiBold, Tiro and Yatra One',
          );
          for (final PdfObj f in fonts) {
            final Uint8List file = pdf.fontFile(f, fileKey: b.key);
            final OtFont font = OtFont(file);
            expect(font.numGlyphs, greaterThan(20));
            expect(font.hasTable('glyf'), isTrue);
            int drawn = 0;
            for (int g = 0; g < font.numGlyphs; g++) {
              if (font.glyphData(g).isNotEmpty) drawn++;
            }
            expect(drawn, greaterThan(15), reason: 'outlines present');
            final Map<int, String> map = pdf.toUnicode(f, fileKey: b.key);
            final int hindi = map.values
                .where((String s) => RegExp('[ऀ-ॿ]').hasMatch(s))
                .length;
            expect(
              hindi,
              greaterThan(15),
              reason:
                  'Devanagari in the ToUnicode map of ${font.postScriptName}',
            );
          }
        }
      },
    );

    test(
      'no glyph is the missing-glyph box, and no character lacks a face',
      () {
        final RegExp hex = RegExp(r'\[<([0-9a-fA-F]+)>\]TJ');
        for (final Built b in built) {
          expect(
            b.result.missingCodes,
            isEmpty,
            reason: b.result.missingCodes
                .map((int c) => 'U+${c.toRadixString(16)}')
                .join(' '),
          );
        }
        final Built b = built.first;
        int checked = 0;
        for (final PdfObj page in b.pdf.pages.take(40)) {
          for (final PdfObj c in b.pdf.contentsOf(page)) {
            final String content = String.fromCharCodes(
              b.pdf.stream(c, fileKey: b.key),
            );
            for (final RegExpMatch m in hex.allMatches(content)) {
              final String h = m.group(1)!;
              for (int i = 0; i + 4 <= h.length; i += 4) {
                expect(
                  h.substring(i, i + 4),
                  isNot('0000'),
                  reason: '.notdef drawn',
                );
                checked++;
              }
            }
          }
        }
        expect(checked, greaterThan(5000));
        // And nothing came back from the viewer's side as an unknown character.
        expect(b.text, isNot(contains('�')));
      },
    );

    test('the book is Hindi: every sentence is set in Devanagari', () {
      final Built b = built.first;
      final int dev = RegExp('[ऀ-ॿ]').allMatches(b.text).length;
      final int lat = RegExp('[A-Za-z]').allMatches(b.text).length;
      expect(dev, greaterThan(40000));
      // Latin letters appear only in the person's name and the place, in
      // labels such as UTC, JPL and DE440s, and nowhere as English text.
      expect(lat, lessThan(dev ~/ 60));
    });
  });

  group('what the book will not say', () {
    List<String> hits(Iterable<String> texts, Iterable<String> stems) =>
        <String>[
          for (final String t in texts)
            for (final String stem in stems)
              if (t.contains(stem))
                '$stem in "${t.length > 80 ? t.substring(0, 80) : t}"',
        ];

    test('no refused subject appears anywhere in what the PDF says', () {
      final List<String> stems = <String>[
        ...engine.refusedHindi,
        ...tajika.forbiddenHindiTerms,
        ...refusedHindiStems,
      ];
      // The engine's stem "मरण" (death) is also the end of "स्मरण"
      // (remembrance), a word the pitra dosha's own text uses for what the
      // tradition asks of the person. Words with that conjunct are set aside
      // before the engine's plain substring lists are applied.
      String withoutRemembrance(String s) =>
          s.replaceAll(RegExp('[ऀ-ॿ]*स्मरण[ऀ-ॿ]*'), '');
      for (final Built b in built) {
        // The words as read back out of the file, and the sentences as written.
        expect(hits(b.words.map(withoutRemembrance), stems), isEmpty);
        expect(hits(<String>[withoutRemembrance(b.squashed)], stems), isEmpty);
        expect(hits(b.result.ledger.map(withoutRemembrance), stems), isEmpty);
        // The classical yoga list, which the engine applies to its yoga texts,
        // applied to the pages of the yoga section.
        final String yogaScan = classical.bannedHindi
            .allMatches(b.wordsOfSections('yoga', 'matbhed').join(' '))
            .map((Match m) => m.group(0)!)
            .join(',');
        expect(yogaScan, isEmpty, reason: 'classical yoga ban list');
        // No Latin word of the English lists either.
        final String english = b.words
            .where((String w) => RegExp(r'^[A-Za-z]+$').hasMatch(w))
            .join(' ');
        expect(engine.refusedEnglish.hasMatch(english), isFalse);
        expect(engine.doomEnglish.hasMatch(english), isFalse);
      }
    });

    test('a refused word is caught, and a harmless one is not', () {
      expect(isRefusedHindi('इस वर्ष मृत्यु का योग'), isTrue);
      expect(isRefusedHindi('परीक्षा का परिणाम'), isTrue);
      expect(isRefusedHindi('निवेश की सलाह'), isTrue);
      expect(isRefusedHindi('धैर्य और अनुशासन'), isFalse);
      expect(isRefusedHindi('उम्र 12 वर्ष'), isFalse);
      expect(isRefusedHindi('आयु', yoga: true), isTrue);
    });

    test(
      'the names that would be a refused subject were left out, and said so',
      () {
        final Built b = built.first;
        expect(b.result.omitted, isNotEmpty);
        // The omissions are the Mrityu and Roga names and the cards that list
        // them, not a reading.
        for (final String o in b.result.omitted) {
          expect(isRefusedHindi(o) || isRefusedHindi(o, yoga: true), isTrue);
        }
      },
    );

    test('remedies are practice only: nothing to buy, nothing promised', () {
      for (final Built b in built) {
        expect(b.result.remedyLedger, isNotEmpty);
        for (final String r in b.result.remedyLedger) {
          for (final String stem in engine.buyingHindi) {
            expect(r, isNot(contains(stem)), reason: r);
          }
          for (final String stem in engine.promisesHindi) {
            expect(r, isNot(contains(stem)), reason: r);
          }
        }
      }
    });

    test('a band is a count of factors and is never a chance', () {
      // The words the engine keeps out of its readings, applied to every page
      // that carries a band: the timeline, the periods, houses, grahas and
      // transits. (The year chart's Mudda dasha says how much of a nakshatra
      // the Moon had crossed, a fraction of a star and not a chance.)
      for (final Built b in built) {
        final List<String> banded = <String>[
          ...b.wordsOfSections('timeline', 'yoga'),
          ...b.wordsOfSections('gochar', 'varshphal'),
        ];
        for (final String stem in engine.chanceHindi) {
          expect(
            banded.where((String w) => w.contains(stem)),
            isEmpty,
            reason: stem,
          );
        }
        expect(b.result.omitted.where((String o) => o.contains('%')), isEmpty);
      }
    });
  });

  group('every adverse finding carries its relief', () {
    test('houses, grahas, periods, windows and transits that are printed', () {
      int adverse = 0;
      for (final Built b in built) {
        final Phaladesh p = b.result.data.phala;
        final List<IndicatedReading> printed = <IndicatedReading>[
          ...p.bhavas,
          ...p.grahas,
          ...p.dasha.mahadashas,
          ...p.dasha.chainAt(b.result.data.now),
          ...p.timeline.windows,
          ...b.result.data.gochar.readings,
        ];
        for (final IndicatedReading r in printed) {
          if (!engine.isAdverse(r)) continue;
          adverse++;
          final List<Remedy> remedies = r.remedies;
          final Bi? relief = switch (r) {
            BhavaReading x => x.relief,
            GrahaReading x => x.relief,
            PeriodReading x => x.relief,
            TimelineWindow x => x.relief,
            GocharReading x => x.relief,
            _ => null,
          };
          expect(
            relief != null || remedies.isNotEmpty,
            isTrue,
            reason: 'adverse and nothing to ease it: ${r.headline.hi}',
          );
          if (relief != null) {
            expect(
              b.squashed,
              contains(squash(relief.hi)),
              reason: 'relief not printed: ${relief.hi}',
            );
          }
          for (final Remedy rem in remedies) {
            expect(
              b.squashed,
              contains(squash(rem.addresses.hi)),
              reason: 'remedy not printed for ${r.headline.hi}',
            );
            expect(b.squashed, contains(squash(rem.kit.mantra.hi)));
            expect(b.squashed, contains(squash(rem.kit.simpleAct.hi)));
          }
        }
      }
      expect(adverse, greaterThan(100));
    });

    test(
      'every dosha is printed with its cancellation or what the tradition asks',
      () {
        int doshas = 0;
        for (final Built b in built) {
          for (final YogaFinding f in b.result.data.yogas.where(
            (YogaFinding f) => f.isDosha,
          )) {
            doshas++;
            expect(f.hasRelief, isTrue, reason: f.key);
            final String relief = f.cancellationHindi ?? f.mitigationHindi!;
            expect(b.squashed, contains(squash(f.nameHindi)), reason: f.key);
            expect(
              b.squashed,
              contains(squash(relief)),
              reason: '${f.key} relief',
            );
          }
        }
        expect(doshas, greaterThan(0));
      },
    );

    test('every reading names the chart factors it came from', () {
      final Built b = built.first;
      final Phaladesh p = b.result.data.phala;
      for (final IndicatedReading r in <IndicatedReading>[
        ...p.bhavas,
        ...p.grahas,
        ...p.timeline.windows,
      ]) {
        expect(r.basis, isNotEmpty);
        for (final Bi f in r.basis.take(2)) {
          expect(b.squashed, contains(squash(f.hi)), reason: f.hi);
        }
      }
      expect(b.text, contains('आधार'));
    });
  });

  edgeCases();

  group('what the book holds', () {
    test(
      'every section the owner asked for is there, in order, with its page',
      () {
        for (final Built b in built.take(4)) {
          const List<String> ids = <String>[
            'birth',
            'charts',
            'planets',
            'panchang',
            'shadbala',
            'ashtaka',
            'dasha',
            'timeline',
            'dashaphala', //
            'bhava',
            'graha',
            'yoga',
            'matbhed',
            'gochar',
            'varshphal',
            'sudarshan',
            'other',
            'upaya',
          ];
          int previous = 1;
          for (final String id in ids) {
            final int? page = b.result.sectionPages[id];
            expect(page, isNotNull, reason: id);
            expect(
              page!,
              greaterThan(previous),
              reason: '$id after the one before',
            );
            previous = page;
          }
          expect(b.result.sectionPages['contents'], 2);
          // The contents page itself prints those page numbers.
          final List<String> contents = b.pdf.pageWords(
            b.pdf.pages[1],
            fileKey: b.key,
          );
          expect(
            contents.where(
              (String w) => w == '${b.result.sectionPages['timeline']}',
            ),
            isNotEmpty,
          );
        }
      },
    );

    test('the charts are drawn, all sixteen vargas of them', () {
      final Built b = built.first;
      for (final String name in <String>[
        'नवांश',
        'होरा',
        'द्रेष्काण',
        'षष्ठ्यंश',
        'त्रिंशांश',
        'अक्षवेदांश',
      ]) {
        expect(b.squashed, contains(squash(name)));
      }
      // Each chart sets the sign numbers 1 to 12 as its own words and draws
      // its lines; the section holds the lagna chart in two styles, the Moon
      // and Sun charts and the sixteen vargas, so many such numbers.
      final List<String> pageWords = b.wordsOfSections('charts', 'planets');
      final int numbers = pageWords
          .where((String w) => RegExp(r'^\d{1,2}$').hasMatch(w))
          .length;
      expect(numbers, greaterThan(19 * 12 - 20));
      final MiniPdf pdf = b.pdf;
      int rects = 0;
      for (
        int i = b.result.sectionPages['charts']! - 1;
        i < b.result.sectionPages['planets']! - 1;
        i++
      ) {
        for (final PdfObj c in pdf.contentsOf(pdf.pages[i])) {
          rects += RegExp(r'(?<![\w/.])re(?=\s)')
              .allMatches(String.fromCharCodes(pdf.stream(c, fileKey: b.key)))
              .length;
        }
      }
      expect(rects, greaterThan(19));
    });

    test('the life timeline carries every window of the engine, dated', () {
      for (final Built b in built.take(3)) {
        final LifeTimeline t = b.result.data.phala.timeline;
        for (final TimelineWindow w in t.windows) {
          final String dates = squash(
            '${phalaDate(w.start, b.result.data.zone).hi} – ${phalaDate(w.end, b.result.data.zone).hi}',
          );
          expect(b.squashed, contains(dates), reason: 'window ${w.index}');
        }
      }
    });

    test(
      'both the Hindi planets and the Sanskrit terms are the app\'s own',
      () {
        final Built b = built.first;
        for (final Graha g in Graha.values) {
          expect(b.squashed, contains(squash(grahaInfo(g).hindi)));
        }
      },
    );
  });
}

extension on MiniPdf {
  List<String> words(PdfObj page, Built b) => pageWords(page, fileKey: b.key);
}

/// Charts at the edges: a newborn, a very old birth, the polar summer, the
/// southern hemisphere, a west-of-Greenwich zone, an unknown time of day and a
/// name with no Latin letters in it. None may stop the book from being made.
void edgeCases() {
  group('charts at the edges still make a whole book', () {
    final List<(String, BirthData)> cases = <(String, BirthData)>[
      (
        'a newborn',
        BirthData(
          name: 'Baby',
          localDateTime: DateTime(2026, 10, 18, 4, 5),
          utcOffset: const Duration(hours: 5, minutes: 30),
          place: engine.delhi,
        ),
      ),
      (
        'an old birth',
        BirthData(
          name: 'Dada',
          localDateTime: DateTime(1921, 1, 2, 23, 59),
          utcOffset: const Duration(hours: 5, minutes: 30),
          place: engine.delhi,
        ),
      ),
      (
        'the polar summer',
        BirthData(
          name: 'Tromso',
          localDateTime: DateTime(2000, 6, 21, 2, 0),
          utcOffset: const Duration(hours: 2),
          place: const GeoPlace(
            name: 'Tromsø, Norway',
            latitude: 69.6492,
            longitude: 18.9553,
            timeZoneId: 'Europe/Oslo',
          ),
        ),
      ),
      (
        'the southern hemisphere',
        BirthData(
          name: 'Sydney',
          localDateTime: DateTime(1985, 12, 25, 15, 30),
          utcOffset: const Duration(hours: 11),
          place: const GeoPlace(
            name: 'Sydney, Australia',
            latitude: -33.8688,
            longitude: 151.2093,
            timeZoneId: 'Australia/Sydney',
          ),
        ),
      ),
      (
        'west of Greenwich',
        BirthData(
          name: 'New Yorker',
          localDateTime: DateTime(1999, 3, 14, 21, 40),
          utcOffset: const Duration(hours: -5),
          place: const GeoPlace(
            name: 'New York, United States',
            latitude: 40.7128,
            longitude: -74.006,
            timeZoneId: 'America/New_York',
          ),
        ),
      ),
      (
        'a name in Devanagari alone, time unsure',
        BirthData(
          name: 'श्रीमती गायत्री देवी',
          localDateTime: DateTime(1969, 7, 20, 12, 0),
          utcOffset: const Duration(hours: 5, minutes: 30),
          place: const GeoPlace(
            name: 'वाराणसी, उत्तर प्रदेश, भारत',
            latitude: 25.3176,
            longitude: 82.9739,
            timeZoneId: 'Asia/Kolkata',
          ),
          timeIsApproximate: true,
        ),
      ),
    ];
    for (final (String, BirthData) c in cases) {
      test(c.$1, () async {
        final KundliPdfResult r = await buildKundliPdf(
          KundliPdfRequest(
            birth: c.$2,
            ayanamsa: Ayanamsa.lahiri,
            now: DateTime.utc(2026, 10, 21, 12),
            fonts: loadFonts(),
            password: kundliPdfPassword,
          ),
        );
        expect(r.pageCount, inInclusiveRange(40, 260));
        expect(r.missingCodes, isEmpty);
        final MiniPdf pdf = MiniPdf.parse(r.bytes);
        expect(pdf.pages.length, r.pageCount);
        expect(
          PdfAes256Encryption.checksUserPassword(
            pdf.hexEntry('/U'),
            kundliPdfPassword,
          ),
          isTrue,
        );
        // A name written only in Devanagari has no name number to count.
        if (c.$2.name.contains('श्रीमती')) {
          expect(r.ledger.where((String s) => s.contains('नामांक')), isEmpty);
        }
      });
    }
  });
}
