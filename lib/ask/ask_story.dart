import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/dasha.dart' show vimshottariYears;
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/phaladesh.dart';
import '../engine/jyotish/remedies.dart';
import 'answer_model.dart';
import 'ask_context.dart';
import 'ask_language.dart';
import 'ask_plain.dart';
import 'ask_timing.dart';
import 'ask_topics.dart';

// =============================================================================
// The six-part answer.
//
// Every substantial question is answered in the same order, the way a person
// who knows the chart would explain it to someone sitting in front of them:
//
//   1. what is running now, with its dates;
//   2. what that period tends to bring, read from THIS chart;
//   3. what helps;
//   4. the next clearly better stretch, with its dates, compared with now;
//   5. how it comes about, and what the shastra says of that combination;
//   6. a plain closing line.
//
// A period is only ever described by what it asks for and supports. A date
// here is where a period begins or ends, never the day something happens.
// =============================================================================

AnswerSection closeSection(AskLang l) => AnswerSection(
  key: SectionKey.close,
  heading: l.t('To close', 'अंत में'),
  paragraphs: <String>[l.t(closingEnglish, closingHindi)],
);

/// Composes the six-part answer for the moment in [c]. With a [topic] the
/// answer is about one part of life; with [compact] each part is kept short.
Answer composeStory(
  AskCtx c, {
  Topic? topic,
  bool compact = false,
  required String titleEn,
  required String titleHi,
}) {
  if (c.maha == null || c.antar == null || c.window == null) {
    return notYetAnswer(c.hindi);
  }
  final Stretch stretch = findStretch(
    c.p.timeline,
    c.now,
    focus: topic?.touchHouses ?? const <int>{},
    concerns: topic == null
        ? null
        : (Graha g) => c.concerns(g, topic.touchHouses),
  );
  return Answer(
    title: c.l.t(titleEn, titleHi),
    short: shortSection(c, topic, stretch),
    sections: <AnswerSection>[
      nowSection(c),
      effectSection(c, topic, compact: compact),
      remedySection(c, topic, compact: compact),
      betterSection(c, topic, stretch, compact: compact),
      howSection(c, topic, stretch, compact: compact),
      closeSection(c.l),
    ],
    basis: storyBasis(c, topic, stretch),
  );
}

// -----------------------------------------------------------------------------
// 0. The plain answer
// -----------------------------------------------------------------------------

/// The answer in three lines and no terms of the shastra: how the time is,
/// when it eases, and one thing to do. The six parts below explain each line.
AnswerSection shortSection(AskCtx c, Topic? topic, Stretch s) {
  final AskLang l = c.l;
  final TimelineWindow cur = s.current ?? c.window!;
  final List<String> paras = <String>[];

  if (topic != null) {
    // About one part of life the line is read for that part, and the general
    // tone of the time is not repeated: it is said once, on its own.
    final String name = l.t(topic.nameEn, topic.nameHi);
    final Tone tone = blendTone(blendScore(cur));
    paras.add(
      !topicTouches(c, topic, cur)
          ? l.t(
              'The present time does not put much weight on $name; it neither pushes it forward nor holds it back.',
              'अभी का समय $name पर ज़्यादा ज़ोर नहीं देता; न इसे आगे धकेलता है, न रोकता है।',
            )
          : switch (tone) {
              Tone.supportive => l.t(
                'For $name the time is good now: the chart stands with it, so this is the time to put in effort.',
                '$name के लिए अभी समय अच्छा है: कुंडली इसका साथ देती है, इसलिए अभी मेहनत लगाइए।',
              ),
              Tone.mixed => l.t(
                '$name is in focus now, but the support is not full: things move with effort.',
                '$name पर अभी ध्यान रहता है, पर पूरा सहारा नहीं: मेहनत से बात बनती है।',
              ),
              Tone.demanding => l.t(
                '$name asks for patience now. Do not hurry big decisions here.',
                '$name में अभी धैर्य चाहिए। इसमें बड़े फ़ैसले जल्दबाज़ी में न लीजिए।',
              ),
            },
    );
  } else {
    final String until = c.monthYear(cur.end);
    paras.add(switch (blendTone(blendScore(cur))) {
      Tone.supportive => l.t(
        'Your time is good right now. Work you put in now tends to move forward easily. This stretch runs until $until.',
        'अभी आपका समय अच्छा चल रहा है। इस समय की गई मेहनत आसानी से आगे बढ़ती है। यह दौर $until तक है।',
      ),
      Tone.mixed => l.t(
        'Your time is mixed right now: some things come easily, some take a little more effort. This stretch runs until $until.',
        'अभी आपका समय मिला-जुला है: कुछ काम आसानी से बनते हैं, कुछ में थोड़ी ज़्यादा मेहनत लगती है। यह दौर $until तक है।',
      ),
      Tone.demanding => l.t(
        'Right now the time asks for hard work and patience. Do not worry, it does not stay like this. This stretch runs until $until.',
        'अभी का समय मेहनत और धैर्य वाला है। घबराइए नहीं, यह हमेशा ऐसा नहीं रहता। यह दौर $until तक है।',
      ),
    });
  }

  switch (s.kind) {
    case StretchKind.alreadyGood:
      final DateTime end = s.goodRun.isEmpty ? cur.end : s.goodRun.last.end;
      paras.add(
        l.t(
          'This is itself the good time${topic == null ? '' : ' for ${topic.nameEn}'}, until ${c.monthYear(end)}. Make full use of it.',
          '${topic == null ? 'यही आपका अच्छा समय है' : '${topic.nameHi} के लिए यही अच्छा समय है'}, ${c.monthYear(end)} तक। इसका पूरा फ़ायदा उठाइए।',
        ),
      );
    case StretchKind.betterAhead:
      final TimelineWindow t = s.target!;
      paras.add(
        l.t(
          'A better time${topic == null ? '' : ' for ${topic.nameEn}'} begins in ${c.monthYear(t.start)} and runs until ${c.monthYear(t.end)}.',
          '${topic == null ? 'इससे बेहतर समय' : '${topic.nameHi} के लिए बेहतर समय'} ${c.monthYear(t.start)} से शुरू होता है और ${c.monthYear(t.end)} तक चलता है।',
        ),
      );
    case StretchKind.modestAhead:
      final TimelineWindow t = s.target!;
      paras.add(
        l.t(
          'From ${c.monthYear(t.start)} the time gets somewhat lighter.',
          '${c.monthYear(t.start)} से समय कुछ हल्का होने लगता है।',
        ),
      );
    case StretchKind.nothingAhead:
      paras.add(
        l.t(
          'The coming years stay much like now, so steady effort is your biggest support.',
          'आने वाले सालों में समय लगभग ऐसा ही रहता है, इसलिए लगातार मेहनत ही सबसे बड़ा सहारा है।',
        ),
      );
    case StretchKind.outside:
      break;
  }

  final List<Remedy> remedies = pickRemedies(c, topic);
  if (remedies.isNotEmpty) {
    paras.add(
      l.t(
        'One easy thing to do: ${remedies.first.kit.simpleAct.en}',
        'एक आसान उपाय: ${remedies.first.kit.simpleAct.hi}',
      ),
    );
  }

  return plainSection(l, paras);
}

/// How one part of life stands at the moment, for a one-word label.
enum TopicMood { good, mixed, patience, quiet }

TopicMood topicMood(AskCtx c, Topic topic) {
  final TimelineWindow? cur = c.window;
  if (cur == null || !topicTouches(c, topic, cur)) return TopicMood.quiet;
  return switch (blendTone(blendScore(cur))) {
    Tone.supportive => TopicMood.good,
    Tone.mixed => TopicMood.mixed,
    Tone.demanding => TopicMood.patience,
  };
}

/// The plain answer's part, under the same heading in every answer.
AnswerSection plainSection(AskLang l, List<String> paragraphs) => AnswerSection(
  key: SectionKey.short,
  heading: l.t('The answer in short', 'सीधा जवाब'),
  paragraphs: paragraphs.where((String p) => p.trim().isNotEmpty).toList(),
);

