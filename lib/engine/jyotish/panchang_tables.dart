// Rule tables for the parts of a printed panchang that go beyond the five
// limbs. Everything here is data: names and one-line meanings in English and
// Hindi, and the weekday, tithi and nakshatra tables the yogas are cut from.
//
// Where the traditions differ the North Indian reading that Drik Panchang
// prints is used, and the variant is named beside the table. Nakshatra
// numbers are zero-based from Ashwini, weekdays are 0 = Sunday, and tithi
// numbers are one to fifteen within a paksha.

enum PanchangTone { auspicious, inauspicious, neutral }

/// A rule's name and its one-line meaning, in both languages.
class RuleNote {
  const RuleNote(
    this.key,
    this.name,
    this.nameHindi,
    this.meaning,
    this.meaningHindi, {
    this.tone = PanchangTone.neutral,
  });

  /// Stable identifier, safe to key a map or a widget on.
  final String key;
  final String name;
  final String nameHindi;
  final String meaning;
  final String meaningHindi;
  final PanchangTone tone;
}

// ---------------------------------------------------------------------------
// Flags and windows
// ---------------------------------------------------------------------------

const RuleNote panchakNote = RuleNote(
  'panchak',
  'Panchak',
  'पंचक',
  'The Moon is in Kumbha or Meena, the last five nakshatras from the second '
      'half of Dhanishta to Revati. Gathering fuel, roofing, making a bed and '
      'travelling south are avoided, and a cremation is done with the '
      'prescribed shanti.',
  'चंद्रमा कुंभ या मीन राशि में रहता है, यानी धनिष्ठा के उत्तरार्ध से रेवती '
      'तक के पाँच नक्षत्र। इसमें ईंधन-लकड़ी का संग्रह, छत डालना, चारपाई '
      'बनवाना और दक्षिण दिशा की यात्रा वर्जित है; दाह-संस्कार विधिपूर्वक '
      'शांति-कर्म के साथ किया जाता है।',
  tone: PanchangTone.inauspicious,
);

/// The Panchak nakshatras, zero-based: Dhanishta, Shatabhisha, Purva
/// Bhadrapada, Uttara Bhadrapada, Revati.
const List<int> panchakNakshatras = <int>[22, 23, 24, 25, 26];

/// Sidereal longitude at which Panchak begins: the Moon entering Kumbha,
/// which is the third pada of Dhanishta. The first half of Dhanishta, still in
/// Makara, is not Panchak; the Hindi panchangs say "धनिष्ठा के उत्तरार्ध से".
const double panchakStartDegree = 300.0;

/// What kind of Panchak it is, named for the weekday it begins on.
class PanchakKind {
  const PanchakKind(
    this.key,
    this.name,
    this.nameHindi,
    this.meaning,
    this.meaningHindi,
  );

  final String key;
  final String name;
  final String nameHindi;
  final String meaning;
  final String meaningHindi;
}

/// Indexed by the weekday on which the Panchak begins, 0 = Sunday. A Panchak
/// that begins on Wednesday or Thursday has no named kind and is called
/// Madhyam; it is held free of the special ill effects.
///
/// Variant: the weekday here is the civil weekday of the moment the Moon
/// enters Kumbha, which is how Drik Panchang and the common printed lists name
/// them. A strict reading would use the Vedic day, which changes at sunrise,
/// so a Panchak beginning between midnight and dawn would take the weekday
/// before.
const List<PanchakKind> panchakKinds = <PanchakKind>[
  PanchakKind(
    'roga',
    'Roga Panchak',
    'रोग पंचक',
    'Begins on a Sunday: said to bring illness and bodily distress.',
    'रविवार से आरंभ: रोग और शारीरिक कष्ट देने वाला माना जाता है।',
  ),
  PanchakKind(
    'raja',
    'Raja Panchak',
    'राज पंचक',
    'Begins on a Monday: held favourable for government and official matters.',
    'सोमवार से आरंभ: सरकारी और राजकीय कार्यों के लिए अनुकूल माना जाता है।',
  ),
  PanchakKind(
    'agni',
    'Agni Panchak',
    'अग्नि पंचक',
    'Begins on a Tuesday: fear of fire, accidents and disputes; avoid building '
        'and machinery work.',
    'मंगलवार से आरंभ: अग्नि, दुर्घटना और विवाद का भय; निर्माण और मशीनरी का '
        'कार्य वर्जित।',
  ),
  PanchakKind(
    'madhyam',
    'Madhyam Panchak',
    'मध्यम पंचक',
    'Begins on a Wednesday: no named kind, held free of the special ill '
        'effects.',
    'बुधवार से आरंभ: कोई विशेष नाम नहीं, विशेष दोष से मुक्त माना जाता है।',
  ),
  PanchakKind(
    'madhyam',
    'Madhyam Panchak',
    'मध्यम पंचक',
    'Begins on a Thursday: no named kind, held free of the special ill '
        'effects.',
    'गुरुवार से आरंभ: कोई विशेष नाम नहीं, विशेष दोष से मुक्त माना जाता है।',
  ),
  PanchakKind(
    'chora',
    'Chora Panchak',
    'चोर पंचक',
    'Begins on a Friday: risk of theft and loss; avoid travel and trade in '
        'valuables.',
    'शुक्रवार से आरंभ: चोरी और हानि का भय; यात्रा और कीमती वस्तुओं के '
        'लेन-देन से बचें।',
  ),
  PanchakKind(
    'mrityu',
    'Mrityu Panchak',
    'मृत्यु पंचक',
    'Begins on a Saturday: risk of accident and grave harm; avoid hazardous '
        'work and journeys.',
    'शनिवार से आरंभ: दुर्घटना और गंभीर हानि का भय; जोखिम भरे कार्य और यात्रा '
        'से बचें।',
  ),
];

