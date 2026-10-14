/// Ghat Chakra: the elements of a day that the tradition advises a person not
/// to choose for beginning something important, keyed on the janma rashi.
///
/// It is a muhurta aid. It says which month, tithi group, weekday, nakshatra,
/// yoga, karana, prahar and Moon sign to avoid when *choosing a day to begin*;
/// it says nothing about a person's life and nothing about how any day will go.
/// Nothing here is an event, and the readings it produces say so.
///
/// Where the table comes from. Every printed janampatri carries it, and the
/// rows are the widely published ones. They were checked against several
/// independent appearances of the same table:
///
///  * the complete twelve-row table at sanjayprabhakaran.blogspot.com
///    ("Ghaata Chakra", 2025), which is the source of every column;
///  * a Slideshare print of a sample kundli (the Mesha row: Kartika, tithis
///    1-6-11, Sunday, Magha, Vishkambha, Bava, prahar 1, Moon in Mesha);
///  * a user-posted sample on IndiaDivine (the Karka row: Pausha, tithis
///    2-7-12, Wednesday, Anuradha, Vyaghata, Naga, prahar 1);
///  * the astrologyapi.com ghat_chakra documentation sample (the Dhanu row:
///    Shravana, tithis 3-8-13, Friday, Bharani, Vajra, Taitila, prahar 1);
///  * Sanjay Rath's worked Mithuna example (tithis 2-7-12, Monday, Swati) and
///    his statement that Rikta tithis are the Makara ghat tithis;
///  * a Webdunia article, which gives the ghat-Moon sequence for the twelve
///    rashis from Mesha as 1, 5, 9, 2, 6, 10, 3, 7, 4, 8, 11, 12, the same
///    sequence as the blog table's first sign column.
///
/// The Vrishabha row (Saturday, Poorna, Hasta, Margashirsha, Sukarma, Shakuni,
/// prahar 4) was also seen quoted in a search snippet. The remaining rows rest
/// on the blog table alone: Simha, Kanya, Tula, Vrishchika, Makara, Kumbha and
/// Meena for the weekday, yoga, karana, prahar and month columns. Within the
/// table the nakshatra column advances in a regular nine-star step from a star
/// of each sign, and the month column uses every Hindu month once, which are
/// the marks of an uncorrupted table. The blog prints the yoga Vajra against
/// both Dhanu and Meena; it is kept as printed.
///
/// What is not in the table above, and where it is now:
///
///  * The ghat lagna. The common table prints no lagna column at all; its two
///    sign columns are the ghat Moon for a man and for a woman (the headings
///    differ between copies). A ghat lagna appears only in the table taught in
///    Sanjay Rath's lineage, which also differs from the common one in the
///    ghat Moon itself. [ghatChakraMatbhed] shows both, side by side.
///  * The lunar-month variant. No table keyed on the lunar birth month could be
///    found in any source; the common table already pairs each of the twelve
///    Hindu months with one rashi. What is disputed is how the month column is
///    matched to a day (lunar month, or the Sun's sign), which
///    [ghatMonthMatbhed] works out for a given date.
library;

import 'chart.dart';
import 'mat.dart';
import 'nakshatra.dart';
import 'panchang.dart';
import 'panchang_calendar.dart';
import 'rashi.dart';
import 'tajika_common.dart' show Bi;

/// The five groups of tithis, each three of the fifteen.
enum TithiGroup { nanda, bhadra, jaya, rikta, poorna }

extension TithiGroupNames on TithiGroup {
  String get english => switch (this) {
    TithiGroup.nanda => 'Nanda',
    TithiGroup.bhadra => 'Bhadra',
    TithiGroup.jaya => 'Jaya',
    TithiGroup.rikta => 'Rikta',
    TithiGroup.poorna => 'Poorna',
  };

  String get hindi => switch (this) {
    TithiGroup.nanda => 'नंदा',
    TithiGroup.bhadra => 'भद्रा',
    TithiGroup.jaya => 'जया',
    TithiGroup.rikta => 'रिक्ता',
    TithiGroup.poorna => 'पूर्णा',
  };

  /// The three tithis of the group, counted 1 to 15 in each fortnight.
  List<int> get tithis => switch (this) {
    TithiGroup.nanda => const <int>[1, 6, 11],
    TithiGroup.bhadra => const <int>[2, 7, 12],
    TithiGroup.jaya => const <int>[3, 8, 13],
    TithiGroup.rikta => const <int>[4, 9, 14],
    TithiGroup.poorna => const <int>[5, 10, 15],
  };
}

