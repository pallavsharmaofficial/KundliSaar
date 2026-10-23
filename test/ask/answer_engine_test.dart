import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/ask/answer_engine.dart';
import 'package:kundlisaar/ask/ask_language.dart';
import 'package:kundlisaar/ask/ask_timing.dart';
import 'package:kundlisaar/ask/ask_yogas.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/phaladesh.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';
import 'package:kundlisaar/engine/jyotish/yogas.dart';

// =============================================================================
// The Ask feature, held to the rules it was written under:
//
//  * a question about timing is answered in the six parts, in order;
//  * every substantive answer ends with the closing line, in both languages;
//  * the refusals are exactly what they were, and they fire first;
//  * no answer says that something will happen on a date;
//  * no answer is without a chart factor;
//  * the yogas answer stays short however many yogas the chart carries.
// =============================================================================

const GeoPlace delhi = GeoPlace(
  name: 'Delhi',
  latitude: 28.6139,
  longitude: 77.2090,
  timeZoneId: 'Asia/Kolkata',
);
const GeoPlace chennai = GeoPlace(
  name: 'Chennai',
  latitude: 13.0827,
  longitude: 80.2707,
  timeZoneId: 'Asia/Kolkata',
);
const GeoPlace kolkata = GeoPlace(
  name: 'Kolkata',
  latitude: 22.5726,
  longitude: 88.3639,
  timeZoneId: 'Asia/Kolkata',
);

Kundli chartOf(DateTime local, GeoPlace place) => computeKundli(
  BirthData(
    name: 'Test',
    localDateTime: local,
    utcOffset: const Duration(hours: 5, minutes: 30),
    place: place,
  ),
);

/// Different lagnas, different moon nakshatras, and so different dasha
/// sequences and different tones.
final List<(String, Kundli)> charts = <(String, Kundli)>[
  ('delhi 1988', chartOf(DateTime(1988, 8, 14, 9, 35), delhi)),
  ('chennai 1975', chartOf(DateTime(1975, 3, 2, 22, 10), chennai)),
  ('kolkata 1999', chartOf(DateTime(1999, 12, 25, 5, 45), kolkata)),
  ('delhi 1962', chartOf(DateTime(1962, 6, 30, 14, 0), delhi)),
];

final DateTime moment = DateTime.utc(2026, 10, 14);

/// The words that mark the six parts of the timing answer, in order.
const List<String> sixParts = <String>[
  SectionKey.now,
  SectionKey.effect,
  SectionKey.remedy,
  SectionKey.better,
  SectionKey.how,
  SectionKey.close,
];

const List<String> hindiQuestions = <String>[
  'मेरी चंद्र राशि क्या है?',
  'मेरा अच्छा टाइम कब आएगा?',
  'अभी कौन सी दशा चल रही है?',
  'क्या मुझे मंगल दोष है?',
  'क्या साढ़े साती चल रही है?',
  'मेरी कुंडली में कौन से योग हैं?',
  'विवाह के बारे में कुंडली क्या कहती है?',
  'करियर के लिए कौन से भाव देखे जाते हैं?',
  'मेरे लिए कौन सा उपाय बताया गया है?',
  'मेरा लग्न क्या है?',
  'मेरा जन्म नक्षत्र क्या है?',
  'नक्षत्र क्या है?',
  'दशा क्या है?',
  'कौन सा ग्रह सबसे बलवान है?',
  'मेरे कौन से ग्रह वक्री हैं?',
  'नवांश के बारे में बताइए',
  'मेरी पढ़ाई कैसी रहेगी?',
  'पैसे के बारे में कुंडली क्या कहती है?',
  'मेरी नौकरी का अच्छा समय कब आएगा?',
  'शादी का अच्छा समय कब आएगा?',
  'मेरा बुरा समय कब ख़त्म होगा?',
  'कब सुधरेगा मेरा समय?',
  'आने वाला समय कैसा रहेगा',
  'पैसों का अच्छा टाइम कब आएगा',
  'पढ़ाई का अच्छा समय कब आएगा',
];

const List<String> englishQuestions = <String>[
  'What is my moon sign?',
  'When will my good time come?',
  'Which dasha is running now?',
  'Do I have Mangal dosha?',
  'Is Sade Sati running?',
  'Which yogas does my chart carry?',
  'What does the chart say about marriage?',
  'Which houses are read for career?',
  'What remedy does the tradition give me?',
  'What is my lagna?',
  'What is my janma nakshatra?',
  'What is a nakshatra?',
  'What is a dasha?',
  'Which planet is the strongest?',
  'Which of my planets are retrograde?',
  'Tell me about the navamsa',
  'How will my study go?',
  'What does the chart say about money?',
  'When is a good time for my career?',
  'When is a good time to get married?',
  'When will my bad time end?',
  'when will things get better',
  'What will the coming time be like, my period',
  'When will my income get better',
];

typedef Case = ({String chart, bool hindi, String question, Answer answer});

/// Every question, in both languages, on every chart. Worked out once.
final List<Case> allAnswers = () {
  final List<Case> out = <Case>[];
  for (final (String name, Kundli k) in charts) {
    for (final bool hindi in <bool>[true, false]) {
      for (final String q in hindi ? hindiQuestions : englishQuestions) {
        out.add((
          chart: name,
          hindi: hindi,
          question: q,
          answer: answerQuestion(k, q, hindi: hindi, now: moment),
        ));
      }
    }
  }
  return out;
}();

