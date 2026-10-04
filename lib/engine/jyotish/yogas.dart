import '../astro/angles.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'rashi.dart';

/// A yoga or dosha the chart actually carries, with the rule that fired.
class YogaFinding {
  const YogaFinding({
    required this.key,
    required this.nameEnglish,
    required this.nameHindi,
    required this.isDosha,
    required this.ruleEnglish,
    required this.ruleHindi,
    required this.meaningEnglish,
    required this.meaningHindi,
    this.cancellationEnglish,
    this.cancellationHindi,
  });

  final String key;
  final String nameEnglish;
  final String nameHindi;
  final bool isDosha;

  /// The condition in the chart that produced this finding.
  final String ruleEnglish;
  final String ruleHindi;
  final String meaningEnglish;
  final String meaningHindi;

  /// What classical texts say weakens or cancels it, when something does.
  final String? cancellationEnglish;
  final String? cancellationHindi;

  bool get isCancelled => cancellationEnglish != null;
}

const List<int> _kendras = <int>[1, 4, 7, 10];
const List<int> _trikonas = <int>[1, 5, 9];

int _houseFrom(int fromSign, int ofSign) => ((ofSign - fromSign + 12) % 12) + 1;

List<YogaFinding> findYogas(Kundli kundli) {
  final List<YogaFinding> out = <YogaFinding>[];
  final Map<Graha, PlacedGraha> g = kundli.grahas;

  // Mangal (Kuja) dosha.
  final int marsHouse = g[Graha.mars]!.house;
  final int marsFromMoon = _houseFrom(
    g[Graha.moon]!.rashi.index,
    g[Graha.mars]!.rashi.index,
  );
  if (<int>[1, 2, 4, 7, 8, 12].contains(marsHouse) ||
      <int>[1, 2, 4, 7, 8, 12].contains(marsFromMoon)) {
    final Dignity dignity = g[Graha.mars]!.dignity;
    final bool strongMars =
        dignity == Dignity.own ||
        dignity == Dignity.exalted ||
        dignity == Dignity.moolatrikona;
    final bool jupiterWith =
        g[Graha.jupiter]!.rashi.index == g[Graha.mars]!.rashi.index;
    out.add(
      YogaFinding(
        key: 'mangal_dosha',
        nameEnglish: 'Mangal dosha',
        nameHindi: 'मंगल दोष',
        isDosha: true,
        ruleEnglish:
            'Mars stands in house $marsHouse from the lagna and house $marsFromMoon from the Moon.',
        ruleHindi:
            'मंगल लग्न से $marsHouseवें और चंद्र से $marsFromMoonवें भाव में है।',
        meaningEnglish: 'Classically read as friction in marriage and a hot temper early in life. It is extremely common and it is not a verdict on anyone.',
        meaningHindi: 'परंपरा में इसे विवाह में टकराव और उग्र स्वभाव से जोड़ा गया है। यह बहुत आम है और किसी पर फैसला नहीं है।',
        cancellationEnglish: strongMars
            ? 'Mars is in its own or exalted sign, which the texts treat as cancelling the dosha.'
            : (jupiterWith
                  ? 'Jupiter sits with Mars, which the texts treat as cancelling the dosha.'
                  : null),
        cancellationHindi: strongMars
            ? 'मंगल अपनी राशि या उच्च में है, जिसे शास्त्र दोष का भंग मानते हैं।'
            : (jupiterWith
                  ? 'गुरु मंगल के साथ है, जिसे शास्त्र दोष का भंग मानते हैं।'
                  : null),
      ),
    );
  }

  // Kaal Sarpa: every graha between Rahu and Ketu.
  final double rahu = g[Graha.rahu]!.siderealLongitude;
  final double ketu = g[Graha.ketu]!.siderealLongitude;
  final Iterable<PlacedGraha> others = g.values.where(
    (PlacedGraha p) => p.graha != Graha.rahu && p.graha != Graha.ketu,
  );
  final bool allOneSide = others.every(
    (PlacedGraha p) =>
        norm360(p.siderealLongitude - rahu) < norm360(ketu - rahu),
  );
  final bool allOtherSide = others.every(
    (PlacedGraha p) =>
        norm360(p.siderealLongitude - ketu) < norm360(rahu - ketu),
  );
  if (allOneSide || allOtherSide) {
    out.add(
      const YogaFinding(
        key: 'kaal_sarpa',
        nameEnglish: 'Kaal Sarpa yoga',
        nameHindi: 'कालसर्प योग',
        isDosha: true,
        ruleEnglish: 'All seven grahas fall on one side of the Rahu-Ketu axis.',
        ruleHindi: 'सातों ग्रह राहु-केतु अक्ष के एक ही ओर हैं।',
        meaningEnglish: 'Read as a life of concentrated effort with delays before results. Many well-known charts carry it.',
        meaningHindi:
            'इसे परिश्रम और विलंब के बाद फल मिलने के रूप में पढ़ा जाता है।',
      ),
    );
  }

  // Gaja Kesari: Jupiter in a kendra from the Moon.
  final int jupiterFromMoon = _houseFrom(
    g[Graha.moon]!.rashi.index,
    g[Graha.jupiter]!.rashi.index,
  );
  if (_kendras.contains(jupiterFromMoon)) {
    out.add(
      YogaFinding(
        key: 'gaja_kesari',
        nameEnglish: 'Gaja Kesari yoga',
        nameHindi: 'गजकेसरी योग',
        isDosha: false,
        ruleEnglish: 'Jupiter stands in house $jupiterFromMoon from the Moon.',
        ruleHindi: 'गुरु चंद्र से $jupiterFromMoonवें भाव में है।',
        meaningEnglish:
            'Read as steady respect, good judgement and support from elders.',
        meaningHindi: 'इसे सम्मान, विवेक और बड़ों के सहयोग से जोड़ा जाता है।',
      ),
    );
  }

  // Budhaditya: Sun and Mercury in one sign.
  if (g[Graha.sun]!.rashi == g[Graha.mercury]!.rashi) {
    out.add(
      YogaFinding(
        key: 'budhaditya',
        nameEnglish: 'Budhaditya yoga',
        nameHindi: 'बुधादित्य योग',
        isDosha: false,
        ruleEnglish:
            'Sun and Mercury share ${rashiInfo(g[Graha.sun]!.rashi).english}.',
        ruleHindi:
            'सूर्य और बुध दोनों ${rashiInfo(g[Graha.sun]!.rashi).hindi} राशि में हैं।',
        meaningEnglish:
            'Read as clear speech, quick learning and administrative skill.',
        meaningHindi:
            'इसे स्पष्ट वाणी, तीव्र बुद्धि और प्रबंधन कौशल से जोड़ा जाता है।',
      ),
    );
  }

  // Panch Mahapurusha yogas.
  const Map<Graha, List<String>> mahapurusha = <Graha, List<String>>{
    Graha.mars: <String>['Ruchaka', 'रुचक'],
    Graha.mercury: <String>['Bhadra', 'भद्र'],
    Graha.jupiter: <String>['Hamsa', 'हंस'],
    Graha.venus: <String>['Malavya', 'मालव्य'],
    Graha.saturn: <String>['Shasha', 'शश'],
  };
  for (final MapEntry<Graha, List<String>> entry in mahapurusha.entries) {
    final PlacedGraha p = g[entry.key]!;
    final bool strong =
        p.dignity == Dignity.own ||
        p.dignity == Dignity.exalted ||
        p.dignity == Dignity.moolatrikona;
    if (strong && _kendras.contains(p.house)) {
      out.add(
        YogaFinding(
          key: 'mahapurusha_${entry.key.name}',
          nameEnglish: '${entry.value[0]} yoga',
          nameHindi: '${entry.value[1]} योग',
          isDosha: false,
          ruleEnglish:
              '${grahaInfo(entry.key).english} is strong in ${rashiInfo(p.rashi).english} and stands in kendra house ${p.house}.',
          ruleHindi:
              '${grahaInfo(entry.key).hindi} ${rashiInfo(p.rashi).hindi} राशि में बली है और ${p.house}वें केंद्र भाव में है।',
          meaningEnglish: 'One of the five Mahapurusha yogas, read as a marked strength of character in that planet’s area of life.',
          meaningHindi: 'पंच महापुरुष योगों में से एक, जो उस ग्रह के क्षेत्र में विशेष बल देता है।',
        ),
      );
    }
  }

  // Raja yoga: a kendra lord and a trikona lord sharing a sign.
  for (final int kendra in _kendras) {
    for (final int trikona in _trikonas) {
      if (kendra == trikona) continue;
      final Graha kendraLord = rashiInfo(
        Rashi.values[kundli.signOfHouse(kendra)],
      ).lord;
      final Graha trikonaLord = rashiInfo(
        Rashi.values[kundli.signOfHouse(trikona)],
      ).lord;
      if (kendraLord == trikonaLord) continue;
      if (g[kendraLord]!.rashi == g[trikonaLord]!.rashi) {
        out.add(
          YogaFinding(
            key: 'raja_yoga_${kendra}_$trikona',
            nameEnglish: 'Raja yoga',
            nameHindi: 'राजयोग',
            isDosha: false,
            ruleEnglish:
                'The lord of house $kendra (${grahaInfo(kendraLord).english}) and the lord of house $trikona (${grahaInfo(trikonaLord).english}) sit together.',
            ruleHindi:
                '$kendraवें भाव का स्वामी (${grahaInfo(kendraLord).hindi}) और $trikonaवें भाव का स्वामी (${grahaInfo(trikonaLord).hindi}) एक साथ हैं।',
            meaningEnglish: 'A classical combination for rise in standing through one’s own work.',
            meaningHindi: 'अपने कार्य से प्रतिष्ठा बढ़ने का शास्त्रीय योग।',
          ),
        );
      }
    }
  }

  // Kemadruma: the Moon with no graha in the 2nd or 12th from it.
  final int moonSign = g[Graha.moon]!.rashi.index;
  final bool neighbours = g.values.any(
    (PlacedGraha p) =>
        p.graha != Graha.moon &&
        p.graha != Graha.rahu &&
        p.graha != Graha.ketu &&
        (p.rashi.index == (moonSign + 1) % 12 ||
            p.rashi.index == (moonSign + 11) % 12 ||
            p.rashi.index == moonSign),
  );
  if (!neighbours) {
    out.add(
      const YogaFinding(
        key: 'kemadruma',
        nameEnglish: 'Kemadruma yoga',
        nameHindi: 'केमद्रुम योग',
        isDosha: true,
        ruleEnglish: 'No graha stands with the Moon or in the signs on either side of it.',
        ruleHindi:
            'चंद्र के साथ या उसके दोनों ओर की राशियों में कोई ग्रह नहीं है।',
        meaningEnglish: 'Read as having to build support for oneself rather than inheriting it. Kendra placements of other grahas are said to relieve it.',
        meaningHindi: 'इसे अपना आधार खुद बनाने के रूप में पढ़ा जाता है।',
      ),
    );
  }

  return out;
}

