import 'dart:math' as math;

import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/houses.dart';
import '../astro/rise_set.dart';
import '../astro/time.dart';
import 'nakshatra.dart';

const List<String> tithiNames = <String>[
  'Pratipada',
  'Dwitiya',
  'Tritiya',
  'Chaturthi',
  'Panchami',
  'Shashthi',
  'Saptami',
  'Ashtami',
  'Navami',
  'Dashami',
  'Ekadashi',
  'Dwadashi',
  'Trayodashi',
  'Chaturdashi',
  'Purnima',
];

const List<String> tithiNamesHindi = <String>[
  'प्रतिपदा',
  'द्वितीया',
  'तृतीया',
  'चतुर्थी',
  'पंचमी',
  'षष्ठी',
  'सप्तमी',
  'अष्टमी',
  'नवमी',
  'दशमी',
  'एकादशी',
  'द्वादशी',
  'त्रयोदशी',
  'चतुर्दशी',
  'पूर्णिमा',
];

const List<String> yogaNames = <String>[
  'Vishkambha',
  'Priti',
  'Ayushman',
  'Saubhagya',
  'Shobhana',
  'Atiganda',
  'Sukarma',
  'Dhriti',
  'Shula',
  'Ganda',
  'Vriddhi',
  'Dhruva',
  'Vyaghata',
  'Harshana',
  'Vajra',
  'Siddhi',
  'Vyatipata',
  'Variyana',
  'Parigha',
  'Shiva',
  'Siddha',
  'Sadhya',
  'Shubha',
  'Shukla',
  'Brahma',
  'Indra',
  'Vaidhriti',
];

const List<String> movableKaranas = <String>[
  'Bava',
  'Balava',
  'Kaulava',
  'Taitila',
  'Garaja',
  'Vanija',
  'Vishti',
];

/// The 27 nitya yogas as a Hindi panchang prints them.
const List<String> yogaNamesHindi = <String>[
  'विष्कुम्भ',
  'प्रीति',
  'आयुष्मान',
  'सौभाग्य',
  'शोभन',
  'अतिगण्ड',
  'सुकर्मा',
  'धृति',
  'शूल',
  'गण्ड',
  'वृद्धि',
  'ध्रुव',
  'व्याघात',
  'हर्षण',
  'वज्र',
  'सिद्धि',
  'व्यतीपात',
  'वरीयान',
  'परिघ',
  'शिव',
  'सिद्ध',
  'साध्य',
  'शुभ',
  'शुक्ल',
  'ब्रह्म',
  'इन्द्र',
  'वैधृति',
];

/// The seven movable karanas in Hindi; Vishti is the Bhadra of the texts.
const List<String> movableKaranasHindi = <String>[
  'बव',
  'बालव',
  'कौलव',
  'तैतिल',
  'गर',
  'वणिज',
  'विष्टि (भद्रा)',
];

/// "Shukla" or "Krishna" in Hindi.
String pakshaNameHindi(String paksha) => paksha == 'Shukla' ? 'शुक्ल' : 'कृष्ण';

const List<String> weekdayNames = <String>[
  'Ravivara',
  'Somavara',
  'Mangalavara',
  'Budhavara',
  'Guruvara',
  'Shukravara',
  'Shanivara',
];

const List<String> weekdayNamesHindi = <String>[
  'रविवार',
  'सोमवार',
  'मंगलवार',
  'बुधवार',
  'गुरुवार',
  'शुक्रवार',
  'शनिवार',
];

const List<Graha> weekdayLords = <Graha>[
  Graha.sun,
  Graha.moon,
  Graha.mars,
  Graha.mercury,
  Graha.jupiter,
  Graha.venus,
  Graha.saturn,
];

const List<String> choghadiyaCycle = <String>[
  'Udveg',
  'Char',
  'Labh',
  'Amrit',
  'Kaal',
  'Shubh',
  'Rog',
];

const List<String> choghadiyaCycleHindi = <String>[
  'उद्वेग',
  'चर',
  'लाभ',
  'अमृत',
  'काल',
  'शुभ',
  'रोग',
];

const List<String> choghadiyaMeaning = <String>[
  'Unsettled; avoid new beginnings, fit only for dealing with officials.',
  'Moving; good for travel, trade and anything that must keep going.',
  'Gain; favourable for business, study and money matters.',
  'Nectar; the best slot, good for any auspicious work.',
  'Death-like; avoid starting anything.',
  'Auspicious; good for ceremonies and new work.',
  'Illness; avoid starting work.',
];

