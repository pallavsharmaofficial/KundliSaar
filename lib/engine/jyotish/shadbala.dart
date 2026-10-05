import 'dart:math' as math;

import '../astro/angles.dart';
import '../astro/ephemeris.dart';
import '../astro/frames.dart';
import '../astro/rise_set.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'rashi.dart';
import 'varga.dart';

/// Shadbala: the six strengths, in virupas. Sixty virupas make one rupa, and
/// a graha is read as able to deliver its promise once it clears the minimum
/// rupas the texts set for it.
///
/// Where Parashara gives a choice of method the code says which one it took;
/// the drik bala in particular uses the graded house aspect rather than the
/// arc formula, which is what most Indian software does.
class BalaBreakdown {
  const BalaBreakdown({
    required this.graha,
    required this.uchcha,
    required this.saptavargaja,
    required this.ojhayugma,
    required this.kendradi,
    required this.drekkana,
    required this.dig,
    required this.nathonnatha,
    required this.paksha,
    required this.tribhaga,
    required this.varshadi,
    required this.ayana,
    required this.chesta,
    required this.naisargika,
    required this.drik,
  });

  final Graha graha;
  final double uchcha;
  final double saptavargaja;
  final double ojhayugma;
  final double kendradi;
  final double drekkana;
  final double dig;
  final double nathonnatha;
  final double paksha;
  final double tribhaga;
  final double varshadi;
  final double ayana;
  final double chesta;
  final double naisargika;
  final double drik;

  double get sthana => uchcha + saptavargaja + ojhayugma + kendradi + drekkana;
  double get kala => nathonnatha + paksha + tribhaga + varshadi + ayana;
  double get totalVirupas => sthana + dig + kala + chesta + naisargika + drik;
  double get totalRupas => totalVirupas / 60.0;

  double get requiredRupas => _required[graha]!;
  double get ratio => totalRupas / requiredRupas;
  bool get isStrong => totalRupas >= requiredRupas;
}

const Map<Graha, double> _required = <Graha, double>{
  Graha.sun: 5.0,
  Graha.moon: 6.0,
  Graha.mars: 5.0,
  Graha.mercury: 7.0,
  Graha.jupiter: 6.5,
  Graha.venus: 5.5,
  Graha.saturn: 5.0,
};

const Map<Graha, double> _naisargika = <Graha, double>{
  Graha.sun: 60.0,
  Graha.moon: 51.43,
  Graha.venus: 42.85,
  Graha.jupiter: 34.28,
  Graha.mercury: 25.70,
  Graha.mars: 17.14,
  Graha.saturn: 8.57,
};

/// Mean geocentric daily motion in degrees. Mercury and Venus keep pace with
/// the Sun as seen from here, which is why they share its mean motion.
const Map<Graha, double> meanDailyMotion = <Graha, double>{
  Graha.sun: 0.9856,
  Graha.moon: 13.1764,
  Graha.mars: 0.5240,
  Graha.mercury: 0.9856,
  Graha.jupiter: 0.0831,
  Graha.venus: 0.9856,
  Graha.saturn: 0.0335,
};

/// The point of deepest fall, 180 degrees from exaltation.
double _debilitationDegree(Graha graha) =>
    norm360(grahaInfo(graha).exaltationDegree! + 180.0);

/// Where each graha is strongest by direction, as a house number.
const Map<Graha, int> _digStrongHouse = <Graha, int>{
  Graha.mercury: 1,
  Graha.jupiter: 1,
  Graha.sun: 10,
  Graha.mars: 10,
  Graha.saturn: 7,
  Graha.moon: 4,
  Graha.venus: 4,
};

const List<Graha> shadbalaGrahas = <Graha>[
  Graha.sun,
  Graha.moon,
  Graha.mars,
  Graha.mercury,
  Graha.jupiter,
  Graha.venus,
  Graha.saturn,
];

const List<Varga> _saptavarga = <Varga>[
  Varga.d1,
  Varga.d2,
  Varga.d3,
  Varga.d7,
  Varga.d9,
  Varga.d12,
  Varga.d30,
];

