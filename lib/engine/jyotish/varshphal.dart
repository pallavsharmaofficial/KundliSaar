import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/houses.dart';
import '../astro/rise_set.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'rashi.dart';
import 'saham.dart';
import 'tajika_aspects.dart';
import 'tajika_bala.dart';
import 'tajika_common.dart';
import 'varshphal_dasha.dart';
import 'varshphal_months.dart';

/// Varshphal, the annual chart, read the Tajika way.
///
/// It is the kundli of the moment the Sun returns to the exact sidereal
/// longitude it held at birth, and on top of that chart this engine builds
/// what a Tajika reader works with: Muntha; the five office-bearers
/// (panchadhikari) and the lord of the year chosen from them by five-fold
/// strength; the Tajika aspects and yogas (Ittasala, Ishrafa and the yogas that
/// hang on them); the sahams; the Mudda and Patyayini dashas; and a dated
/// reading of the year in windows.
///
/// Sources, and what was checked against what, are in docs/ENGINE.md.
class Varshphal {
  const Varshphal({
    required this.year,
    required this.returnMoment,
    required this.nextReturnMoment,
    required this.startJd,
    required this.endJd,
    required this.chart,
    required this.munthaSign,
    required this.munthaHouse,
    required this.munthaLord,
    required this.isDay,
    required this.bala,
    required this.varshesh,
    required this.tajika,
    required this.sahams,
    required this.mudda,
    required this.patyayini,
    required this.windows,
  });

  /// The age the person completes in this year.
  final int year;

  /// The pravesh: the moment the Sun returns, in UT.
  final DateTime returnMoment;

  /// The next pravesh, where this year ends.
  final DateTime nextReturnMoment;
  final double startJd;
  final double endJd;
  final Kundli chart;

  /// Muntha, the progressed point: it moves one whole sign a year.
  final int munthaSign;
  final int munthaHouse;
  final Graha munthaLord;

  /// Whether the pravesh fell by day (the Sun above the horizon). It decides
  /// the day or night form of every saham and the lords of the day-or-night
  /// and triplicity offices.
  final bool isDay;

  /// The five-fold strength of the seven grahas.
  final Map<Graha, PanchaVargiyaBala> bala;
  final VarsheshResult varshesh;
  final TajikaReport tajika;
  final List<Saham> sahams;
  final MuddaDasha mudda;
  final PatyayiniDasha patyayini;

  /// The year in dated windows, tiling it exactly.
  final List<YearWindow> windows;

  /// Varshesha, the lord of the year.
  Graha get yearLord => varshesh.lord;

  /// The five-fold strength of each office-bearer, in vishwa out of 20.
  Map<Graha, double> get candidates => <Graha, double>{
    for (final VarshaOfficer o in varshesh.officers) o.graha: o.vishwa,
  };

  double get yearDays => endJd - startJd;

  Saham saham(SahamId id) => sahams.firstWhere((Saham s) => s.id == id);
}

/// The five office-bearers, in the order Hayanaratna 5.8 lists them.
enum VarshaOffice { muntha, varshaLagna, trirashi, dinaRatri, janmaLagna }

Bi varshaOfficeBi(VarshaOffice office) => switch (office) {
  VarshaOffice.muntha => const Bi('Muntha lord', 'मुन्था पति'),
  VarshaOffice.varshaLagna => const Bi('Year Lagna lord', 'वर्ष लग्नेश'),
  VarshaOffice.trirashi => const Bi('Tri-rashi pati', 'त्रिराशिपति'),
  VarshaOffice.dinaRatri => const Bi('Dina-ratri pati', 'दिन-रात्रि पति'),
  VarshaOffice.janmaLagna => const Bi('Birth Lagna lord', 'जन्म लग्नेश'),
};

/// One of the five office-bearers (panchadhikari).
class VarshaOfficer {
  const VarshaOfficer({
    required this.office,
    required this.graha,
    required this.basis,
    required this.vishwa,
    required this.aspectToLagna,
  });