const List<String> choghadiyaMeaningHindi = <String>[
  'अस्थिर; नया आरंभ वर्जित, केवल अधिकारियों से कार्य के लिए ठीक।',
  'चलायमान; यात्रा, व्यापार और चलते रहने वाले कार्यों के लिए अच्छा।',
  'लाभ; व्यापार, विद्या और धन-संबंधी कार्यों के लिए शुभ।',
  'अमृत; सबसे उत्तम, सभी शुभ कार्यों के लिए।',
  'काल; कोई कार्य आरंभ न करें।',
  'शुभ; मांगलिक और नए कार्यों के लिए अच्छा।',
  'रोग; कार्य आरंभ न करें।',
];

/// Hora lords in Chaldean order, slowest first, with what each hora favours.
const List<String> horaNamesHindi = <String>[
  'शनि होरा',
  'गुरु होरा',
  'मंगल होरा',
  'सूर्य होरा',
  'शुक्र होरा',
  'बुध होरा',
  'चन्द्र होरा',
];

const List<String> horaMeaning = <String>[
  'Labour, iron, oil and long-term work; avoid fresh beginnings.',
  'Learning, teaching, prayer, finance and ceremonies; the most auspicious hora.',
  'Courage, land, machinery and contests; not for peace-making.',
  'Authority, government work, health and one\'s father.',
  'Arts, romance, vehicles, comforts and marriage matters.',
  'Trade, study, writing and communication.',
  'The mind, public dealings, travel and home; gentle and fruitful.',
];

const List<String> horaMeaningHindi = <String>[
  'श्रम, लोहा, तेल और दीर्घकालिक कार्य; नया आरंभ वर्जित।',
  'विद्या, उपदेश, पूजा, धन और मांगलिक कार्य; सबसे शुभ होरा।',
  'साहस, भूमि, मशीनरी और प्रतियोगिता; सुलह के लिए नहीं।',
  'सत्ता, सरकारी कार्य, स्वास्थ्य और पिता से जुड़े कार्य।',
  'कला, प्रेम, वाहन, सुख-साधन और विवाह-संबंधी कार्य।',
  'व्यापार, पढ़ाई, लेखन और संवाद।',
  'मन, जनसंपर्क, यात्रा और घर के कार्य; सौम्य और फलदायी।',
];

/// Index into [choghadiyaCycle] that each weekday's day period starts with.
const List<int> dayChoghadiyaStart = <int>[0, 3, 6, 2, 5, 1, 4];

/// Index into [choghadiyaCycle] that each weekday's night period starts with.
const List<int> nightChoghadiyaStart = <int>[5, 1, 4, 0, 3, 6, 2];

/// Part of the day, 1..8, that each inauspicious period falls in, by weekday.
const List<int> rahuKaalPart = <int>[8, 2, 7, 5, 6, 4, 3];
const List<int> yamagandaPart = <int>[5, 4, 3, 2, 1, 7, 6];
const List<int> gulikaPart = <int>[7, 6, 5, 4, 3, 2, 1];

/// An element of the panchang that runs out at a known moment.
class PanchangElement {
  const PanchangElement({
    required this.index,
    required this.name,
    required this.nameHindi,
    required this.endsAtJdUt,
  });

  final int index;
  final String name;
  final String nameHindi;
  final double endsAtJdUt;
}

class TimeSpan {
  const TimeSpan(
    this.name,
    this.startJdUt,
    this.endJdUt, {
    this.nameHindi = '',
    this.meaning = '',
    this.meaningHindi = '',
  });

  /// For horas this is the lord's enum name (`sun`, `moon`, ...), kept as it
  /// always was; use [title] and [titleHindi] for display.
  final String name;
  final String nameHindi;
  final double startJdUt;
  final double endJdUt;

  /// One line on what the span is good or bad for, in both languages.
  final String meaning;
  final String meaningHindi;

  String get title =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

  String get titleHindi => nameHindi.isEmpty ? title : nameHindi;
}

class Panchang {
  const Panchang({
    required this.date,
    required this.place,
    required this.sunrise,
    required this.sunset,
    required this.moonrise,
    required this.moonset,
    required this.weekday,
    required this.tithi,
    required this.paksha,
    required this.nakshatra,
    required this.yoga,
    required this.karana,
    required this.rahuKaal,
    required this.yamaganda,
    required this.gulika,
    required this.abhijit,
    required this.dayChoghadiya,
    required this.nightChoghadiya,
    required this.horas,
    required this.ayanamsaDegrees,
    required this.ayanamsa,
    required this.utcOffset,
    required this.dayStartJdUt,
  });

