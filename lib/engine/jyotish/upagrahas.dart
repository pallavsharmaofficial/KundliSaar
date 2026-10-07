/// Upagrahas: the minor points the tradition computes beside the nine grahas.
///
/// Two sets, both from Parashara (Brihat Parashara Hora Shastra chapter 3,
/// verses 61 to 70, read in the Sanskrit):
///
///  * the Sun-derived set (Dhuma, Vyatipata, Parivesha, Indrachapa, Upaketu),
///    each a fixed arc from the Sun, and
///  * the Kaala set (Kaala, Mrityu, Ardha Prahara, Yama Ghantaka, Gulika and
///    Mandi), each the rising ascendant at a point inside one of the eight
///    parts of the day or of the night.
///
/// "Ardha Prahara" and "Artha Prahara" are one upagraha, Mercury's, written two
/// ways; it appears here once.
///
/// How they are read. The texts count all of them among the non-luminous,
/// shadowy points and speak of them in harsh terms. Here each is read only as a
/// faint overlay on the house it falls in: the area of life where that point
/// asks for a particular kind of care. Nothing here is an event, and the name
/// Mrityu (Mars's portion, literally "end") is a name, not a prediction.
library;

import '../astro/angles.dart';
import '../astro/ephemeris.dart';
import '../astro/houses.dart';
import '../astro/rise_set.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'nakshatra.dart';
import 'rashi.dart';

enum Upagraha {
  dhuma,
  vyatipata,
  parivesha,
  indrachapa,
  upaketu,
  kaala,
  mrityu,
  ardhaprahara,
  yamaghantaka,
  gulika,
  mandi,
}

/// Where inside its part of the day or night the ascendant is taken.
enum UpagrahaPoint { begin, middle, end }

/// The convention for the point inside each part. The texts say "the lagna of
/// the Gulika time" (BPHS 3.70) and do not fix the point, and the schools
/// differ, so it is a stated choice:
///
///  * Gulika: the beginning of Saturn's part. This is the Parashari reading,
///    and it makes Gulika's time the same as the Gulika Kaal the panchang shows.
///  * Mandi: the end of Saturn's part, the Kerala convention as the Prasna
///    Marga states it ("the ascendant rising at the end of Saturn's portion"),
///    where Mandi is kept apart from Gulika. Some software takes Mandi at the
///    middle of the part instead.
///  * Kaala, Mrityu, Ardha Prahara and Yama Ghantaka: the middle of their
///    parts, as PyJHora does (which in turn follows Jagannatha Hora).
class UpagrahaConvention {
  const UpagrahaConvention({
    this.gulika = UpagrahaPoint.begin,
    this.mandi = UpagrahaPoint.end,
    this.others = UpagrahaPoint.middle,
  });

  final UpagrahaPoint gulika;
  final UpagrahaPoint mandi;
  final UpagrahaPoint others;
}

class UpagrahaInfo {
  const UpagrahaInfo({
    required this.upagraha,
    required this.english,
    required this.hindi,
    required this.isSolar,
    required this.formulaEnglish,
    required this.formulaHindi,
    required this.readingEnglish,
    required this.readingHindi,
  });

  final Upagraha upagraha;
  final String english;
  final String hindi;

  /// True for the five derived from the Sun; false for the Kaala set.
  final bool isSolar;

  /// How its longitude is found.
  final String formulaEnglish;
  final String formulaHindi;

  /// What it stands for, as an area of life and a disposition.
  final String readingEnglish;
  final String readingHindi;
}