const RuleNote bhadraNote = RuleNote(
  'bhadra',
  'Bhadra (Vishti karana)',
  'भद्रा (विष्टि करण)',
  'The seventh karana, Vishti. Auspicious beginnings, journeys and '
      'ceremonies are avoided while it runs, most strictly when Bhadra dwells '
      'on earth.',
  'सातवाँ करण विष्टि। इसके रहते शुभ आरंभ, यात्रा और मांगलिक कार्य वर्जित हैं, '
      'विशेषकर जब भद्रा का वास पृथ्वी लोक में हो।',
  tone: PanchangTone.inauspicious,
);

/// Where Bhadra dwells.
enum BhadraLoka { swarga, patala, prithvi }

/// Bhadra's dwelling by the sign the Moon is in, indexed Mesha..Meena. Moon in
/// Karka, Simha, Kumbha or Meena puts Bhadra on earth, where it troubles
/// people; elsewhere it is in heaven or the netherworld and is called
/// harmless. The earth-dwelling signs are the part the sources agree on; the
/// split of the other eight between Swarga and Patala is the one printed in
/// the Muhurta Chintamani tradition.
const List<BhadraLoka> bhadraLokaBySign = <BhadraLoka>[
  BhadraLoka.swarga, // Mesha
  BhadraLoka.swarga, // Vrishabha
  BhadraLoka.swarga, // Mithuna
  BhadraLoka.prithvi, // Karka
  BhadraLoka.prithvi, // Simha
  BhadraLoka.patala, // Kanya
  BhadraLoka.patala, // Tula
  BhadraLoka.swarga, // Vrishchika
  BhadraLoka.patala, // Dhanu
  BhadraLoka.patala, // Makara
  BhadraLoka.prithvi, // Kumbha
  BhadraLoka.prithvi, // Meena
];

const List<String> bhadraLokaName = <String>[
  'Swarga (heaven)',
  'Patala (netherworld)',
  'Prithvi (earth)',
];

const List<String> bhadraLokaNameHindi = <String>[
  'स्वर्ग लोक',
  'पाताल लोक',
  'पृथ्वी लोक',
];

const List<String> bhadraLokaMeaning = <String>[
  'Bhadra is in heaven: held harmless.',
  'Bhadra is in the netherworld: held harmless.',
  'Bhadra is on earth: inauspicious, avoid auspicious work.',
];

const List<String> bhadraLokaMeaningHindi = <String>[
  'भद्रा स्वर्ग में है: दोषरहित मानी जाती है।',
  'भद्रा पाताल में है: दोषरहित मानी जाती है।',
  'भद्रा पृथ्वी पर है: अशुभ, शुभ कार्य वर्जित।',
];

const RuleNote gandMoolNote = RuleNote(
  'gand_mool',
  'Gand Mool',
  'गण्डमूल',
  'The Moon stands in one of the six junction nakshatras: Ashwini, Ashlesha, '
      'Magha, Jyeshtha, Mula or Revati. New auspicious work is avoided in it. '
      'Remedy: a child born in it has Mool Shanti, a havan with the '
      "nakshatra's mantras and charity, on the 27th day after birth when the "
      'Moon returns to the birth nakshatra.',
  'चंद्रमा छह संधि नक्षत्रों में से किसी में है: अश्विनी, आश्लेषा, मघा, '
      'ज्येष्ठा, मूल या रेवती। इसमें नया शुभ कार्य वर्जित है। उपाय: इसमें जन्मे '
      'शिशु की मूल शांति: नक्षत्र के मंत्रों से हवन और दान, जन्म के 27वें दिन '
      'जब चंद्रमा उसी जन्म-नक्षत्र में लौटे।',
  tone: PanchangTone.inauspicious,
);

/// Ashwini, Ashlesha, Magha, Jyeshtha, Mula, Revati.
const List<int> gandMoolNakshatras = <int>[0, 8, 9, 17, 18, 26];

class DishaShool {
  const DishaShool({
    required this.weekday,
    required this.direction,
    required this.directionHindi,
    required this.parihar,
    required this.pariharHindi,
  });

  final int weekday;
  final String direction;
  final String directionHindi;

  /// The traditional substitute: what to eat or do before setting out if the
  /// journey cannot be avoided.
  final String parihar;
  final String pariharHindi;
}

const RuleNote dishaShoolNote = RuleNote(
  'disha_shool',
  'Disha Shool',
  'दिशाशूल',
  'The direction in which travel is traditionally avoided on this weekday. If '
      'the journey cannot wait, take the weekday\'s prescribed food before '
      'setting out.',
  'इस वार को जिस दिशा में यात्रा वर्जित मानी गई है। यात्रा आवश्यक हो तो उस '
      'वार की निर्धारित वस्तु खाकर निकलें।',
  tone: PanchangTone.inauspicious,
);