Iterable<Case> get substantive =>
    allAnswers.where((Case c) => c.answer.isSubstantive);

String label(Case c) => '${c.chart} / ${c.hindi ? 'hi' : 'en'} / ${c.question}';

/// Sentences of an answer, for the rules about what a sentence may say.
List<String> sentencesOf(String text) => text
    .split(RegExp(r'(?<=[.।!?])\s+|\n+'))
    .map((String s) => s.trim())
    .where((String s) => s.isNotEmpty)
    .toList();

final RegExp datePattern = RegExp(r'\b(19|20)\d{2}\b');

/// A verb that promises something will happen.
final RegExp eventVerb = RegExp(
  r'\b(will|shall|going to|would)\b|होगा|होगी|होंगे|मिलेगा|मिलेगी|मिलेंगे|आएगा|आएगी|आएँगे|आयेगा|आयेगी|पाएगा|पाएगी|पाएँगे|पाओगे|बनेगा|बनेगी|घटेगा|घटेगी',
  caseSensitive: false,
);

void main() {
  group('the refusals are what they always were, and they come first', () {
    // The wording the app has always used. A richer way of answering must not
    // soften it.
    const String refusalHindi =
        'यह ऐप मृत्यु, बीमारी, गर्भ, मुकदमे या निवेश के बारे में भविष्यवाणी नहीं करता। ये विषय किसी योग्य व्यक्ति से पूछें। कुंडली के बाक़ी हिस्सों के बारे में बेझिझक पूछिए।';
    const String refusalEnglish =
        'This app does not predict death, illness, pregnancy, court cases or investments. Those belong with a qualified professional. Ask me anything else about the chart.';

    // The phrases the refusal list has always held.
    const List<String> refused = <String>[
      'die',
      'death',
      'kab marunga',
      'mrityu',
      'cancer',
      'disease',
      'illness',
      'pregnan',
      'abortion',
      'court case',
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
    ];

    final Kundli k = charts.first.$2;

    test(
      'every phrase on the old list is still refused, in both languages',
      () {
        for (final String phrase in refused) {
          for (final bool hindi in <bool>[true, false]) {
            final Answer a = answerQuestion(
              k,
              phrase,
              hindi: hindi,
              now: moment,
            );
            expect(a.isRefusal, isTrue, reason: phrase);
            expect(a.isSubstantive, isFalse, reason: phrase);
          }
        }
      },
    );

    test(
      'the neighbours of those subjects are refused too, so a fuller answer is no way in',
      () {
        for (final String q in <String>[
          'mera swasthya kaisa rahega',
          'क्या मेरी सेहत का अच्छा समय कब आएगा',
          'when will my health get better',
          'bimari kab theek hogi',
          'will I have surgery',
          'accident ka yog hai kya',
          'संतान कब होगी',
          'baby kab hoga',
          'will we conceive',
          'court mein case kab jeetunga',
          'निवेश का अच्छा समय कब आएगा',
          'share market ka acha time kab aayega',
          'crypto mein paisa lagaun',
          'क्या मैं फेल हो जाऊँगा',
          'kya main pass ho jaunga',
          'maut kab aayegi',
          'rog kab theek hoga',
          'उम्र कितनी है मेरी',
        ]) {
          for (final bool hindi in <bool>[true, false]) {
            expect(
              answerQuestion(k, q, hindi: hindi, now: moment).isRefusal,
              isTrue,
              reason: q,
            );
          }
        }
      },
    );

    test('and no ordinary question is refused by mistake', () {
      for (final Case c in allAnswers) {
        expect(c.answer.isRefusal, isFalse, reason: label(c));
      }
      for (final String q in <String>[
        'what is a program of dasha',
        'tell me about my lagna',
        'which operation of the dasha runs now',
      ]) {
        // "program" holds "rog" but not as a word; "operation" is on the list,
        // so that last one is refused, and is the price of the list.
        final bool refused = answerQuestion(
          k,
          q,
          hindi: false,
          now: moment,
        ).isRefusal;
        expect(refused, q.contains('operation'), reason: q);
      }
    });

    test('the words of the refusal have not changed', () {
      final Answer hi = answerQuestion(k, 'मृत्यु', hindi: true);
      final Answer en = answerQuestion(k, 'death', hindi: false);
      expect(hi.title, 'यह मैं नहीं बता सकता');
      expect(en.title, 'I will not answer that');
      expect(hi.body, refusalHindi);
      expect(en.body, refusalEnglish);
      for (final Answer a in <Answer>[hi, en]) {
        expect(a.sections, hasLength(1));
        expect(a.basis, isEmpty);
        expect(a.closing, isEmpty);
      }
    });

    test('a refusal wins over every other intent in the same question', () {
      // Each question that would otherwise be answered richly, with a refused
      // phrase added at the end or put in front of it.
      final List<String> others = <String>[
        ...hindiQuestions,
        ...englishQuestions,
        'मेरा अच्छा टाइम कब आएगा',
        'अच्छा समय कब आएगा और मेरी मृत्यु कब होगी',
        'will my bad time end, and will i pass my exam',
        'when will my good time come, i want to invest',
        'what is my nakshatra, what is a dasha, any illness',
        'मेरी शादी का समय और मुकदमा',
        'पैसे का अच्छा समय कब आएगा शेयर में',
        'is sade sati running, will there be a pregnancy',
      ];
      for (final String q in others) {
        for (final String refusal in <String>[
          'death',
          'invest',
          'मृत्यु',
          'बीमारी',
        ]) {
          for (final String text in <String>['$q $refusal', '$refusal $q']) {
            expect(
              answerQuestion(
                k,
                text,
                hindi: text.contains(RegExp('[ऀ-ॿ]')),
                now: moment,
              ).isRefusal,
              isTrue,
              reason: text,
            );
          }
        }
      }
    });

    test(
      'the way a keyboard writes a Hindi letter does not get a person past it',
      () {
        // Anusvara for chandrabindu, a nukta or none, one character or two.
        for (final String q in <String>[
          'क्या मैं पास हूंगा',
          'मेरा रिज़ल्ट क्या होगा',
          'मेरा रिजल्ट क्या होगा',
          'बीमारी कब ठीक होगी',
          'मुक\u093Cदमा कब ख़त्म होगा',
          'मुक़दमा कब ख़त्म होगा',
        ]) {
          expect(intentOf(q), 'refuse', reason: q);
        }
        // And the same folding finds a subject typed another way.
        expect(intentOf('मेरी पढ़ाई कैसी रहेगी'), 'education');
        expect(intentOf('मेरी पढ\u093Cाई कैसी रहेगी'), 'education');
        expect(intentOf('मेरी पढाई कैसी रहेगी'), 'education');
        expect(foldHindi('\u095D\u093C'), foldHindi('\u0922'));
      },
    );

    test('the refusal is the first intent', () {
      expect(intentOf('death'), 'refuse');
      expect(intentOf('मेरा अच्छा टाइम कब आएगा और मृत्यु'), 'refuse');
      expect(intentOf('what is a nakshatra and any disease'), 'refuse');
    });

    test('no answer other than the refusal mentions the refused subjects', () {
      final RegExp banned = RegExp(
        r'\b(death|die|dies|dying|illness|disease|cancer|pregnancy|pregnant|abortion|lottery|jail|court)\b|मृत्यु|मौत|बीमारी|रोग|गर्भ|मुकदमा|रिजल्ट|नतीजा',
        caseSensitive: false,
      );
      for (final Case c in substantive) {
        final RegExpMatch? m = banned.firstMatch(c.answer.body);
        expect(m, isNull, reason: '${label(c)}: ${m?.group(0)}');
      }
    });

    test('the questions that were routed oddly before are routed rightly', () {
      expect(intentOf('what is a nakshatra'), 'whatis_nakshatra');
      expect(intentOf('नक्षत्र क्या है'), 'whatis_nakshatra');
      expect(intentOf('what is a dasha'), 'whatis_dasha');
      expect(intentOf('दशा क्या है'), 'whatis_dasha');
      expect(intentOf('क्या साढ़े साती चल रही है?'), 'sadesati');
      expect(intentOf('Is Sade Sati running?'), 'sadesati');
      expect(intentOf('अभी कौन सी दशा चल रही है?'), 'dasha');
      // A word that only contains "star" or "आय" is not those words.
      expect(intentOf('when do I start'), isNot('nakshatra'));
      expect(intentOf('मेरा अच्छा टाइम कब आयेगा?'), 'timing');
      expect(intentOf('मेरी आय कैसी रहेगी'), 'money');
      expect(intentOf('आयुर्वेद के बारे में'), isNot('money'));
      expect(intentOf('mera achha samay kab aayega'), 'timing');
    });
  });

  group('a question about timing is answered in six parts', () {
    final List<String> timing = <String>[
      'मेरा अच्छा टाइम कब आएगा?',
      'When will my good time come?',
    ];

    test('all six parts, in order, none of them empty', () {
      for (final (String name, Kundli k) in charts) {
        for (final String q in timing) {
          final bool hindi = q.contains(RegExp('[ऀ-ॿ]'));
          final Answer a = answerQuestion(k, q, hindi: hindi, now: moment);
          expect(
            a.sections.map((AnswerSection s) => s.key).toList(),
            sixParts,
            reason: '$name / $q',
          );
          for (final AnswerSection s in a.sections) {
            expect(s.heading, isNotEmpty, reason: '$name / $q / ${s.key}');
            expect(s.paragraphs, isNotEmpty, reason: '$name / $q / ${s.key}');
          }
        }
      }
    });

    test(
      'part one gives the running dasha, antardasha and pratyantardasha with dates',
      () {
        for (final (String name, Kundli k) in charts) {
          final Phaladesh p = computePhaladesh(k);
          final List<PeriodReading> chain = p.dasha.chainAt(moment);
          for (final bool hindi in <bool>[true, false]) {
            final Answer a = answerQuestion(
              k,
              hindi
                  ? 'मेरा अच्छा टाइम कब आएगा?'
                  : 'When will my good time come?',
              hindi: hindi,
              now: moment,
            );
            final String now = a.section(SectionKey.now)!.paragraphs.join(' ');
            for (final PeriodReading period in chain) {
              final String lord = hindi
                  ? grahaInfo(period.lord).hindi
                  : grahaInfo(period.lord).english;
              expect(now, contains(lord), reason: '$name ${period.level}');
            }
            // Dates: the antardasha and pratyantardasha carry a full date, the
            // mahadasha a month and year.
            final Iterable<RegExpMatch> years = RegExp(
              r'\b(19|20)\d{2}\b',
            ).allMatches(now);
            expect(years.length, greaterThanOrEqualTo(5), reason: name);
          }
        }
      },
    );

    test(
      'part two reads the lords from this chart: houses, sign, dignity, strength',
      () {
        for (final (String name, Kundli k) in charts) {
          final Phaladesh p = computePhaladesh(k);
          final PeriodReading maha = p.dasha.chainAt(moment).first;
          final GrahaStanding st = p.context.of(maha.lord);
          final Answer a = answerQuestion(
            k,
            'When will my good time come?',
            hindi: false,
            now: moment,
          );
          final String effect = a
              .section(SectionKey.effect)!
              .paragraphs
              .join(' ');
          expect(effect, contains(grahaInfo(maha.lord).english), reason: name);
          expect(effect, contains('house'), reason: name);
          if (st.bala != null) {
            expect(effect, contains('shadbala'), reason: name);
          }
          expect(
            effect,
            contains(rashiInfo(st.placed.rashi).english),
            reason: name,
          );
        }
      },
    );

    test('part three gives a remedy that has to be bought by no one', () {
      for (final Case c in allAnswers) {
        final Answer a = c.answer;
        if (a.section(SectionKey.remedy) == null || !a.isSubstantive) continue;
        final String remedy = a
            .section(SectionKey.remedy)!
            .paragraphs
            .join(' ');
        expect(
          remedy,
          c.hindi ? contains('ख़रीदना') : contains('bought'),
          reason: label(c),
        );
        expect(
          remedy,
          isNot(
            c.hindi
                ? matches(
                    RegExp(
                      'माणिक्य|मोती|मूंगा|पन्ना|पुखराज|हीरा|नीलम|गोमेद|लहसुनिया|अंगूठी',
                    ),
                  )
                : matches(
                    RegExp(
                      r'\b(ruby|pearl|coral|emerald|sapphire|diamond|ring|yantra)\b',
                      caseSensitive: false,
                    ),
                  ),
          ),
          reason: label(c),
        );
      }
    });

    test(
      'part four names the next stretch with dates and compares it with now',
      () {
        for (final (String name, Kundli k) in charts) {
          for (final bool hindi in <bool>[true, false]) {
            final Answer a = answerQuestion(
              k,
              hindi
                  ? 'मेरा अच्छा टाइम कब आएगा?'
                  : 'When will my good time come?',
              hindi: hindi,
              now: moment,
            );
            final String better = a
                .section(SectionKey.better)!
                .paragraphs
                .join(' ');
            expect(
              better,
              contains(hindi ? compareMarkerHindi : compareMarkerEnglish),
              reason: '$name / ${hindi ? 'hi' : 'en'}',
            );
            expect(
              datePattern.hasMatch(better),
              isTrue,
              reason: '$name: no date in part four',
            );
          }
        }
      },
    );

    test('part five names a lord and says what the tradition holds', () {
      for (final (String name, Kundli k) in charts) {
        final Answer a = answerQuestion(
          k,
          'When will my good time come?',
          hindi: false,
          now: moment,
        );
        final String how = a.section(SectionKey.how)!.paragraphs.join(' ');
        expect(how, contains('antardasha'), reason: name);
        expect(
          how,
          anyOf(contains('tradition'), contains('shastra')),
          reason: name,
        );
      }
    });

    test('part six is the closing line', () {
      for (final bool hindi in <bool>[true, false]) {
        final Answer a = answerQuestion(
          charts.first.$2,
          hindi ? 'मेरा अच्छा टाइम कब आएगा?' : 'When will my good time come?',
          hindi: hindi,
          now: moment,
        );
        expect(a.sections.last.key, SectionKey.close);
        expect(a.closing, hindi ? closingHindi : closingEnglish);
      }
    });

    test(
      'the same six parts answer a topic asked as a question about time',
      () {
        final Kundli k = charts.first.$2;
        for (final String q in <String>[
          'मेरी नौकरी का अच्छा समय कब आएगा?',
          'शादी का अच्छा समय कब आएगा?',
          'When is a good time for my career?',
          'When will my income get better',
        ]) {
          final Answer a = answerQuestion(
            k,
            q,
            hindi: q.contains(RegExp('[ऀ-ॿ]')),
            now: moment,
          );
          expect(
            a.sections.map((AnswerSection s) => s.key).toList(),
            sixParts,
            reason: q,
          );
        }
      },
    );

    test('shorter questions get a shorter version, never a bare sentence', () {
      final Kundli k = charts.first.$2;
      final Answer full = answerQuestion(
        k,
        'When will my good time come?',
        hindi: false,
        now: moment,
      );
      final Answer dasha = answerQuestion(
        k,
        'Which dasha is running now?',
        hindi: false,
        now: moment,
      );
      expect(dasha.sections.map((AnswerSection s) => s.key).toList(), sixParts);
      expect(dasha.body.length, lessThan(full.body.length));
      final Answer lagna = answerQuestion(
        k,
        'What is my lagna?',
        hindi: false,
        now: moment,
      );
      expect(lagna.sections.length, greaterThanOrEqualTo(3));
      expect(lagna.body.length, greaterThan(500));
    });
  });

  group('every substantive answer', () {
    test('ends with the closing line, in its own language', () {
      expect(substantive, isNotEmpty);
      for (final Case c in substantive) {
        expect(c.answer.sections.last.key, SectionKey.close, reason: label(c));
        expect(
          c.answer.closing,
          c.hindi ? closingHindi : closingEnglish,
          reason: label(c),
        );
        expect(
          c.answer.body.endsWith(c.hindi ? closingHindi : closingEnglish),
          isTrue,
          reason: label(c),
        );
      }
    });

    test(
      'the closing line says it is according to the shastra and not certain',
      () {
        expect(closingHindi, contains('शास्त्र के अनुसार'));
        expect(closingHindi, contains('निश्चित'));
        expect(closingEnglish, contains('according to the shastra'));
        expect(closingEnglish, contains('certain'));
        // A calm sentence, not a legal disclaimer.
        for (final String line in <String>[closingHindi, closingEnglish]) {
          expect(line.length, lessThan(260));
          expect(
            line,
            isNot(
              matches(
                RegExp(
                  'liab|responsib|disclaimer|दावा|ज़िम्मेदार',
                  caseSensitive: false,
                ),
              ),
            ),
          );
        }
      },
    );

    test('names at least one chart factor', () {
      for (final Case c in substantive) {
        expect(c.answer.basis, isNotEmpty, reason: label(c));
        final bool names = Graha.values.any(
          (Graha g) => c.answer.body.contains(
            c.hindi ? grahaInfo(g).hindi : grahaInfo(g).english,
          ),
        );
        expect(names, isTrue, reason: label(c));
      }
    });

    test(
      'the answers that are not substantive are only the refusals and the "not yet"',
      () {
        for (final Case c in allAnswers) {
          if (!c.answer.isSubstantive) {
            expect(c.answer.isRefusal || c.answer.isFallback, isTrue);
          }
        }
        // No question in the battery falls through to "not yet".
        expect(allAnswers.where((Case c) => c.answer.isFallback), isEmpty);
      },
    );

    test('is made of short paragraphs under clear headings', () {
      for (final Case c in substantive) {
        for (final AnswerSection s in c.answer.sections) {
          expect(s.heading, isNotEmpty, reason: '${label(c)} / ${s.key}');
          for (final String p in s.paragraphs) {
            expect(p.trim(), isNotEmpty, reason: label(c));
            expect(
              p.length,
              lessThan(900),
              reason: '${label(c)} / ${s.key}: a wall of text',
            );
          }
        }
      }
    });

    test('reads cleanly: no leftovers, no stray language', () {
      final RegExp leftovers = RegExp(
        r'null|NaN|Infinity|Instance of|\$\{|\$[a-z]|\{\}|  ',
      );
      final RegExp latin = RegExp(r'[A-Za-z]');
      final RegExp devanagari = RegExp('[ऀ-ॿ]');
      for (final Case c in allAnswers) {
        final String text =
            '${c.answer.title}\n${c.answer.body}\n${c.answer.basis.join('\n')}';
        expect(
          leftovers.hasMatch(text),
          isFalse,
          reason: '${label(c)}: ${leftovers.firstMatch(text)?.group(0)}',
        );
        if (c.hindi) {
          // Hindi answers carry no English words, apart from the names of the
          // divisional charts (D9, D10, D24).
          final String stripped = text.replaceAll(RegExp(r'\bD\d+\b'), '');
          final Match? m = latin.firstMatch(stripped);
          expect(
            m,
            isNull,
            reason:
                '${label(c)}: ${m == null ? '' : stripped.substring(m.start > 30 ? m.start - 30 : 0, m.start + 30)}',
          );
        } else {
          expect(
            devanagari.hasMatch(text),
            isFalse,
            reason: '${label(c)}: Hindi in an English answer',
          );
        }
      }
    });

    test(
      'is never frightening, and never promises a remedy will change anything',
      () {
        final RegExp doom = RegExp(
          r'\b(doom|disaster|catastroph|ruin|curse|tragedy|misfortune|calamity|dreadful|ominous|inauspicious|punish(ed|ment)? you)\w*|विनाश|बर्बाद|अनर्थ|अपशकुन|अमंगल|दुर्भाग्य|भयानक|विपत्ति|तबाही|सत्यानाश',
          caseSensitive: false,
        );
        for (final Case c in substantive) {
          if (c.answer.title.contains('योग') && c.hindi) continue;
          final Match? m = doom.firstMatch(c.answer.body);
          // The yoga library's own names (Shrapit and the like) are not doom
          // language written here.
          if (m != null && c.question.contains(RegExp('yoga|योग'))) continue;
          expect(m, isNull, reason: '${label(c)}: ${m?.group(0)}');
        }
      },
    );
  });

  group('no answer says that something will happen on a date', () {
    test('a sentence with a date in it never uses a verb that promises', () {
      for (final Case c in allAnswers) {
        for (final String s in sentencesOf(c.answer.body)) {
          if (!datePattern.hasMatch(s)) continue;
          expect(eventVerb.hasMatch(s), isFalse, reason: '${label(c)}: $s');
        }
      }
    });

    test('nothing in any answer promises an event', () {
      final RegExp promise = RegExp(
        r'you will (get|receive|marry|find|meet|be married|have)|will happen|will marry|शादी होगी|विवाह होगा|नौकरी मिलेगी|पैसा मिलेगा|धन मिलेगा|संतान होगी|बच्चा होगा',
        caseSensitive: false,
      );
      for (final Case c in allAnswers) {
        final Match? m = promise.firstMatch(c.answer.body);
        expect(m, isNull, reason: '${label(c)}: ${m?.group(0)}');
      }
    });

    test(
      'a question about when something happens is answered by periods, with the app saying it gives no dates for events',
      () {
        final Kundli k = charts.first.$2;
        final Answer en = answerQuestion(
          k,
          'When is a good time to get married?',
          hindi: false,
          now: moment,
        );
        final Answer hi = answerQuestion(
          k,
          'शादी का अच्छा समय कब आएगा?',
          hindi: true,
          now: moment,
        );
        expect(
          en.body,
          anyOf(
            contains('does not give dates for events'),
            contains('no stretch'),
          ),
        );
        expect(
          hi.body,
          anyOf(contains('घटना की तारीख़ नहीं'), contains('कोई ऐसा दौर नहीं')),
        );
      },
    );

    test('the dates given are where periods begin and end', () {
      final Kundli k = charts.first.$2;
      final Phaladesh p = computePhaladesh(k);
      final PeriodReading maha = p.dasha.chainAt(moment).first;
      final Answer a = answerQuestion(
        k,
        'Which dasha is running now?',
        hindi: false,
        now: moment,
      );
      final String now = a.section(SectionKey.now)!.paragraphs.join(' ');
      final DateTime end = maha.end.add(const Duration(hours: 5, minutes: 30));
      expect(now, contains('${end.year}'));
    });
  });

  group('the better stretch is found by rules that hold on every chart', () {
    test('invariants over sixty years of moments, general and by topic', () {
      final List<Set<int>> focuses = <Set<int>>[
        const <int>{},
        const <int>{7},
        const <int>{10, 6, 11},
        const <int>{2, 11},
        const <int>{4, 5},
      ];
      for (final (String name, Kundli k) in charts) {
        final Phaladesh p = computePhaladesh(k);
        final DateTime first = k.instant.utc.add(const Duration(days: 400));
        for (int i = 0; i < 90; i++) {
          final DateTime at = first.add(Duration(days: i * 247));
          for (final Set<int> focus in focuses) {
            final Stretch s = findStretch(p.timeline, at, focus: focus);
            final String why = '$name $at $focus ${s.kind}';
            switch (s.kind) {
              case StretchKind.outside:
                expect(p.timeline.windowAt(at), isNull, reason: why);
              case StretchKind.alreadyGood:
                expect(s.current, isNotNull, reason: why);
                for (final TimelineWindow w in s.goodRun) {
                  expect(
                    blendTone(blendScore(w)),
                    Tone.supportive,
                    reason: why,
                  );
                }
                expect(s.goodRun.first, same(s.current), reason: why);
                if (s.after != null) {
                  expect(
                    s.after!.start.isBefore(s.goodRun.last.end),
                    isFalse,
                    reason: why,
                  );
                }
              case StretchKind.betterAhead:
              case StretchKind.modestAhead:
                final TimelineWindow t = s.target!;
                expect(t.start.isBefore(s.current!.end), isFalse, reason: why);
                expect(blendScore(t), greaterThan(0), reason: why);
                if (s.kind == StretchKind.betterAhead && focus.isEmpty) {
                  expect(
                    blendTone(blendScore(t)),
                    Tone.supportive,
                    reason: why,
                  );
                  expect(
                    blendScore(t),
                    greaterThanOrEqualTo(blendScore(s.current!) + 1),
                    reason: why,
                  );
                }
                for (final TimelineWindow w in s.between) {
                  expect(
                    w.start.isBefore(s.current!.end),
                    isFalse,
                    reason: why,
                  );
                  expect(w.end.isAfter(t.start), isFalse, reason: why);
                }
              case StretchKind.nothingAhead:
                expect(s.current, isNotNull, reason: why);
            }
          }
        }
      }
    });

    test('a person already in a good stretch is told so, not told to wait', () {
      // Find a moment that is already good on the first chart.
      final Kundli k = charts.first.$2;
      final Phaladesh p = computePhaladesh(k);
      DateTime? good;
      for (final TimelineWindow w in p.timeline.windows) {
        if (blendTone(blendScore(w)) == Tone.supportive &&
            w.start.isAfter(k.instant.utc.add(const Duration(days: 400)))) {
          good = w.start.add(const Duration(days: 20));
          break;
        }
      }
      expect(good, isNotNull);
      final Answer en = answerQuestion(
        k,
        'When will my good time come?',
        hindi: false,
        now: good,
      );
      expect(
        en.section(SectionKey.better)!.paragraphs.first,
        contains('already'),
      );
      expect(
        en.section(SectionKey.better)!.paragraphs.join(' '),
        contains(compareMarkerEnglish),
      );
    });

    test('whatever moment is asked, the six parts are there', () {
      final Kundli k = charts[1].$2;
      for (final DateTime at in <DateTime>[
        DateTime.utc(1990, 2, 1),
        DateTime.utc(2005, 6, 15),
        DateTime.utc(2019, 11, 30),
        DateTime.utc(2030, 1, 1),
        DateTime.utc(2041, 9, 9),
        DateTime.utc(2060, 5, 5),
      ]) {
        for (final bool hindi in <bool>[true, false]) {
          final Answer a = answerQuestion(
            k,
            hindi ? 'मेरा अच्छा टाइम कब आएगा?' : 'When will my good time come?',
            hindi: hindi,
            now: at,
          );
          expect(a.isSubstantive, isTrue, reason: '$at');
          expect(
            a.sections.map((AnswerSection s) => s.key).toList(),
            sixParts,
            reason: '$at',
          );
        }
      }
    });

    test(
      'outside the years the chart can be read, the answer says so rather than guess',
      () {
        final Answer a = answerQuestion(
          charts.first.$2,
          'When will my good time come?',
          hindi: false,
          now: DateTime.utc(1970, 1, 1),
        );
        expect(a.isFallback, isTrue);
        expect(a.basis, isEmpty);
      },
    );
  });

  group('the yogas answer is grouped and bounded', () {
    test('every real chart: bounded, with the strongest first', () {
      for (final (String name, Kundli k) in charts) {
        for (final bool hindi in <bool>[true, false]) {
          final Answer a = answerQuestion(
            k,
            hindi
                ? 'मेरी कुंडली में कौन से योग हैं?'
                : 'Which yogas does my chart carry?',
            hindi: hindi,
            now: moment,
          );
          expect(
            a.body.length,
            lessThan(5200),
            reason: '$name ${a.body.length}',
          );
          final AnswerSection leading = a.section(SectionKey.leading)!;
          expect(
            leading.paragraphs.length,
            lessThanOrEqualTo(leadingYogas + 1),
            reason: name,
          );
        }
      }
    });

    YogaFinding make(
      String key,
      YogaFamily family, {
      bool dosha = false,
    }) => YogaFinding(
      key: key,
      nameEnglish: 'Yoga $key',
      nameHindi: 'योग $key',
      isDosha: dosha,
      ruleEnglish:
          'Jupiter stands in house 5 and Venus in house 9, the rule being written at some length as the real ones are.',
      ruleHindi:
          'गुरु पाँचवें भाव में और शुक्र नौवें भाव में है, और नियम उतना ही लंबा लिखा गया है जितने असली नियम होते हैं।',
      meaningEnglish:
          'Read as steady respect, good judgement and support from elders, which the books describe in a sentence or two of this length.',
      meaningHindi:
          'इसे सम्मान, विवेक और बड़ों के सहयोग से जोड़ा जाता है, जिसे ग्रंथ इतने ही लंबे एक-दो वाक्यों में बताते हैं।',
      cancellationEnglish: dosha
          ? 'A classical cancellation applies, and it is described in a sentence of some length.'
          : null,
      cancellationHindi: dosha
          ? 'एक शास्त्रीय भंग लागू होता है, और उसका वर्णन कुछ लंबे वाक्य में है।'
          : null,
      family: family,
    );

    test('seventy findings do not make a long answer', () {
      final List<YogaFinding> seventy = <YogaFinding>[
        for (int i = 0; i < 12; i++) make('mahapurusha_$i', YogaFamily.general),
        for (int i = 0; i < 12; i++)
          make('raja_yoga_${i}_9', YogaFamily.rajaDhana),
        for (int i = 0; i < 8; i++) make('vip_$i', YogaFamily.vipreetRaja),
        for (int i = 0; i < 8; i++) make('moon_$i', YogaFamily.chandra),
        for (int i = 0; i < 8; i++) make('sun_$i', YogaFamily.surya),
        for (int i = 0; i < 12; i++) make('nabhasa_$i', YogaFamily.nabhasa),
        for (int i = 0; i < 10; i++)
          make('dosha_$i', YogaFamily.dosha, dosha: true),
      ];
      expect(seventy.length, 70);
      for (final bool hindi in <bool>[true, false]) {
        final Answer a = composeYogas(AskLang(hindi), seventy);
        expect(
          a.body.length,
          lessThan(5200),
          reason: 'hindi=$hindi ${a.body.length}',
        );
        expect(a.sections.last.key, SectionKey.close);
        // Described in full: the leading yogas only, and two doshas.
        expect(
          a.section(SectionKey.leading)!.paragraphs.length,
          leadingYogas + 1,
        );
        expect(
          a.section(SectionKey.care)!.paragraphs.length,
          lessThanOrEqualTo(leadingDoshas + 3),
        );
        // The rest as names, a handful per family and a count for the others.
        for (final String line in a.section(SectionKey.others)!.paragraphs) {
          expect(line.length, lessThan(420), reason: line);
        }
      }
    });

    test('the strongest yogas lead and the weaker ones are only named', () {
      final List<YogaFinding> findings = <YogaFinding>[
        make('nabhasa_a', YogaFamily.nabhasa),
        make('vihaga', YogaFamily.chandra),
        make('mahapurusha_mars', YogaFamily.general),
        make('raja_yoga_10_9', YogaFamily.rajaDhana),
        make('gaja_kesari', YogaFamily.general),
        make('mangal_dosha', YogaFamily.dosha, dosha: true),
        make('lesser_dosha', YogaFamily.dosha, dosha: true),
        make('kaal_sarpa', YogaFamily.dosha, dosha: true),
      ];
      final Answer a = composeYogas(AskLang(false), findings);
      final String leading = a
          .section(SectionKey.leading)!
          .paragraphs
          .join(' ');
      expect(leading, contains('Yoga mahapurusha_mars'));
      expect(leading, contains('Yoga raja_yoga_10_9'));
      expect(leading, contains('Yoga gaja_kesari'));
      expect(leading, isNot(contains('Yoga nabhasa_a')));
      expect(
        a.section(SectionKey.others)!.paragraphs.join(' '),
        contains('Yoga nabhasa_a'),
      );
      final String care = a.section(SectionKey.care)!.paragraphs.join(' ');
      expect(
        care.indexOf('Yoga mangal_dosha'),
        lessThan(care.indexOf('Yoga lesser_dosha')),
      );
      expect(yogaWeight(findings[2]), greaterThan(yogaWeight(findings[0])));
    });

    test(
      'a chart with no yoga is told so plainly, and still gets the closing line',
      () {
        final Answer a = composeYogas(AskLang(true), const <YogaFinding>[]);
        expect(a.sections.last.key, SectionKey.close);
        expect(a.closing, closingHindi);
        expect(a.body, contains('कोई बड़ा योग'));
      },
    );

    test(
      'the doshas come with the relief the chart carries, never as a verdict',
      () {
        for (final (String name, Kundli k) in charts) {
          final Answer a = answerQuestion(
            k,
            'Which yogas does my chart carry?',
            hindi: false,
            now: moment,
          );
          final AnswerSection? care = a.section(SectionKey.care);
          if (care == null) continue;
          expect(
            care.paragraphs.first,
            contains('not a verdict'),
            reason: name,
          );
        }
      },
    );

    test('the yogas are tied to the dasha that brings them out', () {
      final Answer a = answerQuestion(
        charts.first.$2,
        'Which yogas does my chart carry?',
        hindi: false,
        now: moment,
      );
      final AnswerSection? running = a.section(SectionKey.running);
      expect(running, isNotNull);
      expect(running!.paragraphs.join(' '), contains('dasha'));
    });
  });

  group('whatever moment is asked, every question has a safe answer', () {
    test('from before birth to beyond the years the chart is read', () {
      final Kundli k = charts.first.$2;
      for (final DateTime at in <DateTime>[
        DateTime.utc(1960, 1, 1),
        DateTime.utc(1988, 8, 14, 5),
        DateTime.utc(2000, 3, 3),
        DateTime.utc(2060, 12, 31),
        DateTime.utc(2077, 6, 6),
        DateTime.utc(2100, 1, 1),
      ]) {
        for (final bool hindi in <bool>[true, false]) {
          for (final String q in hindi ? hindiQuestions : englishQuestions) {
            final Answer a = answerQuestion(k, q, hindi: hindi, now: at);
            final String why = '$at / ${hindi ? 'hi' : 'en'} / $q';
            if (a.isSubstantive) {
              expect(
                a.closing,
                hindi ? closingHindi : closingEnglish,
                reason: why,
              );
              expect(a.basis, isNotEmpty, reason: why);
            } else {
              expect(a.isFallback || a.isRefusal, isTrue, reason: why);
              expect(a.body, isNotEmpty, reason: why);
            }
          }
        }
      }
    });
  });

  group('reading aloud', () {
    test(
      'asked by voice, the answer is spoken as its gist, and still closes',
      () {
        final Kundli k = charts.first.$2;
        for (final bool hindi in <bool>[true, false]) {
          final Answer a = answerQuestion(
            k,
            hindi ? 'मेरा अच्छा टाइम कब आएगा?' : 'When will my good time come?',
            hindi: hindi,
            now: moment,
          );
          expect(a.gist.length, lessThan(a.spoken.length ~/ 2 + 400));
          expect(
            a.gist.endsWith(hindi ? closingHindi : closingEnglish),
            isTrue,
          );
          // Spoken unasked, it is the plain answer and the closing line.
          expect(a.short, isNotNull);
          expect(a.gist, contains(a.short!.heading));
          for (final String p in a.short!.paragraphs) {
            expect(a.gist, contains(p));
          }
        }
      },
    );

    test('the spoken answer is in pieces a speech engine will take', () {
      for (final Case c in substantive.take(120)) {
        final List<String> chunks = c.answer.spokenChunks();
        expect(chunks, isNotEmpty, reason: label(c));
        for (final String chunk in chunks) {
          expect(chunk.length, lessThanOrEqualTo(3500), reason: label(c));
        }
        // The closing line is the last thing said.
        expect(
          chunks.last.endsWith(c.hindi ? closingHindi : closingEnglish),
          isTrue,
          reason: label(c),
        );
        // Every heading is said.
        for (final AnswerSection s in c.answer.sections) {
          expect(
            chunks.join(' '),
            contains(s.heading),
            reason: '${label(c)} / ${s.key}',
          );
        }
      }
    });
  });
}