// -----------------------------------------------------------------------------
// 1. What is running now
// -----------------------------------------------------------------------------

AnswerSection nowSection(AskCtx c) {
  final AskLang l = c.l;
  final PeriodReading maha = c.maha!;
  final PeriodReading antar = c.antar!;
  final String m = c.name(maha.lord);
  final List<String> paras = <String>[];

  // The mahadasha.
  final int years = vimshottariYears[maha.lord]!.round();
  final String tag = years >= 18
      ? l.t(
          'which counts among the longest dashas',
          'जो सबसे लंबी दशाओं में गिनी जाती है',
        )
      : years >= 16
      ? l.t(
          'which counts among the long dashas',
          'जो लंबी दशाओं में गिनी जाती है',
        )
      : years <= 7
      ? l.t(
          'which counts among the short dashas',
          'जो छोटी दशाओं में गिनी जाती है',
        )
      : l.t('which is of middling length', 'जो बीच की लंबाई की दशा है');
  final double total = maha.end.difference(maha.start).inSeconds.toDouble();
  final double done = total <= 0
      ? 1
      : c.now.difference(maha.start).inSeconds / total;
  final String part = done < 1 / 3
      ? l.t('early part', 'शुरुआती हिस्से')
      : done < 2 / 3
      ? l.t('middle part', 'बीच के हिस्से')
      : l.t('last part', 'आख़िरी हिस्से');
  final String remain = l.span(maha.end.difference(c.now));
  final String end = c.monthYear(maha.end);
  final String began = c.startedAtBirth(maha)
      ? l.t(
          'which had already begun before you were born',
          'जो आपके जन्म से पहले ही शुरू हो चुकी थी',
        )
      : l.t(
          'which began in ${c.monthYear(maha.start)}',
          'जो ${c.monthYear(maha.start)} में शुरू हुई थी',
        );
  paras.add(
    l.t(
      'Right now you are in the $m mahadasha, $began and runs until $end. It is a $years-year dasha, $tag. You are in its $part, with $remain still to run.',
      'अभी आप $m की महादशा में हैं, $began और $end तक चलेगी। यह कुल $years साल की दशा है, $tag। आप इसके $part में हैं, और अभी $remain बाक़ी हैं।',
    ),
  );

  // The antardasha.
  final String a = c.name(antar.lord);
  final String same = antar.lord == maha.lord
      ? l.t(
          ' Here the antardasha belongs to the same graha, so the mahadasha’s own nature comes forward in its plainest form.',
          ' यहाँ अंतर्दशा भी उसी ग्रह की है, इसलिए महादशा का अपना स्वभाव सबसे सीधे रूप में सामने रहता है।',
        )
      : '';
  paras.add(
    l.t(
      'Inside it the $a antardasha is running, from ${c.date(antar.start)} to ${c.date(antar.end)}. Think of the mahadasha as a long chapter and the antardasha as the page of it you are on now.$same',
      'इसके भीतर $a की अंतर्दशा चल रही है, जो ${c.date(antar.start)} से ${c.date(antar.end)} तक है। महादशा को लंबा अध्याय समझिए और अंतर्दशा को उस अध्याय का वह पन्ना, जिस पर आप अभी हैं।$same',
    ),
  );

  // The pratyantardasha.
  final PeriodReading? praty = c.praty;
  if (praty != null) {
    final String p = c.name(praty.lord);
    final String span = l.span(praty.end.difference(praty.start));
    paras.add(
      l.t(
        'At the finest level the $p pratyantardasha is running, from ${c.date(praty.start)} to ${c.date(praty.end)}: a short turn of $span.',
        'सबसे बारीक स्तर पर $p की प्रत्यंतर्दशा चल रही है, ${c.date(praty.start)} से ${c.date(praty.end)} तक, यानी $span का एक छोटा-सा मोड़।',
      ),
    );
  }

  if (c.k.birth.timeIsApproximate) {
    paras.add(
      l.t(
        'One caution: the birth time was entered as an estimate. A few minutes’ difference can move the dates of the dashas by weeks, and an hour’s difference can change the lagna and the houses, so do not treat these dates as exact.',
        'एक सावधानी: जन्म का समय अनुमान से दर्ज है। कुछ मिनट का फ़र्क़ दशाओं की तारीख़ें हफ़्तों खिसका सकता है, और घंटे भर का फ़र्क़ लग्न और भाव बदल सकता है; इसलिए इन तारीख़ों को पक्का न मानें।',
      ),
    );
  }

  return AnswerSection(
    key: SectionKey.now,
    heading: l.t('Which period is running now', 'अभी कौन सी दशा चल रही है'),
    paragraphs: paras,
  );
}

// -----------------------------------------------------------------------------
// 2. What it tends to bring
// -----------------------------------------------------------------------------

/// How the long chapter and the page of it sit together, in a sentence.
String toneSentence(AskLang l, Tone maha, Tone antar) {
  switch ((maha, antar)) {
    case (Tone.supportive, Tone.supportive):
      return l.t(
        'On the whole the mahadasha and the antardasha both stand with you in this chart, and effort put in at such a time tends to move forward without much resistance.',
        'कुल मिलाकर महादशा और अंतर्दशा, दोनों इस कुंडली में आपका साथ देती हैं, और ऐसे समय में की गई मेहनत अक्सर बिना ज़्यादा रुकावट के आगे बढ़ती है।',
      );
    case (Tone.supportive, Tone.mixed):
      return l.t(
        'The mahadasha stands with you, and in the antardasha support and effort go together. The time as a whole is in your favour; it only asks for a little patience now and then.',
        'महादशा आपका साथ देती है, और अंतर्दशा में सहारा और मेहनत साथ-साथ चलते हैं। कुल मिलाकर समय आपके पक्ष में है, बस बीच-बीच में थोड़ा धैर्य चाहिए।',
      );
    case (Tone.supportive, Tone.demanding):
      return l.t(
        'The long chapter is in your favour, but this smaller page asks you to walk a little carefully. The support of the whole chapter stays with you.',
        'बड़ा अध्याय आपके पक्ष में है, पर यह छोटा पन्ना थोड़ा सँभलकर चलने को कहता है। पूरे अध्याय का सहारा फिर भी आपके साथ बना रहता है।',
      );
    case (Tone.mixed, Tone.supportive):
      return l.t(
        'In the mahadasha support and effort go together, but the antardasha is helping, so the part you are in now is the easier one.',
        'महादशा में सहारा और मेहनत साथ-साथ चलते हैं, पर अंतर्दशा मदद कर रही है, इसलिए अभी का हिस्सा ज़्यादा आसान है।',
      );
    case (Tone.mixed, Tone.mixed):
      return l.t(
        'In both, support and effort go together: some things come easily, others take more patience.',
        'दोनों में सहारा और मेहनत साथ-साथ चलते हैं: कुछ बातें सहज बनती हैं, कुछ में ज़्यादा धैर्य लगता है।',
      );
    case (Tone.mixed, Tone.demanding):
      return l.t(
        'The mahadasha is mixed, but the antardasha asks for more effort, so the part you are in now is the heavier one. Pages turn, and this is only a page.',
        'महादशा मिली-जुली है, पर अंतर्दशा ज़्यादा मेहनत माँगती है, इसलिए अभी का हिस्सा थोड़ा भारी है। पन्ने बदलते रहते हैं, और यह सिर्फ़ एक पन्ना है।',
      );
    case (Tone.demanding, Tone.supportive):
      return l.t(
        'The long chapter (the mahadasha) asks a lot of effort, but the page you are on (the antardasha) helps. So this is the lighter part of a heavy chapter.',
        'बड़ा अध्याय (महादशा) मेहनत माँगता है, पर आप जिस पन्ने पर हैं (अंतर्दशा), वह मदद करता है। यानी यह एक भारी अध्याय का कुछ हल्का हिस्सा है।',
      );
    case (Tone.demanding, Tone.mixed):
      return l.t(
        'The mahadasha asks for more effort, and in the antardasha too support and effort go together. This is a time of patience.',
        'महादशा ज़्यादा मेहनत माँगती है, और अंतर्दशा में भी सहारा और मेहनत साथ-साथ चलते हैं। यह धैर्य का समय है।',
      );
    case (Tone.demanding, Tone.demanding):
      return l.t(
        'Both the mahadasha and the antardasha ask for effort and patience. Do not read this as a punishment: the tradition treats such a time as one in which work is built step by step rather than all at once.',
        'महादशा और अंतर्दशा, दोनों मेहनत और धैर्य माँगती हैं। इसे सज़ा न समझिए: शास्त्र ऐसे समय को वह दौर मानता है जिसमें काम एक साथ नहीं, एक-एक क़दम करके बनता है।',
      );
  }
}