const List<String> hinduMonthsEnglish = <String>[
  'Chaitra',
  'Vaishakha',
  'Jyeshtha',
  'Ashadha',
  'Shravana',
  'Bhadrapada',
  'Ashwina',
  'Kartika',
  'Margashirsha',
  'Pausha',
  'Magha',
  'Phalguna',
];

const List<String> hinduMonthsHindi = <String>[
  'चैत्र',
  'वैशाख',
  'ज्येष्ठ',
  'आषाढ़',
  'श्रावण',
  'भाद्रपद',
  'आश्विन',
  'कार्तिक',
  'मार्गशीर्ष',
  'पौष',
  'माघ',
  'फाल्गुन',
];

/// 0 = Sunday, to match the rest of the engine.
const List<String> ghatWeekdaysEnglish = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const List<String> ghatWeekdaysHindi = <String>[
  'रविवार',
  'सोमवार',
  'मंगलवार',
  'बुधवार',
  'गुरुवार',
  'शुक्रवार',
  'शनिवार',
];

/// One row of the table: what to avoid beginning something on, for a given
/// janma rashi.
class GhatRow {
  const GhatRow({
    required this.rashi,
    required this.monthIndex,
    required this.tithiGroup,
    required this.weekday,
    required this.nakshatraIndex,
    required this.yogaEnglish,
    required this.yogaHindi,
    required this.karanaEnglish,
    required this.karanaHindi,
    required this.prahar,
    required this.chandra,
  });

  final Rashi rashi;

  /// Index into [hinduMonthsEnglish], 0 = Chaitra.
  final int monthIndex;
  final TithiGroup tithiGroup;

  /// 0 = Sunday.
  final int weekday;

  /// Zero-based index from Ashwini, as in [nakshatraTable].
  final int nakshatraIndex;
  final String yogaEnglish;
  final String yogaHindi;
  final String karanaEnglish;
  final String karanaHindi;

  /// The prahar, one eighth of the day and night together, counted from
  /// sunrise: 1 to 4 fall by day, 5 to 8 by night.
  final int prahar;

  /// The Moon sign the tradition calls the ghat Moon for this janma rashi.
  final Rashi chandra;

  String get monthEnglish => hinduMonthsEnglish[monthIndex];
  String get monthHindi => hinduMonthsHindi[monthIndex];
  String get weekdayEnglish => ghatWeekdaysEnglish[weekday];
  String get weekdayHindi => ghatWeekdaysHindi[weekday];
  NakshatraInfo get nakshatra => nakshatraTable[nakshatraIndex];
  bool get praharIsNight => prahar > 4;
}

