/// Sudarshana Chakra: every house read from three references at once, the
/// Lagna (the body), the Chandra (the mind) and the Surya (the soul).
///
/// The method is Parashara's, chapter 74 of the Brihat Parashara Hora Shastra,
/// read in the Sanskrit. The chakra has three rings of twelve houses, each ring
/// counted from its own first house: the lagna, the Moon and the Sun (74.4-7).
/// A house is judged in each ring by the rules of 74.8-74.25, and the verdicts
/// are weighed together. A house that stands well from all three is the
/// classical signature of a reliably good area of life; one that stands well
/// from only a single reference is not.
///
/// How one house is judged in one ring (all of it from chapter 74):
///
///  * A house joined or aspected by its own lord, and by benefics, thrives; one
///    joined or aspected by malefics declines (74.10).
///  * An occupied house takes the result of those who sit in it; an empty house
///    takes the result of the aspects on it (74.11).
///  * Benefics give good, malefics bad, a mixture mixed, and where one side
///    outnumbers the other the result follows it (74.12).
///  * A house with no graha in it and no aspect on it is judged by its lord's
///    strength (74.14, 74.16).
///  * The Sun is good in the first house of a ring and unwelcome elsewhere
///    (74.8). A malefic in its sign of exaltation does no harm (74.9). Rahu
///    harms the house it sits in (74.24). Malefics in the 3rd, 6th and 11th
///    houses, and benefics in the 6th and 12th, give good results (74.25).
///
/// Where the three references fall in fewer than three signs, that is, where
/// two or three of the lagna, Moon and Sun share a sign, the text says to read
/// from the lagna (74.20). The result carries that as a flag so a screen can
/// say so; the agreement count is then less independent than it looks.
///
/// Rahu and Ketu are counted only as occupants (Ketu as an ordinary malefic).
/// Their aspects are not used: the texts that give them disagree.
///
/// What a reading says is an area of life and a disposition. It never says
/// what will happen.
library;

import '../astro/ephemeris.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'rashi.dart';
import 'yogas.dart';

enum SudarshanReference { lagna, chandra, surya }

extension SudarshanReferenceNames on SudarshanReference {
  String get english => switch (this) {
    SudarshanReference.lagna => 'Lagna',
    SudarshanReference.chandra => 'Chandra',
    SudarshanReference.surya => 'Surya',
  };

  String get hindi => switch (this) {
    SudarshanReference.lagna => 'लग्न',
    SudarshanReference.chandra => 'चंद्र',
    SudarshanReference.surya => 'सूर्य',
  };

  /// What the reference stands for in the tradition.
  String get standsForEnglish => switch (this) {
    SudarshanReference.lagna => 'the body and outer life',
    SudarshanReference.chandra => 'the mind and feeling',
    SudarshanReference.surya => 'the soul and standing',
  };

  String get standsForHindi => switch (this) {
    SudarshanReference.lagna => 'शरीर और बाहरी जीवन',
    SudarshanReference.chandra => 'मन और भावना',
    SudarshanReference.surya => 'आत्मा और प्रतिष्ठा',
  };
}

enum HouseVerdict { strong, mixed, weak }

/// How many of the three references support a house.
enum SudarshanAgreement { all, two, one, none }

/// One house as it stands in one ring.
class HouseStanding {
  const HouseStanding({
    required this.reference,
    required this.sign,
    required this.favourable,
    required this.unfavourable,
    required this.verdict,
    required this.factorsEnglish,
    required this.factorsHindi,
  });

  final SudarshanReference reference;

  /// Zero-based sign index of the house in this ring.
  final int sign;
  final int favourable;
  final int unfavourable;
  final HouseVerdict verdict;

  /// The chart factors the verdict was read from, one short line each.
  final List<String> factorsEnglish;
  final List<String> factorsHindi;

  Rashi get rashi => Rashi.values[sign];
}

/// One house across all three rings, with a short reading.
class SudarshanHouse {
  const SudarshanHouse({
    required this.house,
    required this.fromLagna,
    required this.fromChandra,
    required this.fromSurya,
    required this.agreement,
    required this.areaEnglish,
    required this.areaHindi,
    required this.readingEnglish,
    required this.readingHindi,
  });

  /// 1 to 12.
  final int house;
  final HouseStanding fromLagna;
  final HouseStanding fromChandra;
  final HouseStanding fromSurya;
  final SudarshanAgreement agreement;
  final String areaEnglish;
  final String areaHindi;
  final String readingEnglish;
  final String readingHindi;

  List<HouseStanding> get standings => <HouseStanding>[
    fromLagna,
    fromChandra,
    fromSurya,
  ];

  int get strongCount => standings
      .where((HouseStanding s) => s.verdict == HouseVerdict.strong)
      .length;
}

