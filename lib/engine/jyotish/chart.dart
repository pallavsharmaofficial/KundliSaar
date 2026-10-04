import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/houses.dart';
import '../astro/time.dart';
import 'dasha.dart';
import 'graha_data.dart';
import 'nakshatra.dart';
import 'rashi.dart';
import 'varga.dart';

/// What the user typed in, before anything is computed.
class BirthData {
  const BirthData({
    required this.name,
    required this.localDateTime,
    required this.utcOffset,
    required this.place,
    this.timeIsApproximate = false,
    this.gender,
  });

  final String name;
  final DateTime localDateTime;
  final Duration utcOffset;
  final GeoPlace place;

  /// True when the user only knew the hour roughly; the app then says which
  /// results it would not trust.
  final bool timeIsApproximate;
  final String? gender;
}

enum Dignity { exalted, moolatrikona, own, friend, neutral, enemy, debilitated }

/// One graha as it stands in a chart.
class PlacedGraha {
  const PlacedGraha({
    required this.graha,
    required this.siderealLongitude,
    required this.tropicalLongitude,
    required this.latitude,
    required this.speed,
    required this.house,
    required this.dignity,
    required this.isCombust,
  });

  final Graha graha;
  final double siderealLongitude;
  final double tropicalLongitude;
  final double latitude;
  final double speed;
  final int house;
  final Dignity dignity;
  final bool isCombust;

  Rashi get rashi => rashiOf(siderealLongitude);
  double get degreesInSign => degreesInRashi(siderealLongitude);
  NakshatraInfo get nakshatra => nakshatraOf(siderealLongitude);
  int get pada => padaOf(siderealLongitude);
  bool get isRetrograde =>
      speed < 0 && graha != Graha.rahu && graha != Graha.ketu;
}

/// A computed kundli: the chart, its houses, its dashas.
class Kundli {
  Kundli({
    required this.birth,
    required this.instant,
    required this.ayanamsa,
    required this.ayanamsaValue,
    required this.ascendant,
    required this.midheaven,
    required this.cusps,
    required this.grahas,
    required this.vimshottari,
  });

  final BirthData birth;
  final Instant instant;
  final Ayanamsa ayanamsa;
  final double ayanamsaValue;

  /// Sidereal longitude of the rising degree.
  final double ascendant;
  final double midheaven;

  /// Sidereal Sripati cusps, for the bhava chalit chart.
  final List<double> cusps;
  final Map<Graha, PlacedGraha> grahas;
  final List<DashaPeriod> vimshottari;

  Rashi get lagnaRashi => rashiOf(ascendant);
  Rashi get moonRashi => grahas[Graha.moon]!.rashi;
  Rashi get sunRashi => grahas[Graha.sun]!.rashi;
  NakshatraInfo get janmaNakshatra => grahas[Graha.moon]!.nakshatra;

  /// Sign occupying a house, zero-based sign index.
  int signOfHouse(int house) => (lagnaRashi.index + house - 1) % 12;

  /// Grahas standing in a whole-sign house.
  List<PlacedGraha> grahasInHouse(int house) => grahas.values
      .where((PlacedGraha g) => g.house == house)
      .toList(growable: false);

  /// The same chart re-mapped into a divisional chart.
  Map<Graha, int> vargaPlacements(Varga varga) => <Graha, int>{
    for (final MapEntry<Graha, PlacedGraha> e in grahas.entries)
      e.key: vargaSign(varga, e.value.siderealLongitude),
  };

  int vargaLagna(Varga varga) => vargaSign(varga, ascendant);

  List<DashaPeriod> dashaChainAt(DateTime moment) =>
      dashaAt(vimshottari, julianDayFromUtc(moment.toUtc()));
}

Dignity _dignityOf(Graha graha, double siderealLongitude) {
  final GrahaInfo info = grahaInfo(graha);
  final int sign = (siderealLongitude / 30).floor() % 12;
  final double degree = siderealLongitude % 30;
  final double? exaltation = info.exaltationDegree;
  if (exaltation != null) {
    final int exaltSign = (exaltation / 30).floor();
    final int debilitationSign = (exaltSign + 6) % 12;
    if (sign == exaltSign) return Dignity.exalted;
    if (sign == debilitationSign) return Dignity.debilitated;
  }
  final List<double>? mt = info.moolatrikona;
  if (mt != null &&
      sign == mt[0].toInt() &&
      degree >= mt[1] &&
      degree < mt[2]) {
    return Dignity.moolatrikona;
  }
  if (info.ownSigns.contains(sign)) return Dignity.own;
  final Graha lord = rashiInfo(Rashi.values[sign]).lord;
  if (lord == graha) return Dignity.own;
  return switch (relationBetween(graha, lord)) {
    Relation.friend => Dignity.friend,
    Relation.neutral => Dignity.neutral,
    Relation.enemy => Dignity.enemy,
  };
}

/// Computes a full kundli from birth data.
Kundli computeKundli(BirthData birth, {Ayanamsa ayanamsa = Ayanamsa.lahiri}) {
  final Instant instant = Instant.fromLocal(
    birth.localDateTime,
    birth.utcOffset,
  );
  final double t = instant.centuriesTt;
  final double ayan = ayanamsaDegrees(ayanamsa, t);
  final Angles angles = computeAngles(
    instant,
    birth.place.latitude,
    birth.place.longitude,
  );
  final double ascendant = norm360(angles.ascendant - ayan);
  final double midheaven = norm360(angles.midheaven - ayan);
  final List<double> cusps = sripatiCusps(ascendant, midheaven);

  final Map<Graha, BodyPosition> raw = allPositions(instant);
  final double sunLongitude = raw[Graha.sun]!.tropicalLongitude;
  final Map<Graha, PlacedGraha> placed = <Graha, PlacedGraha>{};
  for (final MapEntry<Graha, BodyPosition> entry in raw.entries) {
    final double sidereal = norm360(entry.value.tropicalLongitude - ayan);
    final double orb = grahaInfo(entry.key).combustionOrb;
    placed[entry.key] = PlacedGraha(
      graha: entry.key,
      siderealLongitude: sidereal,
      tropicalLongitude: entry.value.tropicalLongitude,
      latitude: entry.value.latitude,
      speed: entry.value.speed,
      house: wholeSignHouse(sidereal, ascendant),
      dignity: _dignityOf(entry.key, sidereal),
      isCombust:
          orb > 0 &&
          angleDiff(entry.value.tropicalLongitude, sunLongitude).abs() < orb,
    );
  }

  return Kundli(
    birth: birth,
    instant: instant,
    ayanamsa: ayanamsa,
    ayanamsaValue: ayan,
    ascendant: ascendant,
    midheaven: midheaven,
    cusps: cusps,
    grahas: placed,
    vimshottari: vimshottariTree(
      moonSiderealLongitude: placed[Graha.moon]!.siderealLongitude,
      birthJdUt: instant.julianDayUt,
    ),
  );
}
