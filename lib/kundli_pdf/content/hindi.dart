import '../../engine/astro/ephemeris.dart';
import '../../engine/jyotish/chart.dart';
import '../../engine/jyotish/graha_data.dart';
import '../../engine/jyotish/nakshatra.dart';
import '../../engine/jyotish/phaladesh.dart';
import '../../engine/jyotish/rashi.dart';
import '../../engine/astro/ayanamsa.dart';

/// Hindi wording and number formatting shared by the sections. Where the app
/// already has the word (a graha, a sign, a dignity) it is the app's word.
class Hi {
  const Hi._();

  static String graha(Graha g) => grahaInfo(g).hindi;
  static String sign(Rashi r) => rashiInfo(r).hindi;
  static String signAt(int index) => rashiInfo(Rashi.values[index % 12]).hindi;

  /// "5 जून 1996" for a wall-clock date.
  static String localDate(DateTime local) => _date(local);

  /// "5 जून 1996" for a UTC moment read in the birth place's own offset.
  static String date(DateTime utc, Duration offset) =>
      phalaDate(utc, offset).hi;

  static const List<String> _months = <String>[
    'जनवरी',
    'फ़रवरी',
    'मार्च',
    'अप्रैल',
    'मई',
    'जून',
    'जुलाई',
    'अगस्त',
    'सितंबर',
    'अक्टूबर',
    'नवंबर',
    'दिसंबर',
  ];

  static String _date(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// "09:35" on the 24-hour clock.
  static String clock(DateTime local) =>
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  static String dateTime(DateTime utc, Duration offset) {
    final DateTime l = utc.add(offset);
    return '${_date(l)}, ${clock(l)}';
  }

  /// "12°34′" with the minute mark Mukta carries.
  static String deg(double value) {
    final double d = value.abs();
    int whole = d.floor();
    int minutes = ((d - whole) * 60).round();
    if (minutes == 60) {
      whole += 1;
      minutes = 0;
    }
    return "$whole°${minutes.toString().padLeft(2, '0')}'";
  }

  static String dms(double value) {
    final double d = value.abs();
    int whole = d.floor();
    double rest = (d - whole) * 60;
    int m = rest.floor();
    int s = ((rest - m) * 60).round();
    if (s == 60) {
      s = 0;
      m += 1;
    }
    if (m == 60) {
      m = 0;
      whole += 1;
    }
    return "$whole°${m.toString().padLeft(2, '0')}'${s.toString().padLeft(2, '0')}\"";
  }

  static String dignity(Dignity d) => switch (d) {
    Dignity.exalted => 'उच्च',
    Dignity.debilitated => 'नीच',
    Dignity.own => 'स्वराशि',
    Dignity.moolatrikona => 'मूलत्रिकोण',
    Dignity.friend => 'मित्र राशि',
    Dignity.neutral => 'सम राशि',
    Dignity.enemy => 'शत्रु राशि',
  };

  static String ayanamsa(Ayanamsa a) => switch (a) {
    Ayanamsa.lahiri => 'लाहिड़ी (चित्रपक्ष)',
    Ayanamsa.raman => 'रमण',
    Ayanamsa.krishnamurti => 'कृष्णमूर्ति (के.पी.)',
    Ayanamsa.trueChitra => 'सत्य चित्रा',
    Ayanamsa.pushyaPaksha => 'पुष्य-पक्ष',
  };

  static String gana(Gana g) => switch (g) {
    Gana.deva => 'देव',
    Gana.manushya => 'मनुष्य',
    Gana.rakshasa => 'राक्षस',
  };

  static String nadi(Nadi n) => switch (n) {
    Nadi.adi => 'आदि',
    Nadi.madhya => 'मध्य',
    Nadi.antya => 'अंत्य',
  };

  static const Map<String, String> _yoni = <String, String>{
    'horse': 'अश्व',
    'elephant': 'गज',
    'sheep': 'मेष',
    'serpent': 'सर्प',
    'dog': 'श्वान',
    'cat': 'मार्जार',
    'rat': 'मूषक',
    'cow': 'गौ',
    'buffalo': 'महिष',
    'tiger': 'व्याघ्र',
    'deer': 'मृग',
    'monkey': 'वानर',
    'mongoose': 'नकुल',
    'lion': 'सिंह',
  };

  static String yoni(String key) => _yoni[key] ?? key;

  /// The short label a graha takes inside a chart box.
  static String chartLabel(Graha g) => switch (g) {
    Graha.sun => 'सू',
    Graha.moon => 'चं',
    Graha.mars => 'मं',
    Graha.mercury => 'बु',
    Graha.jupiter => 'गु',
    Graha.venus => 'शु',
    Graha.saturn => 'श',
    Graha.rahu => 'रा',
    Graha.ketu => 'के',
  };

  static const List<String> weekdays = <String>[
    'रविवार',
    'सोमवार',
    'मंगलवार',
    'बुधवार',
    'गुरुवार',
    'शुक्रवार',
    'शनिवार',
  ];

  static const List<String> yoginiNames = <String>[
    'मंगला',
    'पिंगला',
    'धान्या',
    'भ्रामरी',
    'भद्रिका',
    'उल्का',
    'सिद्धा',
    'संकटा',
  ];

  /// A span of [days] as years and months, or months and days when short.
  static String span(double days) {
    final double yearDays = 365.2425;
    final int y = (days / yearDays).floor();
    final double rest = days - y * yearDays;
    final int m = (rest / (yearDays / 12)).floor();
    final int d = (rest - m * (yearDays / 12)).round();
    if (y > 0) return m > 0 ? '$y वर्ष $m माह' : '$y वर्ष';
    if (m > 0) return d > 0 ? '$m माह $d दिन' : '$m माह';
    return '$d दिन';
  }

  /// "12.5 वर्ष".
  static String years(double v) => '${v.toStringAsFixed(v < 10 ? 1 : 0)} वर्ष';

  /// Ordinal house: "चतुर्थ भाव".
  static const List<String> ordinal = <String>[
    'प्रथम',
    'द्वितीय',
    'तृतीय',
    'चतुर्थ',
    'पंचम',
    'षष्ठ',
    'सप्तम',
    'अष्टम',
    'नवम',
    'दशम',
    'एकादश',
    'द्वादश',
  ];

  static String house(int h) => '${ordinal[(h - 1) % 12]} भाव';
}
