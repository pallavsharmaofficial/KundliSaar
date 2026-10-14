import '../engine/jyotish/chart.dart';
import 'answer_model.dart';
import 'ask_context.dart';
import 'ask_language.dart';
import 'ask_plain.dart';
import 'ask_short.dart';
import 'ask_story.dart';
import 'ask_topics.dart';
import 'ask_yogas.dart';

export 'answer_model.dart';
export 'ask_context.dart' show phaladeshFor;
export 'ask_plain.dart' show notYetAnswer, refusalAnswer;
export 'ask_language.dart'
    show
        closingEnglish,
        closingHindi,
        compareMarkerEnglish,
        compareMarkerHindi,
        foldHindi;

// =============================================================================
// The Ask feature.
//
// A question is matched to an intent, and the intent is answered the way a
// person who knows the chart would explain it to someone sitting in front of
// them: what is running now, what it tends to bring, what helps, when a better
// stretch comes and how it differs from now, what the shastra says, and a
// plain closing line. Shorter questions get a shorter version of the same
// thing, never a bare sentence.
//
// The order of the intents matters, and the refusal is first. Death, illness,
// pregnancy, examination results, court cases and investments are never
// answered, and no way of answering richly is allowed to become a way in.
// =============================================================================

class _Intent {
  const _Intent(
    this.key,
    this.keywords, {
    this.words = const <String>[],
    this.pairs = const <(List<String>, List<String>)>[],
  });

  final String key;

  /// Substrings that match anywhere in the question.
  final List<String> keywords;

  /// Short words that only count when they stand alone.
  final List<String> words;

  /// A question matches when one word from each side is in it.
  final List<(List<String>, List<String>)> pairs;

  /// [text] is lowercased and folded (see [foldHindi]).
  bool matches(String text) {
    bool has(String k) => text.contains(foldHindi(k));
    if (keywords.any(has)) return true;
    if (words.any((String w) => hasWholeWord(text, foldHindi(w)))) return true;
    for (final (List<String> a, List<String> b) in pairs) {
      if (a.any(has) && b.any(has)) return true;
    }
    return false;
  }
}

/// Words that mark a question about time ("when", "good time").
const List<String> _whenWords = <String>['कब', 'when', 'kab'];
const List<String> _qualityWords = <String>[
  'अच्छा',
  'अच्छे',
  'अच्छी',
  'बेहतर',
  'सुधर',
  'सही',
  'good',
  'better',
  'bad',
  'बुरा',
  'बुरे',
  'खराब',
  'ख़राब',
  'मुश्किल',
  'कठिन',
  'bura',
  'kharab',
  'acha',
  'achha',
  'accha',
  'theek',
  'thik',
  'sahi',
];
const List<String> _timeWords = <String>[
  'समय',
  'टाइम',
  'time',
  'दौर',
  'samay',
  'phase',
  'period',
];