  final DateTime date;
  final GeoPlace place;

  /// The zodiac this panchang was cast in, and the clock it was asked for;
  /// the detailed layer (panchang_details.dart) needs both to carry on.
  final Ayanamsa ayanamsa;
  final Duration utcOffset;

  /// The sunrise the panchang day starts at. Equal to [sunrise] except in the
  /// polar circles, where there may be none and a stand-in is used.
  final double dayStartJdUt;
  final double? sunrise;
  final double? sunset;
  final double? moonrise;
  final double? moonset;

  /// 0 = Sunday.
  final int weekday;
  final PanchangElement tithi;
  final String paksha;
  final PanchangElement nakshatra;
  final PanchangElement yoga;
  final PanchangElement karana;
  final TimeSpan? rahuKaal;
  final TimeSpan? yamaganda;
  final TimeSpan? gulika;
  final TimeSpan? abhijit;
  final List<TimeSpan> dayChoghadiya;
  final List<TimeSpan> nightChoghadiya;
  final List<TimeSpan> horas;
  final double ayanamsaDegrees;

  Graha get dayLord => weekdayLords[weekday];
}

/// Apparent tropical longitude of [graha] in the true ecliptic of date.
///
/// This reads [apparentOfDate], the series the JPL fixtures and the equinox
/// test pin down, rather than [positionOf]. The two now agree. They did not
/// while this was written: [positionOf] used to precess and nutate that result
/// a second time, parking every longitude east of the truth by the precession
/// since J2000 (0.376 degrees in October 2026), which put a nakshatra boundary
/// forty minutes early and a yoga boundary seventy-six while tithi and karana,
/// being differences, never noticed. The panchang times were checked against
/// Drik Panchang and an independent skyfield run on DE440s, and the test
/// suite pins the equinox. [apparentOfDate] is also the cheaper call: a
/// boundary search probes it dozens of times, and [positionOf] spends two more
/// evaluations on a speed this code never reads.
double longitudeOfDate(Graha graha, Instant instant) =>
    apparentOfDate(graha, instant.centuriesTt)[0];

/// Moon minus Sun, 0..360: the angle the tithis and karanas are cut from.
double lunarElongationAt(Instant instant) => norm360(
  longitudeOfDate(Graha.moon, instant) - longitudeOfDate(Graha.sun, instant),
);

/// Sidereal longitude of [graha] in the chosen zodiac.
double siderealLongitudeAt(Graha graha, Instant instant, Ayanamsa ayanamsa) =>
    toSidereal(longitudeOfDate(graha, instant), ayanamsa, instant.centuriesTt);

double _elongation(Instant instant) => lunarElongationAt(instant);

double _sumLongitude(Instant instant, Ayanamsa ayanamsa) => norm360(
  siderealLongitudeAt(Graha.sun, instant, ayanamsa) +
      siderealLongitudeAt(Graha.moon, instant, ayanamsa),
);

double _moonSidereal(Instant instant, Ayanamsa ayanamsa) =>
    siderealLongitudeAt(Graha.moon, instant, ayanamsa);

/// Bounds on how fast the quantities the panchang watches can move, in degrees
/// per day, so a crossing can be bracketed without scanning for it. Each pair
/// brackets the real extremes with a little room.
const double moonRateMin = 11.0;
const double moonRateMax = 15.7;
const double elongationRateMin = 10.0;
const double elongationRateMax = 14.7;
const double sunRateMin = 0.94;
const double sunRateMax = 1.03;