/// The twelve rows, in the order Mesha to Meena. See the library comment for
/// how each was checked.
const List<GhatRow> ghatChakraTable = <GhatRow>[
  GhatRow(
    rashi: Rashi.mesha,
    monthIndex: 7,
    tithiGroup: TithiGroup.nanda,
    weekday: 0,
    nakshatraIndex: 9,
    yogaEnglish: 'Vishkambha',
    yogaHindi: 'विष्कुंभ',
    karanaEnglish: 'Bava',
    karanaHindi: 'बव',
    prahar: 1,
    chandra: Rashi.mesha,
  ),
  GhatRow(
    rashi: Rashi.vrishabha,
    monthIndex: 8,
    tithiGroup: TithiGroup.poorna,
    weekday: 6,
    nakshatraIndex: 12,
    yogaEnglish: 'Sukarma',
    yogaHindi: 'सुकर्मा',
    karanaEnglish: 'Shakuni',
    karanaHindi: 'शकुनि',
    prahar: 4,
    chandra: Rashi.simha,
  ),
  GhatRow(
    rashi: Rashi.mithuna,
    monthIndex: 3,
    tithiGroup: TithiGroup.bhadra,
    weekday: 1,
    nakshatraIndex: 14,
    yogaEnglish: 'Parigha',
    yogaHindi: 'परिघ',
    karanaEnglish: 'Chatushpada',
    karanaHindi: 'चतुष्पद',
    prahar: 3,
    chandra: Rashi.dhanu,
  ),
  GhatRow(
    rashi: Rashi.karka,
    monthIndex: 9,
    tithiGroup: TithiGroup.bhadra,
    weekday: 3,
    nakshatraIndex: 16,
    yogaEnglish: 'Vyaghata',
    yogaHindi: 'व्याघात',
    karanaEnglish: 'Naga',
    karanaHindi: 'नाग',
    prahar: 1,
    chandra: Rashi.vrishabha,
  ),
  GhatRow(
    rashi: Rashi.simha,
    monthIndex: 2,
    tithiGroup: TithiGroup.jaya,
    weekday: 6,
    nakshatraIndex: 18,
    yogaEnglish: 'Dhriti',
    yogaHindi: 'धृति',
    karanaEnglish: 'Bava',
    karanaHindi: 'बव',
    prahar: 1,
    chandra: Rashi.kanya,
  ),
  GhatRow(
    rashi: Rashi.kanya,
    monthIndex: 5,
    tithiGroup: TithiGroup.poorna,
    weekday: 6,
    nakshatraIndex: 21,
    yogaEnglish: 'Shubha',
    yogaHindi: 'शुभ',
    karanaEnglish: 'Kaulava',
    karanaHindi: 'कौलव',
    prahar: 1,
    chandra: Rashi.makara,
  ),
  GhatRow(
    rashi: Rashi.tula,
    monthIndex: 10,
    tithiGroup: TithiGroup.rikta,
    weekday: 4,
    nakshatraIndex: 23,
    yogaEnglish: 'Shukla',
    yogaHindi: 'शुक्ल',
    karanaEnglish: 'Taitila',
    karanaHindi: 'तैतिल',
    prahar: 4,
    chandra: Rashi.mithuna,
  ),
  GhatRow(
    rashi: Rashi.vrischika,
    monthIndex: 6,
    tithiGroup: TithiGroup.nanda,
    weekday: 5,
    nakshatraIndex: 26,
    yogaEnglish: 'Vyatipata',
    yogaHindi: 'व्यतीपात',
    karanaEnglish: 'Gara',
    karanaHindi: 'गर',
    prahar: 1,
    chandra: Rashi.tula,
  ),
  GhatRow(
    rashi: Rashi.dhanu,
    monthIndex: 4,
    tithiGroup: TithiGroup.jaya,
    weekday: 5,
    nakshatraIndex: 1,
    yogaEnglish: 'Vajra',
    yogaHindi: 'वज्र',
    karanaEnglish: 'Taitila',
    karanaHindi: 'तैतिल',
    prahar: 1,
    chandra: Rashi.karka,
  ),
  GhatRow(
    rashi: Rashi.makara,
    monthIndex: 1,
    tithiGroup: TithiGroup.rikta,
    weekday: 2,
    nakshatraIndex: 3,
    yogaEnglish: 'Vaidhriti',
    yogaHindi: 'वैधृति',
    karanaEnglish: 'Shakuni',
    karanaHindi: 'शकुनि',
    prahar: 4,
    chandra: Rashi.vrischika,
  ),
  GhatRow(
    rashi: Rashi.kumbha,
    monthIndex: 0,
    tithiGroup: TithiGroup.jaya,
    weekday: 4,
    nakshatraIndex: 5,
    yogaEnglish: 'Ganda',
    yogaHindi: 'गंड',
    karanaEnglish: 'Vanija',
    karanaHindi: 'वणिज',
    prahar: 3,
    chandra: Rashi.kumbha,
  ),
  GhatRow(
    rashi: Rashi.meena,
    monthIndex: 11,
    tithiGroup: TithiGroup.poorna,
    weekday: 5,
    nakshatraIndex: 8,
    yogaEnglish: 'Vajra',
    yogaHindi: 'वज्र',
    karanaEnglish: 'Vishti (Bhadra)',
    karanaHindi: 'विष्टि (भद्रा)',
    prahar: 6,
    chandra: Rashi.meena,
  ),
];

GhatRow ghatRowFor(Rashi janmaRashi) => ghatChakraTable[janmaRashi.index];

/// The ghat chakra of a person, with a statement in both languages.
class GhatChakraReading {
  const GhatChakraReading({
    required this.row,
    required this.statementEnglish,
    required this.statementHindi,
    required this.cautionEnglish,
    required this.cautionHindi,
    required this.factorsEnglish,
    required this.factorsHindi,
  });

  final GhatRow row;
  final String statementEnglish;
  final String statementHindi;