/// A short paragraph on the two slow transits that matter most, for the
/// general question only.
String? gocharParagraph(AskCtx c) {
  final AskLang l = c.l;
  GocharReading? sat;
  GocharReading? jup;
  for (final GocharReading r in c.gochar.readings) {
    if (r.graha == Graha.saturn) sat = r;
    if (r.graha == Graha.jupiter) jup = r;
  }
  if (sat == null || jup == null) return null;
  String line(GocharReading r) => l.t(
    '${c.name(r.graha)} is in ${l.sign(r.sign)}, ${l.house(r.houseFromMoon)} from your natal Moon, which the usual table counts as ${r.favourable ? 'favourable' : 'asking for effort'}',
    '${c.name(r.graha)} ${l.sign(r.sign)} राशि में है, आपके जन्म चंद्र से ${l.house(r.houseFromMoon)} में, जिसे गोचर की आम तालिका ${r.favourable ? 'अच्छा' : 'मेहनत वाला'} मानती है',
  );
  final String sade = c.gochar.sadeSati == null
      ? ''
      : ' ${c.gochar.sadeSati!.of(c.hindi)}';
  final String lands = sat.landsOnDasha
      ? l.t(
          ' Saturn’s weight falls on the very matters the running dasha is about.',
          ' शनि का असर उन्हीं बातों पर पड़ रहा है जिनसे चल रही दशा जुड़ी है।',
        )
      : '';
  return l.t(
    'Now the transits, that is, where the grahas stand in the sky today: ${line(sat)}; ${line(jup)}.$sade$lands',
    'अब गोचर देखिए, यानी ग्रह आज आसमान में कहाँ हैं: ${line(sat)}; ${line(jup)}।$sade$lands',
  );
}

AnswerSection effectSection(AskCtx c, Topic? topic, {required bool compact}) {
  final AskLang l = c.l;
  final PeriodReading maha = c.maha!;
  final PeriodReading antar = c.antar!;
  final List<String> paras = <String>[];
  final Set<int> optional = <int>{};

  if (topic != null) {
    // A part of life: the chart's own reading of it, then the running periods
    // linked to it, then how the two sit together.
    paras.addAll(topicEffectParagraphs(c, topic, compact: compact));
  } else {
    paras.add(c.standing(maha.lord, depth: compact ? 2 : 3));

    // What the mahadasha concentrates on.
    final List<LifeArea> areas = maha.areas;
    if (areas.isNotEmpty) {
      final int first = areas.first.house;
      final String why = c.whyHouse(maha.lord, first);
      final String also = areas.length > 1
          ? l.t(
              ', with ${l.area(areas[1].house)} also in view',
              ', और साथ में ${l.area(areas[1].house)} की बातें भी नज़र में रहती हैं',
            )
          : '';
      final String me = c.name(maha.lord);
      final String colour = compact
          ? ''
          : l.t(
              ' $me’s own nature (${l.themes(maha.lord)}) colours all of it.',
              ' $me का अपना स्वभाव, यानी ${l.themes(maha.lord)}, इस सब पर रंग चढ़ाता है।',
            );
      final String tends = compact
          ? ''
          : ' ${c.firstSentenceOf(maha.tends.of(c.hindi))}';
      paras.add(
        l.t(
          'So in this mahadasha most things revolve around ${l.area(first)} ($why)$also.$colour$tends',
          'इसलिए इस महादशा में ज़्यादातर बातें ${l.area(first)} के आसपास घूमती हैं ($why)$also।$colour$tends',
        ),
      );
    }

    // The antardasha lord.
    final String b = c.name(antar.lord);
    final String focusWhy = antar.areas.isEmpty
        ? ''
        : ' (${c.whyHouse(antar.lord, antar.areas.first.house)})';
    paras.add(
      l.t(
        'The antardasha lord is $b. ${c.standing(antar.lord, depth: compact ? 0 : 1)} ${c.modifierLine(antar)}',
        'अंतर्दशा का स्वामी $b है। ${c.standing(antar.lord, depth: compact ? 0 : 1)} ${c.modifierLine(antar)}',
      ),
    );
    paras.add(
      l.t(
        'In this antardasha the weight falls on ${c.focusPhrase(antar)}$focusWhy. ${toneSentence(l, maha.tone, antar.tone)}',
        'इस अंतर्दशा में ज़ोर ${c.focusPhrase(antar)} पर रहता है$focusWhy। ${toneSentence(l, maha.tone, antar.tone)}',
      ),
    );
  }

  // What eases it.
  if (maha.tone != Tone.supportive || antar.tone != Tone.supportive) {
    final List<String> eases = <String>[
      if (maha.relief != null)
        l.t(
          'For ${c.name(maha.lord)}: ${maha.relief!.en}',
          '${c.name(maha.lord)} के लिए: ${maha.relief!.hi}',
        ),
      if (antar.relief != null && antar.relief!.en != maha.relief?.en)
        l.t(
          'For ${c.name(antar.lord)}: ${antar.relief!.en}',
          '${c.name(antar.lord)} के लिए: ${antar.relief!.hi}',
        ),
    ];
    if (eases.isNotEmpty && !compact) {
      optional.add(paras.length);
      paras.add(
        l.t(
          'On what eases it. ${eases.join(' ')}',
          'राहत के आधार देखें तो। ${eases.join(' ')}',
        ),
      );
    }
  }

  if (!compact && topic == null) {
    final String? transits = gocharParagraph(c);
    if (transits != null) {
      optional.add(paras.length);
      paras.add(transits);
    }
  }

  return AnswerSection(
    key: SectionKey.effect,
    heading: topic == null
        ? l.t('What this period tends to bring', 'इसका आप पर क्या असर पड़ता है')
        : l.t(
            'What the chart shows for ${topic.nameEn}',
            'इसका ${topic.nameHi} पर क्या असर पड़ता है',
          ),
    paragraphs: paras,
    optional: optional,
  );
}

// -----------------------------------------------------------------------------
// 3. What helps
// -----------------------------------------------------------------------------

/// The first sentence of [text], without its full stop.
String _firstSentence(String text) {
  final int at = text.indexOf(RegExp(r'[.।]'));
  return at < 0 ? text : text.substring(0, at);
}

String _afterLead(String text, String lead) =>
    text.startsWith(lead) ? text.substring(lead.length) : text;