/// The first moment at or after [fromJd] when [value], an angle that only ever
/// grows (the Moon's longitude, the elongation, the Sun's longitude), reaches
/// [target] degrees. [minRate] and [maxRate] bound its speed in degrees a day.
double crossingAfter(
  double Function(Instant) value,
  double target,
  double fromJd, {
  required double minRate,
  required double maxRate,
}) {
  final double v0 = value(Instant.fromJulianDayUt(fromJd));
  final double ahead = norm360(target - v0);
  double low = math.max(fromJd, fromJd + ahead / maxRate - 0.03);
  double high = fromJd + ahead / minRate + 0.03;
  for (int i = 0; i < 60 && high - low > 1e-6; i++) {
    final double mid = (low + high) / 2;
    final double progress = norm360(value(Instant.fromJulianDayUt(mid)) - v0);
    if (progress >= ahead) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return (low + high) / 2;
}

/// The last moment at or before [fromJd] when [value] stood at [target]: the
/// moment the segment [fromJd] sits in began.
double crossingBefore(
  double Function(Instant) value,
  double target,
  double fromJd, {
  required double minRate,
  required double maxRate,
}) {
  final double v0 = value(Instant.fromJulianDayUt(fromJd));
  final double behind = norm360(v0 - target);
  double low = fromJd - behind / minRate - 0.03;
  double high = math.min(fromJd, fromJd - behind / maxRate + 0.03);
  for (int i = 0; i < 60 && high - low > 1e-6; i++) {
    final double mid = (low + high) / 2;
    final double progress = norm360(v0 - value(Instant.fromJulianDayUt(mid)));
    if (progress > behind) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return (low + high) / 2;
}

/// Finds when a quantity that advances by [span] degrees next completes, by
/// bisection on the fractional part.
double _endOfSegment(
  double Function(Instant) value,
  double startJd,
  double span, {
  double searchDays = 2.0,
}) {
  final double startValue = value(Instant.fromJulianDayUt(startJd));
  final double target = ((startValue / span).floor() + 1) * span;
  double low = startJd;
  double high = startJd + searchDays;
  for (int i = 0; i < 48; i++) {
    final double mid = (low + high) / 2;
    final double here = value(Instant.fromJulianDayUt(mid));
    final double advanced = norm360(here - startValue);
    if (advanced + startValue >= target && advanced < 180) {
      high = mid;
    } else {
      low = mid;
    }
    if (high - low < 1e-6) break;
  }
  return (low + high) / 2;
}

/// Builds the panchang for the local day containing [localNoon].
Panchang computePanchang({
  required DateTime localDate,
  required Duration utcOffset,
  required GeoPlace place,
  Ayanamsa ayanamsa = Ayanamsa.lahiri,
}) {
  final Instant midnight = Instant.fromLocal(
    DateTime(localDate.year, localDate.month, localDate.day),
    utcOffset,
  );
  final RiseSet sun = findRiseSet(
    Graha.sun,
    midnight.julianDayUt,
    place,
    horizon: sunHorizon,
  );
  final RiseSet moon = findRiseSet(
    Graha.moon,
    midnight.julianDayUt,
    place,
    horizon: moonHorizon,
  );
  final double sunriseJd = sun.rise ?? midnight.julianDayUt + 0.25;
  final double sunsetJd = sun.set ?? midnight.julianDayUt + 0.75;
  final Instant atSunrise = Instant.fromJulianDayUt(sunriseJd);

  // The vara is the weekday of the civil date the sunrise belongs to. Reading
  // it off the sunrise's UT Julian day instead slips a day wherever local
  // sunrise falls on the previous UT date (Singapore, Australia, New Zealand).
  final int weekday =
      DateTime(localDate.year, localDate.month, localDate.day).weekday % 7;

  final double elongation = _elongation(atSunrise);
  final int tithiIndex = (elongation / 12.0).floor();
  final double tithiEnd = _endOfSegment(_elongation, sunriseJd, 12.0);
  final double moonLongitude = _moonSidereal(atSunrise, ayanamsa);
  final int nakshatraIndex = nakshatraIndexOf(moonLongitude);
  final double nakshatraEnd = _endOfSegment(
    (Instant i) => _moonSidereal(i, ayanamsa),
    sunriseJd,
    nakshatraSpan,
  );
  final double sum = _sumLongitude(atSunrise, ayanamsa);
  final int yogaIndex = (sum / nakshatraSpan).floor() % 27;
  final double yogaEnd = _endOfSegment(
    (Instant i) => _sumLongitude(i, ayanamsa),
    sunriseJd,
    nakshatraSpan,
  );
  final int karanaIndex = (elongation / 6.0).floor();
  final double karanaEnd = _endOfSegment(_elongation, sunriseJd, 6.0);

  final double dayLength = sunsetJd - sunriseJd;
  final double part = dayLength / 8.0;
  TimeSpan partSpan(String name, int index) =>
      TimeSpan(name, sunriseJd + (index - 1) * part, sunriseJd + index * part);

  final double midday = (sunriseJd + sunsetJd) / 2;
  final double muhurta = dayLength / 15.0;

  TimeSpan choghadiyaSpan(int cycleIndex, double start, double end) => TimeSpan(
    choghadiyaCycle[cycleIndex],
    start,
    end,
    nameHindi: choghadiyaCycleHindi[cycleIndex],
    meaning: choghadiyaMeaning[cycleIndex],
    meaningHindi: choghadiyaMeaningHindi[cycleIndex],
  );

  final List<TimeSpan> dayChoghadiya = <TimeSpan>[
    for (int i = 0; i < 8; i++)
      choghadiyaSpan(
        (dayChoghadiyaStart[weekday] + i) % 7,
        sunriseJd + i * part,
        sunriseJd + (i + 1) * part,
      ),
  ];
  // The night runs to the next sunrise, which is not exactly a day on.
  final double nextSunrise =
      fastSunRiseSet(midnight.julianDayUt + 1.0, place).rise ?? sunriseJd + 1.0;
  final double nightPart = (nextSunrise - sunsetJd) / 8.0;
  final List<TimeSpan> nightChoghadiya = <TimeSpan>[
    for (int i = 0; i < 8; i++)
      choghadiyaSpan(
        (nightChoghadiyaStart[weekday] + i) % 7,
        sunsetJd + i * nightPart,
        sunsetJd + (i + 1) * nightPart,
      ),
  ];

  final List<TimeSpan> horas = <TimeSpan>[];
  const List<Graha> chaldean = <Graha>[
    Graha.saturn,
    Graha.jupiter,
    Graha.mars,
    Graha.sun,
    Graha.venus,
    Graha.mercury,
    Graha.moon,
  ];
  final int firstHora = chaldean.indexOf(weekdayLords[weekday]);
  for (int i = 0; i < 24; i++) {
    final double length = i < 12
        ? dayLength / 12
        : (nextSunrise - sunsetJd) / 12;
    final double start = i < 12
        ? sunriseJd + i * length
        : sunsetJd + (i - 12) * length;
    final int slot = (firstHora + i) % 7;
    horas.add(
      TimeSpan(
        chaldean[slot].name,
        start,
        start + length,
        nameHindi: horaNamesHindi[slot],
        meaning: horaMeaning[slot],
        meaningHindi: horaMeaningHindi[slot],
      ),
    );
  }

  return Panchang(
    date: localDate,
    place: place,
    sunrise: sun.rise,
    sunset: sun.set,
    moonrise: moon.rise,
    moonset: moon.set,
    weekday: weekday,
    tithi: PanchangElement(
      index: tithiIndex,
      name: tithiIndex == 29 ? 'Amavasya' : tithiNames[tithiIndex % 15],
      nameHindi: tithiIndex == 29
          ? 'अमावस्या'
          : tithiNamesHindi[tithiIndex % 15],
      endsAtJdUt: tithiEnd,
    ),
    paksha: tithiIndex < 15 ? 'Shukla' : 'Krishna',
    nakshatra: PanchangElement(
      index: nakshatraIndex,
      name: nakshatraTable[nakshatraIndex].english,
      nameHindi: nakshatraTable[nakshatraIndex].hindi,
      endsAtJdUt: nakshatraEnd,
    ),
    yoga: PanchangElement(
      index: yogaIndex,
      name: yogaNames[yogaIndex],
      nameHindi: yogaNamesHindi[yogaIndex],
      endsAtJdUt: yogaEnd,
    ),
    karana: PanchangElement(
      index: karanaIndex,
      name: _karanaName(karanaIndex),
      nameHindi: _karanaNameHindi(karanaIndex),
      endsAtJdUt: karanaEnd,
    ),
    rahuKaal: partSpan('Rahu Kaal', rahuKaalPart[weekday]),
    yamaganda: partSpan('Yamaganda', yamagandaPart[weekday]),
    gulika: partSpan('Gulika', gulikaPart[weekday]),
    abhijit: TimeSpan('Abhijit', midday - muhurta / 2, midday + muhurta / 2),
    dayChoghadiya: dayChoghadiya,
    nightChoghadiya: nightChoghadiya,
    horas: horas,
    ayanamsaDegrees: ayanamsaDegrees(ayanamsa, atSunrise.centuriesTt),
    ayanamsa: ayanamsa,
    utcOffset: utcOffset,
    dayStartJdUt: sunriseJd,
  );
}

String _karanaName(int index) {
  if (index == 0) return 'Kimstughna';
  if (index >= 57) {
    return <String>['Shakuni', 'Chatushpada', 'Naga'][index - 57];
  }
  return movableKaranas[(index - 1) % 7];
}

String _karanaNameHindi(int index) {
  if (index == 0) return 'किंस्तुघ्न';
  if (index >= 57) {
    return <String>['शकुनि', 'चतुष्पद', 'नाग'][index - 57];
  }
  return movableKaranasHindi[(index - 1) % 7];
}

/// Whether karana [index], 0..59 from the new moon, is Vishti, the Bhadra of
/// the texts: the seventh of each run of seven movable karanas.
bool isVishtiKarana(int index) =>
    index >= 1 && index <= 56 && (index - 1) % 7 == 6;