  /// What the table is for, and what it is not.
  final String cautionEnglish;
  final String cautionHindi;

  /// The chart factors the row was keyed on.
  final List<String> factorsEnglish;
  final List<String> factorsHindi;
}

/// Keys the table on the janma rashi, the convention of the printed table.
GhatChakraReading ghatChakraOf(Kundli kundli) {
  final Rashi moon = kundli.moonRashi;
  final GhatRow row = ghatRowFor(moon);
  final RashiInfo info = rashiInfo(moon);
  final RashiInfo chandra = rashiInfo(row.chandra);
  final String tithisEn = row.tithiGroup.tithis.join(', ');
  return GhatChakraReading(
    row: row,
    statementEnglish:
        'For a ${info.english} Moon, the ghat chakra marks these as poor choices for beginning something important: '
        '${row.tithiGroup.english} tithis ($tithisEn) of either fortnight, ${row.weekdayEnglish}, '
        '${row.nakshatra.english} nakshatra, ${row.yogaEnglish} yoga, ${row.karanaEnglish} karana, '
        'prahar ${row.prahar}, the month of ${row.monthEnglish}, and the Moon passing through ${chandra.english}.',
    statementHindi:
        '${info.hindi} राशि के चंद्र के लिए घात चक्र इन्हें कोई महत्वपूर्ण कार्य आरंभ करने के लिए अनुपयुक्त मानता है: '
        'दोनों पक्षों की ${row.tithiGroup.hindi} तिथियाँ ($tithisEn), ${row.weekdayHindi}, '
        '${row.nakshatra.hindi} नक्षत्र, ${row.yogaHindi} योग, ${row.karanaHindi} करण, '
        'प्रहर ${row.prahar}, ${row.monthHindi} मास, और चंद्रमा का ${chandra.hindi} राशि से गुज़रना।',
    cautionEnglish:
        'This is a muhurta aid for choosing a day to begin something, and nothing more. It says nothing about your life or how any day will go. The tradition weighs it more when several of these coincide on one day; a single one is only a reason to prefer another day when the panchang allows. Some traditions key the table on the lunar birth month instead of the Moon sign; this one uses the Moon sign.',
    cautionHindi:
        'यह कोई काम शुरू करने का दिन चुनने के लिए मुहूर्त का सहारा है, इससे अधिक कुछ नहीं। यह आपके जीवन या किसी दिन के बारे में कुछ नहीं कहता। परंपरा इसे तब अधिक महत्व देती है जब इनमें से कई एक ही दिन मिलें; अकेला एक केवल यह कारण है कि पंचांग अनुमति दे तो दूसरा दिन चुना जाए। कुछ परंपराएँ तालिका को चंद्र राशि के बजाय चंद्र जन्म-मास पर आधारित करती हैं; यहाँ चंद्र राशि ली गई है।',
    factorsEnglish: <String>[
      'Moon: ${info.english}, ${kundli.janmaNakshatra.english}',
    ],
    factorsHindi: <String>[
      'चंद्र: ${info.hindi}, ${kundli.janmaNakshatra.hindi}',
    ],
  );
}

// =============================================================================
// Where the tables differ: मतभेद on the ghat Moon, the ghat lagna and the month.
// =============================================================================

/// The second sign column of the common table: the ghat Moon for a woman, in
/// the order Mesha to Meena. The first column, for a man, is
/// [GhatRow.chandra]. Seen on sanjayprabhakaran.blogspot.com (October 2025)
/// and astrovachmi.com, which agree on all twelve entries.
const List<Rashi> ghatMoonForWoman = <Rashi>[
  Rashi.mesha,
  Rashi.vrischika,
  Rashi.tula,
  Rashi.dhanu,
  Rashi.karka,
  Rashi.mithuna,
  Rashi.kanya,
  Rashi.vrishabha,
  Rashi.makara,
  Rashi.kumbha,
  Rashi.simha,
  Rashi.meena,
];

/// One row of the table taught in Sanjay Rath's lineage.
class GhatRathRow {
  const GhatRathRow(
    this.janma,
    this.ghatMoon,
    this.lagnaSameSex,
    this.lagnaOpposite,
  );

  final Rashi janma;

  /// The ghataka rasi, the Moon sign to avoid.
  final Rashi ghatMoon;

  /// The ghataka lagna for a native of the same sex as the one the table is
  /// read for, and for the opposite sex. The two are always seven signs apart.
  final Rashi lagnaSameSex;
  final Rashi lagnaOpposite;
}

