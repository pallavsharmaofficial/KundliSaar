import '../astro/ephemeris.dart';

/// The twelve signs, in zodiacal order from Mesha.
enum Rashi {
  mesha,
  vrishabha,
  mithuna,
  karka,
  simha,
  kanya,
  tula,
  vrischika,
  dhanu,
  makara,
  kumbha,
  meena,
}

enum Element { fire, earth, air, water }

enum Quality { movable, fixed, dual }

class RashiInfo {
  const RashiInfo({
    required this.rashi,
    required this.english,
    required this.hindi,
    required this.lord,
    required this.element,
    required this.quality,
    required this.symbolEnglish,
    required this.symbolHindi,
  });

  final Rashi rashi;
  final String english;
  final String hindi;
  final Graha lord;
  final Element element;
  final Quality quality;
  final String symbolEnglish;
  final String symbolHindi;
}

const List<RashiInfo> rashiTable = <RashiInfo>[
  RashiInfo(
    rashi: Rashi.mesha,
    english: 'Mesha',
    hindi: 'मेष',
    lord: Graha.mars,
    element: Element.fire,
    quality: Quality.movable,
    symbolEnglish: 'Ram',
    symbolHindi: 'मेड़ा',
  ),
  RashiInfo(
    rashi: Rashi.vrishabha,
    english: 'Vrishabha',
    hindi: 'वृषभ',
    lord: Graha.venus,
    element: Element.earth,
    quality: Quality.fixed,
    symbolEnglish: 'Bull',
    symbolHindi: 'बैल',
  ),
  RashiInfo(
    rashi: Rashi.mithuna,
    english: 'Mithuna',
    hindi: 'मिथुन',
    lord: Graha.mercury,
    element: Element.air,
    quality: Quality.dual,
    symbolEnglish: 'Twins',
    symbolHindi: 'युग्म',
  ),
  RashiInfo(
    rashi: Rashi.karka,
    english: 'Karka',
    hindi: 'कर्क',
    lord: Graha.moon,
    element: Element.water,
    quality: Quality.movable,
    symbolEnglish: 'Crab',
    symbolHindi: 'केकड़ा',
  ),
  RashiInfo(
    rashi: Rashi.simha,
    english: 'Simha',
    hindi: 'सिंह',
    lord: Graha.sun,
    element: Element.fire,
    quality: Quality.fixed,
    symbolEnglish: 'Lion',
    symbolHindi: 'शेर',
  ),
  RashiInfo(
    rashi: Rashi.kanya,
    english: 'Kanya',
    hindi: 'कन्या',
    lord: Graha.mercury,
    element: Element.earth,
    quality: Quality.dual,
    symbolEnglish: 'Maiden',
    symbolHindi: 'कन्या',
  ),
  RashiInfo(
    rashi: Rashi.tula,
    english: 'Tula',
    hindi: 'तुला',
    lord: Graha.venus,
    element: Element.air,
    quality: Quality.movable,
    symbolEnglish: 'Scales',
    symbolHindi: 'तराजू',
  ),
  RashiInfo(
    rashi: Rashi.vrischika,
    english: 'Vrischika',
    hindi: 'वृश्चिक',
    lord: Graha.mars,
    element: Element.water,
    quality: Quality.fixed,
    symbolEnglish: 'Scorpion',
    symbolHindi: 'बिच्छू',
  ),
  RashiInfo(
    rashi: Rashi.dhanu,
    english: 'Dhanu',
    hindi: 'धनु',
    lord: Graha.jupiter,
    element: Element.fire,
    quality: Quality.dual,
    symbolEnglish: 'Archer',
    symbolHindi: 'धनुष',
  ),
  RashiInfo(
    rashi: Rashi.makara,
    english: 'Makara',
    hindi: 'मकर',
    lord: Graha.saturn,
    element: Element.earth,
    quality: Quality.movable,
    symbolEnglish: 'Crocodile',
    symbolHindi: 'मगर',
  ),
  RashiInfo(
    rashi: Rashi.kumbha,
    english: 'Kumbha',
    hindi: 'कुंभ',
    lord: Graha.saturn,
    element: Element.air,
    quality: Quality.fixed,
    symbolEnglish: 'Water bearer',
    symbolHindi: 'घड़ा',
  ),
  RashiInfo(
    rashi: Rashi.meena,
    english: 'Meena',
    hindi: 'मीन',
    lord: Graha.jupiter,
    element: Element.water,
    quality: Quality.dual,
    symbolEnglish: 'Fishes',
    symbolHindi: 'मछली',
  ),
];

RashiInfo rashiInfo(Rashi rashi) => rashiTable[rashi.index];

Rashi rashiOf(double siderealLongitude) =>
    Rashi.values[(siderealLongitude / 30.0).floor() % 12];

/// Degrees into the sign, 0..30.
double degreesInRashi(double siderealLongitude) => siderealLongitude % 30.0;