/// Natural benefic or malefic. The Moon turns malefic as it wanes and Mercury
/// takes the character of whatever it sits with, which both matter for paksha
/// and drik bala.
bool isBenefic(Kundli kundli, Graha graha) {
  switch (graha) {
    case Graha.jupiter:
    case Graha.venus:
      return true;
    case Graha.sun:
    case Graha.mars:
    case Graha.saturn:
    case Graha.rahu:
    case Graha.ketu:
      return false;
    case Graha.moon:
      return _moonPhase(kundli) > 72;
    case Graha.mercury:
      final int mercurySign = kundli.grahas[Graha.mercury]!.rashi.index;
      final bool withMalefic = kundli.grahas.values.any(
        (PlacedGraha p) =>
            p.graha != Graha.mercury &&
            p.rashi.index == mercurySign &&
            !<Graha>[Graha.jupiter, Graha.venus].contains(p.graha),
      );
      return !withMalefic;
  }
}

/// Elongation of the Moon from the Sun, 0 at new moon.
double _moonPhase(Kundli kundli) => norm360(
  kundli.grahas[Graha.moon]!.siderealLongitude -
      kundli.grahas[Graha.sun]!.siderealLongitude,
);

/// Compound relationship, natural plus temporal, after Parashara.
Relation _compound(Kundli kundli, Graha of, Graha lord) {
  if (of == lord) return Relation.friend;
  final Relation natural = relationBetween(of, lord);
  final int fromSign = kundli.grahas[of]!.rashi.index;
  final int lordSign = kundli.grahas[lord]!.rashi.index;
  final int distance = ((lordSign - fromSign + 12) % 12) + 1;
  final bool temporalFriend = <int>[2, 3, 4, 10, 11, 12].contains(distance);
  if (natural == Relation.friend) {
    return temporalFriend ? Relation.friend : Relation.neutral;
  }
  if (natural == Relation.enemy) {
    return temporalFriend ? Relation.neutral : Relation.enemy;
  }
  return temporalFriend ? Relation.friend : Relation.enemy;
}

double _saptavargajaValue(Kundli kundli, Graha graha, Varga varga) {
  final double longitude = kundli.grahas[graha]!.siderealLongitude;
  final int sign = vargaSign(varga, longitude);
  final GrahaInfo info = grahaInfo(graha);
  final List<double>? mt = info.moolatrikona;
  if (varga == Varga.d1 &&
      mt != null &&
      sign == mt[0].toInt() &&
      longitude % 30 >= mt[1] &&
      longitude % 30 < mt[2]) {
    return 45.0;
  }
  if (info.ownSigns.contains(sign)) return 30.0;
  final Graha lord = rashiInfo(Rashi.values[sign]).lord;
  if (lord == graha) return 30.0;
  final Relation natural = relationBetween(graha, lord);
  final Relation compound = _compound(kundli, graha, lord);
  if (natural == Relation.friend && compound == Relation.friend) return 22.5;
  if (compound == Relation.friend) return 15.0;
  if (compound == Relation.neutral) return 7.5;
  if (natural == Relation.enemy && compound == Relation.enemy) return 1.875;
  return 3.75;
}

double _uchchaBala(Kundli kundli, Graha graha) {
  final double longitude = kundli.grahas[graha]!.siderealLongitude;
  final double arc = norm180(longitude - _debilitationDegree(graha)).abs();
  return arc / 3.0;
}

double _ojhayugmaBala(Kundli kundli, Graha graha) {
  final double longitude = kundli.grahas[graha]!.siderealLongitude;
  final bool wantsEven = graha == Graha.moon || graha == Graha.venus;
  final bool rasiOdd = (longitude / 30).floor() % 2 == 0;
  final bool navamsaOdd = vargaSign(Varga.d9, longitude) % 2 == 0;
  double total = 0;
  if (rasiOdd != wantsEven) total += 15;
  if (navamsaOdd != wantsEven) total += 15;
  return total;
}

double _kendradiBala(Kundli kundli, Graha graha) {
  final int house = kundli.grahas[graha]!.house;
  if (<int>[1, 4, 7, 10].contains(house)) return 60;
  if (<int>[2, 5, 8, 11].contains(house)) return 30;
  return 15;
}

double _drekkanaBala(Kundli kundli, Graha graha) {
  final double degree = kundli.grahas[graha]!.degreesInSign;
  final int third = (degree / 10).floor();
  const List<Graha> male = <Graha>[Graha.sun, Graha.mars, Graha.jupiter];
  const List<Graha> neuter = <Graha>[Graha.mercury, Graha.saturn];
  if (male.contains(graha) && third == 0) return 15;
  if (neuter.contains(graha) && third == 1) return 15;
  if (<Graha>[Graha.moon, Graha.venus].contains(graha) && third == 2) return 15;
  return 0;
}