const List<UpagrahaInfo> upagrahaTable = <UpagrahaInfo>[
  UpagrahaInfo(
    upagraha: Upagraha.dhuma,
    english: 'Dhuma',
    hindi: 'धूम',
    isSolar: true,
    formulaEnglish:
        'Sun + 133°20′ (four signs and thirteen degrees twenty minutes), BPHS 3.61.',
    formulaHindi:
        'सूर्य + 133°20′ (चार राशि, तेरह अंश बीस कला), बृहत्पाराशर 3.61।',
    readingEnglish:
        'Dhuma means smoke. The tradition counts it among the shadowy points; here it is read only as a haze over its house, where clarity comes by patience.',
    readingHindi:
        'धूम का अर्थ धुआँ है। परंपरा इसे छायावी बिंदुओं में गिनती है; यहाँ इसे केवल अपने भाव पर छाई धुंध की तरह पढ़ा गया है, जहाँ स्पष्टता धैर्य से आती है।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.vyatipata,
    english: 'Vyatipata',
    hindi: 'व्यतीपात',
    isSolar: true,
    formulaEnglish: '360° − Dhuma, BPHS 3.62.',
    formulaHindi: '360° − धूम, बृहत्पाराशर 3.62।',
    readingEnglish:
        'Vyatipata means a turning across. It is read as a house where plans are best checked twice and where changes of course are better made deliberately.',
    readingHindi:
        'व्यतीपात का अर्थ आर-पार पलटना है। इसे ऐसे भाव की तरह पढ़ा गया है जहाँ योजनाओं को दो बार जाँचना और दिशा बदलना सोच-समझकर करना अच्छा है।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.parivesha,
    english: 'Parivesha',
    hindi: 'परिवेष',
    isSolar: true,
    formulaEnglish: 'Vyatipata + 180°, BPHS 3.62.',
    formulaHindi: 'व्यतीपात + 180°, बृहत्पाराशर 3.62।',
    readingEnglish:
        'Parivesha means a halo. It is read as a ring around its house: a guarded, self-contained quality in that area of life.',
    readingHindi:
        'परिवेष का अर्थ प्रभामंडल है। इसे अपने भाव के चारों ओर के घेरे की तरह पढ़ा गया है: जीवन के उस क्षेत्र में सुरक्षित, आत्म-निहित स्वभाव।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.indrachapa,
    english: 'Indrachapa',
    hindi: 'इंद्रचाप',
    isSolar: true,
    formulaEnglish: '360° − Parivesha, BPHS 3.63.',
    formulaHindi: '360° − परिवेष, बृहत्पाराशर 3.63।',
    readingEnglish:
        'Indrachapa is the rainbow. It is read as a house where appearances shift with the light, so what is promised is best weighed against what is delivered.',
    readingHindi:
        'इंद्रचाप इंद्रधनुष है। इसे ऐसे भाव की तरह पढ़ा गया है जहाँ रूप रोशनी के साथ बदलते हैं, इसलिए जो वादा किया गया उसे जो निभाया गया उससे तौलना अच्छा है।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.upaketu,
    english: 'Upaketu',
    hindi: 'उपकेतु',
    isSolar: true,
    formulaEnglish:
        'Indrachapa + 16°40′, BPHS 3.63; which is the same as the Sun − 30°.',
    formulaHindi:
        'इंद्रचाप + 16°40′, बृहत्पाराशर 3.63; जो सूर्य − 30° के बराबर है।',
    readingEnglish:
        'Upaketu is the little flag or flame-tip. It is read as a house with a quick, flickering quality, where attention is better held on one thing at a time.',
    readingHindi:
        'उपकेतु नन्ही ध्वजा या लौ की नोक है। इसे तेज़, टिमटिमाते स्वभाव वाले भाव की तरह पढ़ा गया है, जहाँ ध्यान एक बार में एक चीज़ पर रखना अच्छा है।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.kaala,
    english: 'Kaala',
    hindi: 'काल',
    isSolar: false,
    formulaEnglish:
        'The ascendant rising at the middle of the Sun’s part of the day or night (BPHS 3.68).',
    formulaHindi:
        'दिन या रात में सूर्य के भाग के मध्य में उदय होने वाला लग्न (बृहत्पाराशर 3.68)।',
    readingEnglish:
        'Kaala is time itself, the Sun’s portion. It is read as the area of life where one meets the pressure of time and learns to pace oneself.',
    readingHindi:
        'काल स्वयं समय है, सूर्य का भाग। इसे जीवन के उस क्षेत्र की तरह पढ़ा गया है जहाँ समय के दबाव से सामना होता है और गति साधनी पड़ती है।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.mrityu,
    english: 'Mrityu',
    hindi: 'मृत्यु',
    isSolar: false,
    formulaEnglish:
        'The ascendant rising at the middle of Mars’s part of the day or night (BPHS 3.69).',
    formulaHindi:
        'दिन या रात में मंगल के भाग के मध्य में उदय होने वाला लग्न (बृहत्पाराशर 3.69)।',
    readingEnglish:
        'This is Mars’s portion, a sharp-edged point. It is read only as the area of life where care and steadiness are asked; the name is a name, not a forecast.',
    readingHindi:
        'यह मंगल का भाग है, एक तीखा बिंदु। इसे केवल उस क्षेत्र की तरह पढ़ा गया है जहाँ सावधानी और स्थिरता माँगी जाती है; नाम केवल नाम है, पूर्वानुमान नहीं।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.ardhaprahara,
    english: 'Ardha Prahara',
    hindi: 'अर्धप्रहर',
    isSolar: false,
    formulaEnglish:
        'The ascendant rising at the middle of Mercury’s part of the day or night (BPHS 3.69).',
    formulaHindi:
        'दिन या रात में बुध के भाग के मध्य में उदय होने वाला लग्न (बृहत्पाराशर 3.69)।',
    readingEnglish:
        'The half-watch, Mercury’s portion. It is read as the area of life where timing and speech matter, and where a pause before answering helps.',
    readingHindi:
        'अर्धप्रहर, बुध का भाग। इसे उस क्षेत्र की तरह पढ़ा गया है जहाँ समय का चुनाव और वाणी मायने रखती है, और उत्तर देने से पहले ठहरना काम आता है।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.yamaghantaka,
    english: 'Yama Ghantaka',
    hindi: 'यमघंटक',
    isSolar: false,
    formulaEnglish:
        'The ascendant rising at the middle of Jupiter’s part of the day or night (BPHS 3.69).',
    formulaHindi:
        'दिन या रात में गुरु के भाग के मध्य में उदय होने वाला लग्न (बृहत्पाराशर 3.69)।',
    readingEnglish:
        'The bell of restraint, Jupiter’s portion. It is read as the area of life where order and self-discipline are asked.',
    readingHindi:
        'संयम की घंटी, गुरु का भाग। इसे उस क्षेत्र की तरह पढ़ा गया है जहाँ व्यवस्था और आत्म-अनुशासन माँगा जाता है।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.gulika,
    english: 'Gulika',
    hindi: 'गुलिक',
    isSolar: false,
    formulaEnglish:
        'The ascendant rising at the beginning of Saturn’s part of the day or night (BPHS 3.66-70, Parashari reading).',
    formulaHindi:
        'दिन या रात में शनि के भाग के आरंभ में उदय होने वाला लग्न (बृहत्पाराशर 3.66-70, पाराशरी पाठ)।',
    readingEnglish:
        'Saturn’s portion. It is read as the area of life that moves slowly and rewards persistence: some weight, and the discipline that goes with it.',
    readingHindi:
        'शनि का भाग। इसे जीवन के उस क्षेत्र की तरह पढ़ा गया है जो धीमे चलता है और निरंतरता का फल देता है: कुछ भार, और उसके साथ का अनुशासन।',
  ),
  UpagrahaInfo(
    upagraha: Upagraha.mandi,
    english: 'Mandi',
    hindi: 'मांदि',
    isSolar: false,
    formulaEnglish:
        'The ascendant rising at the end of Saturn’s part of the day or night (the Kerala convention, as the Prasna Marga states it).',
    formulaHindi:
        'दिन या रात में शनि के भाग के अंत में उदय होने वाला लग्न (केरल परंपरा, जैसा प्रश्नमार्ग कहता है)।',
    readingEnglish:
        'The same Saturn portion as Gulika, taken at its close. It is read in the same way: a slow area of life that rewards persistence.',
    readingHindi:
        'गुलिक वाला ही शनि का भाग, उसके अंत पर लिया गया। इसे वैसे ही पढ़ा गया है: जीवन का धीमा क्षेत्र जो निरंतरता का फल देता है।',
  ),
];