/// Monday and Saturday: east. Tuesday and Wednesday: north. Thursday: south.
/// Sunday and Friday: west. Some panchangs add a corner direction beside the
/// main one; only the main direction is kept, as Drik Panchang prints it.
const List<DishaShool> dishaShoolTable = <DishaShool>[
  DishaShool(
    weekday: 0,
    direction: 'West',
    directionHindi: 'पश्चिम',
    parihar: 'porridge, ghee or a betel leaf',
    pariharHindi: 'दलिया, घी या पान खाकर',
  ),
  DishaShool(
    weekday: 1,
    direction: 'East',
    directionHindi: 'पूर्व',
    parihar: 'look into a mirror',
    pariharHindi: 'दर्पण देखकर',
  ),
  DishaShool(
    weekday: 2,
    direction: 'North',
    directionHindi: 'उत्तर',
    parihar: 'jaggery',
    pariharHindi: 'गुड़ खाकर',
  ),
  DishaShool(
    weekday: 3,
    direction: 'North',
    directionHindi: 'उत्तर',
    parihar: 'sesame or coriander',
    pariharHindi: 'तिल या धनिया खाकर',
  ),
  DishaShool(
    weekday: 4,
    direction: 'South',
    directionHindi: 'दक्षिण',
    parihar: 'curd or cumin',
    pariharHindi: 'दही या जीरा खाकर',
  ),
  DishaShool(
    weekday: 5,
    direction: 'West',
    directionHindi: 'पश्चिम',
    parihar: 'barley or mustard seed',
    pariharHindi: 'जौ या राई खाकर',
  ),
  DishaShool(
    weekday: 6,
    direction: 'East',
    directionHindi: 'पूर्व',
    parihar: 'ginger, urad or sesame',
    pariharHindi: 'अदरक, उड़द या तिल खाकर',
  ),
];

// ---------------------------------------------------------------------------
// Balas
// ---------------------------------------------------------------------------

const RuleNote chandraBalaNote = RuleNote(
  'chandra_bala',
  'Chandra Bala',
  'चंद्र बल',
  "The strength of the day's Moon for you, read from the house it occupies "
      'counted from your birth Moon sign.',
  'आज के चंद्रमा का आपके लिए बल, जन्म राशि से गिने गए उसके भाव के अनुसार।',
);

/// Houses from the natal Moon sign where the transit Moon is favourable.
///
/// Variant: this is the list Drik Panchang prints. Some texts also count the
/// 2nd, 5th and 9th good in the bright half; they are left as neutral here.
const List<int> chandraBalaGoodHouses = <int>[1, 3, 6, 7, 10, 11];

/// Houses where the Moon is unfavourable; the 8th is Chandrashtama.
const List<int> chandraBalaBadHouses = <int>[4, 8, 12];

const RuleNote taraBalaNote = RuleNote(
  'tara_bala',
  'Tara Bala',
  'तारा बल',
  "The strength of the day's nakshatra for you: the count from your birth "
      'nakshatra, in nines, gives one of nine taras.',
  'आज के नक्षत्र का आपके लिए बल: जन्म नक्षत्र से गिनती को नौ से भाग देने पर '
      'नौ तारा में से एक आती है।',
);

class TaraInfo {
  const TaraInfo(
    this.number,
    this.name,
    this.nameHindi,
    this.meaning,
    this.meaningHindi,
    this.tone,
  );

  /// One to nine.
  final int number;
  final String name;
  final String nameHindi;
  final String meaning;
  final String meaningHindi;
  final PanchangTone tone;
}

/// The nine taras. Janma is neutral because the sources disagree: some call it
/// plainly bad, some good for routine work; it is flagged for caution.
const List<TaraInfo> taraTable = <TaraInfo>[
  TaraInfo(
    1,
    'Janma',
    'जन्म',
    'Your own birth star: take care over the body and avoid big beginnings.',
    'आपका अपना जन्म नक्षत्र: शरीर का ध्यान रखें, बड़ा आरंभ टालें।',
    PanchangTone.neutral,
  ),
  TaraInfo(
    2,
    'Sampat',
    'संपत्',
    'Wealth: favourable for gain and for starting work.',
    'संपत्: धन-लाभ और कार्यारंभ के लिए अनुकूल।',
    PanchangTone.auspicious,
  ),
  TaraInfo(
    3,
    'Vipat',
    'विपत्',
    'Danger: obstacles and setbacks; avoid important work.',
    'विपत्: बाधा और हानि; महत्वपूर्ण कार्य टालें।',
    PanchangTone.inauspicious,
  ),
  TaraInfo(
    4,
    'Kshema',
    'क्षेम',
    'Well-being: safe and comfortable for any work.',
    'क्षेम: कुशल-मंगल; हर कार्य के लिए सुरक्षित।',
    PanchangTone.auspicious,
  ),
  TaraInfo(
    5,
    'Pratyari',
    'प्रत्यरि',
    'The opposing star: obstruction and quarrels.',
    'प्रत्यरि: विरोध, बाधा और कलह।',
    PanchangTone.inauspicious,
  ),
  TaraInfo(
    6,
    'Sadhana',
    'साधक',
    'Achievement: work started now is accomplished.',
    'साधक: अब आरंभ किया कार्य सिद्ध होता है।',
    PanchangTone.auspicious,
  ),
  TaraInfo(
    7,
    'Vadha',
    'वध (नैधन)',
    'Harm: danger to health and plans; avoid risks.',
    'वध: स्वास्थ्य और योजनाओं को हानि; जोखिम से बचें।',
    PanchangTone.inauspicious,
  ),
  TaraInfo(
    8,
    'Mitra',
    'मित्र',
    'Friend: support from others, favourable.',
    'मित्र: दूसरों का सहयोग, अनुकूल।',
    PanchangTone.auspicious,
  ),
  TaraInfo(
    9,
    'Ati Mitra',
    'अतिमित्र (परम मित्र)',
    'The great friend: the most favourable tara.',
    'अतिमित्र: सबसे अनुकूल तारा।',
    PanchangTone.auspicious,
  ),
];