  final VarshaOffice office;
  final Graha graha;

  /// Why this graha holds the office, in words.
  final Bi basis;

  /// Its five-fold strength in vishwa, out of 20.
  final double vishwa;

  /// How its sign stands to the year Lagna, or null when it does not aspect
  /// it (the 2nd, 6th, 8th and 12th signs do not).
  final SignAspect? aspectToLagna;

  Bi get officeName => varshaOfficeBi(office);
  bool get aspectsLagna => aspectToLagna != null;
}

/// The choice of the lord of the year, with its working.
class VarsheshResult {
  const VarsheshResult({
    required this.lord,
    required this.officers,
    required this.eligible,
    required this.usedFallback,
    required this.rule,
    required this.reading,
    required this.factors,
  });

  final Graha lord;
  final List<VarshaOfficer> officers;

  /// The office-bearers that aspect the year Lagna, strongest first.
  final List<Graha> eligible;

  /// True when none aspected the Lagna and the Muntha lord was taken.
  final bool usedFallback;
  final Bi rule;
  final Bi reading;
  final List<Bi> factors;
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

/// Whether the Sun is above the horizon of [place] at [instant]: the day of a
/// day-and-night reading. It is the Sun's altitude against the standard
/// horizon depression, so it flips at exactly the sunrise and sunset the
/// panchang uses.
bool isDayAt(Instant instant, GeoPlace place) =>
    altitudeOf(Graha.sun, instant, place) > sunHorizon;

Varshphal computeVarshphal(Kundli natal, int age, {Ayanamsa? ayanamsa}) {
  final DateTime moment = solarReturnMoment(natal, age);
  final DateTime nextMoment = solarReturnMoment(natal, age + 1);
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
  final Graha munthaLord = rashiInfo(Rashi.values[munthaSign]).lord;

  final bool isDay = isDayAt(annual.instant, natal.birth.place);
  final Map<Graha, PanchaVargiyaBala> bala = computePanchaVargiyaBala(annual);
  final VarsheshResult varshesh = _chooseVarshesh(
    chart: annual,
    natal: natal,
    munthaSign: munthaSign,
    isDay: isDay,
    bala: bala,
  );

  final double startJd = julianDayFromUtc(moment);
  final double endJd = julianDayFromUtc(nextMoment);
  final YearGrid grid = YearGrid.build(annual, endJd);
  final TajikaReport tajika = computeTajika(annual, bala, grid, isDay: isDay);
  final List<Saham> sahams = computeSahams(
    annual,
    bala,
    isDay: isDay,
    grid: grid,
  );
  final MuddaDasha mudda = computeMudda(
    natal: natal,
    age: age,
    startJd: startJd,
    endJd: endJd,
  );
  final PatyayiniDasha patyayini = computePatyayini(
    annual,
    bala,
    startJd: startJd,
    endJd: endJd,
  );
  final List<YearWindow> windows = buildYearWindows(
    chart: annual,
    mudda: mudda,
    tajika: tajika,
    sahams: sahams,
    bala: bala,
    yearLord: varshesh.lord,
    munthaLord: munthaLord,
    munthaHouse: munthaHouse,
    utcOffset: natal.birth.utcOffset,
  );

  return Varshphal(
    year: age,
    returnMoment: moment,
    nextReturnMoment: nextMoment,
    startJd: startJd,
    endJd: endJd,
    chart: annual,
    munthaSign: munthaSign,
    munthaHouse: munthaHouse,
    munthaLord: munthaLord,
    isDay: isDay,
    bala: bala,
    varshesh: varshesh,
    tajika: tajika,
    sahams: sahams,
    mudda: mudda,
    patyayini: patyayini,
    windows: windows,
  );
}

/// Chooses the lord of the year from the five office-bearers.
///
/// The five, as Hayanaratna 5.8 lists them from the Tajika authorities: the
/// lord of the Muntha sign; the lord of the year Lagna; the lord of its
/// triplicity (the day ruler by day, the night ruler by night); by day the lord
/// of the Sun's sign, by night the lord of the Moon's sign; and the lord of the
/// birth Lagna. (The brief for this engine named the janma-rashi lord among the
/// five; the Tajika books name the birth LAGNA lord, and that is what is used.)
///
/// The rule: of the five, the one that aspects the year Lagna and carries the
/// most five-fold strength is lord of the year. A strong graha that does not
/// aspect the Lagna does not qualify, and a weak one that does is still
/// eligible ("even one without strength, aspecting the ascendant, is ruler of
/// the year", Yadava, in Hayanaratna 5.8). A conjunction with the Lagna counts
/// as an aspect. Equal strength goes to the day-night lord, then to the
/// triplicity lord, then to the order listed above. If none of the five
/// aspects the Lagna, Yadava's rule is followed: the Muntha lord stands as lord
/// of the year (Tuka Jyotirvid and Ganesa Daivajna differ, as Hayanaratna
/// records).
VarsheshResult _chooseVarshesh({
  required Kundli chart,
  required Kundli natal,
  required int munthaSign,
  required bool isDay,
  required Map<Graha, PanchaVargiyaBala> bala,
}) {
  final int lagnaSign = chart.lagnaRashi.index;
  SignAspect? aspectOf(Graha g) =>
      signAspectOf(signDistance(chart.grahas[g]!.rashi.index, lagnaSign));

  final Graha munthaLord = rashiInfo(Rashi.values[munthaSign]).lord;
  final Graha lagnaLord = houseLord(chart, 1);
  final Graha trirashi = trirashiLordOf(lagnaSign, isDay: isDay);
  final int luminarySign = isDay ? chart.sunRashi.index : chart.moonRashi.index;
  final Graha dinaRatri = rashiInfo(Rashi.values[luminarySign]).lord;
  final Graha janmaLord = rashiInfo(natal.lagnaRashi).lord;

  VarshaOfficer officer(VarshaOffice office, Graha g, Bi basis) =>
      VarshaOfficer(
        office: office,
        graha: g,
        basis: basis,
        vishwa: bala[g]!.vishwa,
        aspectToLagna: aspectOf(g),
      );

  final List<VarshaOfficer> officers = <VarshaOfficer>[
    officer(
      VarshaOffice.muntha,
      munthaLord,
      Bi(
        'Lord of ${rashiBi(munthaSign).en}, where Muntha stands',
        '${rashiBi(munthaSign).hi} का स्वामी, जहाँ मुन्था है',
      ),
    ),
    officer(
      VarshaOffice.varshaLagna,
      lagnaLord,
      Bi(
        'Lord of ${rashiBi(lagnaSign).en}, the year Lagna',
        '${rashiBi(lagnaSign).hi} का स्वामी, वर्ष लग्न',
      ),
    ),
    officer(
      VarshaOffice.trirashi,
      trirashi,
      Bi(
        '${isDay ? 'Day' : 'Night'} ruler of the triplicity of '
            '${rashiBi(lagnaSign).en}',
        '${rashiBi(lagnaSign).hi} त्रिराशि का ${isDay ? 'दिन' : 'रात्रि'} का '
            'स्वामी',
      ),
    ),
    officer(
      VarshaOffice.dinaRatri,
      dinaRatri,
      isDay
          ? Bi(
              'Lord of ${rashiBi(luminarySign).en}, where the Sun stands (a '
                  'day chart)',
              '${rashiBi(luminarySign).hi} का स्वामी, जहाँ सूर्य है (दिन की '
                  'कुंडली)',
            )
          : Bi(
              'Lord of ${rashiBi(luminarySign).en}, where the Moon stands (a '
                  'night chart)',
              '${rashiBi(luminarySign).hi} का स्वामी, जहाँ चंद्र है (रात्रि '
                  'की कुंडली)',
            ),
    ),
    officer(
      VarshaOffice.janmaLagna,
      janmaLord,
      Bi(
        'Lord of ${rashiBi(natal.lagnaRashi.index).en}, the birth Lagna',
        '${rashiBi(natal.lagnaRashi.index).hi} का स्वामी, जन्म लग्न',
      ),
    ),
  ];

  // Eligible: aspects the Lagna. Strongest first; ties to the day-night lord,
  // then the triplicity lord, then the listed order.
  const List<VarshaOffice> tieOrder = <VarshaOffice>[
    VarshaOffice.dinaRatri,
    VarshaOffice.trirashi,
    VarshaOffice.muntha,
    VarshaOffice.varshaLagna,
    VarshaOffice.janmaLagna,
  ];
  final List<VarshaOfficer> aspecting = officers
      .where((VarshaOfficer o) => o.aspectsLagna)
      .toList();
  aspecting.sort((VarshaOfficer a, VarshaOfficer b) {
    final double diff = b.vishwa - a.vishwa;
    if (diff.abs() > 1e-9) return diff < 0 ? -1 : 1;
    return tieOrder.indexOf(a.office).compareTo(tieOrder.indexOf(b.office));
  });
  final List<Graha> eligible = <Graha>[];
  for (final VarshaOfficer o in aspecting) {
    if (!eligible.contains(o.graha)) eligible.add(o.graha);
  }
  final bool fallback = eligible.isEmpty;
  final Graha lord = fallback ? munthaLord : eligible.first;

  final Bi lordName = grahaBi(lord);
  final List<int> ruled = housesRuledBy(chart, lord);
  final PlacedGraha placed = chart.grahas[lord]!;

  final Bi rule = const Bi(
    'Of the five office-bearers, the one that aspects the year Lagna and has '
        'the most five-fold strength is lord of the year. A strong graha that '
        'does not aspect the Lagna does not qualify.',
    'पाँच अधिकारियों में जो वर्ष लग्न को देखता हो और जिसका पंचवर्गीय बल सबसे '
        'अधिक हो वही वर्षेश है। लग्न को न देखने वाला बलवान ग्रह भी पात्र नहीं।',
  );

  final Bi reading = fallback
      ? Bi(
          'None of the five office-bearers aspects the year Lagna, so the '
              'Muntha lord, ${lordName.en}, stands as lord of the year (the '
              'rule Yadava gives, reported in Hayanaratna 5.8). What '
              '${lordName.en} signifies, ${grahaTheme(lord).en}, runs through '
              'the twelve months, and the year leans on '
              '${housesBi(ruled).en}, which it rules.',
          'पाँचों अधिकारियों में से कोई वर्ष लग्न को नहीं देखता, इसलिए मुन्था '
              'पति ${lordName.hi} वर्षेश है (यादव का नियम, हायनरत्न 5.8 में '
              'उद्धृत)। ${lordName.hi} के कारकत्व, ${grahaTheme(lord).hi}, बारह '
              'महीने चलते हैं, और वर्ष ${housesBi(ruled).hi} पर टिका है, जिसका '
              'वह स्वामी है।',
        )
      : Bi(
          '${lordName.en} is the lord of the year. Of the five office-bearers '
              '${eligible.length == 1 ? 'it is the only one' : 'it is the '
                        'strongest of those'} aspecting the year Lagna, with '
              '${compactNumber(bala[lord]!.vishwa)} of 20 vishwa of five-fold '
              'strength. What ${lordName.en} signifies, ${grahaTheme(lord).en}, '
              'runs through the twelve months, and the year leans on '
              '${housesBi(ruled).en}, which it rules; it stands in '
              '${houseBi(placed.house).en}.',
          '${lordName.hi} वर्षेश है। पाँच अधिकारियों में '
              '${eligible.length == 1 ? 'वर्ष लग्न को देखने वाला यही एकमात्र है' : 'वर्ष लग्न को देखने वालों में यह सबसे बलवान है'}, '
              'पंचवर्गीय बल 20 में से ${compactNumber(bala[lord]!.vishwa)} '
              'विश्वा। ${lordName.hi} के कारकत्व, ${grahaTheme(lord).hi}, बारह '
              'महीने चलते हैं, और वर्ष ${housesBi(ruled).hi} पर टिका है, जिसका '
              'वह स्वामी है; वह ${houseBi(placed.house).hi} में है।',
        );

