import '../astro/ephemeris.dart';
import 'bilingual.dart';
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

/// The traditional japa count for a full course of each graha's mantra, as
/// the remedy tables commonly list it. Lineages differ a little, and no verse
/// is quoted for these numbers.
const Map<Graha, int> japaCounts = <Graha, int>{
  Graha.sun: 7000,
  Graha.moon: 11000,
  Graha.mars: 10000,
  Graha.mercury: 9000,
  Graha.jupiter: 19000,
  Graha.venus: 16000,
  Graha.saturn: 23000,
  Graha.rahu: 18000,
  Graha.ketu: 17000,
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

// ---------------------------------------------------------------------------
// Remedies that belong to a finding
// ---------------------------------------------------------------------------
//
// Phaladesh attaches an upaya to every strained house, every difficult period,
// every adverse yoga and every testing transit. What it attaches is the
// classical kit for the graha concerned (mantra, japa count, fasting day,
// deity, daan, one plain act) together with a line saying which graha it is
// for and which affliction it answers, so it is never a generic list.
//
// House rules, held by tests:
//  * A remedy is a mantra, a fast, giving, service or a discipline. Nothing
//    in it has to be bought from anyone, nothing is a paid ritual, and no
//    gemstone, ring, yantra or amulet is ever recommended.
//  * It is offered as what the tradition prescribes to strengthen a graha and
//    as nothing more: no remedy says or implies that anything will change.
//  * These are common practice, handed down in the remedy tables, and no verse
//    is quoted for any of them.

/// What the tradition commonly prescribes for one graha.
class GrahaRemedyKit {
  const GrahaRemedyKit._({
    required this.graha,
    required this.mantra,
    required this.japaCount,
    required this.japa,
    required this.fastDay,
    required this.fast,
    required this.deity,
    required this.daan,
    required this.simpleAct,
  });

  final Graha graha;

  /// The mantra itself, in Latin letters for English and in Devanagari for
  /// Hindi.
  final Bi mantra;

  /// The traditional count for a full course.
  final int japaCount;

  /// The count, and the light way most people keep it.
  final Bi japa;

  /// 0 = Sunday.
  final int fastDay;
  final Bi fast;
  final Bi deity;
  final Bi daan;
  final Bi simpleAct;

  Iterable<Bi> get texts => <Bi>[mantra, japa, fast, deity, daan, simpleAct];
}

const List<Bi> _dayNames = <Bi>[
  Bi('Sunday', 'रविवार'),
  Bi('Monday', 'सोमवार'),
  Bi('Tuesday', 'मंगलवार'),
  Bi('Wednesday', 'बुधवार'),
  Bi('Thursday', 'गुरुवार'),
  Bi('Friday', 'शुक्रवार'),
  Bi('Saturday', 'शनिवार'),
];

String _thousands(int n) {
  final String digits = n.toString();
  return digits.length <= 3
      ? digits
      : '${digits.substring(0, digits.length - 3)},${digits.substring(digits.length - 3)}';
}

GrahaRemedyKit _kit({
  required Graha graha,
  required String mantraHindi,
  required Bi deity,
  required Bi daanItems,
  required Bi simpleAct,
}) {
  final int count = japaCounts[graha]!;
  final int day = grahaInfo(graha).weekday;
  final Bi dayName = _dayNames[day];
  final String total = _thousands(count);
  return GrahaRemedyKit._(
    graha: graha,
    mantra: Bi(grahaInfo(graha).mantra, mantraHindi),
    japaCount: count,
    japa: Bi(
      'Traditional count: $total repetitions in all, as the remedy tables commonly list it (lineages differ a little). Most people keep it as one mala of 108 a day, or on ${dayName.en}; the full count is the traditional target, not a requirement.',
      'परंपरा की गिनती: कुल $total जप (उपाय की तालिकाओं में यही संख्या आम है; अलग-अलग परंपराओं में थोड़ा फ़र्क़ मिलता है)। ज़्यादातर लोग रोज़ एक माला (108 जप) करते हैं, या सिर्फ़ ${dayName.hi} को; पूरी गिनती परंपरा का लक्ष्य है, ज़रूरी शर्त नहीं।',
    ),
    fastDay: day,
    fast: Bi(
      '${dayName.en}: a light fast (one simple meal, or fruit and water). Anyone for whom fasting does not suit keeps the day with the mantra and giving alone.',
      '${dayName.hi}: हल्का व्रत (एक सादा भोजन, या फल और पानी)। जिन्हें उपवास रास न आए, वे उस दिन सिर्फ़ मंत्र और दान करें।',
    ),
    deity: deity,
    daan: Bi(
      'Traditionally: ${daanItems.en}. Give what you already have at home, or can spare, with your own hand to someone who needs it. The item and the amount are not fixed.',
      'परंपरा में: ${daanItems.hi}। जो आपके घर में है या जो आप दे सकें, वह अपने हाथ से किसी ज़रूरतमंद को दें। चीज़ और मात्रा तय नहीं है।',
    ),
    simpleAct: simpleAct,
  );
}

/// The kit for each of the nine grahas.
final Map<Graha, GrahaRemedyKit> grahaRemedyKits = <Graha, GrahaRemedyKit>{
  Graha.sun: _kit(
    graha: Graha.sun,
    mantraHindi: 'ॐ ह्रां ह्रीं ह्रौं सः सूर्याय नमः',
    deity: const Bi('Surya Dev', 'सूर्य देव'),
    daanItems: const Bi(
      'wheat, jaggery and red cloth',
      'गेहूँ, गुड़ और लाल कपड़ा',
    ),
    simpleAct: const Bi(
      'Offer water to the rising Sun and stand in the morning light for a few minutes.',
      'सुबह उगते सूरज को जल चढ़ाएँ और कुछ मिनट धूप में खड़े रहें।',
    ),
  ),
  Graha.moon: _kit(
    graha: Graha.moon,
    mantraHindi: 'ॐ श्रां श्रीं श्रौं सः चंद्राय नमः',
    deity: const Bi('Shiva, with Parvati', 'शिव, पार्वती के साथ'),
    daanItems: const Bi(
      'rice, milk, sugar and white cloth',
      'चावल, दूध, चीनी और सफ़ेद कपड़ा',
    ),
    simpleAct: const Bi(
      'Keep a regular bedtime, and spend time with your mother or an elder woman of the house.',
      'समय पर सोएँ और माँ या घर की किसी बड़ी स्त्री के साथ कुछ समय बिताएँ।',
    ),
  ),
  Graha.mars: _kit(
    graha: Graha.mars,
    mantraHindi: 'ॐ क्रां क्रीं क्रौं सः भौमाय नमः',
    deity: const Bi('Hanuman, or Kartikeya', 'हनुमान जी, या कार्तिकेय'),
    daanItems: const Bi(
      'red lentils, jaggery and red cloth',
      'मसूर की दाल, गुड़ और लाल कपड़ा',
    ),
    simpleAct: const Bi(
      'Give an hour a day to hard physical work or a brisk walk, and pause before you answer in anger.',
      'रोज़ एक घंटा मेहनत का काम या तेज़ चलना रखें, और ग़ुस्से में जवाब देने से पहले रुकें।',
    ),
  ),
  Graha.mercury: _kit(
    graha: Graha.mercury,
    mantraHindi: 'ॐ ब्रां ब्रीं ब्रौं सः बुधाय नमः',
    deity: const Bi('Vishnu', 'विष्णु'),
    daanItems: const Bi(
      'green gram (moong), green vegetables and books for a child',
      'मूंग की दाल, हरी सब्ज़ियाँ और किसी बच्चे के लिए किताबें',
    ),
    simpleAct: const Bi(
      'Keep your word even on small things, and read or learn something new for a few minutes every day.',
      'छोटी बातों में भी अपना वचन निभाएँ, और रोज़ कुछ मिनट कुछ नया पढ़ें या सीखें।',
    ),
  ),
  Graha.jupiter: _kit(
    graha: Graha.jupiter,
    mantraHindi: 'ॐ ग्रां ग्रीं ग्रौं सः गुरवे नमः',
    deity: const Bi('Vishnu, and Brihaspati', 'विष्णु, और बृहस्पति'),
    daanItems: const Bi(
      'chana dal, turmeric, ghee and yellow cloth',
      'चने की दाल, हल्दी, घी और पीला कपड़ा',
    ),
    simpleAct: const Bi(
      'Sit with a teacher or an elder once a week and listen without arguing.',
      'हफ़्ते में एक बार किसी गुरु या बड़े के पास बैठें और बिना बहस किए सुनें।',
    ),
  ),
  Graha.venus: _kit(
    graha: Graha.venus,
    mantraHindi: 'ॐ द्रां द्रीं द्रौं सः शुक्राय नमः',
    deity: const Bi('Lakshmi, and Durga', 'लक्ष्मी, और दुर्गा'),
    daanItems: const Bi(
      'rice, sugar, curd and white cloth',
      'चावल, चीनी, दही और सफ़ेद कपड़ा',
    ),
    simpleAct: const Bi(
      'Keep one corner of your home clean and pleasant, and speak gently to the person closest to you.',
      'घर का एक कोना साफ़ और सुंदर रखें, और अपने सबसे क़रीबी इंसान से नरमी से बात करें।',
    ),
  ),
  Graha.saturn: _kit(
    graha: Graha.saturn,
    mantraHindi: 'ॐ प्रां प्रीं प्रौं सः शनैश्चराय नमः',
    deity: const Bi('Hanuman, and Shani Dev', 'हनुमान जी, और शनि देव'),
    daanItems: const Bi(
      'black sesame, mustard oil, black urad dal, or a meal for someone who works with their hands',
      'काले तिल, सरसों का तेल, काली उड़द की दाल, या हाथ से मेहनत करने वाले को भोजन',
    ),
    simpleAct: const Bi(
      'Finish one task you have been postponing each week, and be kind to someone who works with their hands.',
      'हर हफ़्ते एक टाला हुआ काम पूरा करें, और हाथ से मेहनत करने वाले के साथ भलाई से पेश आएँ।',
    ),
  ),
  Graha.rahu: _kit(
    graha: Graha.rahu,
    mantraHindi: 'ॐ भ्रां भ्रीं भ्रौं सः राहवे नमः',
    deity: const Bi('Durga', 'दुर्गा'),
    daanItems: const Bi(
      'a blanket, mustard and a coconut',
      'कंबल, सरसों और नारियल',
    ),
    simpleAct: const Bi(
      'Cut an hour of screen time a day and spend it on something you do with your hands.',
      'रोज़ एक घंटा स्क्रीन कम करें और वह समय हाथ से किए जाने वाले किसी काम को दें।',
    ),
  ),
  Graha.ketu: _kit(
    graha: Graha.ketu,
    mantraHindi: 'ॐ स्रां स्रीं स्रौं सः केतवे नमः',
    deity: const Bi('Ganesha', 'गणेश जी'),
    daanItems: const Bi(
      'a blanket, sesame and food for street dogs',
      'कंबल, तिल और गली के कुत्तों के लिए भोजन',
    ),
    simpleAct: const Bi(
      'Feed a street dog, and keep ten quiet minutes a day without your phone.',
      'किसी गली के कुत्ते को रोटी दें, और रोज़ दस मिनट फ़ोन के बिना चुपचाप बैठें।',
    ),
  ),
};

/// One remedy attached to one finding: the graha's kit, and the plain
/// statement of which graha it is for and which affliction it answers.
class Remedy {
  const Remedy({required this.graha, required this.addresses});

  final Graha graha;

  /// Which graha this is for, and what presses on it. Never generic.
  final Bi addresses;

  GrahaRemedyKit get kit => grahaRemedyKits[graha]!;

  Iterable<Bi> get texts => <Bi>[addresses, ...kit.texts];
}

/// Said once under any set of remedies: what they are and what they are not.
const Bi remedyStance = Bi(
  'These are what the tradition commonly prescribes to strengthen a graha. They are common practice handed down in the tradition, and no verse is quoted for them. They are offered as practice only and promise nothing about what will happen. Each one can be done at home, by you, with what you already have.',
  'ये वे उपाय हैं जो परंपरा में ग्रह को बल देने के लिए आम तौर पर बताए जाते हैं। ये परंपरा से चले आ रहे चलन हैं, इनके लिए कोई श्लोक नहीं दिया गया है। इन्हें सिर्फ़ अभ्यास की तरह रखा गया है; ये आगे क्या होगा, इसका कोई वादा नहीं करते। हर उपाय आप घर पर, ख़ुद, अपने पास जो है उसी से कर सकते हैं।',
);

/// Every text of a set of remedies, with the stance said once.
Iterable<Bi> remedyTexts(List<Remedy> remedies) => <Bi>[
  if (remedies.isNotEmpty) remedyStance,
  for (final Remedy r in remedies) ...r.texts,
];