// ---------------------------------------------------------------------------
// Auspicious yogas
// ---------------------------------------------------------------------------

const RuleNote sarvarthaSiddhiNote = RuleNote(
  'sarvartha_siddhi',
  'Sarvartha Siddhi Yoga',
  'सर्वार्थ सिद्धि योग',
  'A weekday and nakshatra pairing in which work of every kind is held to '
      'succeed.',
  'वार और नक्षत्र का ऐसा संयोग जिसमें आरंभ किया हर कार्य सिद्ध माना जाता है।',
  tone: PanchangTone.auspicious,
);

const RuleNote amritSiddhiNote = RuleNote(
  'amrit_siddhi',
  'Amrit Siddhi Yoga',
  'अमृत सिद्धि योग',
  'A rarer weekday and nakshatra pairing, held to give lasting success and to '
      'soften lesser faults.',
  'वार और नक्षत्र का विशिष्ट संयोग; स्थायी सफलता देने वाला और छोटे दोषों को '
      'शांत करने वाला माना जाता है।',
  tone: PanchangTone.auspicious,
);

const RuleNote raviPushyaNote = RuleNote(
  'ravi_pushya',
  'Ravi Pushya Yoga',
  'रवि पुष्य योग',
  'Pushya nakshatra on a Sunday: held the best time for purchases, '
      'investments and fresh ventures.',
  'रविवार को पुष्य नक्षत्र: खरीदारी, निवेश और नए कार्य के लिए श्रेष्ठ माना '
      'जाता है।',
  tone: PanchangTone.auspicious,
);

const RuleNote guruPushyaNote = RuleNote(
  'guru_pushya',
  'Guru Pushya Yoga',
  'गुरु पुष्य योग',
  'Pushya nakshatra on a Thursday: favoured for study, gold and ceremonies.',
  'गुरुवार को पुष्य नक्षत्र: विद्या, स्वर्ण-खरीद और मांगलिक कार्यों के लिए '
      'श्रेष्ठ।',
  tone: PanchangTone.auspicious,
);

const RuleNote raviYogaNote = RuleNote(
  'ravi_yoga',
  'Ravi Yoga',
  'रवि योग',
  "The Moon's nakshatra is the 4th, 6th, 9th, 10th, 13th or 20th from the "
      "Sun's; held to burn away many faults.",
  'चंद्र नक्षत्र सूर्य नक्षत्र से 4, 6, 9, 10, 13 या 20वाँ हो; अनेक दोषों को '
      'नष्ट करने वाला माना जाता है।',
  tone: PanchangTone.auspicious,
);

const RuleNote dwipushkarNote = RuleNote(
  'dwipushkar',
  'Dwipushkar Yoga',
  'द्विपुष्कर योग',
  'Whatever is gained or lost in it is doubled: a Bhadra tithi (2, 7 or 12) '
      'on a Sunday, Tuesday or Saturday with Mrigashira, Chitra or Dhanishta.',
  'इसमें लाभ या हानि दुगुनी होती है: भद्रा तिथि (2, 7, 12) रविवार, मंगलवार '
      'या शनिवार को, और मृगशिरा, चित्रा या धनिष्ठा नक्षत्र।',
);

const RuleNote tripushkarNote = RuleNote(
  'tripushkar',
  'Tripushkar Yoga',
  'त्रिपुष्कर योग',
  'Whatever is gained or lost in it is tripled: a Bhadra tithi (2, 7 or 12) '
      'on a Sunday, Tuesday or Saturday with Krittika, Punarvasu, Uttara '
      'Phalguni, Vishakha, Uttara Ashadha or Purva Bhadrapada.',
  'इसमें लाभ या हानि तिगुनी होती है: भद्रा तिथि (2, 7, 12) रविवार, मंगलवार '
      'या शनिवार को, और कृत्तिका, पुनर्वसु, उत्तरा फाल्गुनी, विशाखा, उत्तराषाढ़ा '
      'या पूर्व भाद्रपद नक्षत्र।',
);

