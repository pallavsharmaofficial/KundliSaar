import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/kundli_pdf/crypto/pdf_aes256.dart';
import 'package:kundlisaar/kundli_pdf/delivery/kundli_pdf_service.dart';
import 'package:kundlisaar/kundli_pdf/kundli_pdf_password.dart';

import 'mini_pdf.dart';

/// The path the app takes: fonts out of the asset bundle, the whole book made
/// in a background isolate, plain bytes handed back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the app\'s own route makes an encrypted PDF that opens with the password',
    () async {
      final List<String> stages = <String>[];
      final KundliPdfFile file = await makeKundliPdf(
        birth: BirthData(
          name: 'पल्लव शर्मा',
          localDateTime: DateTime(1996, 6, 13, 8, 30),
          utcOffset: const Duration(hours: 5, minutes: 30),
          place: const GeoPlace(
            name: 'Delhi',
            latitude: 28.6139,
            longitude: 77.2090,
            timeZoneId: 'Asia/Kolkata',
          ),
        ),
        ayanamsa: Ayanamsa.lahiri,
        now: DateTime(2026, 10, 21, 12),
        onStage: stages.add,
      );
      expect(stages, isNotEmpty);
      expect(file.fileName, 'KundliSaar_पल्लव_शर्मा_20261021.pdf');
      expect(file.pageCount, inInclusiveRange(60, 220));

      final MiniPdf pdf = MiniPdf.parse(file.bytes);
      expect(pdf.hasHeader && pdf.hasEof, isTrue);
      final Uint8List u = pdf.hexEntry('/U');
      expect(
        PdfAes256Encryption.checksUserPassword(u, kundliPdfPassword),
        isTrue,
      );
      expect(PdfAes256Encryption.checksUserPassword(u, 'wrong'), isFalse);
      final Uint8List key = PdfAes256Encryption.fileKeyFromUser(
        u,
        pdf.hexEntry('/UE'),
        kundliPdfPassword,
      );
      final List<String> words = pdf.pageWords(pdf.pages.first, fileKey: key);
      expect(words, contains('पत्रिका'));
      expect(words.join(' '), contains('पल्लव'));
    },
  );
}
