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
  });

  final String name;
  final String nameHindi;
  final double startJdUt;
  final double endJdUt;
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
  });

  final DateTime date;
  final GeoPlace place;
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

double _elongation(Instant instant) {
  final double sun = positionOf(Graha.sun, instant).tropicalLongitude;
  final double moon = positionOf(Graha.moon, instant).tropicalLongitude;
  return norm360(moon - sun);
}

double _sumLongitude(Instant instant, Ayanamsa ayanamsa) {
  final double t = instant.centuriesTt;
  final double sun = toSidereal(
    positionOf(Graha.sun, instant).tropicalLongitude,
    ayanamsa,
    t,
  );
  final double moon = toSidereal(
    positionOf(Graha.moon, instant).tropicalLongitude,
    ayanamsa,
    t,
  );
  return norm360(sun + moon);
}

double _moonSidereal(Instant instant, Ayanamsa ayanamsa) => toSidereal(
  positionOf(Graha.moon, instant).tropicalLongitude,
  ayanamsa,
  instant.centuriesTt,
);

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

  final int weekday = ((sunriseJd + 1.5).floor()) % 7;

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

  final List<TimeSpan> dayChoghadiya = <TimeSpan>[
    for (int i = 0; i < 8; i++)
      TimeSpan(
        choghadiyaCycle[(dayChoghadiyaStart[weekday] + i) % 7],
        sunriseJd + i * part,
        sunriseJd + (i + 1) * part,
      ),
  ];
  final double nextSunrise = sunriseJd + 1.0;
  final double nightPart = (nextSunrise - sunsetJd) / 8.0;
  final List<TimeSpan> nightChoghadiya = <TimeSpan>[
    for (int i = 0; i < 8; i++)
      TimeSpan(
        choghadiyaCycle[(nightChoghadiyaStart[weekday] + i) % 7],
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
    horas.add(
      TimeSpan(chaldean[(firstHora + i) % 7].name, start, start + length),
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
      nameHindi: yogaNames[yogaIndex],
      endsAtJdUt: yogaEnd,
    ),
    karana: PanchangElement(
      index: karanaIndex,
      name: _karanaName(karanaIndex),
      nameHindi: _karanaName(karanaIndex),
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
  );
}

String _karanaName(int index) {
  if (index == 0) return 'Kimstughna';
  if (index >= 57) {
    return <String>['Shakuni', 'Chatushpada', 'Naga'][index - 57];
  }
  return movableKaranas[(index - 1) % 7];
}