/// The remedy of one graha, as it is said to a person: the mantra, the day,
/// the giving and one plain thing for every day. [why] names what presses on
/// the graha in this chart. Nothing here is bought.
List<String> kitParagraphs(
  AskCtx c,
  Graha g, {
  Bi? why,
  bool brief = false,
  bool compact = false,
}) {
  final AskLang l = c.l;
  final GrahaRemedyKit kit = grahaRemedyKits[g]!;
  final String me = c.name(g);
  final String mantra = kit.mantra.of(c.hindi);
  final String day = l.weekday(kit.fastDay);
  final String deity = kit.deity.of(c.hindi);
  final String reason = why == null ? '' : '${why.of(c.hindi)} ';
  if (brief) {
    return <String>[
      l.t(
        '${reason}The same simple way serves here: the mantra “$mantra”, a light fast on $day, and some giving.',
        '$reasonइसके लिए भी वही सरल तरीक़ा है: “$mantra” का जप, $day का हल्का व्रत और थोड़ा दान।',
      ),
    ];
  }
  if (compact) {
    return <String>[
      l.t(
        '${reason}To strengthen $me the tradition gives the mantra “$mantra” (one mala a day is enough), a light fast or some giving on $day, and one easy daily thing: ${kit.simpleAct.en}',
        '$reasonपरंपरा में $me को बल देने के लिए “$mantra” का जप (रोज़ एक माला काफ़ी है), $day को हल्का व्रत या थोड़ा दान, और रोज़ की एक आसान बात बताई गई है: ${kit.simpleAct.hi}',
      ),
    ];
  }
  final String items = _firstSentence(
    _afterLead(
      kit.daan.of(c.hindi),
      c.hindi ? 'परंपरा में: ' : 'Traditionally: ',
    ),
  );
  return <String>[
    l.t(
      '${reason}The tradition gives these simple things to strengthen $me: the mantra “$mantra”, where one mala a day (108 repetitions) is enough; and a light fast on $day, remembering $deity. Anyone for whom fasting does not suit keeps the day with the mantra and giving alone.',
      '$reasonपरंपरा में $me को बल देने के लिए ये सरल बातें बताई गई हैं: “$mantra” का जप, जिसमें रोज़ एक माला (108 बार) काफ़ी है; और $day को हल्का व्रत, जिसमें $deity का स्मरण करें। जिन्हें व्रत रास न आए, वे उस दिन सिर्फ़ मंत्र और दान करें।',
    ),
    l.t(
      'For giving, the tradition names $items; give whatever you have at home, with your own hand, to someone who needs it. And one easy thing for every day: ${kit.simpleAct.en}',
      'दान में परंपरा $items बताती है; जो आपके घर में हो, वही अपने हाथ से किसी ज़रूरतमंद को दे दीजिए। और रोज़ की एक आसान बात: ${kit.simpleAct.hi}',
    ),
  ];
}

/// The remedies the chart itself asks for, the topic's own first, then those of
/// the running periods, at most two grahas.
List<Remedy> pickRemedies(AskCtx c, Topic? topic) {
  final Set<Graha> seen = <Graha>{};
  final List<Remedy> out = <Remedy>[];
  final List<Remedy> pool = <Remedy>[
    if (topic != null)
      for (final int h in topic.readHouses) ...c.p.bhavas[h - 1].remedies,
    ...?c.maha?.remedies,
    ...?c.antar?.remedies,
  ];
  for (final Remedy r in pool) {
    if (seen.add(r.graha)) out.add(r);
    if (out.length == 2) break;
  }
  return out;
}

AnswerSection remedySection(AskCtx c, Topic? topic, {required bool compact}) {
  final AskLang l = c.l;
  final PeriodReading maha = c.maha!;
  final PeriodReading antar = c.antar!;
  final List<String> paras = <String>[];
  final Set<int> optional = <int>{};

  // First the attitude, which is what the period itself asks.
  final List<String> asks = <String>[maha.asks.of(c.hindi)];
  if (antar.tone == Tone.demanding && antar.asks.en != maha.asks.en) {
    asks.add(antar.asks.of(c.hindi));
  }
  paras.add(
    l.t(
      'First, the attitude the period asks for. ${asks.join(' ')}',
      'सबसे पहले इस दौर का रवैया समझ लीजिए। ${asks.join(' ')}',
    ),
  );

  final List<Remedy> remedies = pickRemedies(c, topic);
  if (remedies.isEmpty) {
    final Graha g = maha.lord;
    paras.add(
      l.t(
        'Nothing in this chart presses hard on the ${c.name(g)} period, so a remedy here is not a cure for anything. It only keeps a good time strong.',
        'इस कुंडली में ${c.name(g)} की दशा पर कोई बड़ा दबाव नहीं दिखता, इसलिए यहाँ उपाय किसी तकलीफ़ का इलाज नहीं है। यह सिर्फ़ अच्छे समय को मज़बूत रखने के लिए है।',
      ),
    );
    paras.addAll(kitParagraphs(c, g, compact: compact));
  } else {
    paras.addAll(
      kitParagraphs(
        c,
        remedies.first.graha,
        why: remedies.first.addresses,
        compact: compact,
      ),
    );
    if (remedies.length > 1 && !compact) {
      optional.add(paras.length);
      paras.addAll(
        kitParagraphs(
          c,
          remedies[1].graha,
          why: remedies[1].addresses,
          brief: true,
        ),
      );
    }
  }
  paras.add(
    l.t(
      'Nothing here has to be bought; what is in your house is enough. Keep these as a practice: they steady the mind, but they promise nothing about what will come.',
      'इनमें कुछ भी ख़रीदना ज़रूरी नहीं है; जो आपके घर में है, उसी से हो जाता है। इन्हें अभ्यास की तरह रखिए। ये मन को स्थिर करते हैं, पर आगे क्या होगा, इसका कोई वादा नहीं करते।',
    ),
  );
  return AnswerSection(
    key: SectionKey.remedy,
    heading: l.t('What can help during this time', 'इस समय क्या उपाय करें'),
    paragraphs: paras,
    optional: optional,
  );
}

// -----------------------------------------------------------------------------
// 4. The better stretch, compared with now
// -----------------------------------------------------------------------------

String _windowLine(AskCtx c, TimelineWindow w) => c.l.t(
  'the ${c.name(w.antarLord)} antardasha (${c.date(w.start)} to ${c.date(w.end)})',
  '${c.name(w.antarLord)} की अंतर्दशा (${c.date(w.start)} से ${c.date(w.end)} तक)',
);

/// What the graha is for this lagna, as a clause that follows its name.
String natureClause(AskCtx c, Graha g) {
  final AskLang l = c.l;
  final Graha who = (g == Graha.rahu || g == Graha.ketu) ? c.st(g).reader : g;
  return switch (c.st(who).nature) {
    FunctionalNature.yogakaraka => l.t(
      'is a yogakaraka for your lagna',
      'आपके लग्न के लिए योगकारक है',
    ),
    FunctionalNature.benefic => l.t(
      'gives good results for your lagna',
      'आपके लग्न के लिए शुभ फल देने वाला है',
    ),
    FunctionalNature.mixed => l.t(
      'gives mixed results for your lagna',
      'आपके लग्न के लिए मिला-जुला फल देने वाला है',
    ),
    FunctionalNature.malefic => l.t(
      'gives its results through effort for your lagna',
      'आपके लग्न के लिए मेहनत से फल देने वाला है',
    ),
  };
}

bool topicTouches(AskCtx c, Topic topic, TimelineWindow w) => windowTouches(
  w,
  topic.touchHouses,
  concerns: (Graha g) => c.concerns(g, topic.touchHouses),
);

String _stateOfNow(AskCtx c, Topic? topic, TimelineWindow cur) {
  final AskLang l = c.l;
  final Tone blend = blendTone(blendScore(cur));
  final String m = l.toneClause(cur.maha.tone, feminine: true);
  final String a = l.toneClause(cur.period.tone, feminine: true);
  if (topic != null) {
    final String name = l.t(topic.nameEn, topic.nameHi);
    if (!topicTouches(c, topic, cur)) {
      return l.t(
        'For $name, the period running now does not put its weight on that part of life, so it stays in the background for the moment.',
        '$name के लिए अभी चल रहा दौर ज़िंदगी के इस हिस्से पर ज़ोर नहीं देता, इसलिए यह अभी पीछे है।',
      );
    }
    return l.t(
      'For $name, the period running now does touch that part of life, but the chart’s support for it is not full: taken together, the time ${l.toneClause(blend)}.',
      '$name के लिए अभी चल रहा दौर ज़िंदगी के इस हिस्से को छूता तो है, पर कुंडली का सहारा पूरा नहीं है: दोनों को मिलाकर समय ${l.toneClause(blend)}।',
    );
  }
  if (blend == Tone.demanding) {
    return l.t(
      'The time you are in asks for more patience than most: the mahadasha $m and the antardasha $a.',
      'अभी का दौर सामान्य से ज़्यादा धैर्य माँगता है: महादशा $m और अंतर्दशा $a।',
    );
  }
  return l.t(
    'The time you are in is mixed: the mahadasha $m and the antardasha $a. Taken together there is support and there is effort.',
    'अभी का दौर मिला-जुला है: महादशा $m और अंतर्दशा $a। दोनों को मिलाकर सहारा भी है और मेहनत भी।',
  );
}