UpagrahaInfo upagrahaInfo(Upagraha u) =>
    upagrahaTable.firstWhere((UpagrahaInfo i) => i.upagraha == u);

/// An upagraha as it stands in a chart.
class PlacedUpagraha {
  const PlacedUpagraha({
    required this.upagraha,
    required this.siderealLongitude,
    required this.house,
    this.partNumber,
    this.partLord,
  });

  final Upagraha upagraha;

  /// Sidereal longitude, 0 up to but not including 360.
  final double siderealLongitude;

  /// Whole-sign house from the lagna, 1..12.
  final int house;

  /// For the Kaala set: which of the eight parts (1..8) it was taken from, and
  /// the graha that rules that part.
  final int? partNumber;
  final Graha? partLord;

  UpagrahaInfo get info => upagrahaInfo(upagraha);
  Rashi get rashi => rashiOf(siderealLongitude);
  double get degreesInSign => degreesInRashi(siderealLongitude);
  NakshatraInfo get nakshatra => nakshatraOf(siderealLongitude);
}

class UpagrahaResult {
  const UpagrahaResult({
    required this.placed,
    required this.isDayBirth,
    required this.weekday,
    required this.sunriseJdUt,
    required this.sunsetJdUt,
    required this.nextSunriseJdUt,
  });

