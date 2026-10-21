import 'package:pdf/pdf.dart';

/// The page's colours. The ink is a warm black so that every chart and every
/// line of text still prints as plain black and white; the other colours only
/// ever carry decoration, never meaning.
class Pal {
  const Pal._();

  static const PdfColor ink = PdfColor.fromInt(0xFF2A1B13);
  static const PdfColor inkSoft = PdfColor.fromInt(0xFF5E4B3C);
  static const PdfColor inkFaint = PdfColor.fromInt(0xFF8A7763);
  static const PdfColor maroon = PdfColor.fromInt(0xFF7A1D1D);
  static const PdfColor gold = PdfColor.fromInt(0xFFB4832A);
  static const PdfColor goldLight = PdfColor.fromInt(0xFFD9B968);
  static const PdfColor parchment = PdfColor.fromInt(0xFFFCF5E3);
  static const PdfColor parchmentDeep = PdfColor.fromInt(0xFFF1E1B8);
  static const PdfColor panel = PdfColor.fromInt(0xFFF8EED4);
  static const PdfColor rule = PdfColor.fromInt(0xFFCDB580);
  static const PdfColor white = PdfColor.fromInt(0xFFFFFFFF);
}