String _compare(
  AskCtx c,
  Topic? topic,
  TimelineWindow cur,
  TimelineWindow tgt, {
  required bool compact,
}) {
  final AskLang l = c.l;
  final PeriodReading ca = cur.period;
  final PeriodReading ta = tgt.period;
  final String nowLord = c.name(ca.lord);
  final String nextLord = c.name(ta.lord);
  final bool sameLord = ca.lord == ta.lord;
  final String curMaha = c.name(cur.maha.lord);
  final String tgtMaha = c.name(tgt.maha.lord);
  final List<String> parts = <String>[
    sameLord && cur.maha.lord != tgt.maha.lord
        ? l.t(
            '$compareMarkerEnglish: the same graha, $nowLord, holds the antardasha then as now; what changes is the mahadasha around it, $curMaha now and $tgtMaha then. $curMaha ${natureClause(c, cur.maha.lord)}, and $tgtMaha ${natureClause(c, tgt.maha.lord)}. The weight now is on ${c.focusPhrase(ca)}; then it is on ${c.focusPhrase(ta)}.',
            '$compareMarkerHindi: अंतर्दशा में वही ग्रह $nowLord तब भी है जो अभी है; बदलता है उसके आसपास का अध्याय, यानी महादशा: अभी $curMaha की, तब $tgtMaha की। $curMaha ${natureClause(c, cur.maha.lord)}, और $tgtMaha ${natureClause(c, tgt.maha.lord)}। अभी ज़ोर ${c.focusPhrase(ca)} पर है; तब ${c.focusPhrase(ta)} पर रहता है।',
          )
        : l.t(
            '$compareMarkerEnglish: the $nowLord antardasha is running, with its weight on ${c.focusPhrase(ca)}, and $nowLord ${natureClause(c, ca.lord)}. The $nextLord antardasha has its weight on ${c.focusPhrase(ta)}, and $nextLord ${natureClause(c, ta.lord)}.',
            '$compareMarkerHindi: अभी $nowLord की अंतर्दशा है, जिसमें ज़ोर ${c.focusPhrase(ca)} पर है, और $nowLord ${natureClause(c, ca.lord)}। $nextLord की अंतर्दशा में ज़ोर ${c.focusPhrase(ta)} पर रहता है, और $nextLord ${natureClause(c, ta.lord)}।',
          ),
  ];
  if (tgt.maha.lord != cur.maha.lord && !compact && !sameLord) {
    parts.add(
      l.t(
        'In the bigger picture the mahadasha itself changes, from ${c.name(cur.maha.lord)} to ${c.name(tgt.maha.lord)}.',
        'बड़ी तस्वीर में महादशा भी बदलती है, ${c.name(cur.maha.lord)} से ${c.name(tgt.maha.lord)} की।',
      ),
    );
  }
  final Tone before = blendTone(blendScore(cur));
  final Tone after = blendTone(blendScore(tgt));
  if (topic != null) {
    final bool nowTouches = topicTouches(c, topic, cur);
    final bool laterSupportive = after == Tone.supportive;
    parts.add(
      nowTouches
          ? (laterSupportive
                ? l.t(
                    'Put plainly: now the matter is in front but the chart’s support is not full; later it is in front and the support is greater.',
                    'सीधे शब्दों में: अभी यह विषय सामने तो है पर कुंडली का सहारा पूरा नहीं; आगे वही विषय सामने भी है और सहारा ज़्यादा है।',
                  )
                : l.t(
                    'Put plainly: the matter is in front then as it is now, and the chart’s support stays about as mixed as it is today.',
                    'सीधे शब्दों में: यह विषय आगे भी अभी की तरह सामने रहता है, और कुंडली का सहारा लगभग आज जैसा ही मिला-जुला रहता है।',
                  ))
          : (laterSupportive
                ? l.t(
                    'Put plainly: the period running now does not lean on this matter, while the later one leans on it directly and the chart stands with it.',
                    'सीधे शब्दों में: अभी चल रहा दौर इस विषय पर ज़ोर नहीं देता, जबकि आगे का दौर सीधे इसी पर ज़ोर देता है और कुंडली उसका साथ देती है।',
                  )
                : l.t(
                    'Put plainly: the period running now does not lean on this matter, while the later one leans on it directly, though the chart’s support there is mixed.',
                    'सीधे शब्दों में: अभी चल रहा दौर इस विषय पर ज़ोर नहीं देता, जबकि आगे का दौर सीधे इसी पर ज़ोर देता है, पर वहाँ कुंडली का सहारा मिला-जुला है।',
                  )),
    );
  } else if (before == Tone.demanding && after == Tone.supportive) {
    parts.add(
      l.t(
        'Put plainly: where the time now asks for a good deal of patience, the chart later stands clearly with you.',
        'सीधे शब्दों में: अभी जहाँ धैर्य की ज़्यादा माँग है, वहाँ आगे कुंडली साफ़ तौर पर साथ देती है।',
      ),
    );
  } else if (before == Tone.mixed && after == Tone.supportive) {
    parts.add(
      l.t(
        'Put plainly: where support and effort now go together, later there is more support and less resistance.',
        'सीधे शब्दों में: अभी जहाँ सहारा और मेहनत साथ-साथ चलते हैं, वहाँ आगे सहारा ज़्यादा और रुकावट कम रहती है।',
      ),
    );
  } else {
    parts.add(
      l.t(
        'Put plainly: the later stretch is somewhat lighter than the one you are in.',
        'सीधे शब्दों में: आगे का दौर अभी वाले से कुछ हल्का है।',
      ),
    );
  }
  return parts.join(' ');
}

/// The sentence that names the better stretch and gives its dates. When it
/// opens a new mahadasha the chapter is named first, since that is the bigger
/// change; otherwise the antardasha is.
String _targetSentence(
  AskCtx c,
  Topic? topic,
  TimelineWindow cur,
  TimelineWindow tgt, {
  required bool clearly,
}) {
  final AskLang l = c.l;
  final String until = l.span(tgt.start.difference(c.now));
  final String antar = c.name(tgt.antarLord);
  final String maha = c.name(tgt.maha.lord);
  final String name = topic == null ? '' : l.t(topic.nameEn, topic.nameHi);
  final bool chapter = tgt.startsChapter;
  final String what = chapter
      ? l.t(
          'the $maha mahadasha, which opens with ${tgt.antarLord == tgt.maha.lord ? 'its own antardasha' : 'the $antar antardasha'}',
          '$maha की महादशा, जिसकी शुरुआत ${tgt.antarLord == tgt.maha.lord ? 'उसी की अपनी अंतर्दशा' : '$antar की अंतर्दशा'} से होती है',
        )
      : l.t(
          'the $antar antardasha, ${tgt.maha.lord != cur.maha.lord ? 'inside the' : 'still inside the'} $maha mahadasha',
          '$antar की अंतर्दशा, ${tgt.maha.lord != cur.maha.lord ? '$maha की महादशा में' : '$maha की ही महादशा के भीतर'}',
        );
  final String lead = topic == null
      ? (clearly
            ? l.t(
                'The next clearly better stretch is this: $what.',
                'अगला साफ़ तौर पर बेहतर दौर यह है: $what।',
              )
            : l.t(
                'Nothing ahead is clearly and fully better, but one stretch is somewhat easier: $what.',
                'कोई दौर साफ़ तौर पर पूरी तरह बेहतर नहीं दिखता, पर एक दौर ज़्यादा सहज है: $what।',
              ))
      : (clearly
            ? l.t(
                'The chart’s support for $name is clearest in this stretch: $what.',
                '$name के लिए कुंडली का सहारा सबसे साफ़ इस दौर में दिखता है: $what।',
              )
            : l.t(
                'The next stretch that puts its weight on $name is this: $what.',
                '$name पर ज़ोर देने वाला अगला दौर यह है: $what।',
              ));
  final String detail = chapter
      ? l.t(
          'The mahadasha begins on ${c.date(tgt.start)}, which is $until from now, and runs until ${c.date(tgt.maha.end)}; its first antardasha runs until ${c.date(tgt.end)}.',
          'यह महादशा ${c.date(tgt.start)} से शुरू होती है, यानी अभी से $until बाद, और ${c.date(tgt.maha.end)} तक चलेगी; इसकी पहली अंतर्दशा ${c.date(tgt.end)} तक है।',
        )
      : l.t(
          'It begins on ${c.date(tgt.start)}, which is $until from now, and runs until ${c.date(tgt.end)}.',
          'यह ${c.date(tgt.start)} से शुरू होती है, यानी अभी से $until बाद, और ${c.date(tgt.end)} तक चलती है।',
        );
  return '$lead $detail';
}

