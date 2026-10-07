import 'chart.dart';
import 'graha_data.dart';
import 'nakshatra.dart';
import 'rashi.dart';
import '../astro/ephemeris.dart';

/// One of the eight kootas, with the score it earned and why.
class Koota {
  const Koota({
    required this.key,
    required this.english,
    required this.hindi,
    required this.score,
    required this.maximum,
    required this.reasonEnglish,
    required this.reasonHindi,
  });

  final String key;
  final String english;
  final String hindi;
  final double score;
  final double maximum;
  final String reasonEnglish;
  final String reasonHindi;
}

class MatchResult {
  const MatchResult({
    required this.kootas,
    required this.total,
    required this.maximum,
    required this.brideMangal,
    required this.groomMangal,
  });

  final List<Koota> kootas;
  final double total;
  final double maximum;
  final bool brideMangal;
  final bool groomMangal;

  bool get mangalBalanced => brideMangal == groomMangal;
}

const List<int> _varnaOfSign = <int>[2, 1, 0, 3, 2, 1, 0, 3, 2, 1, 0, 3];
const List<String> _varnaNames = <String>[
  'Shudra',
  'Vaishya',
  'Kshatriya',
  'Brahmin',
];

enum _Vashya { chatushpada, manava, jalachara, vanachara, keeta }

_Vashya _vashyaOf(int sign, double degreeInSign) {
  switch (sign) {
    case 0:
    case 1:
      return _Vashya.chatushpada;
    case 2:
    case 5:
    case 6:
    case 10:
      return _Vashya.manava;
    case 3:
    case 11:
      return _Vashya.jalachara;
    case 4:
      return _Vashya.vanachara;
    case 7:
      return _Vashya.keeta;
    case 8:
      return degreeInSign < 15 ? _Vashya.manava : _Vashya.chatushpada;
    case 9:
      return degreeInSign < 15 ? _Vashya.chatushpada : _Vashya.jalachara;
    default:
      return _Vashya.manava;
  }
}

/// Yoni pairs the texts call enemies; everything else is neutral or friendly.
const List<List<String>> _yoniEnemies = <List<String>>[
  <String>['cow', 'tiger'],
  <String>['elephant', 'lion'],
  <String>['horse', 'buffalo'],
  <String>['dog', 'deer'],
  <String>['monkey', 'sheep'],
  <String>['cat', 'rat'],
  <String>['serpent', 'mongoose'],
  <String>['lion', 'elephant'],
  <String>['goat', 'monkey'],
];

/// Gana kuta points. Public so the website's reference pages quote the same
/// numbers the matcher uses instead of a second copy that could drift.
const Map<String, List<int>> ganaScores = <String, List<int>>{
  // groom gana -> [bride deva, bride manushya, bride rakshasa]
  'deva': <int>[6, 6, 0],
  'manushya': <int>[5, 6, 0],
  'rakshasa': <int>[1, 0, 6],
};

double _tara(int fromIndex, int toIndex) {
  final int count = ((toIndex - fromIndex + 27) % 27) + 1;
  final int remainder = count % 9;
  return <int>[3, 5, 7].contains(remainder) ? 0 : 1.5;
}