/// Sarajit Poddar's "Ghataka Chakra" as reproduced on melooha.com (read in a
/// web-archive copy), which matches Sanjay Rath's Mithuna case as a student's
/// blog writes it up (ghataka Moon Aquarius, lagna Cancer for the same sex,
/// Capricorn for the opposite). Rath's own article could not be read.
const List<GhatRathRow> ghatChakraRathTable = <GhatRathRow>[
  GhatRathRow(Rashi.mesha, Rashi.mesha, Rashi.mesha, Rashi.tula),
  GhatRathRow(Rashi.vrishabha, Rashi.kanya, Rashi.vrishabha, Rashi.vrischika),
  GhatRathRow(Rashi.mithuna, Rashi.kumbha, Rashi.karka, Rashi.makara),
  GhatRathRow(Rashi.karka, Rashi.simha, Rashi.tula, Rashi.mesha),
  GhatRathRow(Rashi.simha, Rashi.makara, Rashi.makara, Rashi.karka),
  GhatRathRow(Rashi.kanya, Rashi.mithuna, Rashi.meena, Rashi.kanya),
  GhatRathRow(Rashi.tula, Rashi.dhanu, Rashi.kanya, Rashi.meena),
  GhatRathRow(
    Rashi.vrischika,
    Rashi.vrishabha,
    Rashi.vrischika,
    Rashi.vrishabha,
  ),
  GhatRathRow(Rashi.dhanu, Rashi.meena, Rashi.dhanu, Rashi.mithuna),
  GhatRathRow(Rashi.makara, Rashi.simha, Rashi.kumbha, Rashi.simha),
  GhatRathRow(Rashi.kumbha, Rashi.dhanu, Rashi.mithuna, Rashi.dhanu),
  GhatRathRow(Rashi.meena, Rashi.kumbha, Rashi.simha, Rashi.kumbha),
];

GhatRathRow ghatRathRowFor(Rashi janmaRashi) =>
    ghatChakraRathTable[janmaRashi.index];

Bi _rashiBi(Rashi r) {
  final RashiInfo i = rashiInfo(r);
  return Bi(i.english, i.hindi);
}