String _betweenLine(AskCtx c, List<TimelineWindow> between) {
  final AskLang l = c.l;
  String one(TimelineWindow w) => l.t(
    'the ${c.name(w.antarLord)} antardasha (${c.date(w.start)} to ${c.date(w.end)}) ${l.toneClause(blendTone(blendScore(w)))}',
    '${c.name(w.antarLord)} की अंतर्दशा (${c.date(w.start)} से ${c.date(w.end)} तक) ${l.toneClause(blendTone(blendScore(w)), feminine: true)}',
  );
  final String items = between.map(one).join(l.t('; then ', '; फिर '));
  return l.t('On the way there, $items.', 'बीच के रास्ते में, $items।');
}

/// The turn to the person's own question, which opens the part that answers
/// it: the earlier parts were the groundwork.
String _lead(AskLang l, String sentence) => l.t(
  'Now to your question. $sentence',
  'अब आपके सवाल पर आते हैं। $sentence',
);

AnswerSection betterSection(
  AskCtx c,
  Topic? topic,
  Stretch s, {
  required bool compact,
}) {
  final AskLang l = c.l;
  final TimelineWindow cur = s.current!;
  final List<String> paras = <String>[];
  final Set<int> optional = <int>{};
  final String name = topic == null ? '' : l.t(topic.nameEn, topic.nameHi);
  const String marker = compareMarkerHindi;

  switch (s.kind) {
    case StretchKind.alreadyGood:
      paras.add(
        topic == null
            ? l.t(
                'The good news is that you are in a stretch the chart itself counts as supportive. So before waiting for a good time to arrive, see that it is already running.',
                'अच्छी बात यह है कि आप अभी ख़ुद एक ऐसे दौर में हैं जिसे कुंडली साथ देने वाला मानती है। इसलिए अच्छे समय के आने का इंतज़ार करने से पहले यह देखिए कि वह चल रहा है।',
              )
            : l.t(
                'For $name you are already in a stretch that puts its weight on that very part of life, and the chart stands with it.',
                '$name के लिए आप अभी ऐसे दौर में हैं जो सीधे इसी हिस्से पर ज़ोर देता है, और कुंडली उसका साथ भी देती है।',
              ),
      );
      final List<TimelineWindow> run = s.goodRun;
      if (run.length == 1) {
        paras.add(
          l.t(
            'This is the ${c.name(cur.antarLord)} antardasha, and its support lasts until ${c.date(cur.end)}.',
            'यह ${c.name(cur.antarLord)} की अंतर्दशा है, और इसका सहारा ${c.date(cur.end)} तक चलता है।',
          ),
        );
      } else {
        final String items = run
            .take(4)
            .map(
              (TimelineWindow w) => l.t(
                'the ${c.name(w.antarLord)} antardasha (${c.date(w.start)} to ${c.date(w.end)})',
                '${c.name(w.antarLord)} की अंतर्दशा (${c.date(w.start)} से ${c.date(w.end)} तक)',
              ),
            )
            .join(l.t(', then ', ', फिर '));
        paras.add(
          l.t(
            'This supportive run lasts until ${c.date(run.last.end)}: $items.',
            'यह साथ देने वाला सिलसिला ${c.date(run.last.end)} तक चलता है: $items।',
          ),
        );
      }
      final TimelineWindow? after = s.after;
      if (after != null) {
        final Tone t = blendTone(blendScore(after));
        final String advice = t == Tone.demanding
            ? l.t(
                'So use this good stretch for preparation: finish what is pending, tend your relationships, and keep up the practices above.',
                'इसलिए इस अच्छे दौर को तैयारी में लगाइए: अधूरे काम निपटाइए, रिश्ते सँवारिए, और ऊपर बताए उपाय नियम से करते रहिए।',
              )
            : l.t(
                'Support and effort go together there again, so this is the time to lay a firm foundation.',
                'वहाँ सहारा और मेहनत फिर साथ-साथ चलते हैं, इसलिए यह समय नींव मज़बूत करने का है।',
              );
        paras.add(
          l.t(
            '$compareMarkerEnglish, what follows is ${_windowLine(c, after)}. It ${l.toneClause(t)}, with its weight on ${c.focusPhrase(after.period)}. $advice',
            '$marker, इसके बाद ${_windowLine(c, after)} आती है। वह ${l.toneClause(t, feminine: true)}, और उसमें ज़ोर ${c.focusPhrase(after.period)} पर रहता है। $advice',
          ),
        );
      } else {
        paras.add(
          l.t(
            '$compareMarkerEnglish, nothing further ahead in the span read differs from this: the same support carries on.',
            '$marker, पढ़े गए समय में आगे ऐसा कुछ नहीं दिखता जो इससे अलग हो: यही सहारा बना रहता है।',
          ),
        );
      }
      final TimelineWindow? next = s.nextGood;
      if (next != null && !compact) {
        optional.add(paras.length);
        paras.add(
          l.t(
            'The next supportive stretch after that is ${_windowLine(c, next)}.',
            'उसके बाद अगला साथ देने वाला दौर ${_windowLine(c, next)} है।',
          ),
        );
      }
      paras.add(
        topic == null
            ? l.t(
                'These dates are where a period changes, not days on which anything is due to happen.',
                'ये तारीख़ें दशा के बदलने की हैं, किसी घटना की नहीं।',
              )
            : l.t(
                'The app does not give dates for events. It only shows which stretch gives $name the most support in the chart.',
                'ऐप किसी घटना की तारीख़ नहीं बताता। यहाँ सिर्फ़ यह दिखाया गया है कि कुंडली में किस दौर में $name को सबसे ज़्यादा सहारा मिलता है।',
              ),
      );
    case StretchKind.betterAhead:
    case StretchKind.modestAhead:
      final TimelineWindow tgt = s.target!;
      paras.add(_lead(l, _stateOfNow(c, topic, cur)));
      paras.add(
        _targetSentence(
          c,
          topic,
          cur,
          tgt,
          clearly: s.kind == StretchKind.betterAhead,
        ),
      );
      paras.add(_compare(c, topic, cur, tgt, compact: compact));
      if (!compact && s.between.isNotEmpty && s.between.length <= 3) {
        optional.add(paras.length);
        paras.add(_betweenLine(c, s.between));
      }
      paras.add(
        topic == null
            ? l.t(
                'These dates are where a period changes, not days on which anything is due to happen. They only show when the chart’s support grows.',
                'ये तारीख़ें दशा के बदलने की हैं, किसी घटना की नहीं। ये बस यह बताती हैं कि कुंडली का सहारा किस दौर में बढ़ता है।',
              )
            : l.t(
                'The app does not give dates for events. It only shows which stretch gives $name the most support in the chart.',
                'ऐप किसी घटना की तारीख़ नहीं बताता। यहाँ सिर्फ़ यह दिखाया गया है कि कुंडली में किस दौर में $name को सबसे ज़्यादा सहारा मिलता है।',
              ),
      );
    case StretchKind.nothingAhead:
    case StretchKind.outside:
      paras.add(_lead(l, _stateOfNow(c, topic, cur)));
      paras.add(
        topic == null
            ? l.t(
                '$compareMarkerEnglish, no stretch in the next thirty years stands out as clearly better. That does not mean time stands still. It means that in this chart improvement does not come from one date; it is built slowly, through your own work and the practices above.',
                '$marker, अगले तीस सालों में कोई दौर साफ़ तौर पर बेहतर नहीं दिखता। इसका मतलब यह नहीं कि समय ठहरा रहेगा। इसका मतलब है कि इस कुंडली में बेहतरी किसी एक तारीख़ से नहीं आती; वह आपके अपने कर्म और ऊपर बताए उपायों से धीरे-धीरे बनती है।',
              )
            : l.t(
                '$compareMarkerEnglish, no stretch in the next thirty years puts its weight on $name with the chart’s support behind it. That does not close the matter: a dasha only shows where the weight falls, and what is built there is still your own work and the practices above.',
                '$marker, अगले तीस सालों में कोई ऐसा दौर नहीं दिखता जो $name पर ज़ोर भी दे और कुंडली का सहारा भी रखे। इसका मतलब यह नहीं कि बात बंद हो गई: दशा सिर्फ़ यह दिखाती है कि ज़ोर कहाँ पड़ता है, और वहाँ जो बनता है वह आपका अपना कर्म और ऊपर बताए उपाय हैं।',
              ),
      );
  }

  return AnswerSection(
    key: SectionKey.better,
    heading: topic == null
        ? l.t(
            'When a better stretch comes, and how it differs from now',
            'अच्छा समय कब आएगा, और अभी से कैसे अलग होगा',
          )
        : l.t(
            'When the chart supports $name most, and how that differs from now',
            '$name के लिए अच्छा समय कब, और अभी से कैसे अलग',
          ),
    paragraphs: paras,
    optional: optional,
  );
}