MatchResult matchCharts(Kundli bride, Kundli groom) {
  final List<Koota> kootas = <Koota>[];

  final int brideSign = bride.moonRashi.index;
  final int groomSign = groom.moonRashi.index;
  final NakshatraInfo brideNakshatra = bride.janmaNakshatra;
  final NakshatraInfo groomNakshatra = groom.janmaNakshatra;

  // 1. Varna.
  final int brideVarna = _varnaOfSign[brideSign];
  final int groomVarna = _varnaOfSign[groomSign];
  kootas.add(
    Koota(
      key: 'varna',
      english: 'Varna',
      hindi: 'वर्ण',
      score: groomVarna >= brideVarna ? 1 : 0,
      maximum: 1,
      reasonEnglish:
          'Groom is ${_varnaNames[groomVarna]}, bride is ${_varnaNames[brideVarna]}.',
      reasonHindi:
          'वर ${_varnaNames[groomVarna]}, वधू ${_varnaNames[brideVarna]}।',
    ),
  );

  // 2. Vashya.
  final _Vashya brideVashya = _vashyaOf(
    brideSign,
    bride.grahas[Graha.moon]!.degreesInSign,
  );
  final _Vashya groomVashya = _vashyaOf(
    groomSign,
    groom.grahas[Graha.moon]!.degreesInSign,
  );
  final double vashyaScore = brideVashya == groomVashya
      ? 2
      : (brideVashya == _Vashya.manava && groomVashya == _Vashya.chatushpada) ||
            (groomVashya == _Vashya.manava &&
                brideVashya == _Vashya.chatushpada)
      ? 1
      : 0.5;
  kootas.add(
    Koota(
      key: 'vashya',
      english: 'Vashya',
      hindi: 'वश्य',
      score: vashyaScore,
      maximum: 2,
      reasonEnglish:
          'Moon signs fall in the ${groomVashya.name} and ${brideVashya.name} groups.',
      reasonHindi:
          'दोनों राशियाँ ${groomVashya.name} और ${brideVashya.name} वर्ग में हैं।',
    ),
  );

  // 3. Tara.
  final double tara =
      _tara(brideNakshatra.index, groomNakshatra.index) +
      _tara(groomNakshatra.index, brideNakshatra.index);
  kootas.add(
    Koota(
      key: 'tara',
      english: 'Tara',
      hindi: 'तारा',
      score: tara,
      maximum: 3,
      reasonEnglish:
          'Counted from ${brideNakshatra.english} to ${groomNakshatra.english} and back.',
      reasonHindi:
          '${brideNakshatra.hindi} से ${groomNakshatra.hindi} तक और वापस गिनती से।',
    ),
  );

  // 4. Yoni.
  final bool sameYoni = brideNakshatra.yoni == groomNakshatra.yoni;
  final bool enemies = _yoniEnemies.any(
    (List<String> pair) =>
        pair.contains(brideNakshatra.yoni) &&
        pair.contains(groomNakshatra.yoni),
  );
  final double yoniScore = sameYoni ? 4 : (enemies ? 1 : 3);
  kootas.add(
    Koota(
      key: 'yoni',
      english: 'Yoni',
      hindi: 'योनि',
      score: yoniScore,
      maximum: 4,
      reasonEnglish:
          'Yonis are ${groomNakshatra.yoni} and ${brideNakshatra.yoni}.',
      reasonHindi: 'योनि ${groomNakshatra.yoni} और ${brideNakshatra.yoni} हैं।',
    ),
  );

  // 5. Graha Maitri.
  final Graha brideLord = rashiInfo(bride.moonRashi).lord;
  final Graha groomLord = rashiInfo(groom.moonRashi).lord;
  final Relation a = relationBetween(groomLord, brideLord);
  final Relation b = relationBetween(brideLord, groomLord);
  double maitri;
  if (brideLord == groomLord) {
    maitri = 5;
  } else if (a == Relation.friend && b == Relation.friend) {
    maitri = 5;
  } else if ((a == Relation.friend && b == Relation.neutral) ||
      (b == Relation.friend && a == Relation.neutral)) {
    maitri = 4;
  } else if (a == Relation.neutral && b == Relation.neutral) {
    maitri = 3;
  } else if (a == Relation.enemy && b == Relation.enemy) {
    maitri = 0;
  } else if (a == Relation.friend || b == Relation.friend) {
    maitri = 1;
  } else {
    maitri = 0.5;
  }
  kootas.add(
    Koota(
      key: 'maitri',
      english: 'Graha Maitri',
      hindi: 'ग्रह मैत्री',
      score: maitri,
      maximum: 5,
      reasonEnglish:
          'Moon sign lords are ${grahaInfo(groomLord).english} and ${grahaInfo(brideLord).english}.',
      reasonHindi:
          'राशि स्वामी ${grahaInfo(groomLord).hindi} और ${grahaInfo(brideLord).hindi} हैं।',
    ),
  );

  // 6. Gana.
  final double gana =
      ganaScores[groomNakshatra.gana.name]![brideNakshatra.gana.index]
          .toDouble();
  kootas.add(
    Koota(
      key: 'gana',
      english: 'Gana',
      hindi: 'गण',
      score: gana,
      maximum: 6,
      reasonEnglish:
          'Ganas are ${groomNakshatra.gana.name} and ${brideNakshatra.gana.name}.',
      reasonHindi:
          'गण ${groomNakshatra.gana.name} और ${brideNakshatra.gana.name} हैं।',
    ),
  );

  // 7. Bhakoot.
  final int forward = ((groomSign - brideSign + 12) % 12) + 1;
  final int backward = ((brideSign - groomSign + 12) % 12) + 1;
  final bool blocked =
      <int>[2, 12, 5, 9, 6, 8].contains(forward) &&
      <int>[2, 12, 5, 9, 6, 8].contains(backward);
  kootas.add(
    Koota(
      key: 'bhakoot',
      english: 'Bhakoot',
      hindi: 'भकूट',
      score: blocked ? 0 : 7,
      maximum: 7,
      reasonEnglish: 'Moon signs stand $forward and $backward from each other.',
      reasonHindi:
          'दोनों राशियाँ एक-दूसरे से $forward और $backward स्थान पर हैं।',
    ),
  );

  // 8. Nadi.
  final bool sameNadi = brideNakshatra.nadi == groomNakshatra.nadi;
  kootas.add(
    Koota(
      key: 'nadi',
      english: 'Nadi',
      hindi: 'नाड़ी',
      score: sameNadi ? 0 : 8,
      maximum: 8,
      reasonEnglish:
          'Nadis are ${groomNakshatra.nadi.name} and ${brideNakshatra.nadi.name}.',
      reasonHindi:
          'नाड़ी ${groomNakshatra.nadi.name} और ${brideNakshatra.nadi.name} हैं।',
    ),
  );

  final double total = kootas.fold<double>(
    0,
    (double sum, Koota k) => sum + k.score,
  );
  return MatchResult(
    kootas: kootas,
    total: total,
    maximum: 36,
    brideMangal: hasMangalDosha(bride),
    groomMangal: hasMangalDosha(groom),
  );
}

bool hasMangalDosha(Kundli kundli) {
  final int house = kundli.grahas[Graha.mars]!.house;
  final int fromMoon =
      ((kundli.grahas[Graha.mars]!.rashi.index - kundli.moonRashi.index + 12) %
          12) +
      1;
  return <int>[1, 2, 4, 7, 8, 12].contains(house) ||
      <int>[1, 2, 4, 7, 8, 12].contains(fromMoon);
}