  final List<PlacedUpagraha> placed;

  /// Whether the birth fell between sunrise and sunset, which decides whether
  /// the day or the night is divided into eight.
  final bool isDayBirth;

  /// Weekday of the Hindu day the birth belongs to (it begins at sunrise),
  /// 0 = Sunday.
  final int weekday;

  /// The sunrise that began that Hindu day, the sunset after it, and the next
  /// sunrise, as UT Julian days.
  final double sunriseJdUt;
  final double sunsetJdUt;
  final double nextSunriseJdUt;

  PlacedUpagraha of(Upagraha u) =>
      placed.firstWhere((PlacedUpagraha p) => p.upagraha == u);
}

const double _dhumaOffset = 133.0 + 20.0 / 60.0;
const double _upaketuStep = 16.0 + 40.0 / 60.0;

/// The five Sun-derived longitudes from the Sun's sidereal longitude.
///
///  * Dhuma = Sun + 133°20′
///  * Vyatipata = 360° − Dhuma
///  * Parivesha = Vyatipata + 180°
///  * Indrachapa = 360° − Parivesha
///  * Upaketu = Indrachapa + 16°40′ (which equals the Sun − 30°)
Map<Upagraha, double> solarUpagrahaLongitudes(double sunSidereal) {
  final double dhuma = norm360(sunSidereal + _dhumaOffset);
  final double vyatipata = norm360(360.0 - dhuma);
  final double parivesha = norm360(vyatipata + 180.0);
  final double indrachapa = norm360(360.0 - parivesha);
  final double upaketu = norm360(indrachapa + _upaketuStep);
  return <Upagraha, double>{
    Upagraha.dhuma: dhuma,
    Upagraha.vyatipata: vyatipata,
    Upagraha.parivesha: parivesha,
    Upagraha.indrachapa: indrachapa,
    Upagraha.upaketu: upaketu,
  };
}

/// The graha whose part of the eight each Kaala-set upagraha takes, by index in
/// the weekday order Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn.
const Map<Upagraha, int> _partLordIndex = <Upagraha, int>{
  Upagraha.kaala: 0,
  Upagraha.mrityu: 2,
  Upagraha.ardhaprahara: 3,
  Upagraha.yamaghantaka: 4,
  Upagraha.gulika: 6,
  Upagraha.mandi: 6,
};

const List<Graha> _weekdayOrder = <Graha>[
  Graha.sun,
  Graha.moon,
  Graha.mars,
  Graha.mercury,
  Graha.jupiter,
  Graha.venus,
  Graha.saturn,
];

/// Sunrise and sunset of one local date, as UT Julian days, from the closed-form
/// solver (within about a minute of the exact crossing). Inside the polar
/// circles, where there may be none, it falls back to six and eighteen hours
/// local, which is what the panchang does.
({double rise, double set}) _sunTimes(
  DateTime date,
  Duration utcOffset,
  GeoPlace place,
) {
  final double midnight = Instant.fromLocal(
    DateTime(date.year, date.month, date.day),
    utcOffset,
  ).julianDayUt;
  final RiseSet sun = fastSunRiseSet(midnight, place);
  return (rise: sun.rise ?? midnight + 0.25, set: sun.set ?? midnight + 0.75);
}

