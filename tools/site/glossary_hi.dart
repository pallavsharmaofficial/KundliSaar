/// Hindi (and plain English) labels for engine values that the engine only
/// carries in one form.
///
/// The engine already holds names, deities, lords and gemstones in both
/// scripts. What it lacks is a Hindi form for a handful of descriptive strings
/// (the animal of a yoni, the symbol of a nakshatra, the significations of a
/// graha, the names of yogas and karanas). They live here, keyed by the
/// engine's own English string, and every lookup fails loudly when the engine
/// grows a value this file has not heard of. A silent English fallback in the
/// middle of a Hindi paragraph is the failure this is built to prevent.
library;

import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';

String _need(Map<String, String> table, String key, String what) {
  final String? value = table[key];
  if (value == null) {
    throw StateError(
      'tools/site/glossary_hi.dart has no Hindi for $what "$key". '
      'The engine gained a value the site generator has not been taught.',
    );
  }
  return value;
}

/// "First" to "twenty-seventh", masculine, for use before the noun
/// "नक्षत्र" or "राशि" as in "चौथा नक्षत्र".
const List<String> ordinalsHindi = <String>[
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
  'तेरहवाँ',
  'चौदहवाँ',
  'पंद्रहवाँ',
  'सोलहवाँ',
  'सत्रहवाँ',
  'अठारहवाँ',
  'उन्नीसवाँ',
  'बीसवाँ',
  'इक्कीसवाँ',
  'बाईसवाँ',
  'तेईसवाँ',
  'चौबीसवाँ',
  'पच्चीसवाँ',
  'छब्बीसवाँ',
  'सत्ताईसवाँ',
];

