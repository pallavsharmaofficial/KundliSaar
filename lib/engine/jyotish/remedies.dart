import '../astro/ephemeris.dart';
import 'chart.dart';
import 'graha_data.dart';
import 'shadbala.dart';

/// Upay: what the tradition prescribes for a graha that is under pressure.
///
/// Mantra, fasting and giving are safe for anyone. A gemstone is the one
/// remedy the texts themselves treat as strong medicine, so the app always
/// says to ask someone knowledgeable before wearing one.
class RemedySet {
  const RemedySet({
    required this.graha,
    required this.reason,
    required this.reasonHindi,
    required this.japaCount,
    required this.gemstoneWeight,
    required this.finger,
    required this.fingerHindi,
    required this.daan,
    required this.daanHindi,
    required this.fastDay,
    required this.simpleAct,
    required this.simpleActHindi,
    required this.yantra,
  });

  final Graha graha;

  /// Why this graha came up for this chart.
  final String reason;
  final String reasonHindi;

  /// The classical japa count for one full round of the mantra.
  final int japaCount;
  final String gemstoneWeight;
  final String finger;
  final String fingerHindi;
  final String daan;
  final String daanHindi;

  /// 0 = Sunday.
  final int fastDay;

  /// Something anyone can do today, with no purchase.
  final String simpleAct;
  final String simpleActHindi;
  final String yantra;
}

const Map<Graha, int> japaCounts = <Graha, int>{
  Graha.sun: 7000,
  Graha.moon: 11000,
  Graha.mars: 10000,
  Graha.mercury: 9000,
  Graha.jupiter: 19000,
  Graha.venus: 16000,
  Graha.saturn: 23000,
  Graha.rahu: 18000,
  Graha.ketu: 7000,
};

const Map<Graha, List<String>> _remedyText = <Graha, List<String>>{
  // [gem weight, finger, finger hindi, daan, daan hindi, act, act hindi, yantra]
  Graha.sun: <String>[
    '3 to 5 ratti',
    'ring finger',
    'अनामिका',
    'wheat, jaggery, copper, red cloth',
    'गेहूँ, गुड़, ताँबा, लाल वस्त्र',
    'Offer water to the rising Sun and stand in the first light for a few minutes.',
    'सूर्य को जल दें और प्रातः की धूप में कुछ मिनट खड़े हों।',
    'Surya Yantra',
  ],
  Graha.moon: <String>[
    '4 to 6 ratti',
    'little finger',
    'कनिष्ठिका',
    'rice, milk, silver, white cloth',
    'चावल, दूध, चाँदी, सफ़ेद वस्त्र',
    'Keep water by the bed, serve your mother or an elder woman, and sleep at a regular hour.',
    'माँ या किसी बड़ी स्त्री की सेवा करें और समय पर सोएं।',
    'Chandra Yantra',
  ],
  Graha.mars: <String>[
    '6 to 9 ratti',
    'ring finger',
    'अनामिका',
    'red lentils, copper, red cloth',
    'मसूर दाल, ताँबा, लाल वस्त्र',
    'Give physical work an hour a day and keep your temper off other people.',
    'रोज़ एक घंटा श्रम करें और क्रोध पर संयम रखें।',
    'Mangal Yantra',
  ],
  Graha.mercury: <String>[
    '4 to 6 ratti',
    'little finger',
    'कनिष्ठिका',
    'green gram, green cloth, books',
    'मूंग दाल, हरा वस्त्र, पुस्तकें',
    'Give a book to a child who cannot buy one, and keep your word on small things.',
    'किसी बच्चे को पुस्तक दें और छोटे वचन भी निभाएँ।',
    'Budh Yantra',
  ],
  Graha.jupiter: <String>[
    '5 to 7 ratti',
    'index finger',
    'तर्जनी',
    'chana dal, turmeric, yellow cloth, ghee',
    'चना दाल, हल्दी, पीला वस्त्र, घी',
    'Sit with a teacher or an elder once a week and actually listen.',
    'सप्ताह में एक बार गुरु या बड़ों के पास बैठें।',
    'Guru Yantra',
  ],
  Graha.venus: <String>[
    '1 ratti and above',
    'middle or ring finger',
    'मध्यमा या अनामिका',
    'rice, sugar, white cloth, perfume',
    'चावल, चीनी, सफ़ेद वस्त्र, इत्र',
    'Keep one thing around you beautiful and clean, and treat your partner with courtesy.',
    'अपने आसपास स्वच्छता रखें और साथी से शिष्टता से बोलें।',
    'Shukra Yantra',
  ],
  Graha.saturn: <String>[
    '5 to 7 ratti',
    'middle finger',
    'मध्यमा',
    'black sesame, iron, mustard oil, black cloth',
    'काला तिल, लोहा, सरसों का तेल, काला वस्त्र',
    'Feed someone who works with their hands, and finish the dull task you keep postponing.',
    'श्रमिक को भोजन कराएँ और टाला हुआ काम पूरा करें।',
    'Shani Yantra',
  ],
  Graha.rahu: <String>[
    '6 to 9 ratti',
    'middle finger',
    'मध्यमा',
    'mustard, blankets, coconut',
    'सरसों, कंबल, नारियल',
    'Cut one hour of screens a day and give that hour to something with your hands.',
    'दिन में एक घंटा स्क्रीन कम करें।',
    'Rahu Yantra',
  ],
  Graha.ketu: <String>[
    '3 to 6 ratti',
    'little finger',
    'कनिष्ठिका',
    'blankets, sesame, food to dogs',
    'कंबल, तिल, कुत्तों को भोजन',
    'Feed a street dog, and keep ten quiet minutes a day with no phone.',
    'कुत्ते को रोटी दें और दस मिनट मौन रखें।',
    'Ketu Yantra',
  ],
};