// -----------------------------------------------------------------------------
// 5. How it comes about, and what the shastra says
// -----------------------------------------------------------------------------

/// What the tradition says of a lord standing as this one does, as sentences.
/// They are the general rules of the tradition; no text is named. A node owns
/// no sign, so it is read as the lord of the sign it stands in is.
List<String> shastraLines(AskCtx c, Graha g) {
  final AskLang l = c.l;
  final GrahaStanding s = c.st(g);
  final bool node = g == Graha.rahu || g == Graha.ketu;
  if (node) {
    final String me = c.name(g);
    final String reader = c.name(s.reader);
    final List<String> inner = shastraLines(c, s.reader);
    if (inner.isEmpty) return const <String>[];
    return <String>[
      l.t(
        'The tradition reads $me through $reader, the lord of the sign it stands in, so what is said of $reader applies here. ${inner.first}',
        'परंपरा $me को उस राशि के स्वामी $reader के अनुसार पढ़ती है, इसलिए $reader के बारे में जो कहा गया है, वही यहाँ लागू होता है। ${inner.first}',
      ),
      ...inner.skip(1),
    ];
  }
  final String me = c.name(g);
  final List<String> out = <String>[];

  if (s.nature == FunctionalNature.yogakaraka) {
    out.add(
      l.t(
        'According to the shastra, a graha that rules both a kendra and a trikona is called a yogakaraka, and its dasha counts among the most fruitful. For a ${c.lagna} lagna, $me is exactly such a graha.',
        'शास्त्र के अनुसार जो ग्रह केंद्र और त्रिकोण, दोनों का स्वामी हो, वह योगकारक कहलाता है, और उसकी दशा सबसे फलदायी दशाओं में गिनी जाती है। ${c.lagna} लग्न के लिए $me ठीक ऐसा ही ग्रह है।',
      ),
    );
  } else if (s.ruled.any(<int>[1, 5, 9].contains)) {
    final List<int> good = s.ruled.where(<int>[1, 5, 9].contains).toList();
    out.add(
      l.t(
        'According to the shastra, the dasha of the lord of the lagna or of a trikona (the 5th and 9th houses) is counted as one that gives good results, and $me rules ${l.houses(good)} here.',
        'शास्त्र के अनुसार लग्न या त्रिकोण (पाँचवें और नौवें भाव) के स्वामी की दशा शुभ फल देने वाली मानी जाती है, और यहाँ $me ${l.houses(good)} का स्वामी है।',
      ),
    );
  }
  final int house = s.placed.house;
  if (<int>[1, 4, 5, 7, 9, 10].contains(house) &&
      s.placed.dignity != Dignity.debilitated) {
    out.add(
      l.t(
        'The tradition counts the dasha of a graha standing in a kendra or trikona as a supporting one; $me stands in ${l.house(house)}.',
        'परंपरा में केंद्र या त्रिकोण में बैठे ग्रह की दशा को सहारा देने वाली माना जाता है; $me ${l.house(house)} में बैठा है।',
      ),
    );
  }
  if (l.strongDignity(s.placed.dignity)) {
    out.add(
      l.t(
        'A graha in its own or exalted sign gives the results of its dasha firmly, which is a general rule of the tradition; $me stands ${l.dignityIn(s.placed.dignity)}.',
        'स्वराशि या उच्च राशि में बैठा ग्रह अपनी दशा में फल मज़बूती से देता है, यह परंपरा का सामान्य नियम है; $me ${l.dignityIn(s.placed.dignity)} है।',
      ),
    );
  }
  if (const <int>[3, 6, 10, 11].contains(house)) {
    out.add(
      l.t(
        'The 3rd, 6th, 10th and 11th are the upachaya houses, the houses of growth: a graha standing in one is read as giving more with time. $me stands in ${l.house(house)}.',
        'तीसरा, छठा, दसवाँ और ग्यारहवाँ भाव उपचय भाव कहलाते हैं, यानी बढ़ने वाले भाव: इनमें बैठे ग्रह का फल समय के साथ बढ़ता माना जाता है। $me ${l.house(house)} में बैठा है।',
      ),
    );
  }
  final b = s.bala;
  if (b != null && b.isStrong) {
    out.add(
      l.t(
        'A graha whose shadbala clears its minimum is read as able to give what it promises; $me’s does.',
        'जिस ग्रह का षड्बल उसके न्यूनतम से ऊपर हो, वह अपना वादा निभाने में सक्षम माना जाता है; $me का षड्बल ऐसा ही है।',
      ),
    );
  }
  if (s.ruled.contains(2) || s.ruled.contains(11)) {
    out.add(
      l.t(
        'The 2nd and 11th houses are the houses of money and income, so the dasha of their lord is read as backing the means a person has.',
        'दूसरा और ग्यारहवाँ भाव पैसे और कमाई के भाव हैं, इसलिए इनके स्वामी की दशा में साधनों को सहारा मिलता है, ऐसा माना जाता है।',
      ),
    );
  }
  if (s.viparita != null) out.add(s.viparita!.of(c.hindi));
  if (s.neechaBhanga != null) out.add(s.neechaBhanga!.of(c.hindi));
  return out;
}

/// The sentence on the handover from one mahadasha lord to the next.
String handoverLine(AskCtx c, Graha from, Graha to) {
  final AskLang l = c.l;
  final String a = c.name(from);
  final String b = c.name(to);
  return switch (mutualRelation(from, to)) {
    Relation.friend => l.t(
      '$a and $b are natural friends, so the handover from one to the other is an easy one.',
      '$a और $b नैसर्गिक मित्र हैं, इसलिए एक से दूसरे की ओर यह बदलाव सहज रहता है।',
    ),
    Relation.neutral => l.t(
      '$a and $b are neutral to each other, so the handover is a plain change of theme.',
      '$a और $b आपस में सम हैं, इसलिए यह बदलाव सीधा-सादा है।',
    ),
    Relation.enemy => l.t(
      '$a and $b are natural enemies, so the handover asks for some adjustment.',
      '$a और $b नैसर्गिक शत्रु हैं, इसलिए यह बदलाव कुछ तालमेल माँगता है।',
    ),
  };
}