/// The ghat Moon and the ghat lagna for [kundli]'s janma rashi under the two
/// tables. Each view's result is the sign(s) it gives.
Matbhed ghatChakraMatbhed(Kundli kundli) {
  final Rashi moon = kundli.moonRashi;
  final GhatRow common = ghatRowFor(moon);
  final GhatRathRow rath = ghatRathRowFor(moon);
  final Rashi woman = ghatMoonForWoman[moon.index];
  final bool dhanu = moon == Rashi.dhanu;
  final Bi me = _rashiBi(common.chandra);
  final Bi we = _rashiBi(woman);
  final Bi rm = _rashiBi(rath.ghatMoon);
  final Bi ls = _rashiBi(rath.lagnaSameSex);
  final Bi lo = _rashiBi(rath.lagnaOpposite);
  final Bi janma = _rashiBi(moon);
  return Matbhed(
    key: 'ghat_lagna',
    topic: const Bi(
      'The ghat Moon and the ghat lagna',
      'घात चंद्र और घात लग्न',
    ),
    whyTheyDiffer: const Bi(
      'Two tables go by the name. The widely printed one has no lagna column '
          'and gives a ghat Moon for a man and another for a woman. The one '
          'taught in Sanjay Rath’s lineage gives a single ghataka Moon and a '
          'ghataka lagna, and they give a different ghat Moon for nine of the '
          'twelve signs even when both columns of the common table are allowed.',
      'इस नाम से दो तालिकाएँ चलती हैं। व्यापक छपी तालिका में लग्न का स्तंभ नहीं है '
          'और वह पुरुष के लिए एक घात चंद्र और स्त्री के लिए दूसरा देती है। संजय रथ की '
          'परंपरा में पढ़ाई जाने वाली एक ही घातक चंद्र और एक घातक लग्न देती है, और '
          'व्यापक तालिका के दोनों स्तंभ मान लेने पर भी बारह में से नौ राशियों का घात '
          'चंद्र अलग है।',
    ),
    defaultReason: const Bi(
      'The app has used the widely printed table from the start, and its other '
          'columns (month, yoga, karana, prahar) exist only there; the other '
          'table is shown beside it.',
      'ऐप शुरू से व्यापक छपी तालिका लेता आया है, और उसके बाकी स्तंभ (मास, योग, '
          'करण, प्रहर) केवल उसी में हैं; दूसरी तालिका उसके बगल में दिखाई है।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        position: const Bi(
          'A ghat Moon for a man and another for a woman, by the janma rashi; '
              'no ghat lagna.',
          'जन्म राशि के अनुसार पुरुष के लिए एक घात चंद्र और स्त्री के लिए दूसरा; '
              'घात लग्न नहीं।',
        ),
        holder: const Bi(
          'The table printed in many janampatris and on websites, as read on '
              'sanjayprabhakaran.blogspot.com (October 2025) and astrovachmi.com',
          'कई जन्मपत्रियों और वेबसाइटों पर छपी तालिका, जैसी '
              'sanjayprabhakaran.blogspot.com (अक्तूबर 2025) और astrovachmi.com पर '
              'पढ़ी गई',
        ),
        reasoning: const Bi(
          'It splits the ghat Moon by the native’s sex and carries the other '
              'columns (month, tithi, weekday, nakshatra, yoga, karana, prahar) '
              'in one row. The headings of its two sign columns differ between '
              'copies of the same page, so which column belongs to whom is not '
              'settled.',
          'यह घात चंद्र को जातक के लिंग से बाँटती है और बाकी स्तंभ (मास, तिथि, वार, '
              'नक्षत्र, योग, करण, प्रहर) एक ही पंक्ति में रखती है। इसके दोनों राशि-स्तंभों के '
              'शीर्षक एक ही पन्ने की प्रतियों में अलग हैं, इसलिए कौन-सा स्तंभ किसका है '
              'यह तय नहीं।',
        ),
        result: Bi(
          'For a ${janma.en} Moon: ghat Moon ${me.en} (the column for a man) '
              'or ${we.en} (the column for a woman). The table prints no ghat '
              'lagna.${dhanu ? ' Its nakshatra for Dhanu is Bharani.' : ''}',
          '${janma.hi} राशि के चंद्र के लिए: घात चंद्र ${me.hi} (पुरुष का स्तंभ) या '
              '${we.hi} (स्त्री का स्तंभ)। तालिका में घात लग्न नहीं है।${dhanu ? ' धनु के लिए इसका नक्षत्र भरणी है।' : ''}',
        ),
      ),
      Mat(
        position: const Bi(
          'One ghataka Moon by the janma rashi, and a ghataka lagna, one for a '
              'native of the same sex and one for the opposite sex.',
          'जन्म राशि के अनुसार एक घातक चंद्र, और एक घातक लग्न, एक समान लिंग के '
              'जातक के लिए और एक विपरीत लिंग के लिए।',
        ),
        holder: const Bi(
          'Sarajit Poddar’s “Ghataka Chakra”, as reproduced on melooha.com '
              '(read in a web-archive copy), and Sanjay Rath’s teaching of it, '
              'whose Mithuna case is written up on a student blog; Rath’s own '
              'article could not be read',
          'सरजीत पोद्दार का “घातक चक्र”, जैसा melooha.com पर छपा है (वेब-आर्काइव '
              'प्रति में पढ़ा), और संजय रथ की उसकी शिक्षा, जिसका मिथुन का उदाहरण एक '
              'विद्यार्थी के ब्लॉग पर लिखा है; रथ का अपना लेख पढ़ा नहीं जा सका',
        ),
        reasoning: const Bi(
          'It names a ghataka lagna as well as a ghataka Moon, always seven '
              'signs apart for the two sexes, and says the lagna, nakshatra and '
              'tithi are also used in marriage matching. No rule deriving the '
              'signs was found. It has no month, yoga, karana or prahar column.',
          'यह घातक चंद्र के साथ घातक लग्न भी देती है, दोनों लिंगों के लिए सदा सात '
              'राशि के अंतर पर, और कहती है कि लग्न, नक्षत्र और तिथि का उपयोग विवाह-मिलान '
              'में भी होता है। इन राशियों को निकालने का कोई नियम नहीं मिला। इसमें मास, '
              'योग, करण या प्रहर का स्तंभ नहीं है।',
        ),
        result: Bi(
          'For a ${janma.en} Moon: ghataka Moon ${rm.en}; ghataka lagna '
              '${ls.en} for the same sex, ${lo.en} for the opposite sex.'
              '${dhanu ? ' Its nakshatra for Dhanu is written “Dveja”, which some read as Ashwini and others as Bharani.' : ''}',
          '${janma.hi} राशि के चंद्र के लिए: घातक चंद्र ${rm.hi}; घातक लग्न समान '
              'लिंग के लिए ${ls.hi}, विपरीत लिंग के लिए ${lo.hi}।${dhanu ? ' धनु के लिए इसका नक्षत्र “द्वेज” लिखा है, जिसे कुछ अश्विनी और कुछ भरणी पढ़ते हैं।' : ''}',
        ),
      ),
    ],
  );
}

