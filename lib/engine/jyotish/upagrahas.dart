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
import 'mat.dart';
import 'nakshatra.dart';
import 'rashi.dart';
import 'tajika_common.dart' show Bi, degText, houseBi, rashiBi;

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
    this.eighth = EighthPart.lordless,
  });

  final UpagrahaPoint gulika;
  final UpagrahaPoint mandi;
  final UpagrahaPoint others;

  /// What the eighth part of the day or night is: lordless, as the app reads
  /// BPHS 3.67, or a slot in an eight-place cycle after Saturn.
  final EighthPart eighth;
}

/// The two ways the eighth part is handled when the seven grahas are dealt
/// round the eight parts of the day or night.
///
///  * [lordless]: the first seven parts go to the seven grahas in weekday
///    order from the weekday lord, and the eighth belongs to no one. This is
///    how the app reads BPHS 3.67.
///  * [cycleOfEight]: the grahas sit in a cycle of eight places, the eighth
///    place empty and coming straight after Saturn, and the parts are dealt
///    round that cycle from the weekday lord. Where a graha's turn falls after
///    Saturn, its part is one later than in the other reading.
enum EighthPart { lordless, cycleOfEight }

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
    final int k = convention.eighth == EighthPart.cycleOfEight
        ? (e.value - firstLord + 8) % 8
        : (e.value - firstLord + 7) % 7;
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

// =============================================================================
// Where the books differ: मतभेद on the upagrahas.
//
// BPHS 3.66-3.70 (the Sanskrit read on enjoylearningsanskrit.com) names Saturn's
// part of the day as Gulika's and says the eighth part has no lord, and the
// night is counted from the fifth lord. It names a part and gives no point
// inside it, and it does not define Mandi. So two things are conventions:
// where in Saturn's part Mandi is taken, and what the eighth part is. Each is
// worked out here under every position that could be read.
// =============================================================================

Bi _upagrahaName(Upagraha u) {
  final UpagrahaInfo info = upagrahaInfo(u);
  return Bi(info.english, info.hindi);
}

Bi _placedText(Kundli chart, PlacedUpagraha p) {
  final int sign = p.rashi.index;
  final int part = p.partNumber ?? 0;
  return Bi(
    '${_upagrahaName(p.upagraha).en} ${degText(p.degreesInSign)} '
        '${rashiBi(sign).en}, ${houseBi(p.house).en} (part $part)',
    '${_upagrahaName(p.upagraha).hi} ${rashiBi(sign).hi} '
        '${degText(p.degreesInSign)}, ${houseBi(p.house).hi} (भाग $part)',
  );
}