AnswerSection howSection(
  AskCtx c,
  Topic? topic,
  Stretch s, {
  required bool compact,
}) {
  final AskLang l = c.l;
  final TimelineWindow w = s.subject!;
  final PeriodReading sub = w.period;
  final bool ahead =
      s.kind == StretchKind.betterAhead || s.kind == StretchKind.modestAhead;
  final String lord = c.name(sub.lord);
  final List<String> paras = <String>[];

  final bool opensChapter = ahead && w.startsChapter;
  final Graha mahaLord = w.maha.lord;
  if (opensChapter) {
    final String again = mahaLord == sub.lord
        ? ''
        : ' ${c.standing(sub.lord, depth: 0)}';
    paras.add(
      l.t(
        'This better stretch is shaped by the new ${c.name(mahaLord)} mahadasha, and its first antardasha is ${c.name(sub.lord)}’s. ${c.standing(mahaLord, depth: 0)}$again',
        'यह बेहतर दौर ${c.name(mahaLord)} की नई महादशा से बनता है, और उसकी पहली अंतर्दशा ${c.name(sub.lord)} की है। ${c.standing(mahaLord, depth: 0)}$again',
      ),
    );
  } else {
    paras.add(
      ahead
          ? l.t(
              'This better stretch is shaped by the $lord antardasha. ${c.standing(sub.lord, depth: 0)}',
              'यह बेहतर दौर $lord की अंतर्दशा से बनता है। ${c.standing(sub.lord, depth: 0)}',
            )
          : l.t(
              'The $lord antardasha is what shapes this time. ${c.standing(sub.lord, depth: 0)}',
              'इस समय को $lord की अंतर्दशा आकार दे रही है। ${c.standing(sub.lord, depth: 0)}',
            ),
    );
  }
  if (topic != null) {
    final String? link = topicLinkSentence(c, topic, sub.lord);
    if (link != null) paras[0] = '${paras[0]} $link';
  }
  final bool mahaChanges = ahead && mahaLord != s.current!.maha.lord;
  if (mahaChanges) {
    final bool newOnes = !opensChapter;
    final String again = newOnes && mahaLord != sub.lord && !compact
        ? ' ${c.standing(mahaLord, depth: 0)}'
        : '';
    paras.add(
      opensChapter
          ? l.t(
              'The mahadasha passes from ${c.name(s.current!.maha.lord)} to ${c.name(mahaLord)}. ${handoverLine(c, s.current!.maha.lord, mahaLord)}',
              'महादशा ${c.name(s.current!.maha.lord)} से ${c.name(mahaLord)} की ओर जाती है। ${handoverLine(c, s.current!.maha.lord, mahaLord)}',
            )
          : l.t(
              'The mahadasha changes with it, from ${c.name(s.current!.maha.lord)} to ${c.name(mahaLord)}.$again ${handoverLine(c, s.current!.maha.lord, mahaLord)}',
              'इसके साथ महादशा भी बदलती है, ${c.name(s.current!.maha.lord)} से ${c.name(mahaLord)} की।$again ${handoverLine(c, s.current!.maha.lord, mahaLord)}',
            ),
    );
  }
  if (sub.areas.isNotEmpty && !compact) {
    final int h = sub.areas.first.house;
    paras.add(
      l.t(
        'In this antardasha the weight falls on ${c.focusPhrase(sub)} (${c.whyHouse(sub.lord, h)}). ${c.modifierLine(sub)}',
        'इस अंतर्दशा में ज़ोर ${c.focusPhrase(sub)} पर रहता है (${c.whyHouse(sub.lord, h)})। ${c.modifierLine(sub)}',
      ),
    );
  }

  final List<String> rules = <String>[
    ...shastraLines(c, sub.lord),
    if (w.maha.lord != sub.lord) ...shastraLines(c, w.maha.lord),
  ];
  final List<String> chosen = rules.take(compact ? 1 : 2).toList();
  if (chosen.isEmpty) {
    chosen.add(
      l.t(
        'The tradition reads a dasha from what its lord rules, where it stands and how strong it is, and all three above were taken from this chart.',
        'परंपरा में दशा का फल ग्रह के स्वामित्व, उसके स्थान और उसके बल से पढ़ा जाता है, और ऊपर तीनों इसी कुंडली से लिए गए हैं।',
      ),
    );
  }
  paras.add(chosen.join(' '));

  paras.add(
    compact
        ? l.t(
            'One more thing the shastra says: the dasha points the way and the transit delivers, so read the transit of Jupiter and Saturn of that day as well.',
            'शास्त्र की एक बात और: दशा संकेत देती है और गोचर फल देता है, इसलिए उस दिन के गुरु और शनि का गोचर भी देख लीजिए।',
          )
        : l.t(
            'One more thing the shastra says: the dasha points the way and the transit delivers, so when that time comes close, read the transit of Jupiter and Saturn of that day as well. And calling a stretch “supportive” or “asking for patience” is this app’s own way of counting, resting on these same rules; it is not a measure from the texts.',
            'शास्त्र की एक बात और: दशा संकेत देती है और गोचर फल देता है, इसलिए जब वह समय पास आए, तब उस दिन के गुरु और शनि का गोचर भी देख लीजिए। और किसी दौर को “साथ देने वाला” या “धैर्य माँगने वाला” कहना इस ऐप की अपनी गिनती है, जो इन्हीं नियमों पर टिकी है; वह ग्रंथों का माप नहीं है।',
          ),
  );

  return AnswerSection(
    key: SectionKey.how,
    heading: ahead
        ? l.t(
            'How it comes about, and what the shastra says',
            'यह कैसे आएगा, और शास्त्र क्या कहते हैं',
          )
        : l.t(
            'How this time is shaped, and what the shastra says',
            'यह समय कैसे बन रहा है, और शास्त्र क्या कहते हैं',
          ),
    paragraphs: paras,
  );
}

// -----------------------------------------------------------------------------
// The chips under the answer
// -----------------------------------------------------------------------------

String _houseChip(AskCtx c, Graha g) {
  final AskLang l = c.l;
  final GrahaStanding s = c.st(g);
  final String me = c.name(g);
  final String rules = s.ruled.isEmpty
      ? ''
      : l.t(
          'rules ${s.ruled.length == 1 ? 'house' : 'houses'} ${s.ruled.join(' & ')}, ',
          '${s.ruled.join(' और ')} भाव का स्वामी, ',
        );
  return l.t(
    '$me: ${rules}in house ${s.placed.house}',
    '$me: $rules${s.placed.house}वें भाव में',
  );
}

List<String> storyBasis(AskCtx c, Topic? topic, Stretch s) {
  final AskLang l = c.l;
  final PeriodReading maha = c.maha!;
  final PeriodReading antar = c.antar!;
  final List<String> out = <String>[
    l.t(
      'Mahadasha: ${c.name(maha.lord)} (${c.monthYear(maha.start)} – ${c.monthYear(maha.end)})',
      'महादशा: ${c.name(maha.lord)} (${c.monthYear(maha.start)} – ${c.monthYear(maha.end)})',
    ),
    l.t(
      'Antardasha: ${c.name(antar.lord)} (${c.date(antar.start)} – ${c.date(antar.end)})',
      'अंतर्दशा: ${c.name(antar.lord)} (${c.date(antar.start)} – ${c.date(antar.end)})',
    ),
    if (c.praty != null)
      l.t(
        'Pratyantardasha: ${c.name(c.praty!.lord)}',
        'प्रत्यंतर्दशा: ${c.name(c.praty!.lord)}',
      ),
    _houseChip(c, maha.lord),
    if (antar.lord != maha.lord) _houseChip(c, antar.lord),
  ];
  if (topic != null) {
    for (final int h in topic.readHouses) {
      final BhavaReading b = c.p.bhavas[h - 1];
      out.add(
        l.t(
          '${l.ordinal(h)} house: ${l.sign(b.sign)}, lord ${c.name(b.lord)}',
          '${l.ordinal(h)} भाव: ${l.sign(b.sign)}, स्वामी ${c.name(b.lord)}',
        ),
      );
    }
  }
  final TimelineWindow? tgt = s.target;
  if (tgt != null) {
    out.add(
      l.t(
        'Next better stretch: ${c.name(tgt.antarLord)} antardasha from ${c.monthYear(tgt.start)}',
        'अगला बेहतर दौर: ${c.name(tgt.antarLord)} की अंतर्दशा, ${c.monthYear(tgt.start)} से',
      ),
    );
  }
  return out;
}