/// How the month column is matched to a day, worked out for [date] at
/// [kundli]'s birth place: by the day's Hindu lunar month, or by the Sun's
/// sign, as one calculator approximates it. Each view's `value` is 1 when it
/// finds the ghat month running on that day and 0 when not.
Matbhed ghatMonthMatbhed(Kundli kundli, DateTime date) {
  final GhatRow row = ghatRowFor(kundli.moonRashi);
  final Panchang panchang = computePanchang(
    localDate: DateTime(date.year, date.month, date.day),
    utcOffset: kundli.birth.utcOffset,
    place: kundli.birth.place,
    ayanamsa: kundli.ayanamsa,
  );
  final PanchangCalendar calendar = computePanchangCalendar(panchang);
  final int lunar = calendar.amanta.index;
  final int solar = (calendar.nirayanaSun.sign + 1) % 12;
  final bool lunarRuns = lunar == row.monthIndex;
  final bool solarRuns = solar == row.monthIndex;
  final bool purnimantaRuns = calendar.purnimanta.index == row.monthIndex;
  final String day = '${date.day}/${date.month}/${date.year}';
  final Bi ghat = Bi(row.monthEnglish, row.monthHindi);
  return Matbhed(
    key: 'ghat_month',
    topic: const Bi(
      'How the month column is matched to a day',
      'मास का स्तंभ किसी दिन से कैसे मिलाया जाए',
    ),
    whyTheyDiffer: const Bi(
      'The table lists Hindu months, but none of the sources read says how '
          'to tell which month a given day is in. The lunar month and the '
          'Sun’s sign agree on some days and not on others.',
      'तालिका हिंदू मास गिनाती है, पर पढ़े गए किसी स्रोत में नहीं बताया कि कोई दिन '
          'किस मास में है यह कैसे तय हो। चांद्र मास और सूर्य की राशि कुछ दिन एक बताते '
          'हैं, कुछ दिन नहीं।',
    ),
    defaultReason: const Bi(
      'The table names Hindu months, which are lunar, so the lunar month is the '
          'natural reading and the one the panchang of the app uses.',
      'तालिका हिंदू मास गिनाती है, जो चांद्र हैं, इसलिए चांद्र मास ही स्वाभाविक पाठ है '
          'और वही ऐप का पंचांग लेता है।',
    ),
    views: <Mat>[
      Mat(
        isDefault: true,
        value: lunarRuns ? 1 : 0,
        position: const Bi(
          'The day’s Hindu lunar month (amanta) is compared with the ghat '
              'month.',
          'दिन के हिंदू चांद्र मास (अमांत) की तुलना घात मास से की जाती है।',
        ),
        holder: const Bi(
          'A reading of the table’s own wording (it names Hindu months); no '
              'source read states the matching rule',
          'तालिका के अपने शब्दों का पाठ (वह हिंदू मास गिनाती है); पढ़े गए किसी स्रोत '
              'में मिलान का नियम नहीं बताया गया',
        ),
        reasoning: const Bi(
          'Month names such as Kartika and Pausha are names of lunar months in '
              'the panchang, so the day’s lunar month is the one to compare. '
              'The dark half is named one month later in the purnimanta '
              'reckoning, which can change the answer.',
          'कार्तिक और पौष जैसे नाम पंचांग में चांद्र मासों के नाम हैं, इसलिए दिन का '
              'चांद्र मास ही मिलाया जाए। पूर्णिमांत गणना में कृष्ण पक्ष का नाम एक मास '
              'आगे का होता है, जिससे उत्तर बदल सकता है।',
        ),
        result: Bi(
          'On $day the lunar month is ${calendar.amanta.name} (amanta)'
              '${calendar.monthsDiffer ? ', ${calendar.purnimanta.name} in the purnimanta count' : ''}. '
              'The ghat month for a ${_rashiBi(kundli.moonRashi).en} Moon is ${ghat.en}: '
              '${lunarRuns ? 'running' : (purnimantaRuns ? 'not running in the amanta count, but running in the purnimanta count' : 'not running')}.',
          '$day को चांद्र मास ${calendar.amanta.nameHindi} (अमांत) है'
              '${calendar.monthsDiffer ? ', पूर्णिमांत गणना में ${calendar.purnimanta.nameHindi}' : ''}। '
              '${_rashiBi(kundli.moonRashi).hi} राशि के चंद्र के लिए घात मास ${ghat.hi} है: '
              '${lunarRuns ? 'चल रहा है' : (purnimantaRuns ? 'अमांत गणना में नहीं चल रहा, पूर्णिमांत गणना में चल रहा है' : 'नहीं चल रहा')}।',
        ),
      ),
      Mat(
        value: solarRuns ? 1 : 0,
        position: const Bi(
          'The Sun’s sign on the day gives the month (Mesha is Vaishakha, '
              'Vrishabha is Jyeshtha, and so on), and that is compared with the '
              'ghat month.',
          'दिन की सूर्य राशि से मास निकलता है (मेष वैशाख, वृषभ ज्येष्ठ, आदि), और '
              'उसकी तुलना घात मास से की जाती है।',
        ),
        holder: const Bi(
          'The Ghat Chakra calculator on astrovachmi.com, which derives the '
              'ghat month from the Sun’s current rashi and says that this is '
              'an approximation; the pairing of each sign with a month is the '
              'usual one, which is our reading',
          'astrovachmi.com का घात चक्र कैलकुलेटर, जो घात मास सूर्य की वर्तमान राशि से '
              'निकालता है और कहता है कि यह एक अनुमान है; हर राशि का मास से मेल '
              'प्रचलित वाला है, जो हमारा पाठ है',
        ),
        reasoning: const Bi(
          'The Sun’s sign is easy to find and is the same for everyone on the '
              'day, whereas the lunar month needs the new moons worked out. The '
              'site itself calls it only an approximation.',
          'सूर्य की राशि निकालना आसान है और उस दिन सबके लिए एक है, जबकि चांद्र मास के '
              'लिए अमावस्याएँ निकालनी पड़ती हैं। साइट स्वयं इसे केवल अनुमान कहती है।',
        ),
        result: Bi(
          'On $day the Sun is in ${calendar.nirayanaSun.name}, which gives the '
              'month ${hinduMonthsEnglish[solar]}. The ghat month is ${ghat.en}: '
              '${solarRuns ? 'running' : 'not running'}.',
          '$day को सूर्य ${calendar.nirayanaSun.nameHindi} राशि में है, जिससे मास '
              '${hinduMonthsHindi[solar]} बनता है। घात मास ${ghat.hi} है: '
              '${solarRuns ? 'चल रहा है' : 'नहीं चल रहा'}।',
        ),
      ),
    ],
  );
}

