import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/nakshatra.dart';
import '../engine/jyotish/phaladesh.dart' show Tone;
import '../engine/jyotish/rashi.dart';

/// The line every substantive answer ends with: that all of it is said
/// according to the shastra and is not a fixed or certain thing. It is one
/// calm sentence pair, not a legal disclaimer, and it is the same everywhere,
/// so a listener learns to expect it.
const String closingHindi =
    'यह सब शास्त्र के अनुसार कहा गया है, कोई तय या निश्चित बात नहीं। कुंडली रुझान और दिशा दिखाती है; आगे का रास्ता आपके अपने कर्म और फ़ैसलों से बनता है।';

const String closingEnglish =
    'All of this is said according to the shastra, and none of it is fixed or certain. The chart shows tendencies and direction; the road ahead is still made by your own actions and choices.';

/// The words that mark the comparison with the present in the part of a
/// timing answer that names a better stretch. The tests look for them.
const String compareMarkerHindi = 'अभी से तुलना में';
const String compareMarkerEnglish = 'Compared with now';

/// Hindi is typed in more than one way: ढ़ as one character or as ढ and a
/// nukta, a chandrabindu or an anusvara, a nukta or none. Questions and
/// keywords are both folded to one form before they are compared, so a person
/// is never refused an answer for the way their keyboard wrote a letter.
String foldHindi(String text) {
  const Map<int, String> decomposed = <int, String>{
    0x0958: 'क',
    0x0959: 'ख',
    0x095A: 'ग',
    0x095B: 'ज',
    0x095C: 'ड',
    0x095D: 'ढ',
    0x095E: 'फ',
    0x095F: 'य',
  };
  final StringBuffer out = StringBuffer();
  for (final int unit in text.runes) {
    if (unit == 0x093C) continue; // nukta
    if (unit == 0x0901) {
      out.write('ं'); // chandrabindu to anusvara
      continue;
    }
    out.write(decomposed[unit] ?? String.fromCharCode(unit));
  }
  return out.toString();
}

/// The first [count] sentences of [text]. A sentence ends at a full stop or a
/// danda followed by a space, so a decimal point does not end one.
String firstSentences(String text, int count) {
  final List<String> parts = text.trim().split(RegExp(r'(?<=[.।])\s+'));
  return parts.take(count).join(' ');
}

final RegExp _wordChar = RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true);

/// True when [word] stands in [text] as a whole word. Dart's `\b` knows
/// nothing of Devanagari vowel signs, so the neighbours are tested directly.
bool hasWholeWord(String text, String word) {
  int from = 0;
  while (true) {
    final int at = text.indexOf(word, from);
    if (at < 0) return false;
    final bool startsClean = at == 0 || !_wordChar.hasMatch(text[at - 1]);
    final int end = at + word.length;
    final bool endsClean = end >= text.length || !_wordChar.hasMatch(text[end]);
    if (startsClean && endsClean) return true;
    from = at + 1;
  }
}

const List<String> _monthsEn = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _monthsHi = <String>[
  'जनवरी',
  'फ़रवरी',
  'मार्च',
  'अप्रैल',
  'मई',
  'जून',
  'जुलाई',
  'अगस्त',
  'सितंबर',
  'अक्टूबर',
  'नवंबर',
  'दिसंबर',
];

const List<String> _ordEn = <String>[
  '',
  '1st',
  '2nd',
  '3rd',
  '4th',
  '5th',
  '6th',
  '7th',
  '8th',
  '9th',
  '10th',
  '11th',
  '12th',
];

/// "सातवें भाव में", the form that takes में, का, से.
const List<String> _ordHiOblique = <String>[
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
];

/// "सातवाँ भाव", the form that stands as a subject.
const List<String> _ordHiDirect = <String>[
  '',
  'पहला',
  'दूसरा',
  'तीसरा',
  'चौथा',
  'पाँचवाँ',
  'छठा',
  'सातवाँ',
  'आठवाँ',
  'नौवाँ',
  'दसवाँ',
  'ग्यारहवाँ',
  'बारहवाँ',
];

const List<String> _ordHiFeminine = <String>[
  '',
  'पहली',
  'दूसरी',
  'तीसरी',
  'चौथी',
  'पाँचवीं',
  'छठी',
  'सातवीं',
  'आठवीं',
  'नौवीं',
  'दसवीं',
  'ग्यारहवीं',
  'बारहवीं',
];