/// Sarvartha Siddhi by weekday, 0 = Sunday. North Indian table, as in the
/// Muhurta Chintamani and Drik Panchang; checked against the Drik windows for
/// New Delhi in October 2026.
const List<List<int>> sarvarthaSiddhiNakshatras = <List<int>>[
  <int>[
    0,
    7,
    11,
    12,
    18,
    20,
    25,
  ], // Sun: Ashwini, Pushya, U.Phalguni, Hasta, Mula, U.Ashadha, U.Bhadrapada
  <int>[3, 4, 7, 16, 21], // Mon: Rohini, Mrigashira, Pushya, Anuradha, Shravana
  <int>[0, 2, 8, 25], // Tue: Ashwini, Krittika, Ashlesha, U.Bhadrapada
  <int>[2, 3, 4, 12, 16], // Wed: Krittika, Rohini, Mrigashira, Hasta, Anuradha
  <int>[0, 6, 7, 16, 26], // Thu: Ashwini, Punarvasu, Pushya, Anuradha, Revati
  <int>[
    0,
    6,
    16,
    21,
    26,
  ], // Fri: Ashwini, Punarvasu, Anuradha, Shravana, Revati
  <int>[3, 14, 21], // Sat: Rohini, Swati, Shravana
];

/// Amrit Siddhi by weekday: Hasta, Mrigashira, Ashwini, Anuradha, Pushya,
/// Revati, Rohini.
const List<int> amritSiddhiNakshatra = <int>[12, 4, 0, 16, 7, 26, 3];

/// Pushya, for Ravi Pushya (Sunday) and Guru Pushya (Thursday).
const int pushyaNakshatra = 7;

/// The Moon's nakshatra counted from the Sun's, 1 being the Sun's own.
const List<int> raviYogaCounts = <int>[4, 6, 9, 10, 13, 20];

/// Sunday, Tuesday and Saturday: the days the pushkar yogas need.
const List<int> pushkarWeekdays = <int>[0, 2, 6];

/// The Bhadra tithis, the 2nd, 7th and 12th of a paksha.
///
/// Variant: some Hindi sources give the 3rd, 8th and 13th (Jaya tithis) for
/// Tripushkar. Drik Panchang, the Muhurta Chintamani translations and most
/// calendars use the Bhadra tithis for both, which is followed here.
const List<int> pushkarTithis = <int>[2, 7, 12];

/// The two-padas-in-each-sign nakshatras: Mrigashira, Chitra, Dhanishta.
const List<int> dwipushkarNakshatras = <int>[4, 13, 22];

/// The three-padas-in-one-sign nakshatras: Krittika, Punarvasu, Uttara
/// Phalguni, Vishakha, Uttara Ashadha, Purva Bhadrapada. These are the six
/// nakshatras that straddle a sign boundary three padas to one, which is where
/// the name comes from; it settles the lists that print Purva Phalguni or
/// Uttara Bhadrapada by slip.
const List<int> tripushkarNakshatras = <int>[2, 6, 11, 15, 20, 24];

// ---------------------------------------------------------------------------
// Inauspicious yogas
// ---------------------------------------------------------------------------

const RuleNote jwalamukhiNote = RuleNote(
  'jwalamukhi',
  'Jwalamukhi Yoga',
  'ज्वालामुखी योग',
  'A tithi and nakshatra pairing (Pratipada with Mula, Panchami with Bharani, '
      'Ashtami with Krittika, Navami with Rohini, Dashami with Ashlesha). Work '
      'begun in it is said to fail; marriage, house-entry and sowing are '
      'avoided.',
  'तिथि और नक्षत्र का संयोग (प्रतिपदा-मूल, पंचमी-भरणी, अष्टमी-कृत्तिका, '
      'नवमी-रोहिणी, दशमी-आश्लेषा)। इसमें आरंभ किया कार्य विफल माना जाता है; '
      'विवाह, गृह-प्रवेश और बुवाई वर्जित।',
  tone: PanchangTone.inauspicious,
);

/// Tithi number within the paksha to the nakshatra that makes it Jwalamukhi.
const Map<int, int> jwalamukhiPairs = <int, int>{
  1: 18, // Pratipada with Mula
  5: 1, // Panchami with Bharani
  8: 2, // Ashtami with Krittika
  9: 3, // Navami with Rohini
  10: 8, // Dashami with Ashlesha
};

const RuleNote vinchhudoNote = RuleNote(
  'vinchhudo',
  'Vinchhudo',
  'विंछुडो',
  "The Moon passes through Vrishchika, the scorpion's sign, from 210 to 240 "
      'degrees of the sidereal zodiac. Kept chiefly in Gujarat and Rajasthan, '
      'where new auspicious beginnings are avoided in it.',
  'चंद्रमा वृश्चिक राशि (निरयण 210° से 240°) में रहता है। मुख्यतः गुजरात और '
      'राजस्थान में माना जाता है; इसमें नए शुभ कार्य वर्जित हैं।',
  tone: PanchangTone.inauspicious,
);

/// The sign Vinchhudo is kept in, zero-based: Vrishchika.
const int vinchhudoSign = 7;

