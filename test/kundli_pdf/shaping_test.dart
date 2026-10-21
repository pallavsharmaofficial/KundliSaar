import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/kundli_pdf/kundli_pdf.dart';
import 'package:kundlisaar/kundli_pdf/text/devanagari_shaper.dart';
import 'package:kundlisaar/kundli_pdf/text/ot_font.dart';

/// The shaper is judged against HarfBuzz, glyph for glyph.
///
/// test/kundli_pdf/fixtures/shaping_reference.json holds what HarfBuzz
/// (uharfbuzz 0.56, script Deva, language hi, default features) makes of every
/// word in shaping_words.txt and of every Devanagari run the book draws for the
/// sample chart below, for each bundled font: the glyph ids, each glyph's pen
/// position plus its offset, and the advance of the whole word. The test shapes
/// the same words with the Dart engine and demands the same answer.
///
/// When the book gains words the fixture does not hold, the last test here
/// names them and writes them to build/missing_shaping_runs.json. Regenerate
/// the fixture with test/kundli_pdf/fixtures/make_shaping_reference.py (it needs
/// `pip install uharfbuzz`), giving it that file merged with the runs already
/// in the fixture.
void main() {
  final Map<String, dynamic> reference =
      jsonDecode(
            File(
              'test/kundli_pdf/fixtures/shaping_reference.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final String file in reference.keys) {
    group('shaping $file', () {
      final OtFont font = OtFont(File('assets/fonts/$file').readAsBytesSync());
      final DevanagariShaper shaper = DevanagariShaper(font);
      final Map<String, dynamic> words =
          reference[file] as Map<String, dynamic>;

      test('matches HarfBuzz on every word', () {
        final List<String> failures = <String>[];
        int checked = 0;
        for (final MapEntry<String, dynamic> e in words.entries) {
          final String word = e.key;
          if (word.contains(' ')) continue;
          checked++;
          final List<ShapedCluster> clusters = shaper.shape(word);
          final List<List<int>> mine = <List<int>>[];
          int pen = 0;
          for (final ShapedCluster c in clusters) {
            for (final GlyphPlacement g in c.glyphs) {
              mine.add(<int>[g.gid, pen + g.dx, g.dy]);
            }
            pen += c.advance;
          }
          final Map<String, dynamic> ref = e.value as Map<String, dynamic>;
          final List<List<int>> theirs = <List<int>>[
            for (final dynamic g in ref['glyphs'] as List<dynamic>)
              (g as List<dynamic>).cast<int>(),
          ];
          final bool same =
              mine.length == theirs.length &&
              pen == ref['adv'] &&
              <int>[
                for (int i = 0; i < mine.length; i++)
                  if (mine[i][0] != theirs[i][0] ||
                      mine[i][1] != theirs[i][1] ||
                      mine[i][2] != theirs[i][2])
                    i,
              ].isEmpty;
          if (!same) {
            failures.add(
              '$word (${word.runes.map((int r) => r.toRadixString(16)).join(' ')})\n'
              '   mine   : $mine adv $pen\n'
              '   harfbuzz: $theirs adv ${ref['adv']}',
            );
          }
        }
        expect(checked, greaterThan(50));
        expect(
          failures,
          isEmpty,
          reason:
              '${failures.length} of $checked words differ:\n${failures.take(40).join('\n')}',
        );
      });
    });
  }

  test(
    'the reference holds every run the book draws for the sample chart',
    () async {
      final KundliPdfFontBytes bytes = KundliPdfFontBytes(
        regular: File('assets/fonts/Mukta-Regular.ttf').readAsBytesSync(),
        semiBold: File('assets/fonts/Mukta-SemiBold.ttf').readAsBytesSync(),
        tiro: File(
          'assets/fonts/TiroDevanagariHindi-Regular.ttf',
        ).readAsBytesSync(),
        yatra: File('assets/fonts/YatraOne-Regular.ttf').readAsBytesSync(),
      );
      final KundliPdfResult r = await buildKundliPdf(
        KundliPdfRequest(
          birth: BirthData(
            name: 'पल्लव शर्मा',
            localDateTime: DateTime(1996, 6, 13, 8, 30),
            utcOffset: const Duration(hours: 5, minutes: 30),
            place: const GeoPlace(
              name: 'Delhi, India',
              latitude: 28.6139,
              longitude: 77.2090,
              timeZoneId: 'Asia/Kolkata',
            ),
          ),
          ayanamsa: Ayanamsa.lahiri,
          now: DateTime.utc(2026, 10, 21, 12),
          fonts: bytes,
          password: kundliPdfPassword,
          encrypt: false,
          recordDrawn: true,
        ),
      );
      const Map<String, String> files = <String, String>{
        'Mukta-Regular': 'Mukta-Regular.ttf',
        'Mukta-SemiBold': 'Mukta-SemiBold.ttf',
        'TiroDevaHindi-Regular': 'TiroDevanagariHindi-Regular.ttf',
        'YatraOne-Regular': 'YatraOne-Regular.ttf',
      };
      final RegExp dev = RegExp('[\u0900-\u097F\u200C\u200D]+');
      final Map<String, Set<String>> missing = <String, Set<String>>{};
      r.drawnByFont.forEach((String face, Set<String> drawn) {
        final Map<String, dynamic> known =
            (reference[files[face]] ?? <String, dynamic>{})
                as Map<String, dynamic>;
        for (final String word in drawn) {
          for (final RegExpMatch m in dev.allMatches(word)) {
            if (!known.containsKey(m.group(0))) {
              missing.putIfAbsent(face, () => <String>{}).add(m.group(0)!);
            }
          }
        }
      });
      if (missing.isNotEmpty) {
        Directory('build').createSync(recursive: true);
        File('build/missing_shaping_runs.json').writeAsStringSync(
          jsonEncode(<String, List<String>>{
            for (final MapEntry<String, Set<String>> e in missing.entries)
              e.key: e.value.toList(),
          }),
        );
      }
      expect(
        missing.map(
          (String k, Set<String> v) => MapEntry<String, int>(k, v.length),
        ),
        isEmpty,
        reason:
            'runs the HarfBuzz reference does not hold; see build/missing_shaping_runs.json',
      );
    },
  );
}