/// What each house is about, in everyday words and in the form that follows
/// "ज़ोर ... पर" or precedes "की बातें". The wording keeps clear of events: a
/// house is a part of life, never a forecast.
const List<(String, String)> _areas = <(String, String)>[
  (
    'you yourself and the direction of your life',
    'आपके अपने स्वभाव और जीवन की दिशा',
  ),
  ('money, family and speech', 'पैसे, परिवार और बोली'),
  ('effort, courage and siblings', 'मेहनत, हिम्मत और भाई-बहन'),
  ('home, mother and peace of mind', 'घर, माँ और मन की शांति'),
  ('study, children and creative work', 'पढ़ाई, बच्चों और रचनात्मक काम'),
  ('daily work, debts and rivalry', 'रोज़ के काम, कर्ज़ और होड़'),
  (
    'partner, partnerships and close relationships',
    'जीवनसाथी, साझेदारी और क़रीबी रिश्तों',
  ),
  ('change, shared money and hidden matters', 'बदलाव, साझे पैसे और छिपी बातों'),
  (
    'fortune, teachers and elders, and dharma',
    'भाग्य, गुरु-बुज़ुर्गों और धर्म',
  ),
  ('work, position and standing', 'काम, पद और साख'),
  ('income, friends and fulfilled hopes', 'कमाई, दोस्तों और इच्छाओं की पूर्ति'),
  ('expenses, solitude and distant places', 'खर्च, एकांत और विदेश'),
];

/// What each graha stands for, in everyday words.
const Map<Graha, (String, String)> _themes = <Graha, (String, String)>{
  Graha.sun: (
    'position, the father, self-confidence and recognition',
    'पद, पिता, आत्मविश्वास और मान-सम्मान',
  ),
  Graha.moon: ('the mind, the mother and the home', 'मन, माँ और घर'),
  Graha.mars: (
    'energy, courage, land and siblings',
    'ऊर्जा, हिम्मत, ज़मीन और भाई-बहन',
  ),
  Graha.mercury: (
    'speech, intellect, trade and paperwork',
    'बोली, बुद्धि, व्यापार और लिखा-पढ़ी',
  ),
  Graha.jupiter: (
    'knowledge, teachers, children and counsel',
    'ज्ञान, गुरु, बच्चे और सलाह',
  ),
  Graha.venus: (
    'relationships, comfort, art and the means of a pleasant life',
    'रिश्ते, सुख-सुविधा, कला और आराम के साधन',
  ),
  Graha.saturn: (
    'work, discipline, patience and what is built slowly',
    'काम, अनुशासन, धीरज और धीरे-धीरे बनने वाली चीज़ें',
  ),
  Graha.rahu: (
    'big ambition, foreign things, a pull towards the unfamiliar and restlessness',
    'बड़ी चाह, विदेश, अनजान की ओर खिंचाव और बेचैनी',
  ),
  Graha.ketu: (
    'detachment, research, turning inward and letting go',
    'वैराग्य, खोज, भीतर की ओर मुड़ना और छोड़ना',
  ),
};

/// Everything about how the Ask answers speak: names, dates, spans and the
/// small grammar Hindi needs. One instance per answer, so a composer never has
/// to carry the language flag around.
class AskLang {
  const AskLang(this.hindi);

  final bool hindi;

  /// The sentence in the language of the answer.
  String t(String en, String hi) => hindi ? hi : en;

  String graha(Graha g) => hindi ? grahaInfo(g).hindi : grahaInfo(g).english;

  String sign(Rashi r) => hindi ? rashiInfo(r).hindi : rashiInfo(r).english;

  String nakshatra(NakshatraInfo n) => hindi ? n.hindi : n.english;

  /// "सातवें भाव" / "the 7th house", the form that takes में, का and से.
  String house(int h) =>
      hindi ? '${_ordHiOblique[h]} भाव' : 'the ${_ordEn[h]} house';

  /// "सातवाँ भाव" / "the 7th house", the form that stands as a subject.
  String houseSubject(int h) =>
      hindi ? '${_ordHiDirect[h]} भाव' : 'the ${_ordEn[h]} house';

  /// "तीसरे और आठवें भाव" / "the 3rd and 8th houses".
  String houses(List<int> hs) {
    if (hs.isEmpty) return '';
    if (hs.length == 1) return house(hs.first);
    if (hindi) {
      return '${list(hs.map((int h) => _ordHiOblique[h]).toList())} भाव';
    }
    return 'the ${list(hs.map((int h) => _ordEn[h]).toList())} houses';
  }