class SudarshanChakra {
  const SudarshanChakra({
    required this.houses,
    required this.referencesCoincide,
    required this.noteEnglish,
    required this.noteHindi,
  });

  /// Twelve houses, 1 to 12.
  final List<SudarshanHouse> houses;

  /// True when two or three of the lagna, Moon and Sun share a sign, in which
  /// case BPHS 74.20 says to read from the lagna.
  final bool referencesCoincide;
  final String noteEnglish;
  final String noteHindi;
}

const List<String> _areaEnglish = <String>[
  '',
  'the self: body, temperament and the direction of a life',
  'resources, speech and the family one is born into',
  'effort, courage, skills and siblings',
  'home, inner peace and the mother’s side',
  'learning, creativity and devotion',
  'daily work, service and meeting opposition',
  'partnership and dealings with others',
  'change, the hidden and shared resources',
  'fortune, teachers and dharma',
  'work, standing and responsibility',
  'gains, friends and the fulfilment of aims',
  'outlay, retreat and distant places',
];

const List<String> _areaHindi = <String>[
  '',
  'स्वयं: शरीर, स्वभाव और जीवन की दिशा',
  'संचय, वाणी और जन्म का परिवार',
  'प्रयास, साहस, कौशल और भाई-बहन',
  'घर, मन की शांति और माता का पक्ष',
  'विद्या, सृजन और भक्ति',
  'दैनिक कार्य, सेवा और विरोध का सामना',
  'साझेदारी और दूसरों से व्यवहार',
  'परिवर्तन, छिपी बातें और साझा संसाधन',
  'भाग्य, गुरुजन और धर्म',
  'कर्म, प्रतिष्ठा और ज़िम्मेदारी',
  'लाभ, मित्र और उद्देश्यों की पूर्ति',
  'व्यय, एकांत और दूर के स्थान',
];

String _hiOrd(int n) => const <String>[
  '',
  'पहले',
  'दूसरे',
  'तीसरे',
  'चौथे',
  'पाँचवें',
  'छठे',
  'सातवें',
  'आठवें',
  'नौवें',
  'दसवें',
  'ग्यारहवें',
  'बारहवें',
][n];

String _enOrd(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};