const RuleNote aadalNote = RuleNote(
  'aadal',
  'Aadal Yoga',
  'आडल योग',
  "The Moon's nakshatra is the 2nd, 7th, 9th, 14th, 16th, 21st, 23rd or 28th "
      "from the Sun's, counting Abhijit as a nakshatra. Listed among the "
      'inauspicious yogas; new auspicious work is avoided.',
  'चंद्र नक्षत्र सूर्य नक्षत्र से 2, 7, 9, 14, 16, 21, 23 या 28वाँ हो '
      '(अभिजित सहित गिनती)। अशुभ योगों में गिना जाता है; नया शुभ कार्य वर्जित।',
  tone: PanchangTone.inauspicious,
);

const RuleNote vidaalNote = RuleNote(
  'vidaal',
  'Vidaal Yoga',
  'विडाल योग',
  "The Moon's nakshatra is the 3rd, 6th, 10th, 13th, 17th, 20th, 24th or "
      "27th from the Sun's, counting Abhijit as a nakshatra. Listed among the "
      'inauspicious yogas; new auspicious work is avoided.',
  'चंद्र नक्षत्र सूर्य नक्षत्र से 3, 6, 10, 13, 17, 20, 24 या 27वाँ हो '
      '(अभिजित सहित गिनती)। अशुभ योगों में गिना जाता है; नया शुभ कार्य वर्जित।',
  tone: PanchangTone.inauspicious,
);

/// Counts of the Moon's nakshatra from the Sun's, in the 28-nakshatra series
/// that has Abhijit between Uttara Ashadha and Shravana. Checked against the
/// Drik Panchang Vidaal window for New Delhi on 7 October 2026, which opens
/// when the Moon passes from Magha into Purva Phalguni (the 27th count).
const List<int> aadalCounts = <int>[2, 7, 9, 14, 16, 21, 23, 28];
const List<int> vidaalCounts = <int>[3, 6, 10, 13, 17, 20, 24, 27];

/// Position, 1..28, of a nakshatra (0..26) in the 28-nakshatra series that
/// puts Abhijit 22nd. The Moon is never placed in Abhijit itself, only the
/// count passes over it, which is how Aadal, Vidaal and Anandadi are reckoned
/// in the printed panchangs this follows.
int nakshatraPosition28(int nakshatra) =>
    nakshatra < 21 ? nakshatra + 1 : nakshatra + 2;

// ---------------------------------------------------------------------------
// Anandadi yoga
// ---------------------------------------------------------------------------

const RuleNote anandadiNote = RuleNote(
  'anandadi',
  'Anandadi Yoga',
  'आनन्दादि योग',
  "One of 28 yogas counted from the day's nakshatra against a starting "
      'nakshatra that depends on the weekday; some are favourable and some are '
      'not.',
  'वार के अनुसार निश्चित आरंभिक नक्षत्र से दिन के नक्षत्र तक की गिनती से बने '
      '28 योगों में से एक; कुछ शुभ हैं और कुछ अशुभ।',
);

/// Position in the 28-nakshatra series where each weekday's count starts:
/// Ashwini on Sunday, Mrigashira on Monday, Ashlesha on Tuesday, Hasta on
/// Wednesday, Anuradha on Thursday, Uttara Ashadha on Friday, Shatabhisha on
/// Saturday. They sit four apart, which is what makes 28 the cycle.
const List<int> anandadiStartPosition = <int>[1, 5, 9, 13, 17, 21, 25];

class AnandadiInfo {
  const AnandadiInfo(
    this.name,
    this.nameHindi,
    this.meaning,
    this.meaningHindi,
    this.tone,
  );

  final String name;
  final String nameHindi;
  final String meaning;
  final String meaningHindi;
  final PanchangTone tone;
}