/// What is still not settled in the common table.
const List<LeftOut> ghatLeftOut = <LeftOut>[
  LeftOut(
    key: 'ghat_copies',
    name: Bi('Six cells of the common table', 'व्यापक तालिका के छह खाने'),
    reason: Bi(
      'Two copies of the common table read for this app differ in six cells: '
          'the yoga for Vrishabha (Sukarma or Shukla) and Kanya (Shubha or '
          'Shukla), the karana for Mithuna (Chatushpada or Kaulava), Kumbha '
          '(Vanija or Kimstughna) and Meena (Vishti or Chatushpada), and the '
          'prahar for Meena (6 or 4). The app keeps the cells of the first '
          'copy; a text to decide between them was not found.',
      'इस ऐप के लिए पढ़ी गई व्यापक तालिका की दो प्रतियाँ छह खानों में अलग हैं: '
          'वृषभ का योग (सुकर्मा या शुक्ल) और कन्या का (शुभ या शुक्ल), मिथुन का करण '
          '(चतुष्पाद या कौलव), कुंभ का (वणिज या किंस्तुघ्न) और मीन का (विष्टि या '
          'चतुष्पाद), और मीन का प्रहर (6 या 4)। ऐप पहली प्रति के खाने रखता है; इनमें '
          'निर्णय करने वाला कोई ग्रंथ नहीं मिला।',
    ),
  ),
];