/// The same, feminine, for "राशि" and "तिथि": "चौथी राशि".
const List<String> ordinalsHindiFeminine = <String>[
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

String ordinalEnglish(int n) {
  final int tens = n % 100;
  if (tens >= 11 && tens <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

const List<String> weekdayEnglish = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const List<String> monthEnglish = <String>[
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

const List<String> monthHindi = <String>[
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

String ganaEnglish(Gana gana) => switch (gana) {
  Gana.deva => 'Deva',
  Gana.manushya => 'Manushya',
  Gana.rakshasa => 'Rakshasa',
};

String ganaHindi(Gana gana) => switch (gana) {
  Gana.deva => 'देव',
  Gana.manushya => 'मनुष्य',
  Gana.rakshasa => 'राक्षस',
};

String nadiEnglish(Nadi nadi) => switch (nadi) {
  Nadi.adi => 'Adi',
  Nadi.madhya => 'Madhya',
  Nadi.antya => 'Antya',
};

String nadiHindi(Nadi nadi) => switch (nadi) {
  Nadi.adi => 'आदि',
  Nadi.madhya => 'मध्य',
  Nadi.antya => 'अंत्य',
};

String elementEnglish(Element element) => switch (element) {
  Element.fire => 'fire',
  Element.earth => 'earth',
  Element.air => 'air',
  Element.water => 'water',
};

String elementHindi(Element element) => switch (element) {
  Element.fire => 'अग्नि',
  Element.earth => 'पृथ्वी',
  Element.air => 'वायु',
  Element.water => 'जल',
};

/// The Sanskrit term is the useful one here, so English carries both.
String qualityEnglish(Quality quality) => switch (quality) {
  Quality.movable => 'movable (chara)',
  Quality.fixed => 'fixed (sthira)',
  Quality.dual => 'dual (dvisvabhava)',
};

String qualityHindi(Quality quality) => switch (quality) {
  Quality.movable => 'चर',
  Quality.fixed => 'स्थिर',
  Quality.dual => 'द्विस्वभाव',
};

/// The everyday word first and the traditional one in brackets, because a
/// reader who knows "गज योनि" and one who only knows "हाथी" both land here. The
/// sheep keeps its traditional name second so it is never read as the sign.
const Map<String, String> _yoniHindi = <String, String>{
  'horse': 'घोड़ा (अश्व)',
  'elephant': 'हाथी (गज)',
  'sheep': 'भेड़ (मेष)',
  'serpent': 'साँप (सर्प)',
  'dog': 'कुत्ता (श्वान)',
  'cat': 'बिल्ली (मार्जार)',
  'goat': 'बकरी (अज)',
  'rat': 'चूहा (मूषक)',
  'cow': 'गाय (गौ)',
  'buffalo': 'भैंस (महिष)',
  'tiger': 'बाघ (व्याघ्र)',
  'deer': 'हिरण (मृग)',
  'monkey': 'बंदर (वानर)',
  'mongoose': 'नेवला (नकुल)',
  'lion': 'शेर (सिंह)',
};

String yoniHindi(String yoni) => _need(_yoniHindi, yoni, 'yoni');

/// The engine keeps nakshatra symbols in English only.
const Map<String, String> _symbolHindi = <String, String>{
  "Horse's head": 'घोड़े का सिर',
  'Yoni': 'योनि',
  'Razor, flame': 'छुरा, ज्वाला',
  'Cart': 'गाड़ी',
  "Deer's head": 'मृग का सिर',
  'Teardrop': 'आँसू की बूँद',
  'Quiver of arrows': 'बाणों से भरा तरकश',
  "Cow's udder": 'गाय का थन',
  'Coiled serpent': 'कुंडली मारे सर्प',
  'Royal throne': 'राजसिंहासन',
  'Front of a bed': 'पलंग का अगला भाग',
  'Back of a bed': 'पलंग का पिछला भाग',
  'Open hand': 'खुली हथेली',
  'Bright jewel': 'चमकता रत्न',
  'Young shoot in the wind': 'हवा में झूमता नन्हा अंकुर',
  'Triumphal arch': 'विजय-तोरण',
  'Lotus': 'कमल',
  'Earring, umbrella': 'कुंडल, छत्र',
  'Bunch of roots': 'जड़ों का गुच्छा',
  'Winnowing basket': 'सूप',
  "Elephant's tusk": 'हाथी का दाँत',
  'Three footprints': 'तीन पदचिह्न',
  'Drum': 'ढोल',
  'Empty circle': 'खाली घेरा',
  'Front of a funeral cot': 'अर्थी की खाट का अगला भाग',
  'Back of a funeral cot': 'अर्थी की खाट का पिछला भाग',
  'Fish': 'मछली',
};

String symbolHindi(String symbol) => _need(_symbolHindi, symbol, 'symbol');

/// The symbol as a noun phrase that reads in an English sentence ("a cart",
/// "an open hand"), keyed by the engine's label.
const Map<String, String> _symbolPhrase = <String, String>{
  "Horse's head": "a horse's head",
  'Yoni': 'the yoni',
  'Razor, flame': 'a razor and a flame',
  'Cart': 'a cart',
  "Deer's head": "a deer's head",
  'Teardrop': 'a teardrop',
  'Quiver of arrows': 'a quiver of arrows',
  "Cow's udder": "a cow's udder",
  'Coiled serpent': 'a coiled serpent',
  'Royal throne': 'a royal throne',
  'Front of a bed': 'the front of a bed',
  'Back of a bed': 'the back of a bed',
  'Open hand': 'an open hand',
  'Bright jewel': 'a bright jewel',
  'Young shoot in the wind': 'a young shoot in the wind',
  'Triumphal arch': 'a triumphal arch',
  'Lotus': 'a lotus',
  'Earring, umbrella': 'an earring and an umbrella',
  'Bunch of roots': 'a bunch of roots',
  'Winnowing basket': 'a winnowing basket',
  "Elephant's tusk": "an elephant's tusk",
  'Three footprints': 'three footprints',
  'Drum': 'a drum',
  'Empty circle': 'an empty circle',
  'Front of a funeral cot': 'the front of a funeral cot',
  'Back of a funeral cot': 'the back of a funeral cot',
  'Fish': 'a fish',
};

String symbolForSentence(String symbol) =>
    _need(_symbolPhrase, symbol, 'symbol phrase');

/// A deity as it reads in a sentence: the groups take an article.
String deityForSentence(String deity) =>
    deity.endsWith('s') ? 'the $deity' : deity;

/// "the Sun" and "the Moon" take an article in English prose; the rest do
/// not. Pass the engine's English name.
String grahaForSentence(String english) =>
    english == 'Sun' || english == 'Moon' ? 'the $english' : english;

String sentenceCase(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

const Map<String, String> _karakaHindi = <String, String>{
  'Soul, father, authority': 'आत्मा, पिता, अधिकार',
  'Mind, mother, feeling': 'मन, माता, भावना',
  'Courage, brothers, land': 'पराक्रम, भाई, भूमि',
  'Speech, intellect, trade': 'वाणी, बुद्धि, व्यापार',
  'Wisdom, children, teachers': 'ज्ञान, संतान, गुरुजन',
  'Love, marriage, art': 'प्रेम, विवाह, कला',
  'Work, discipline, longevity': 'कर्म, अनुशासन, आयु',
  'Desire, foreign things': 'कामना, परदेश की बातें',
  'Detachment, liberation': 'वैराग्य, मोक्ष',
};

String karakaHindi(String karaka) => _need(_karakaHindi, karaka, 'karaka');

const Map<String, String> _metalHindi = <String, String>{
  'Gold or copper': 'सोना या ताँबा',
  'Silver': 'चाँदी',
  'Copper': 'ताँबा',
  'Bronze': 'काँसा',
  'Gold': 'सोना',
  'Iron': 'लोहा',
  'Lead': 'सीसा',
  'Mixed metal': 'मिश्र धातु',
};

String metalHindi(String metal) => _need(_metalHindi, metal, 'metal');

/// The same metals in the form that goes before "में": "सोने में", "लोहे में".
const Map<String, String> _metalHindiIn = <String, String>{
  'Gold or copper': 'सोने या ताँबे',
  'Silver': 'चाँदी',
  'Copper': 'ताँबे',
  'Bronze': 'काँसे',
  'Gold': 'सोने',
  'Iron': 'लोहे',
  'Lead': 'सीसे',
  'Mixed metal': 'मिश्र धातु',
};

String metalHindiIn(String metal) => _need(_metalHindiIn, metal, 'metal');

/// The same nine mantras the engine holds in Latin letters.
String mantraHindi(Graha graha) => switch (graha) {
  Graha.sun => 'ॐ ह्रां ह्रीं ह्रौं सः सूर्याय नमः',
  Graha.moon => 'ॐ श्रां श्रीं श्रौं सः चंद्राय नमः',
  Graha.mars => 'ॐ क्रां क्रीं क्रौं सः भौमाय नमः',
  Graha.mercury => 'ॐ ब्रां ब्रीं ब्रौं सः बुधाय नमः',
  Graha.jupiter => 'ॐ ग्रां ग्रीं ग्रौं सः गुरवे नमः',
  Graha.venus => 'ॐ द्रां द्रीं द्रौं सः शुक्राय नमः',
  Graha.saturn => 'ॐ प्रां प्रीं प्रौं सः शनैश्चराय नमः',
  Graha.rahu => 'ॐ भ्रां भ्रीं भ्रौं सः राहवे नमः',
  Graha.ketu => 'ॐ स्रां स्रीं स्रौं सः केतवे नमः',
};

/// The Sanskrit name of each graha in Devanagari, which is not always the
/// everyday one: Jupiter is गुरु in speech and बृहस्पति in the texts.
String sanskritHindi(Graha graha) => switch (graha) {
  Graha.sun => 'सूर्य',
  Graha.moon => 'चंद्र',
  Graha.mars => 'मंगल',
  Graha.mercury => 'बुध',
  Graha.jupiter => 'बृहस्पति',
  Graha.venus => 'शुक्र',
  Graha.saturn => 'शनि',
  Graha.rahu => 'राहु',
  Graha.ketu => 'केतु',
};

const Map<String, String> _yogaHindi = <String, String>{
  'Vishkambha': 'विष्कंभ',
  'Priti': 'प्रीति',
  'Ayushman': 'आयुष्मान',
  'Saubhagya': 'सौभाग्य',
  'Shobhana': 'शोभन',
  'Atiganda': 'अतिगंड',
  'Sukarma': 'सुकर्मा',
  'Dhriti': 'धृति',
  'Shula': 'शूल',
  'Ganda': 'गंड',
  'Vriddhi': 'वृद्धि',
  'Dhruva': 'ध्रुव',
  'Vyaghata': 'व्याघात',
  'Harshana': 'हर्षण',
  'Vajra': 'वज्र',
  'Siddhi': 'सिद्धि',
  'Vyatipata': 'व्यतीपात',
  'Variyana': 'वरीयान',
  'Parigha': 'परिघ',
  'Shiva': 'शिव',
  'Siddha': 'सिद्ध',
  'Sadhya': 'साध्य',
  'Shubha': 'शुभ',
  'Shukla': 'शुक्ल',
  'Brahma': 'ब्रह्म',
  'Indra': 'इन्द्र',
  'Vaidhriti': 'वैधृति',
};

String yogaHindi(String yoga) => _need(_yogaHindi, yoga, 'yoga');

const Map<String, String> _karanaHindi = <String, String>{
  'Bava': 'बव',
  'Balava': 'बालव',
  'Kaulava': 'कौलव',
  'Taitila': 'तैतिल',
  'Garaja': 'गर',
  'Vanija': 'वणिज',
  'Vishti': 'विष्टि (भद्रा)',
  'Shakuni': 'शकुनि',
  'Chatushpada': 'चतुष्पाद',
  'Naga': 'नाग',
  'Kimstughna': 'किंस्तुघ्न',
};

String karanaHindi(String karana) => _need(_karanaHindi, karana, 'karana');

const Map<String, String> _choghadiyaHindi = <String, String>{
  'Udveg': 'उद्वेग',
  'Char': 'चर',
  'Labh': 'लाभ',
  'Amrit': 'अमृत',
  'Kaal': 'काल',
  'Shubh': 'शुभ',
  'Rog': 'रोग',
};

String choghadiyaHindi(String name) =>
    _need(_choghadiyaHindi, name, 'choghadiya');

/// The Hindi name of a Rahu Kaal style period, keyed by the engine's name.
const Map<String, String> _periodHindi = <String, String>{
  'Rahu Kaal': 'राहु काल',
  'Yamaganda': 'यमगंड',
  'Gulika': 'गुलिक काल',
  'Abhijit': 'अभिजित मुहूर्त',
};

String periodHindi(String name) => _need(_periodHindi, name, 'period');

/// Paksha as the engine names it, then in Hindi.
String pakshaHindi(String paksha) => switch (paksha) {
  'Shukla' => 'शुक्ल पक्ष',
  'Krishna' => 'कृष्ण पक्ष',
  _ => throw StateError('Unknown paksha "$paksha"'),
};

String pakshaEnglish(String paksha) => '$paksha paksha';