double _digBala(Kundli kundli, Graha graha) {
  final List<double> cusps = kundli.cusps;
  final int strongHouse = _digStrongHouse[graha]!;
  final double strongPoint = cusps[strongHouse - 1];
  final double weakPoint = norm360(strongPoint + 180);
  final double arc = norm180(
    kundli.grahas[graha]!.siderealLongitude - weakPoint,
  ).abs();
  return arc / 3.0;
}

double _nathonnathaBala(Kundli kundli, Graha graha, double hoursFromMidnight) {
  if (graha == Graha.mercury) return 60;
  final double fromMidnight = math.min(
    hoursFromMidnight,
    24 - hoursFromMidnight,
  );
  const List<Graha> nightStrong = <Graha>[Graha.moon, Graha.mars, Graha.saturn];
  final double nightShare = 1 - fromMidnight / 12.0;
  return 60 * (nightStrong.contains(graha) ? nightShare : 1 - nightShare);
}

double _pakshaBala(Kundli kundli, Graha graha) {
  final double elongation = _moonPhase(kundli);
  final double waxing = elongation <= 180 ? elongation : 360 - elongation;
  final double beneficShare = waxing / 180.0 * 60.0;
  final bool benefic = isBenefic(kundli, graha);
  final double value = benefic ? beneficShare : 60 - beneficShare;
  return graha == Graha.moon ? value * 2 : value;
}

double _tribhagaBala(
  Kundli kundli,
  Graha graha,
  double jdUt,
  double sunrise,
  double sunset,
) {
  if (graha == Graha.jupiter) return 60;
  final bool daytime = jdUt >= sunrise && jdUt < sunset;
  final double start = daytime ? sunrise : sunset;
  final double length = daytime ? sunset - sunrise : (sunrise + 1) - sunset;
  final int third = ((jdUt - start) / (length / 3)).floor().clamp(0, 2);
  const List<Graha> day = <Graha>[Graha.mercury, Graha.sun, Graha.saturn];
  const List<Graha> night = <Graha>[Graha.moon, Graha.venus, Graha.mars];
  final Graha ruler = daytime ? day[third] : night[third];
  return graha == ruler ? 60 : 0;
}

/// Lords of the year, month, day and hour, worth 15, 30, 45 and 60 virupas.
double _varshadiBala(Kundli kundli, Graha graha, double jdUt, double sunrise) {
  const List<Graha> weekdayLords = <Graha>[
    Graha.sun,
    Graha.moon,
    Graha.mars,
    Graha.mercury,
    Graha.jupiter,
    Graha.venus,
    Graha.saturn,
  ];
  final int weekday = (jdUt + 1.5).floor() % 7;
  double total = 0;
  if (graha == weekdayLords[weekday]) total += 45;

  // Year and month lords, counted from the solar year and month that were
  // running at birth, by the weekday each began on.
  final int yearIndex = ((jdUt - 2415020.5) / 365.25).floor();
  if (graha == weekdayLords[(yearIndex * 3) % 7]) total += 15;
  final int monthIndex = (kundli.grahas[Graha.sun]!.rashi.index);
  if (graha == weekdayLords[(yearIndex * 3 + monthIndex * 2) % 7]) total += 30;

  // Hora lord, the Chaldean order starting from the lord of the weekday.
  const List<Graha> chaldean = <Graha>[
    Graha.saturn,
    Graha.jupiter,
    Graha.mars,
    Graha.sun,
    Graha.venus,
    Graha.mercury,
    Graha.moon,
  ];
  final int horaIndex = ((jdUt - sunrise) * 24).floor().clamp(0, 23);
  final int first = chaldean.indexOf(weekdayLords[weekday]);
  if (graha == chaldean[(first + horaIndex) % 7]) total += 60;
  return total;
}