final List<_Intent> _intents = <_Intent>[
  // The refusal comes first and its list is the one the app has always had.
  // Do not reorder, and do not loosen it.
  const _Intent(
    'refuse',
    <String>[
      'death',
      'kab marunga',
      'mrityu',
      'cancer',
      'disease',
      'illness',
      'pregnan',
      'abortion',
      'court case',
      // Education as an area of life is read; a result is not predicted.
      // 'exam' alone stays with education, so these have to be the
      // result-seeking phrasings, and refuse is matched before it.
      'exam result',
      'exam ka result',
      'will i pass',
      'will i clear',
      'pass the exam',
      'clear the exam',
      'pass hounga',
      'pass hoonga',
      'paas hounga',
      'exam me pass',
      'result kya',
      'परीक्षा में पास',
      'पास हूँगा',
      'पास होऊंगा',
      'रिजल्ट',
      'नतीजा',
      'jail',
      'stock',
      'invest',
      'lottery',
      'satta',
      'मृत्यु',
      'मौत',
      'बीमारी',
      'रोग',
      'गर्भ',
      'मुकदमा',
      'शेयर',
      'सट्टा',
    ],
    // "die" as a substring also sits inside "studies", so an honest question
    // about schooling was being refused as a question about death. Matched as
    // a whole word it still catches what it is for.
    words: <String>['die', 'died', 'dies', 'dying'],
  ),
  // The same refusal, for the ways these subjects are also asked about: in
  // Roman letters, and by their neighbours (health, surgery, children, the
  // verdict of a court, the share market). The list above is untouched; this
  // one only closes doors a fuller answering style would otherwise leave
  // open.
  const _Intent(
    'refuse',
    <String>[
      'health',
      'sehat',
      'swasthya',
      'स्वास्थ्य',
      'सेहत',
      'तबीयत',
      'tabiyat',
      'bimari',
      'beemari',
      'bimaar',
      'bemari',
      'बिमारी',
      'ilaaj',
      'इलाज',
      'surgery',
      'operation',
      'accident',
      'दुर्घटना',
      'हादसा',
      'ऑपरेशन',
      'सर्जरी',
      'maut',
      'marna',
      'marne',
      'mar jaunga',
      'mar jaungi',
      'longevity',
      'lifespan',
      'life span',
      'umr kitni',
      'उम्र कितनी',
      'आयु कितनी',
      'conceive',
      'conception',
      'baby',
      'garbh',
      'santan',
      'सन्तान',
      'संतान',
      'putra prapti',
      'पुत्र प्राप्ति',
      'bachcha kab',
      'बच्चा कब',
      'बच्चे कब',
      'delivery',
      'डिलीवरी',
      'childbirth',
      'child birth',
      'court',
      'कोर्ट',
      'police',
      'arrest',
      'गिरफ्तार',
      'जेल',
      'mukadma',
      'muqadma',
      'mukdama',
      'lawsuit',
      'निवेश',
      'nivesh',
      'share market',
      'sharemarket',
      'mutual fund',
      'crypto',
      'bitcoin',
      'trading',
      'gambl',
      'जुआ',
      'लॉटरी',
      'speculat',
      'फेल',
      'will i fail',
      'qualify',
      'उत्तीर्ण',
      'अनुत्तीर्ण',
      'पास हो',
      'पास कर',
      'paas ho',
      'pass ho',
      'pass kar',
      'परीक्षा का परिणाम',
      'exam ka natija',
    ],
    words: <String>['rog'],
  ),
  // Explanations of the words themselves. They sit above "nakshatra" and
  // "dasha", whose keywords they contain.
  const _Intent('whatis_nakshatra', <String>[
    'what is a nakshatra',
    'what is nakshatra',
    'nakshatra kya',
    'नक्षत्र क्या',
  ]),
  const _Intent('whatis_dasha', <String>[
    'what is dasha',
    'what is a dasha',
    'dasha kya',
    'दशा क्या',
  ]),
  // When a better time comes. Above "dasha", whose "समय" it contains.
  const _Intent(
    'timing',
    <String>[
      'good time',
      'bad time',
      'better time',
      'good period',
      'bad period',
      'golden period',
      'good phase',
      'bad phase',
      'turning point',
      'achha time',
      'accha time',
      'acha time',
      'achha samay',
      'accha samay',
      'acha samay',
      'bura time',
      'bura samay',
      'kharab time',
      'kharab samay',
      'अच्छा समय',
      'अच्छा टाइम',
      'अच्छे दिन',
      'अच्छा दौर',
      'बुरा समय',
      'बुरा टाइम',
      'बुरा दौर',
      'खराब समय',
      'खराब टाइम',
      'ख़राब समय',
      'ख़राब टाइम',
      'मुश्किल समय',
      'कठिन समय',
      'सही समय',
      'सही टाइम',
      'कब बदलेगा',
      'कब सुधरेगा',
      'कब सुधरेगी',
      'कब ठीक',
      'कब आएगा',
      'कब आयेगा',
      'कब आएगी',
      'कब आयेगी',
      'kab aayega',
      'kab ayega',
      'kab aayegi',
      'kab badlega',
      'kab sudhrega',
      'kab theek',
      'kab thik',
      'when will things',
      'when will it get better',
      'when will my luck',
      'when will my time',
      'when will life',
      'किस्मत कब',
      'भाग्य कब',
    ],
    pairs: <(List<String>, List<String>)>[
      (_whenWords, _timeWords),
      (_whenWords, <String>['दशा', 'dasha']),
      (_qualityWords, _timeWords),
    ],
  ),
  const _Intent('lagna', <String>['lagna', 'ascendant', 'rising', 'लग्न']),
  const _Intent('moon', <String>[
    'moon sign',
    'rashi',
    'chandra',
    'राशि',
    'चंद्र',
  ]),
  const _Intent(
    'nakshatra',
    <String>['nakshatra', 'janma', 'नक्षत्र'],
    words: <String>['star'],
  ),
  // Sade Sati by its own name sits above "dasha", whose "चल रही" would
  // otherwise take "क्या साढ़े साती चल रही है".
  const _Intent('sadesati', <String>[
    'sade sati',
    'sadesati',
    'sade-sati',
    'साढ़े साती',
    'साढ़ेसाती',
    'साढे साती',
    'साढेसाती',
  ]),
  const _Intent('dasha', <String>[
    'dasha',
    'period',
    'mahadasha',
    'antardasha',
    'चल रही',
    'दशा',
    'समय',
  ]),
  const _Intent('sadesati', <String>['shani', 'शनि']),
  const _Intent('mangal', <String>[
    'mangal',
    'manglik',
    'kuja',
    'मंगल',
    'मांगलिक',
  ]),
  _Intent(
    marriageTopic.key,
    marriageTopic.keywords,
    words: marriageTopic.words,
  ),
  _Intent(careerTopic.key, careerTopic.keywords, words: careerTopic.words),
  _Intent(
    educationTopic.key,
    educationTopic.keywords,
    words: educationTopic.words,
  ),
  _Intent(moneyTopic.key, moneyTopic.keywords, words: moneyTopic.words),
  const _Intent('remedy', <String>[
    'remedy',
    'upay',
    'mantra',
    'gemstone',
    'उपाय',
    'मंत्र',
    'रत्न',
  ]),
  const _Intent('strength', <String>[
    'strongest',
    'weakest',
    'strong',
    'weak',
    'बलवान',
    'कमज़ोर',
    'मजबूत',
  ]),
  const _Intent('retrograde', <String>['retrograde', 'vakri', 'वक्री']),
  const _Intent('yogas', <String>['yoga', 'dosha', 'योग', 'दोष']),
  const _Intent('navamsa', <String>['navamsa', 'd9', 'नवांश']),
];