const List<AnandadiInfo> anandadiTable = <AnandadiInfo>[
  AnandadiInfo(
    'Ananda',
    'आनन्द',
    'Joy and the fulfilment of aims.',
    'आनंद और मनोरथ की सिद्धि।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Kaladanda',
    'कालदण्ड',
    "Death's staff: danger and harm; begin nothing.",
    'कालदण्ड: संकट और हानि; कोई आरंभ न करें।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Dhumra',
    'धूम्र',
    'Smoke: distress and obstruction.',
    'धूम्र: संताप और बाधा।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Prajapati',
    'प्रजापति',
    'Auspicious; good for undertakings and household matters.',
    'शुभ; कार्यों और गृहस्थ कार्यों के लिए अनुकूल।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Saumya',
    'सौम्य',
    'Gentle: comfort and contentment.',
    'सौम्य: सुख और संतोष।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Dhwanksha',
    'ध्वांक्ष',
    'The crow: loss of wealth.',
    'ध्वांक्ष (काक): धन-हानि।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Dhwaja',
    'ध्वज',
    'The banner: fame and comfort.',
    'ध्वज: यश और सुख।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Shrivatsa',
    'श्रीवत्स',
    "Lakshmi's mark: wealth and prosperity.",
    'श्रीवत्स: धन और समृद्धि।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Vajra',
    'वज्र',
    'The thunderbolt: destruction and loss.',
    'वज्र: क्षय और हानि।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Mudgara',
    'मुद्गर',
    'The hammer: loss of prosperity.',
    'मुद्गर: लक्ष्मी की हानि।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Chhatra',
    'छत्र',
    'The royal umbrella: honour and favour from the great.',
    'छत्र: मान-सम्मान और राजकृपा।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Mitra',
    'मित्र',
    'The friend: support and nourishment.',
    'मित्र: सहयोग और पुष्टि।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Manasa',
    'मानस',
    'Peace of mind and comfort.',
    'मानस: मन की शांति और सुख।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Padma',
    'पद्म',
    'The lotus: gain of wealth.',
    'पद्म: धन-लाभ।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Lumbaka',
    'लुम्बक',
    'Loss of wealth.',
    'लुम्बक: धन-क्षय।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Utpata',
    'उत्पात',
    'Calamity: portents of harm; avoid beginnings.',
    'उत्पात: अनिष्ट के संकेत; आरंभ टालें।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Mrityu',
    'मृत्यु',
    'Death-like: grave danger; avoid beginnings.',
    'मृत्यु: गंभीर संकट; आरंभ टालें।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Kana',
    'काण',
    'The one-eyed: trouble and vexation.',
    'काण: क्लेश और परेशानी।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Siddhi',
    'सिद्धि',
    'Success in work.',
    'सिद्धि: कार्य में सफलता।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Shubha',
    'शुभ',
    'Auspicious: general welfare.',
    'शुभ: सामान्य कल्याण।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Amrita',
    'अमृत',
    'Nectar: honour and good fortune.',
    'अमृत: मान और सौभाग्य।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Musala',
    'मुसल',
    'The pestle: loss of wealth.',
    'मुसल: धन-क्षय।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Gada',
    'गद',
    'The mace: fear and danger.',
    'गद: भय और संकट।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Matanga',
    'मातंग',
    'The elephant: growth of the family and its fortune.',
    'मातंग: कुल और सौभाग्य की वृद्धि।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Rakshasa',
    'राक्षस',
    'The demon: great hardship.',
    'राक्षस: महान कष्ट।',
    PanchangTone.inauspicious,
  ),
  AnandadiInfo(
    'Chara',
    'चर',
    'The mover: success in work, good for journeys.',
    'चर: कार्य-सिद्धि; यात्रा के लिए अनुकूल।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Sthira',
    'स्थिर',
    'The steady: good for lasting works such as laying a foundation.',
    'स्थिर: स्थायी कार्य, जैसे गृहारंभ, के लिए अनुकूल।',
    PanchangTone.auspicious,
  ),
  AnandadiInfo(
    'Vardhamana',
    'वर्धमान',
    'The growing: increase and prosperity.',
    'वर्धमान: वृद्धि और समृद्धि।',
    PanchangTone.auspicious,
  ),
];

// ---------------------------------------------------------------------------
// Calendar context
// ---------------------------------------------------------------------------

/// The sixty samvatsaras, Prabhava first.
const List<String> samvatsaraNames = <String>[
  'Prabhava',
  'Vibhava',
  'Shukla',
  'Pramoda',
  'Prajapati',
  'Angirasa',
  'Shrimukha',
  'Bhava',
  'Yuva',
  'Dhatri',
  'Ishvara',
  'Bahudhanya',
  'Pramathi',
  'Vikrama',
  'Vrisha',
  'Chitrabhanu',
  'Svabhanu',
  'Tarana',
  'Parthiva',
  'Vyaya',
  'Sarvajit',
  'Sarvadhari',
  'Virodhi',
  'Vikriti',
  'Khara',
  'Nandana',
  'Vijaya',
  'Jaya',
  'Manmatha',
  'Durmukhi',
  'Hevilambi',
  'Vilambi',
  'Vikari',
  'Sharvari',
  'Plava',
  'Shubhakrit',
  'Shobhakrit',
  'Krodhi',
  'Vishvavasu',
  'Parabhava',
  'Plavanga',
  'Kilaka',
  'Saumya',
  'Sadharana',
  'Virodhakrit',
  'Paridhavi',
  'Pramadicha',
  'Ananda',
  'Rakshasa',
  'Nala',
  'Pingala',
  'Kalayukta',
  'Siddharthi',
  'Raudra',
  'Durmati',
  'Dundubhi',
  'Rudhirodgari',
  'Raktakshi',
  'Krodhana',
  'Akshaya',
];

const List<String> samvatsaraNamesHindi = <String>[
  'प्रभव',
  'विभव',
  'शुक्ल',
  'प्रमोद',
  'प्रजापति',
  'अंगिरा',
  'श्रीमुख',
  'भाव',
  'युवा',
  'धाता',
  'ईश्वर',
  'बहुधान्य',
  'प्रमाथी',
  'विक्रम',
  'वृष',
  'चित्रभानु',
  'स्वभानु',
  'तारण',
  'पार्थिव',
  'व्यय',
  'सर्वजित्',
  'सर्वधारी',
  'विरोधी',
  'विकृति',
  'खर',
  'नन्दन',
  'विजय',
  'जय',
  'मन्मथ',
  'दुर्मुख',
  'हेमलम्बी',
  'विलम्बी',
  'विकारी',
  'शार्वरी',
  'प्लव',
  'शुभकृत्',
  'शोभकृत्',
  'क्रोधी',
  'विश्वावसु',
  'पराभव',
  'प्लवंग',
  'कीलक',
  'सौम्य',
  'साधारण',
  'विरोधकृत्',
  'परिधावी',
  'प्रमादी',
  'आनन्द',
  'राक्षस',
  'नल',
  'पिंगल',
  'कालयुक्त',
  'सिद्धार्थी',
  'रौद्र',
  'दुर्मति',
  'दुन्दुभि',
  'रुधिरोद्गारी',
  'रक्ताक्षी',
  'क्रोधन',
  'अक्षय',
];