double _ayanaBala(Kundli kundli, Graha graha) {
  final double t = kundli.instant.centuriesTt;
  final PlacedGraha placed = kundli.grahas[graha]!;
  final List<double> equatorial = eclipticToEquatorial(
    placed.tropicalLongitude,
    placed.latitude,
    trueObliquity(t),
  );
  final double declination = equatorial[1];
  const List<Graha> northStrong = <Graha>[
    Graha.sun,
    Graha.mars,
    Graha.jupiter,
    Graha.venus,
  ];
  final bool north = graha == Graha.mercury || northStrong.contains(graha);
  final double kranti = north ? declination : -declination;
  final double value = (kranti + 24.0) / 48.0 * 60.0;
  return (graha == Graha.sun ? value * 2 : value).clamp(0.0, 120.0);
}

double _chestaBala(Kundli kundli, Graha graha, double ayana) {
  // The Sun and the Moon never turn back, so the texts give them their ayana
  // bala in place of a motional strength.
  if (graha == Graha.sun || graha == Graha.moon) return ayana;
  final double speed = kundli.grahas[graha]!.speed;
  final double mean = meanDailyMotion[graha]!;
  if (speed < 0) return 60; // vakra
  final double ratio = speed / mean;
  if (ratio < 0.25) return 15; // vikala, near a station
  if (ratio < 0.75) return 30; // manda
  if (ratio < 1.25) return 30; // sama
  if (ratio < 1.5) return 40; // chara
  return 45; // atichara
}

/// Graded Parashari aspect, in virupas, cast by [from] on a longitude.
double aspectStrength(Graha from, int fromSign, int toSign) {
  final int distance = ((toSign - fromSign + 12) % 12) + 1;
  if (distance == 7) return 60;
  if (from == Graha.mars && <int>[4, 8].contains(distance)) return 60;
  if (from == Graha.jupiter && <int>[5, 9].contains(distance)) return 60;
  if (from == Graha.saturn && <int>[3, 10].contains(distance)) return 60;
  if (<int>[4, 8].contains(distance)) return 45;
  if (<int>[5, 9].contains(distance)) return 30;
  if (<int>[3, 10].contains(distance)) return 15;
  return 0;
}

double _drikBala(Kundli kundli, Graha graha) {
  final int targetSign = kundli.grahas[graha]!.rashi.index;
  double net = 0;
  for (final Graha other in shadbalaGrahas) {
    if (other == graha) continue;
    final double strength = aspectStrength(
      other,
      kundli.grahas[other]!.rashi.index,
      targetSign,
    );
    if (strength == 0) continue;
    net += isBenefic(kundli, other) ? strength : -strength;
  }
  return net / 4.0;
}

/// The six strengths for all seven grahas.
Map<Graha, BalaBreakdown> computeShadbala(Kundli kundli) {
  final double jdUt = kundli.instant.julianDayUt;
  final RiseSet riseSet = findRiseSet(
    Graha.sun,
    jdUt.floorToDouble() - 0.5,
    kundli.birth.place,
    spanDays: 2.0,
    steps: 96,
  );
  final double sunrise = riseSet.rise ?? jdUt.floorToDouble() + 0.25;
  final double sunset = riseSet.set ?? jdUt.floorToDouble() + 0.75;
  final double hoursFromMidnight = ((jdUt + 0.5 - (jdUt + 0.5).floor()) * 24)
      .toDouble();

  final Map<Graha, BalaBreakdown> out = <Graha, BalaBreakdown>{};
  for (final Graha graha in shadbalaGrahas) {
    double saptavargaja = 0;
    for (final Varga varga in _saptavarga) {
      saptavargaja += _saptavargajaValue(kundli, graha, varga);
    }
    final double ayana = _ayanaBala(kundli, graha);
    out[graha] = BalaBreakdown(
      graha: graha,
      uchcha: _uchchaBala(kundli, graha),
      saptavargaja: saptavargaja,
      ojhayugma: _ojhayugmaBala(kundli, graha),
      kendradi: _kendradiBala(kundli, graha),
      drekkana: _drekkanaBala(kundli, graha),
      dig: _digBala(kundli, graha),
      nathonnatha: _nathonnathaBala(kundli, graha, hoursFromMidnight),
      paksha: _pakshaBala(kundli, graha),
      tribhaga: _tribhagaBala(kundli, graha, jdUt, sunrise, sunset),
      varshadi: _varshadiBala(kundli, graha, jdUt, sunrise),
      ayana: ayana,
      chesta: _chestaBala(kundli, graha, ayana),
      naisargika: _naisargika[graha]!,
      drik: _drikBala(kundli, graha),
    );
  }
  return out;
}