HouseStanding _judge(
  Kundli k,
  SudarshanReference reference,
  int referenceSign,
  int house,
) {
  final int sign = (referenceSign + house - 1) % 12;
  final Graha lord = rashiInfo(Rashi.values[sign]).lord;
  final List<String> en = <String>[];
  final List<String> hi = <String>[];
  int favourable = 0;
  int unfavourable = 0;

  String nameEn(Graha g) => grahaInfo(g).english;
  String nameHi(Graha g) => grahaInfo(g).hindi;

  // The lord's own joining or aspect (BPHS 74.10).
  final PlacedGraha lordPlaced = k.grahas[lord]!;
  final bool lordHere = lordPlaced.rashi.index == sign;
  final bool lordSees = !lordHere && grahaAspectsSign(k, lord, sign);
  if (lordHere || lordSees) {
    favourable += 1;
    en.add(
      'Its lord ${nameEn(lord)} ${lordHere ? 'stands in it' : 'aspects it'} (BPHS 74.10).',
    );
    hi.add(
      'इसके स्वामी ${nameHi(lord)} ${lordHere ? 'इसी में हैं' : 'इसे देखते हैं'} (बृहत्पाराशर 74.10)।',
    );
  }

  for (final Graha g in Graha.values) {
    if (g == lord) continue;
    final PlacedGraha p = k.grahas[g]!;
    final bool occupant = p.rashi.index == sign;
    final bool aspect = !occupant && grahaAspectsSign(k, g, sign);
    if (!occupant && !aspect) continue;

    final bool benefic = isNaturallyBenefic(k, g);
    final String how = occupant ? 'occupies' : 'aspects';
    final String howHi = occupant ? 'इसमें है' : 'इसे देखता है';

    if (benefic) {
      favourable += 1;
      en.add('${nameEn(g)}, a benefic, $how it (BPHS 74.12).');
      hi.add('${nameHi(g)}, शुभ ग्रह, $howHi (बृहत्पाराशर 74.12)।');
      continue;
    }

    // A malefic. The exceptions of 74.8, 74.9, 74.24 and 74.25 first.
    if (g == Graha.sun && occupant && house == 1) {
      favourable += 1;
      en.add(
        'The Sun occupies the first house of this ring, where it is welcome (BPHS 74.8).',
      );
      hi.add(
        'सूर्य इस चक्र के पहले भाव में है, जहाँ वह शुभ है (बृहत्पाराशर 74.8)।',
      );
    } else if (g == Graha.rahu && occupant) {
      unfavourable += 1;
      en.add(
        'Rahu occupies it, and the text says Rahu harms the house he sits in (BPHS 74.24).',
      );
      hi.add(
        'राहु इसमें है, और श्लोक कहता है कि राहु जिस भाव में बैठे उसे हानि पहुँचाता है (बृहत्पाराशर 74.24)।',
      );
    } else if (occupant && p.dignity == Dignity.exalted) {
      en.add(
        '${nameEn(g)}, a malefic, is exalted here and does no harm (BPHS 74.9).',
      );
      hi.add(
        '${nameHi(g)}, पाप ग्रह, यहाँ उच्च का है और हानि नहीं करता (बृहत्पाराशर 74.9)।',
      );
    } else if (occupant && <int>[3, 6, 11].contains(house)) {
      favourable += 1;
      en.add(
        '${nameEn(g)}, a malefic, occupies a ${_enOrd(house)} house, where malefics give good results (BPHS 74.25).',
      );
      hi.add(
        '${nameHi(g)}, पाप ग्रह, ${_hiOrd(house)} भाव में है, जहाँ पाप ग्रह शुभ फल देते हैं (बृहत्पाराशर 74.25)।',
      );
    } else if (g == Graha.sun && occupant) {
      unfavourable += 1;
      en.add(
        'The Sun occupies it, and the Sun is unwelcome outside the first house (BPHS 74.8).',
      );
      hi.add(
        'सूर्य इसमें है, और सूर्य पहले भाव के बाहर अशुभ माना गया है (बृहत्पाराशर 74.8)।',
      );
    } else {
      unfavourable += 1;
      en.add('${nameEn(g)}, a malefic, $how it (BPHS 74.10).');
      hi.add('${nameHi(g)}, पाप ग्रह, $howHi (बृहत्पाराशर 74.10)।');
    }
  }

  HouseVerdict verdict;
  if (favourable + unfavourable == 0) {
    // Nothing in the house and nothing on it: judged by the lord's strength
    // (BPHS 74.14, 74.16).
    final Dignity d = lordPlaced.dignity;
    if (d == Dignity.exalted || d == Dignity.own || d == Dignity.moolatrikona) {
      verdict = HouseVerdict.strong;
    } else if (d == Dignity.debilitated || d == Dignity.enemy) {
      verdict = HouseVerdict.weak;
    } else {
      verdict = HouseVerdict.mixed;
    }
    en.add(
      'Empty and unaspected, so it is judged by its lord ${nameEn(lord)}, who stands in ${rashiInfo(lordPlaced.rashi).english} (${lordPlaced.dignity.name}) (BPHS 74.14).',
    );
    hi.add(
      'खाली है और किसी की दृष्टि नहीं, इसलिए इसे इसके स्वामी ${nameHi(lord)} के बल से आँका गया, जो ${rashiInfo(lordPlaced.rashi).hindi} में हैं (बृहत्पाराशर 74.14)।',
    );
  } else if (favourable > unfavourable) {
    verdict = HouseVerdict.strong;
  } else if (unfavourable > favourable) {
    verdict = HouseVerdict.weak;
  } else {
    verdict = HouseVerdict.mixed;
  }

  return HouseStanding(
    reference: reference,
    sign: sign,
    favourable: favourable,
    unfavourable: unfavourable,
    verdict: verdict,
    factorsEnglish: en,
    factorsHindi: hi,
  );
}

SudarshanAgreement _agreementOf(int strong) => switch (strong) {
  3 => SudarshanAgreement.all,
  2 => SudarshanAgreement.two,
  1 => SudarshanAgreement.one,
  _ => SudarshanAgreement.none,
};