/// Picks the grahas this chart is actually carrying weight for, and says why.
List<RemedySet> remediesFor(Kundli kundli, {int limit = 3}) {
  final Map<Graha, BalaBreakdown> bala = computeShadbala(kundli);
  final List<({Graha graha, double score, String why, String whyHindi})>
  ranked = <({Graha graha, double score, String why, String whyHindi})>[];

  for (final Graha graha in Graha.values) {
    final PlacedGraha placed = kundli.grahas[graha]!;
    double score = 0;
    final List<String> why = <String>[];
    final List<String> whyHindi = <String>[];

    if (placed.dignity == Dignity.debilitated) {
      score += 3;
      why.add('it is debilitated in ${placed.rashi.name}');
      whyHindi.add('यह नीच राशि में है');
    }
    if (placed.dignity == Dignity.enemy) {
      score += 1;
      why.add('it sits in an enemy sign');
      whyHindi.add('यह शत्रु राशि में है');
    }
    if (placed.isCombust) {
      score += 2;
      why.add('it is combust, too close to the Sun');
      whyHindi.add('यह सूर्य के पास अस्त है');
    }
    if (<int>[6, 8, 12].contains(placed.house)) {
      score += 1.5;
      why.add('it falls in house ${placed.house}');
      whyHindi.add('यह ${placed.house}वें भाव में है');
    }
    final BalaBreakdown? strength = bala[graha];
    if (strength != null && !strength.isStrong) {
      score += 2 * (1 - strength.ratio).clamp(0.0, 1.0);
      why.add(
        'its shadbala is ${strength.totalRupas.toStringAsFixed(1)} rupas against the ${strength.requiredRupas} it needs',
      );
      whyHindi.add(
        'षड़बल ${strength.totalRupas.toStringAsFixed(1)} रूप है, चाहिए ${strength.requiredRupas}',
      );
    }
    if (score > 0) {
      ranked.add((
        graha: graha,
        score: score,
        why: why.join(', '),
        whyHindi: whyHindi.join(', '),
      ));
    }
  }

  ranked.sort(
    (
      ({Graha graha, double score, String why, String whyHindi}) a,
      ({Graha graha, double score, String why, String whyHindi}) b,
    ) => b.score.compareTo(a.score),
  );

  return <RemedySet>[
    for (final ({Graha graha, double score, String why, String whyHindi}) entry
        in ranked.take(limit))
      RemedySet(
        graha: entry.graha,
        reason: 'Taken up because ${entry.why}.',
        reasonHindi: 'कारण: ${entry.whyHindi}।',
        japaCount: japaCounts[entry.graha]!,
        gemstoneWeight: _remedyText[entry.graha]![0],
        finger: _remedyText[entry.graha]![1],
        fingerHindi: _remedyText[entry.graha]![2],
        daan: _remedyText[entry.graha]![3],
        daanHindi: _remedyText[entry.graha]![4],
        fastDay: grahaInfo(entry.graha).weekday,
        simpleAct: _remedyText[entry.graha]![5],
        simpleActHindi: _remedyText[entry.graha]![6],
        yantra: _remedyText[entry.graha]![7],
      ),
  ];
}