const List<String> rituNames = <String>[
  'Vasanta (spring)',
  'Grishma (summer)',
  'Varsha (monsoon)',
  'Sharad (autumn)',
  'Hemanta (pre-winter)',
  'Shishira (winter)',
];

const List<String> rituNamesHindi = <String>[
  'वसंत',
  'ग्रीष्म',
  'वर्षा',
  'शरद',
  'हेमंत',
  'शिशिर',
];

const List<String> ayanaNames = <String>['Uttarayana', 'Dakshinayana'];
const List<String> ayanaNamesHindi = <String>['उत्तरायण', 'दक्षिणायन'];

/// Labels for the calendar rows, with a one-line meaning each.
const RuleNote vikramSamvatNote = RuleNote(
  'vikram_samvat',
  'Vikram Samvat',
  'विक्रम संवत्',
  'The era counted from 57 BCE, used across North India. The year turns on '
      'Chaitra Shukla Pratipada.',
  'ई.पू. 57 से गिना जाने वाला संवत्, उत्तर भारत में प्रचलित। वर्ष चैत्र शुक्ल '
      'प्रतिपदा को बदलता है।',
);

const RuleNote shakaSamvatNote = RuleNote(
  'shaka_samvat',
  'Shaka Samvat',
  'शक संवत्',
  "India's national civil era, 78 years behind the Gregorian year. The "
      'samvatsara shown is its name in the sixty-year cycle.',
  'भारत का राष्ट्रीय संवत्, ग्रेगोरियन वर्ष से 78 वर्ष पीछे। दिखाया गया '
      'संवत्सर साठ वर्ष के चक्र में इसका नाम है।',
);

const RuleNote kaliSamvatNote = RuleNote(
  'kali_samvat',
  'Kali Samvat and Ahargana',
  'कलि संवत् और अहर्गण',
  'The year of the Kali Yuga, and the count of days elapsed since its epoch '
      'in 3102 BCE, the day count the old siddhantas run on.',
  'कलियुग का वर्ष, और ई.पू. 3102 के आरंभ से बीते हुए दिनों की गिनती '
      '(कलि अहर्गण), जिस पर पुराने सिद्धांत चलते हैं।',
);

const RuleNote lunarMonthNote = RuleNote(
  'lunar_month',
  'Lunar month (Amanta and Purnimanta)',
  'चांद्र मास (अमांत और पूर्णिमांत)',
  'Amanta months run new moon to new moon (South and West India); Purnimanta '
      'months run full moon to full moon (North India). They agree in the '
      'bright half and differ by one name in the dark half.',
  'अमांत मास अमावस्या से अमावस्या तक (दक्षिण और पश्चिम भारत); पूर्णिमांत मास '
      'पूर्णिमा से पूर्णिमा तक (उत्तर भारत)। शुक्ल पक्ष में दोनों एक हैं, कृष्ण '
      'पक्ष में नाम एक आगे का होता है।',
);

const RuleNote pakshaNote = RuleNote(
  'paksha',
  'Paksha',
  'पक्ष',
  'The fortnight: Shukla while the Moon waxes, Krishna while it wanes.',
  'पखवाड़ा: चंद्रमा बढ़ने पर शुक्ल, घटने पर कृष्ण।',
);

const RuleNote rituNote = RuleNote(
  'ritu',
  'Ritu (season)',
  'ऋतु',
  'Vedic ritu follows the lunar month, two to a season from Chaitra. Drik '
      'ritu follows the Sun\'s tropical longitude, so it tracks the actual '
      'season and runs a month or two ahead.',
  'वैदिक ऋतु चांद्र मास से चलती है, चैत्र से दो-दो मास की। दृक् ऋतु सूर्य के '
      'सायन भोगांश से चलती है, इसलिए वास्तविक मौसम के साथ चलती है और एक-दो '
      'मास आगे रहती है।',
);

const RuleNote ayanaNote = RuleNote(
  'ayana',
  'Ayana',
  'अयन',
  "The Sun's half-year journey: Uttarayana northward, Dakshinayana southward. "
      'Vedic ayana turns at Makara and Karka Sankranti; Drik ayana at the '
      'solstices.',
  'सूर्य की आधे वर्ष की यात्रा: उत्तरायण उत्तर की ओर, दक्षिणायन दक्षिण की ओर। '
      'वैदिक अयन मकर और कर्क संक्रांति पर बदलता है; दृक् अयन अयनांत पर।',
);

const RuleNote solarMonthNote = RuleNote(
  'solar_month',
  'Solar month (Sun sign)',
  'सौर मास (सूर्य राशि)',
  'The sign the Sun is in: nirayana by the sidereal zodiac, which the '
      'Sankranti calendar uses, and sayana by the tropical zodiac.',
  'सूर्य जिस राशि में है: निरयण (नक्षत्र-आधारित राशि, संक्रांति पंचांग में '
      'प्रचलित) और सायन (ऋतु-आधारित राशि)।',
);