({String en, String hi}) _reading(
  int house,
  List<HouseStanding> standings,
  SudarshanAgreement agreement,
) {
  final String area = _areaEnglish[house];
  final String areaHi = _areaHindi[house];
  final List<SudarshanReference> strong = standings
      .where((HouseStanding s) => s.verdict == HouseVerdict.strong)
      .map((HouseStanding s) => s.reference)
      .toList();
  final List<SudarshanReference> weak = standings
      .where((HouseStanding s) => s.verdict == HouseVerdict.weak)
      .map((HouseStanding s) => s.reference)
      .toList();
  String names(List<SudarshanReference> l) =>
      l.map((SudarshanReference r) => r.english).join(' and ');
  String namesHi(List<SudarshanReference> l) =>
      l.map((SudarshanReference r) => r.hindi).join(' और ');

  switch (agreement) {
    case SudarshanAgreement.all:
      return (
        en: 'Supported from the Lagna, the Chandra and the Surya at once: the body, the mind and the soul all stand behind this area, $area. This is the classical signature of a reliably good area of life.',
        hi: 'लग्न, चंद्र और सूर्य तीनों से बल मिलता है: शरीर, मन और आत्मा तीनों इस क्षेत्र के पीछे हैं, $areaHi। यही किसी जीवन-क्षेत्र के भरोसेमंद रूप से अच्छे होने का शास्त्रीय लक्षण है।',
      );
    case SudarshanAgreement.two:
      return (
        en: 'Supported from ${names(strong)} but not from the third reference: $area. The tradition reads it as good more often than not.',
        hi: '${namesHi(strong)} से बल मिलता है, तीसरे से नहीं: $areaHi। परंपरा इसे प्रायः शुभ पढ़ती है।',
      );
    case SudarshanAgreement.one:
      return (
        en: 'Supported only from ${names(strong)}: $area. A house that stands well from a single reference is not read as reliable, so this area rewards attention more than it can be counted on.',
        hi: 'केवल ${namesHi(strong)} से बल मिलता है: $areaHi। जो भाव एक ही संदर्भ से बलवान हो उसे भरोसेमंद नहीं पढ़ा जाता, इसलिए इस क्षेत्र पर भरोसा करने से अधिक ध्यान देना फलदायी है।',
      );
    case SudarshanAgreement.none:
      if (weak.length == 3) {
        return (
          en: 'Not supported from any of the three references: $area. This is the area that asks for steady effort and good habits; the chakra describes where the effort is needed, not what will come of it.',
          hi: 'तीनों में से किसी संदर्भ से बल नहीं मिलता: $areaHi। यह वह क्षेत्र है जो निरंतर प्रयास और अच्छी आदतें माँगता है; चक्र बताता है कि प्रयास कहाँ चाहिए, उसका फल क्या होगा यह नहीं।',
        );
      }
      return (
        en: 'Mixed from the three references: $area. Neither clearly supported nor clearly pressed, so it takes its colour from how it is tended.',
        hi: 'तीनों संदर्भों से मिश्रित: $areaHi। न स्पष्ट बल, न स्पष्ट दबाव, इसलिए इसका रंग इस पर निर्भर है कि इसकी देखभाल कैसे की जाती है।',
      );
  }
}

/// Reads all twelve houses from the lagna, the Moon and the Sun.
SudarshanChakra computeSudarshan(Kundli kundli) {
  final int lagna = kundli.lagnaRashi.index;
  final int moon = kundli.grahas[Graha.moon]!.rashi.index;
  final int sun = kundli.grahas[Graha.sun]!.rashi.index;

  final List<SudarshanHouse> houses = <SudarshanHouse>[];
  for (int h = 1; h <= 12; h++) {
    final HouseStanding a = _judge(kundli, SudarshanReference.lagna, lagna, h);
    final HouseStanding b = _judge(kundli, SudarshanReference.chandra, moon, h);
    final HouseStanding c = _judge(kundli, SudarshanReference.surya, sun, h);
    final List<HouseStanding> all = <HouseStanding>[a, b, c];
    final int strong = all
        .where((HouseStanding s) => s.verdict == HouseVerdict.strong)
        .length;
    final SudarshanAgreement agreement = _agreementOf(strong);
    final ({String en, String hi}) reading = _reading(h, all, agreement);
    houses.add(
      SudarshanHouse(
        house: h,
        fromLagna: a,
        fromChandra: b,
        fromSurya: c,
        agreement: agreement,
        areaEnglish: _areaEnglish[h],
        areaHindi: _areaHindi[h],
        readingEnglish: reading.en,
        readingHindi: reading.hi,
      ),
    );
  }

  final bool coincide = lagna == moon || lagna == sun || moon == sun;
  return SudarshanChakra(
    houses: houses,
    referencesCoincide: coincide,
    noteEnglish: coincide
        ? 'Two of the three references fall in the same sign, and BPHS 74.20 says to read from the lagna in that case. The agreement shown across the three rings is therefore less independent than it looks.'
        : 'The Lagna, the Moon and the Sun fall in three different signs, so the three rings give three independent readings of each house (BPHS 74.20).',
    noteHindi: coincide
        ? 'तीन संदर्भों में से दो एक ही राशि में हैं, और बृहत्पाराशर 74.20 ऐसे में लग्न से फल कहने को कहता है। इसलिए तीनों चक्रों में दिखने वाली सहमति उतनी स्वतंत्र नहीं है जितनी दिखती है।'
        : 'लग्न, चंद्र और सूर्य तीन अलग राशियों में हैं, इसलिए तीनों चक्र हर भाव के तीन स्वतंत्र पाठ देते हैं (बृहत्पाराशर 74.20)।',
  );
}
