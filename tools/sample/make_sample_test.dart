// Makes the unlocked sample PDF that the websites offer, so a visitor can see
// what the report is before parting with anything.
//
// Run it:
//   KUNDLISAAR_SAMPLE=/path/sample.pdf flutter test tools/sample/make_sample_test.dart
//
// The birth details are invented. A real person's date, time and town are
// exactly what this app promises never to put anywhere, and a sample published
// on a website would put one reader's details in front of everybody.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/kundli_pdf/kundli_pdf.dart';

KundliPdfFontBytes _fonts() => KundliPdfFontBytes(
  regular: File('assets/fonts/Mukta-Regular.ttf').readAsBytesSync(),
  semiBold: File('assets/fonts/Mukta-SemiBold.ttf').readAsBytesSync(),
  tiro: File('assets/fonts/TiroDevanagariHindi-Regular.ttf').readAsBytesSync(),
  yatra: File('assets/fonts/YatraOne-Regular.ttf').readAsBytesSync(),
);

void main() {
  test('the sample book builds, unlocked', () async {
    final String? out = Platform.environment['KUNDLISAAR_SAMPLE'];
    if (out == null) {
      markTestSkipped('set KUNDLISAAR_SAMPLE to write the file');
      return;
    }

    final KundliPdfResult r = await buildKundliPdf(
      KundliPdfRequest(
        birth: BirthData(
          // Invented, and named so nobody mistakes it for a real person.
          name: 'नमूना कुंडली',
          localDateTime: DateTime(1990, 4, 12, 7, 42),
          utcOffset: const Duration(hours: 5, minutes: 30),
          place: const GeoPlace(
            name: 'Varanasi, Uttar Pradesh, IN',
            latitude: 25.3176,
            longitude: 82.9739,
            timeZoneId: 'Asia/Kolkata',
          ),
        ),
        ayanamsa: Ayanamsa.lahiri,
        now: DateTime.utc(2026, 10, 22, 12),
        fonts: _fonts(),
        // No password: this one is meant to be opened by anyone.
        password: '',
        encrypt: false,
      ),
    );

    final Uint8List bytes = r.bytes;
    File(out).writeAsBytesSync(bytes);
    // A PDF with no /Encrypt dictionary opens without a password anywhere.
    expect(String.fromCharCodes(bytes.take(2048)), startsWith('%PDF'));
    expect(
      String.fromCharCodes(bytes).contains('/Encrypt'),
      isFalse,
      reason: 'the sample must open without a password',
    );
    stdout.writeln('SAMPLE ${bytes.length ~/ 1024} KB -> $out');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