/// Where Saturn's seven-and-a-half year passage stands today.
class SadeSati {
  const SadeSati({
    required this.isRunning,
    required this.phase,
    required this.detail,
    required this.detailHindi,
  });

  final bool isRunning;

  /// 1, 2 or 3 while running; 0 otherwise.
  final int phase;
  final String detail;
  final String detailHindi;
}

SadeSati sadeSatiStatus(Kundli kundli, DateTime moment) {
  final Instant now = Instant.fromUtc(moment.toUtc());
  final double saturn = norm360(
    positionOf(Graha.saturn, now).tropicalLongitude - kundli.ayanamsaValue,
  );
  final int saturnSign = (saturn / 30).floor() % 12;
  final int moonSign = kundli.moonRashi.index;
  final int distance = (saturnSign - moonSign + 12) % 12;
  if (distance == 11 || distance == 0 || distance == 1) {
    final int phase = distance == 11 ? 1 : (distance == 0 ? 2 : 3);
    return SadeSati(
      isRunning: true,
      phase: phase,
      detail:
          'Saturn is in ${rashiInfo(Rashi.values[saturnSign]).english}, which is phase $phase of Sade Sati for a ${rashiInfo(Rashi.values[moonSign]).english} Moon.',
      detailHindi:
          'शनि ${rashiInfo(Rashi.values[saturnSign]).hindi} राशि में हैं, यह साढ़ेसाती का $phaseरा चरण है।',
    );
  }
  return SadeSati(
    isRunning: false,
    phase: 0,
    detail:
        'Saturn is in ${rashiInfo(Rashi.values[saturnSign]).english}; Sade Sati is not running.',
    detailHindi:
        'शनि ${rashiInfo(Rashi.values[saturnSign]).hindi} राशि में हैं; साढ़ेसाती नहीं चल रही।',
  );
}