  /// The ordinal alone: "सातवें" / "7th".
  String ordinal(int n) => hindi ? _ordHiOblique[n] : _ordEn[n];

  /// The ordinal for a sign or a place, which Hindi makes feminine: "आठवीं".
  String ordinalFem(int n) => hindi ? _ordHiFeminine[n] : _ordEn[n];

  /// What the house is about, in everyday words.
  String area(int h) => hindi ? _areas[h - 1].$2 : _areas[h - 1].$1;

  /// What the graha stands for, in everyday words.
  String themes(Graha g) => hindi ? _themes[g]!.$2 : _themes[g]!.$1;

  /// "a, b and c" / "a, b और c".
  String list(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    final String last = items.last;
    final String head = items.sublist(0, items.length - 1).join(', ');
    return hindi ? '$head और $last' : '$head and $last';
  }

  /// "14 August 2031" / "14 अगस्त 2031", in the zone the person was born in.
  String date(DateTime utc, Duration zone) {
    final DateTime local = utc.add(zone);
    final String month = hindi
        ? _monthsHi[local.month - 1]
        : _monthsEn[local.month - 1];
    return '${local.day} $month ${local.year}';
  }

  /// "August 2031" / "अगस्त 2031".
  String monthYear(DateTime utc, Duration zone) {
    final DateTime local = utc.add(zone);
    final String month = hindi
        ? _monthsHi[local.month - 1]
        : _monthsEn[local.month - 1];
    return '$month ${local.year}';
  }

  /// A length of time in the words a person uses: "about 2 years 3 months".
  String span(Duration d) {
    final double days = d.inHours / 24.0;
    if (days < 10) return t('a few days', 'कुछ ही दिन');
    if (days < 45) {
      final int weeks = (days / 7).round();
      return hindi ? 'लगभग $weeks हफ़्ते' : 'about $weeks weeks';
    }
    if (days < 330) {
      final int months = (days / 30.44).round();
      if (months >= 12) return t('about a year', 'लगभग एक साल');
      return hindi ? 'लगभग $months महीने' : 'about $months months';
    }
    int years = (days / 365.25).floor();
    int months = ((days - years * 365.25) / 30.44).round();
    if (months >= 12) {
      years += 1;
      months = 0;
    }
    if (hindi) {
      if (months == 0) return 'लगभग $years साल';
      return 'लगभग $years साल $months ${months == 1 ? 'महीना' : 'महीने'}';
    }
    final String y = '$years ${years == 1 ? 'year' : 'years'}';
    if (months == 0) return 'about $y';
    return 'about $y $months ${months == 1 ? 'month' : 'months'}';
  }

  /// "महादशा" / "mahadasha" for level 1, and so on.
  String level(int level) => switch (level) {
    1 => t('mahadasha', 'महादशा'),
    2 => t('antardasha', 'अंतर्दशा'),
    _ => t('pratyantardasha', 'प्रत्यंतर्दशा'),
  };

  /// "in its own sign" / "अपनी ही राशि में".
  String dignityIn(Dignity d) => switch (d) {
    Dignity.exalted => t('in its sign of exaltation', 'अपनी उच्च राशि में'),
    Dignity.moolatrikona => t(
      'in its moolatrikona sign',
      'अपनी मूलत्रिकोण राशि में',
    ),
    Dignity.own => t('in its own sign', 'अपनी ही राशि में'),
    Dignity.friend => t('in a friend’s sign', 'मित्र ग्रह की राशि में'),
    Dignity.neutral => t('in a neutral sign', 'सम ग्रह की राशि में'),
    Dignity.enemy => t('in an enemy’s sign', 'शत्रु ग्रह की राशि में'),
    Dignity.debilitated => t('in its sign of fall', 'अपनी नीच राशि में'),
  };

  /// What that dignity does for the graha, as a short clause.
  String dignityGloss(Dignity d, {bool bhanga = false}) => switch (d) {
    Dignity.exalted ||
    Dignity.moolatrikona ||
    Dignity.own => t('where it sits firmly', 'जहाँ यह पूरी मज़बूती से बैठा है'),
    Dignity.friend => t('where it is supported', 'जहाँ इसे सहारा मिलता है'),
    Dignity.neutral => t(
      'where it is neither helped nor held back',
      'जहाँ न सहारा मिलता है, न रुकावट',
    ),
    Dignity.enemy => t(
      'where it has to move a little carefully',
      'जहाँ इसे थोड़ा सँभलकर चलना पड़ता है',
    ),
    Dignity.debilitated =>
      bhanga
          ? t(
              'where its strength is pressed, though the cancellation of the fall steadies it',
              'जहाँ इसकी शक्ति दबी रहती है, पर नीच-भंग की स्थिति इसे सँभाल लेती है',
            )
          : t('where its strength is pressed', 'जहाँ इसकी शक्ति दबी रहती है'),
  };