List<String> suggestedQuestions(bool hindi) => hindi
    ? const <String>[
        'मेरी चंद्र राशि क्या है?',
        'मेरा अच्छा टाइम कब आएगा?',
        'अभी कौन सी दशा चल रही है?',
        'क्या मुझे मंगल दोष है?',
        'क्या साढ़े साती चल रही है?',
        'मेरी कुंडली में कौन से योग हैं?',
        'विवाह के बारे में कुंडली क्या कहती है?',
        'करियर के लिए कौन से भाव देखे जाते हैं?',
        'मेरे लिए कौन सा उपाय बताया गया है?',
      ]
    : const <String>[
        'What is my moon sign?',
        'When will my good time come?',
        'Which dasha is running now?',
        'Do I have Mangal dosha?',
        'Is Sade Sati running?',
        'Which yogas does my chart carry?',
        'What does the chart say about marriage?',
        'Which houses are read for career?',
        'What remedy does the tradition give me?',
      ];

/// The intent a question belongs to, or `fallback`. The tests use it to hold
/// the order of the intents.
String intentOf(String question) {
  final String text = foldHindi(question.toLowerCase());
  for (final _Intent intent in _intents) {
    if (intent.matches(text)) return intent.key;
  }
  return 'fallback';
}

/// Answers [question] from [kundli], in Hindi or English. [now] is the moment
/// the periods and the transits are read for; it defaults to the present.
Answer answerQuestion(
  Kundli kundli,
  String question, {
  required bool hindi,
  DateTime? now,
}) {
  final String key = intentOf(question);
  if (key == 'refuse') return refusalAnswer(hindi);
  if (key == 'fallback') return notYetAnswer(hindi);

  final AskCtx c = AskCtx(kundli, now ?? DateTime.now(), hindi);
  final AskLang l = c.l;
  switch (key) {
    case 'timing':
      final Topic? topic = topicOf(question);
      return composeStory(
        c,
        topic: topic,
        titleEn: topic == null
            ? 'Your good time'
            : '${topic.titleEn}: your good time',
        titleHi: topic == null
            ? 'आपका अच्छा समय'
            : '${topic.titleHi}: आपका अच्छा समय',
      );
    case 'dasha':
      return composeStory(
        c,
        compact: true,
        titleEn: 'The period running now',
        titleHi: 'अभी चल रही दशा',
      );
    case 'marriage':
      return _topicStory(c, marriageTopic);
    case 'career':
      return _topicStory(c, careerTopic);
    case 'education':
      return _topicStory(c, educationTopic);
    case 'money':
      return _topicStory(c, moneyTopic);
    case 'lagna':
      return lagnaAnswer(c);
    case 'moon':
      return moonAnswer(c);
    case 'nakshatra':
      return nakshatraAnswer(c);
    case 'whatis_nakshatra':
      return whatIsNakshatraAnswer(c);
    case 'whatis_dasha':
      return whatIsDashaAnswer(c);
    case 'sadesati':
      return sadeSatiAnswer(c);
    case 'mangal':
      return mangalAnswer(c);
    case 'remedy':
      return remedyAnswer(c);
    case 'strength':
      return strengthAnswer(c);
    case 'retrograde':
      return retrogradeAnswer(c);
    case 'yogas':
      return composeYogaAnswer(c);
    case 'navamsa':
      return navamsaAnswer(c);
  }
  return notYetAnswer(l.hindi);
}

Answer _topicStory(AskCtx c, Topic topic) => composeStory(
  c,
  topic: topic,
  titleEn: topic.titleEn,
  titleHi: topic.titleHi,
);