/// Computes the eleven upagrahas for a chart.
///
/// Two conventions worth knowing, because other software differs:
///
///  * The eight parts. The first seven parts go to the seven grahas in weekday
///    order from the weekday lord, and the eighth part is lordless (BPHS 3.67,
///    "the eighth part has no lord"). This reproduces the traditional
///    Yamaganda kaal (Jupiter's part: the 5th part on Sunday, then 4, 3, 2, 1,
///    7, 6) and the Gulika kaal the panchang shows. PyJHora instead lets the
///    lordless slot follow Saturn in an eight-place cycle, which moves Kaala,
///    Mrityu, Ardha Prahara and Yama Ghantaka one part later on the weekdays
///    where they come after Saturn; Gulika and Mandi are the same either way.
///  * Sunrise and sunset. They are taken as the upper limb of the Sun on the
///    horizon with refraction (-0°50′), as the panchang does. Software that
///    uses the centre of the disc puts them about four minutes later at Delhi
///    in August, which moves an upagraha by up to about 0.7°.
///
/// Given the part times, the ascendants agree with the Swiss Ephemeris to
/// under 0.01° at Delhi, London, Sydney and New York.
///
/// The birth is placed in its Hindu day, which begins at sunrise: a birth
/// before that morning's sunrise belongs to the previous day and its night. If
/// the birth falls between sunrise and sunset the day is divided into eight
/// equal parts, counted from the lord of the weekday, the eighth part having no
/// lord (BPHS 3.66-67). Otherwise the night, from sunset to the next sunrise,
/// is divided into eight and counted from the fifth lord from the weekday lord
/// (BPHS 3.67).
UpagrahaResult computeUpagrahas(
  Kundli kundli, {
  UpagrahaConvention convention = const UpagrahaConvention(),
}) {
  final BirthData birth = kundli.birth;
  final DateTime localDate = DateTime(
    birth.localDateTime.year,
    birth.localDateTime.month,
    birth.localDateTime.day,
  );
  final double birthJd = kundli.instant.julianDayUt;

  final ({double rise, double set}) today = _sunTimes(
    localDate,
    birth.utcOffset,
    birth.place,
  );

  late final DateTime hinduDate;
  late final double sunrise;
  late final double sunset;
  late final double nextSunrise;
  if (birthJd < today.rise) {
    hinduDate = localDate.subtract(const Duration(days: 1));
    final ({double rise, double set}) yesterday = _sunTimes(
      hinduDate,
      birth.utcOffset,
      birth.place,
    );
    sunrise = yesterday.rise;
    sunset = yesterday.set;
    nextSunrise = today.rise;
  } else {
    hinduDate = localDate;
    sunrise = today.rise;
    sunset = today.set;
    final ({double rise, double set}) tomorrow = _sunTimes(
      localDate.add(const Duration(days: 1)),
      birth.utcOffset,
      birth.place,
    );
    nextSunrise = tomorrow.rise;
  }
  final bool isDay = birthJd >= sunrise && birthJd < sunset;

  // Dart numbers Monday 1 to Sunday 7; the engine counts Sunday as 0.
  final int weekday =
      DateTime(hinduDate.year, hinduDate.month, hinduDate.day).weekday % 7;

  final double partStart = isDay ? sunrise : sunset;
  final double partLength =
      (isDay ? sunset - sunrise : nextSunrise - sunset) / 8.0;
  // Day parts run from the weekday lord; night parts from the fifth lord.
  final int firstLord = isDay ? weekday : (weekday + 4) % 7;

  double ascendantAt(double jd) {
    final Angles a = computeAngles(
      Instant.fromJulianDayUt(jd),
      birth.place.latitude,
      birth.place.longitude,
    );
    return norm360(a.ascendant - kundli.ayanamsaValue);
  }

  final List<PlacedUpagraha> placed = <PlacedUpagraha>[];

  final Map<Upagraha, double> solar = solarUpagrahaLongitudes(
    kundli.grahas[Graha.sun]!.siderealLongitude,
  );
  for (final MapEntry<Upagraha, double> e in solar.entries) {
    placed.add(
      PlacedUpagraha(
        upagraha: e.key,
        siderealLongitude: e.value,
        house: wholeSignHouse(e.value, kundli.ascendant),
      ),
    );
  }

  for (final MapEntry<Upagraha, int> e in _partLordIndex.entries) {
    // The part whose lord is the target: counting from the first lord.
    final int k = (e.value - firstLord + 7) % 7;
    final UpagrahaPoint point = switch (e.key) {
      Upagraha.gulika => convention.gulika,
      Upagraha.mandi => convention.mandi,
      _ => convention.others,
    };
    final double within = switch (point) {
      UpagrahaPoint.begin => 0.0,
      UpagrahaPoint.middle => 0.5,
      UpagrahaPoint.end => 1.0,
    };
    final double jd = partStart + (k + within) * partLength;
    final double longitude = ascendantAt(jd);
    placed.add(
      PlacedUpagraha(
        upagraha: e.key,
        siderealLongitude: longitude,
        house: wholeSignHouse(longitude, kundli.ascendant),
        partNumber: k + 1,
        partLord: _weekdayOrder[e.value],
      ),
    );
  }

  // Keep the order the table gives.
  placed.sort(
    (PlacedUpagraha a, PlacedUpagraha b) =>
        a.upagraha.index.compareTo(b.upagraha.index),
  );
  return UpagrahaResult(
    placed: placed,
    isDayBirth: isDay,
    weekday: weekday,
    sunriseJdUt: sunrise,
    sunsetJdUt: sunset,
    nextSunriseJdUt: nextSunrise,
  );
}
