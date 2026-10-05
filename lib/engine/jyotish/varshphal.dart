import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'rashi.dart';
import 'shadbala.dart';

/// Varshphal, the annual chart: the kundli of the moment the Sun returns to
/// the exact sidereal longitude it held at birth.
class Varshphal {
  const Varshphal({
    required this.year,
    required this.returnMoment,
    required this.chart,
    required this.munthaSign,
    required this.munthaHouse,
    required this.yearLord,
    required this.candidates,
  });

  /// The age the person completes in this year.
  final int year;
  final DateTime returnMoment;
  final Kundli chart;

  /// Muntha, the progressed point: it moves one whole sign a year.
  final int munthaSign;
  final int munthaHouse;

  /// Varshesha, the lord of the year.
  final Graha yearLord;

  /// The five contenders and the strength each carried, so the choice is shown.
  final Map<Graha, double> candidates;
}

/// Finds the solar return for the birthday [age] years after birth.
DateTime solarReturnMoment(Kundli natal, int age) {
  final double natalSun = natal.grahas[Graha.sun]!.siderealLongitude;
  final DateTime birth = natal.birth.localDateTime;
  final DateTime guess = DateTime(
    birth.year + age,
    birth.month,
    birth.day,
    birth.hour,
    birth.minute,
  );
  final Instant guessInstant = Instant.fromLocal(guess, natal.birth.utcOffset);
  double low = guessInstant.julianDayUt - 3;
  double high = guessInstant.julianDayUt + 3;

  double difference(double jd) {
    final Instant instant = Instant.fromJulianDayUt(jd);
    final double sun = toSidereal(
      positionOf(Graha.sun, instant).tropicalLongitude,
      natal.ayanamsa,
      instant.centuriesTt,
    );
    return norm180(sun - natalSun);
  }

  double lowValue = difference(low);
  for (int i = 0; i < 60; i++) {
    final double mid = (low + high) / 2;
    final double value = difference(mid);
    if (lowValue.sign == value.sign) {
      low = mid;
      lowValue = value;
    } else {
      high = mid;
    }
    if (high - low < 1e-6) break;
  }
  return utcFromJulianDay((low + high) / 2);
}

Varshphal computeVarshphal(Kundli natal, int age, {Ayanamsa? ayanamsa}) {
  final DateTime moment = solarReturnMoment(natal, age);
  final DateTime local = moment.add(natal.birth.utcOffset);
  final Kundli annual = computeKundli(
    BirthData(
      name: natal.birth.name,
      localDateTime: DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
      ),
      utcOffset: natal.birth.utcOffset,
      place: natal.birth.place,
    ),
    ayanamsa: ayanamsa ?? natal.ayanamsa,
  );

  final int munthaSign = (natal.lagnaRashi.index + age) % 12;
  final int munthaHouse =
      ((munthaSign - annual.lagnaRashi.index + 12) % 12) + 1;

  // Varshesha: the texts put up five contenders and give the year to the
  // strongest. We rank them by shadbala in the annual chart and say so.
  final Map<Graha, BalaBreakdown> bala = computeShadbala(annual);
  final Set<Graha> contenders = <Graha>{
    rashiInfo(Rashi.values[munthaSign]).lord,
    rashiInfo(annual.lagnaRashi).lord,
    rashiInfo(annual.moonRashi).lord,
    weekdayLordOf(annual.instant.julianDayUt),
    rashiInfo(Rashi.values[(annual.lagnaRashi.index + 8) % 12]).lord,
  };
  final Map<Graha, double> scores = <Graha, double>{
    for (final Graha graha in contenders)
      if (bala.containsKey(graha)) graha: bala[graha]!.totalRupas,
  };
  final Graha yearLord = scores.isEmpty
      ? Graha.sun
      : scores.entries
            .reduce(
              (MapEntry<Graha, double> a, MapEntry<Graha, double> b) =>
                  a.value >= b.value ? a : b,
            )
            .key;

  return Varshphal(
    year: age,
    returnMoment: moment,
    chart: annual,
    munthaSign: munthaSign,
    munthaHouse: munthaHouse,
    yearLord: yearLord,
    candidates: scores,
  );
}

Graha weekdayLordOf(double jdUt) {
  const List<Graha> lords = <Graha>[
    Graha.sun,
    Graha.moon,
    Graha.mars,
    Graha.mercury,
    Graha.jupiter,
    Graha.venus,
    Graha.saturn,
  ];
  return lords[(jdUt + 1.5).floor() % 7];
}

/// What the muntha house is read for.
String munthaReading(int house, {required bool hindi}) {
  const List<String> english = <String>[
    'the body and the year’s own direction',
    'money kept and what is said',
    'courage, siblings and short journeys',
    'home, land and the mother',
    'children, learning and what is created',
    'competition, debt and health upkeep',
    'partnership and agreements',
    'things that change hands, and what is inherited',
    'fortune, teachers and long journeys',
    'work and standing',
    'gains and the people who bring them',
    'expense, retreat and what is released',
  ];
  const List<String> devanagari = <String>[
    'शरीर और वर्ष की दिशा',
    'धन और वाणी',
    'पराक्रम और भाई-बहन',
    'घर, भूमि और माता',
    'संतान और विद्या',
    'प्रतिस्पर्धा और ऋण',
    'साझेदारी और अनुबंध',
    'परिवर्तन और उत्तराधिकार',
    'भाग्य, गुरु और लंबी यात्रा',
    'कर्म और प्रतिष्ठा',
    'लाभ और मित्र',
    'व्यय और एकांत',
  ];
  final String area = hindi ? devanagari[house - 1] : english[house - 1];
  return hindi
      ? 'मुन्था $houseवें भाव में है, इसलिए वर्ष का ज़ोर $area पर रहता है।'
      : 'Muntha stands in house $house, so the year leans on $area.';
}

String yearLordReading(Graha lord, {required bool hindi}) {
  final GrahaInfo info = grahaInfo(lord);
  return hindi
      ? 'वर्ष का स्वामी ${info.hindi} है। वर्षफल में इसी ग्रह के कारकत्व प्रमुख रहते हैं।'
      : 'The lord of the year is ${info.english}, so what that graha signifies — ${info.karaka.toLowerCase()} — runs through the twelve months.';
}