  final List<Bi> factors = <Bi>[
    rule,
    for (final VarshaOfficer o in officers)
      Bi(
        '${o.officeName.en}: ${grahaBi(o.graha).en} (${o.basis.en}); '
            '${o.aspectsLagna ? 'aspects the Lagna by ${signAspectBi(o.aspectToLagna!).en}' : 'does not aspect the Lagna'}; '
            '${compactNumber(o.vishwa)} vishwa',
        '${o.officeName.hi}: ${grahaBi(o.graha).hi} (${o.basis.hi}); '
            '${o.aspectsLagna ? 'लग्न को ${signAspectBi(o.aspectToLagna!).hi} से देखता है' : 'लग्न को नहीं देखता'}; '
            '${compactNumber(o.vishwa)} विश्वा',
      ),
    if (fallback)
      const Bi(
        'No office-bearer aspects the Lagna, so the Muntha lord is taken',
        'कोई अधिकारी लग्न को नहीं देखता, इसलिए मुन्था पति लिया गया',
      ),
  ];

  return VarsheshResult(
    lord: lord,
    officers: officers,
    eligible: eligible,
    usedFallback: fallback,
    rule: rule,
    reading: reading,
    factors: factors,
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
Bi munthaReadingBi(int house) {
  final Bi area = houseTheme(house);
  return Bi(
    'Muntha stands in house $house, so the year leans on ${area.en}.',
    'मुन्था ${houseBi(house).hi} में है, इसलिए वर्ष का ज़ोर ${area.hi} पर रहता है।',
  );
}

/// Where the Muntha lord stands and how strong it is: the facts the Muntha
/// reading rests on.
Bi munthaLordReading(Varshphal v) {
  final PlacedGraha placed = v.chart.grahas[v.munthaLord]!;
  final PanchaVargiyaBala b = v.bala[v.munthaLord]!;
  final Bi lord = grahaBi(v.munthaLord);
  final Bi dignity = switch (placed.dignity) {
    Dignity.exalted => const Bi('exalted', 'उच्च का'),
    Dignity.moolatrikona => const Bi('in its moolatrikona', 'मूलत्रिकोण में'),
    Dignity.own => const Bi('in its own sign', 'स्वराशि में'),
    Dignity.friend => const Bi('in a friend’s sign', 'मित्र राशि में'),
    Dignity.neutral => const Bi('in a neutral sign', 'सम राशि में'),
    Dignity.enemy => const Bi('in an enemy’s sign', 'शत्रु राशि में'),
    Dignity.debilitated => const Bi('debilitated', 'नीच का'),
  };
  return Bi(
    'The Muntha lord, ${lord.en}, stands in ${rashiBi(placed.rashi.index).en}, '
        '${houseBi(placed.house).en}, ${dignity.en}, with '
        '${compactNumber(b.vishwa)} of 20 vishwa of five-fold strength '
        '(${pvBandBi(b.band).en}).',
    'मुन्था पति ${lord.hi} ${rashiBi(placed.rashi.index).hi} में, '
        '${houseBi(placed.house).hi} में, ${dignity.hi} है, और उसका पंचवर्गीय '
        'बल 20 में से ${compactNumber(b.vishwa)} विश्वा '
        '(${pvBandBi(b.band).hi}) है।',
  );
}

String munthaReading(int house, {required bool hindi}) =>
    munthaReadingBi(house).of(hindi);

String yearLordReading(Graha lord, {required bool hindi}) {
  final Bi name = grahaBi(lord);
  final Bi theme = grahaTheme(lord);
  return hindi
      ? 'वर्ष का स्वामी ${name.hi} है। वर्षफल में इसी ग्रह के कारकत्व, ${theme.hi}, प्रमुख रहते हैं।'
      : 'The lord of the year is ${name.en}, so what that graha signifies, ${theme.en}, runs through the twelve months.';
}