  /// A strong dignity: own, exalted or moolatrikona.
  bool strongDignity(Dignity d) =>
      d == Dignity.own || d == Dignity.exalted || d == Dignity.moolatrikona;

  /// The temperament of a sign's element, in a few plain words.
  String element(Element e) => switch (e) {
    Element.fire => t('fire', 'अग्नि'),
    Element.earth => t('earth', 'पृथ्वी'),
    Element.air => t('air', 'वायु'),
    Element.water => t('water', 'जल'),
  };

  String elementNature(Element e) => switch (e) {
    Element.fire => t(
      'energetic, direct and quick to act',
      'ऊर्जावान, सीधे और जल्दी काम में उतरने वाले',
    ),
    Element.earth => t(
      'practical, steady and grounded',
      'व्यावहारिक, टिके हुए और ज़मीन से जुड़े',
    ),
    Element.air => t(
      'curious, sociable and always thinking',
      'जिज्ञासु, मिलनसार और हमेशा सोचते रहने वाले',
    ),
    Element.water => t(
      'feeling, intuitive and sensitive to others',
      'भावुक, अंतर्ज्ञानी और दूसरों के मन को भाँपने वाले',
    ),
  };

  /// The same, said of a single mind rather than of people.
  String elementMind(Element e) => switch (e) {
    Element.fire => t('quick and direct', 'तेज़ और सीधा'),
    Element.earth => t('practical and steady', 'व्यावहारिक और टिका हुआ'),
    Element.air => t(
      'curious and always thinking',
      'जिज्ञासु और हमेशा सोचता रहने वाला',
    ),
    Element.water => t('feeling and sensitive', 'भावुक और संवेदनशील'),
  };

  String qualityNature(Quality q) => switch (q) {
    Quality.movable => t(
      'a movable sign, which likes to start things',
      'यह चर राशि है, जिसे नई शुरुआत करना भाता है',
    ),
    Quality.fixed => t(
      'a fixed sign, which holds on and sees things through',
      'यह स्थिर राशि है, जो पकड़कर रखती है और काम पूरा करती है',
    ),
    Quality.dual => t(
      'a dual sign, which adapts and can hold two things at once',
      'यह द्विस्वभाव राशि है, जो हालात के साथ ढल जाती है',
    ),
  };

  /// "साथ देने वाला" / "supportive". Hindi agrees with the thing described, so
  /// [feminine] gives "साथ देने वाली" for a dasha.
  String toneWord(Tone tone, {bool feminine = false}) => switch (tone) {
    Tone.supportive => t(
      'supportive',
      feminine ? 'साथ देने वाली' : 'साथ देने वाला',
    ),
    Tone.mixed => t('mixed', feminine ? 'मिली-जुली' : 'मिला-जुला'),
    Tone.demanding => t(
      'asking for patience',
      feminine ? 'धैर्य माँगने वाली' : 'धैर्य माँगने वाला',
    ),
  };

  /// The tone as a predicate: "stands with you" / "साथ देने वाली है". Hindi
  /// agrees with the thing described, so [feminine] is for a dasha.
  String toneClause(Tone tone, {bool feminine = false}) => switch (tone) {
    Tone.supportive => t(
      'stands with you',
      feminine ? 'साथ देने वाली है' : 'साथ देने वाला है',
    ),
    Tone.mixed => t('is mixed', feminine ? 'मिली-जुली है' : 'मिला-जुला है'),
    Tone.demanding => t(
      'asks for patience',
      feminine ? 'धैर्य माँगने वाली है' : 'धैर्य माँगने वाला है',
    ),
  };

  /// The weekday name, 0 = Sunday.
  String weekday(int day) => hindi
      ? const <String>[
          'रविवार',
          'सोमवार',
          'मंगलवार',
          'बुधवार',
          'गुरुवार',
          'शुक्रवार',
          'शनिवार',
        ][day]
      : const <String>[
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ][day];
}