/// The disagreements on the upagrahas, worked out for [kundli]: where in
/// Saturn's part Mandi is taken, and what the eighth part of the day or night
/// is.
List<Matbhed> upagrahaMatbhed(Kundli kundli) {
  PlacedUpagraha mandiAt(UpagrahaPoint point) => computeUpagrahas(
    kundli,
    convention: UpagrahaConvention(mandi: point),
  ).of(Upagraha.mandi);
  final PlacedUpagraha atEnd = mandiAt(UpagrahaPoint.end);
  final PlacedUpagraha atMiddle = mandiAt(UpagrahaPoint.middle);
  final PlacedUpagraha atBegin = mandiAt(UpagrahaPoint.begin);

  Mat mandiView({
    required PlacedUpagraha placed,
    required Bi position,
    required Bi holder,
    required Bi reasoning,
    bool isDefault = false,
  }) => Mat(
    position: position,
    holder: holder,
    reasoning: reasoning,
    result: _placedText(kundli, placed),
    isDefault: isDefault,
    value: placed.siderealLongitude,
  );

  final Matbhed mandi = Matbhed(
    key: 'upagraha_mandi',
    topic: const Bi(
      'Where Mandi is taken in Saturn’s part',
      'शनि के भाग में मांदि कहाँ ली जाए',
    ),
    whyTheyDiffer: const Bi(
      'Parashara names Saturn’s part of the day or night and gives no point '
          'inside it, and he does not define Mandi. The books and the software '
          'fill the gap in three different ways.',
      'पराशर दिन या रात में शनि का भाग बताते हैं पर उसके भीतर कोई बिंदु नहीं देते, '
          'और मांदि को परिभाषित नहीं करते। ग्रंथ और सॉफ़्टवेयर इस खाली जगह को तीन '
          'अलग तरह से भरते हैं।',
    ),
    defaultReason: const Bi(
      'The app has taken Mandi at the end of Saturn’s part from the start, '
          'as the nearest single rule to the Kerala tables, and keeps Gulika at '
          'the beginning so the two stay apart.',
      'ऐप शुरू से मांदि को शनि के भाग के अंत पर लेता आया है, केरल की तालिकाओं के '
          'सबसे निकट एक नियम की तरह, और गुलिक को आरंभ पर रखता है ताकि दोनों अलग रहें।',
    ),
    views: <Mat>[
      mandiView(
        isDefault: true,
        placed: atEnd,
        position: const Bi(
          'The ascendant at the end of Saturn’s part.',
          'शनि के भाग के अंत पर उदय होने वाला लग्न।',
        ),
        holder: const Bi(
          'The Kerala tradition: Mantreswara’s Phaladeepika (chapter 25) and '
              'the Prasna Marga as B. V. Raman translated it, which tabulate '
              'Mandi’s time after sunrise; G. K. Goel, in a forum thread, says '
              'some prefer the ending point',
          'केरल परंपरा: मंत्रेश्वर की फलदीपिका (अध्याय 25) और बी. वी. रमन द्वारा अनूदित '
              'प्रश्नमार्ग, जो सूर्योदय के बाद मांदि का समय तालिका में देते हैं; जी. के. '
              'गोयल, एक फ़ोरम-चर्चा में, कहते हैं कि कुछ लोग अंतिम बिंदु पसंद करते हैं',
        ),
        reasoning: const Bi(
          'The tables put Mandi late in Saturn’s part, from about half to nine '
              'tenths of the way through it on a thirty-ghatika day (our '
              'arithmetic on the table), so the end of the part is the nearest '
              'single rule.',
          'तालिकाएँ मांदि को शनि के भाग में देर से रखती हैं, तीस घटी के दिन पर '
              'आधे से नौ-दसवें हिस्से तक (तालिका पर हमारा हिसाब), इसलिए भाग का अंत '
              'ही सबसे निकट एक नियम है।',
        ),
      ),
      mandiView(
        placed: atMiddle,
        position: const Bi(
          'The ascendant at the middle of Saturn’s part.',
          'शनि के भाग के मध्य पर उदय होने वाला लग्न।',
        ),
        holder: const Bi(
          'Jagannatha Hora’s default (as two other pages report it), PyJHora’s '
              'code, and the school of Sanjay Rath, as P. V. R. Narasimha Rao '
              'describes it in a 2009 email reproduced on a forum (Gulika at the '
              'beginning, Mandi at the middle)',
          'जगन्नाथ होरा का डिफ़ॉल्ट (जैसा दो और पन्ने बताते हैं), PyJHora का कोड, और '
              'संजय रथ की परंपरा, जैसा पी. वी. आर. नरसिम्हा राव 2009 के एक ईमेल में बताते हैं '
              'जो एक फ़ोरम पर छपा है (गुलिक आरंभ पर, मांदि मध्य पर)',
        ),
        reasoning: const Bi(
          'It keeps Mandi apart from Gulika. The verses give no point inside '
              'the part, so this is a convention: the software defaults to it.',
          'यह मांदि को गुलिक से अलग रखता है। श्लोक भाग के भीतर कोई बिंदु नहीं देते, '
              'इसलिए यह एक परिपाटी है: सॉफ़्टवेयर इसे डिफ़ॉल्ट रखता है।',
        ),
      ),
      mandiView(
        placed: atBegin,
        position: const Bi(
          'The ascendant at the beginning of Saturn’s part: Mandi is Gulika.',
          'शनि के भाग के आरंभ पर उदय होने वाला लग्न: मांदि वही है जो गुलिक।',
        ),
        holder: const Bi(
          'P. V. R. Narasimha Rao, the author of Jagannatha Hora, in the same '
              '2009 email: he recommends every upagraha at the beginning of its '
              'part and calls Mandi “just another name for Gulika”',
          'पी. वी. आर. नरसिम्हा राव, जगन्नाथ होरा के लेखक, उसी 2009 के ईमेल में: '
              'वे हर उपग्रह को उसके भाग के आरंभ पर लेने की सलाह देते हैं और मांदि को '
              '“गुलिक का ही दूसरा नाम” कहते हैं',
        ),
        reasoning: const Bi(
          'Parashara defines Gulika and not Mandi, and he says the beginning-or-'
              'middle question is the one thing left open, so the simplest '
              'rule is the start of the part for all of them.',
          'पराशर गुलिक को परिभाषित करते हैं, मांदि को नहीं, और वे आरंभ या मध्य का '
              'प्रश्न खुला छोड़ देते हैं, इसलिए सबसे सरल नियम सबके लिए भाग का आरंभ है।',
        ),
      ),
    ],
  );

  // The lordless eighth part.
  final UpagrahaResult lordless = computeUpagrahas(kundli);
  final UpagrahaResult cycle = computeUpagrahas(
    kundli,
    convention: const UpagrahaConvention(eighth: EighthPart.cycleOfEight),
  );
  const List<Upagraha> shifted = <Upagraha>[
    Upagraha.kaala,
    Upagraha.mrityu,
    Upagraha.ardhaprahara,
    Upagraha.yamaghantaka,
  ];
  Bi four(UpagrahaResult r) {
    final List<Bi> parts = <Bi>[
      for (final Upagraha u in shifted) _placedText(kundli, r.of(u)),
    ];
    return Bi(
      parts.map((Bi b) => b.en).join('; '),
      parts.map((Bi b) => b.hi).join('; '),
    );
  }

  final int moved = shifted
      .where(
        (Upagraha u) =>
            (lordless.of(u).partNumber ?? 0) != (cycle.of(u).partNumber ?? 0),
      )
      .length;
  final Matbhed eighth = Matbhed(
    key: 'upagraha_eighth',
    topic: const Bi(
      'The eighth part of the day or night',
      'दिन या रात का आठवाँ भाग',
    ),
    whyTheyDiffer: Bi(
      moved == 0
          ? 'The two differ on most weekdays; on this birth’s weekday the '
                'turn of every graha comes before Saturn, so they agree.'
          : 'The two differ on this birth’s weekday: $moved of the four '
                'upagrahas fall in a different part.',
      moved == 0
          ? 'दोनों अधिकतर वारों में अलग पड़ते हैं; इस जन्म के वार पर हर ग्रह की '
                'बारी शनि से पहले आती है, इसलिए वे एक हैं।'
          : 'दोनों इस जन्म के वार पर अलग पड़ते हैं: चार में से $moved उपग्रह दूसरे '
                'भाग में आते हैं।',
    ),
    defaultReason: const Bi(
      'The app follows BPHS 3.67 as the Sanskrit reads: the eighth part has no '
          'lord. The software’s rotation is shown beside it; no text for that '
          'rotation was found.',
      'ऐप बृहत्पाराशर 3.67 का अनुसरण करता है, जैसा संस्कृत पढ़ती है: आठवें भाग का '
          'कोई स्वामी नहीं। सॉफ़्टवेयर का घुमाव उसके बगल में दिखाया है; उस घुमाव का '
          'कोई ग्रंथ नहीं मिला।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        value: 0,
        position: const Bi(
          'The first seven parts go to the seven grahas in weekday order from '
              'the weekday lord; the eighth part has no lord.',
          'पहले सात भाग सात ग्रहों को वार के क्रम से वारेश से मिलते हैं; आठवें भाग '
              'का कोई स्वामी नहीं।',
        ),
        holder: const Bi(
          'Brihat Parashara Hora Shastra 3.67 (the Sanskrit read on '
              'enjoylearningsanskrit.com: the eighth part is lordless; the night '
              'is counted from the fifth lord); Mantreswara’s Phaladeepika '
              'tables for Kala, Yamakantaka and Ardhaprahara fit it, by our check',
          'बृहत्पाराशर होरा शास्त्र 3.67 (enjoylearningsanskrit.com पर पढ़ी संस्कृत: '
              'आठवाँ भाग बिना स्वामी का; रात की गिनती पाँचवें स्वामी से); मंत्रेश्वर की '
              'फलदीपिका की काल, यमकंटक और अर्धप्रहर की तालिकाएँ हमारी जाँच में इससे '
              'मेल खाती हैं',
        ),
        reasoning: const Bi(
          'The verse says the eighth part has no lord, so the grahas fill '
              'the first seven parts only.',
          'श्लोक कहता है कि आठवें भाग का कोई स्वामी नहीं, इसलिए ग्रह केवल पहले सात '
              'भाग भरते हैं।',
        ),
        result: four(lordless),
      ),
      Mat(
        value: moved.toDouble(),
        position: const Bi(
          'The grahas sit in a cycle of eight places with the empty one straight '
              'after Saturn, and the parts are dealt round it from the weekday '
              'lord.',
          'ग्रह आठ स्थानों के चक्र में बैठते हैं जिसमें खाली स्थान शनि के ठीक बाद है, '
              'और भाग वारेश से उसी चक्र में बाँटे जाते हैं।',
        ),
        holder: const Bi(
          'PyJHora’s code (weekday tables in its const.py); the same tables '
              'were not found in any text, and Jagannatha Hora’s own pages speak '
              'of “the lordless 8th portion”',
          'PyJHora का कोड (इसके const.py की वार-तालिकाएँ); वही तालिकाएँ किसी ग्रंथ '
              'में नहीं मिलीं, और जगन्नाथ होरा के अपने पन्ने “बिना स्वामी के आठवें भाग” '
              'की बात करते हैं',
        ),
        reasoning: const Bi(
          'The empty place travels with the cycle, so where a graha’s turn '
              'falls after Saturn its part comes one place later; Gulika and '
              'Mandi, which are Saturn’s, do not move.',
          'खाली स्थान चक्र के साथ चलता है, इसलिए जहाँ किसी ग्रह की बारी शनि के बाद '
              'आती है वहाँ उसका भाग एक स्थान बाद पड़ता है; गुलिक और मांदि, जो शनि के '
              'हैं, नहीं हिलते।',
        ),
        result: four(cycle),
      ),
    ],
  );
  return <Matbhed>[mandi, eighth];
}
