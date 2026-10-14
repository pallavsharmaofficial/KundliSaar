import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/phaladesh.dart';
import '../engine/jyotish/yogas.dart';
import 'answer_model.dart';
import 'ask_context.dart';
import 'ask_language.dart';
import 'ask_story.dart' show closeSection;

// =============================================================================
// The yogas answer.
//
// The yoga library carries about seventy findings, so listing them all would
// bury the few that matter. The answer leads with the strongest few, gives the
// rest by family as bare names, takes the doshas on their own with the relief
// the chart carries, and ties the yogas to the dasha that brings them out.
// =============================================================================

/// How many yogas are described in full, and how many doshas.
const int leadingYogas = 3;
const int leadingDoshas = 2;

/// The most names listed under one family, and in the list of the remaining
/// doshas. Past that the answer says how many more there are.
const int namesPerFamily = 6;

const Set<String> _classicalKeys = <String>{
  'adhi',
  'lakshmi',
  'chamara',
  'parvata',
  'saraswati',
  'amala',
  'kalanidhi',
};

/// How much weight a yoga carries when the few strongest are picked. The order
/// is a convention of this app: the five Mahapurusha yogas and the raja yogas
/// first, then Gaja Kesari and the dhana yogas, then the other classical
/// yogas, and the families of lesser consequence last. Unknown keys fall to
/// the weight of their family, so a yoga added to the library later still
/// finds a place.
int yogaWeight(YogaFinding y) {
  final String k = y.key;
  if (k.startsWith('mahapurusha_')) return 100;
  if (k.startsWith('raja_yoga_')) return 95;
  if (k == 'gaja_kesari') return 90;
  if (k == 'dhana_2_11') return 85;
  if (_classicalKeys.contains(k)) return 80;
  return switch (y.family) {
    YogaFamily.rajaDhana => 75,
    YogaFamily.vipreetRaja => 70,
    YogaFamily.general => 65,
    YogaFamily.chandra => 55,
    YogaFamily.surya => 50,
    YogaFamily.nabhasa => 40,
    YogaFamily.dosha => 30,
  };
}

/// The same for the doshas: the ones people most often ask about come first.
int doshaWeight(YogaFinding y) => switch (y.key) {
  'mangal_dosha' => 100,
  'kaal_sarpa' => 95,
  'guru_chandal' => 90,
  'pitra_dosha' => 85,
  'shrapit' => 80,
  'angarak' => 70,
  'kemadruma' => 65,
  'vish_yoga' => 60,
  _ => 50,
};

List<YogaFinding> _byWeight(
  List<YogaFinding> list,
  int Function(YogaFinding) weight,
) {
  final List<(int, YogaFinding)> indexed = <(int, YogaFinding)>[
    for (int i = 0; i < list.length; i++) (i, list[i]),
  ];
  indexed.sort(((int, YogaFinding) a, (int, YogaFinding) b) {
    final int byWeight = weight(b.$2).compareTo(weight(a.$2));
    return byWeight != 0 ? byWeight : a.$1.compareTo(b.$1);
  });
  return <YogaFinding>[for (final (int, YogaFinding) e in indexed) e.$2];
}

String _name(AskLang l, YogaFinding y) => l.t(y.nameEnglish, y.nameHindi);

/// The yoga's name, its rule, and the first two sentences of what it means:
/// enough to understand it, short enough to read aloud.
String _full(AskLang l, YogaFinding y) {
  final String rule = l.t(y.ruleEnglish, y.ruleHindi);
  final String meaning = firstSentences(
    l.t(y.meaningEnglish, y.meaningHindi),
    2,
  );
  return '${_name(l, y)}: $rule $meaning';
}

String _withRelief(AskLang l, YogaFinding y) {
  final String? cancel = l.hindi ? y.cancellationHindi : y.cancellationEnglish;
  final String? mitigate = l.hindi ? y.mitigationHindi : y.mitigationEnglish;
  final String relief = cancel != null
      ? l.t('What softens it: $cancel', 'इसे हल्का करने वाली बात: $cancel')
      : mitigate != null
      ? l.t('How it is eased: $mitigate', 'इसे सँभालने का तरीक़ा: $mitigate')
      : '';
  return relief.isEmpty ? _full(l, y) : '${_full(l, y)} $relief';
}

String _namesLine(AskLang l, List<YogaFinding> list, {int limit = 99}) {
  // The same name twice (two raja yogas) is one name and a count.
  final Map<String, int> counts = <String, int>{};
  for (final YogaFinding y in list) {
    counts.update(_name(l, y), (int n) => n + 1, ifAbsent: () => 1);
  }
  final List<String> names = counts.entries
      .map(
        (MapEntry<String, int> e) =>
            e.value > 1 ? '${e.key} (×${e.value})' : e.key,
      )
      .toList();
  final List<String> shown = names.take(limit).toList();
  final int more = names.length - shown.length;
  final String joined = l.list(shown);
  if (more <= 0) return joined;
  return l.t('$joined, and $more more', '$joined, और $more और');
}

/// The yogas answer for a chart, with the running dasha tied in.
Answer composeYogaAnswer(AskCtx c) =>
    composeYogas(c.l, c.pc.yogas, ctx: c, basisChips: _chartChips(c));

List<String> _chartChips(AskCtx c) => <String>[
  c.l.t('Lagna: ${c.lagna}', 'लग्न: ${c.lagna}'),
  c.l.t(
    'Moon: ${c.l.sign(c.k.moonRashi)}',
    'चंद्र: ${c.l.sign(c.k.moonRashi)}',
  ),
];

/// Composes the answer from any list of findings. [ctx] ties the yogas to the
/// dasha running now; without it that part is left out.
Answer composeYogas(
  AskLang l,
  List<YogaFinding> findings, {
  AskCtx? ctx,
  List<String> basisChips = const <String>[],
}) {
  final String title = l.t('The yogas in your chart', 'आपकी कुंडली के योग');
  final List<YogaFinding> good = _byWeight(
    findings.where((YogaFinding y) => !y.isDosha).toList(),
    yogaWeight,
  );
  final List<YogaFinding> doshas = _byWeight(
    findings.where((YogaFinding y) => y.isDosha).toList(),
    doshaWeight,
  );
  final List<AnswerSection> sections = <AnswerSection>[];

  if (findings.isEmpty) {
    sections.add(
      AnswerSection(
        key: SectionKey.leading,
        heading: l.t('What the chart shows', 'कुंडली में क्या मिला'),
        paragraphs: <String>[
          l.t(
            'No major yoga or dosha stands out in this chart. That does not mean something is missing: a yoga is only a particular arrangement of the grahas, and a chart can be a good one without carrying any of the named ones.',
            'इस कुंडली में कोई बड़ा योग या दोष प्रमुख नहीं निकला। इसका मतलब यह नहीं कि कुछ कमी है: योग ग्रहों की कुछ ख़ास बनावटें हैं, और कोई कुंडली इनमें से किसी के बिना भी अच्छी हो सकती है।',
          ),
        ],
      ),
    );
    sections.add(closeSection(l));
    return Answer(title: title, sections: sections, basis: basisChips);
  }

  // The strongest few.
  final List<YogaFinding> top = good.take(leadingYogas).toList();
  final String count = l.t(
    '${findings.length} yogas and doshas were found in your chart: ${good.length} yogas and ${doshas.length} doshas.',
    'आपकी कुंडली में कुल ${findings.length} योग और दोष मिले: ${good.length} योग और ${doshas.length} दोष।',
  );
  final String order = findings.length > leadingYogas + leadingDoshas
      ? l.t(
          ' Reading them all at once only tangles things, so the strongest few come first and the rest follow by family.',
          ' इन सबको एक साथ पढ़ने से बात उलझ जाती है, इसलिए पहले सबसे असरदार कुछ, फिर बाक़ी समूह के अनुसार।',
        )
      : '';
  sections.add(
    AnswerSection(
      key: SectionKey.leading,
      heading: l.t('The strongest yogas', 'सबसे प्रमुख योग'),
      paragraphs: <String>[
        '$count$order',
        for (final YogaFinding y in top) _full(l, y),
        if (top.isEmpty)
          l.t(
            'None of the yogas in the strict sense is present; what the chart carries are the doshas below.',
            'सही अर्थ में कोई शुभ योग नहीं मिला; कुंडली में जो है वह नीचे के दोष हैं।',
          ),
      ],
    ),
  );

  // The rest, by family, as names only.
  final List<YogaFinding> rest = good.skip(leadingYogas).toList();
  if (rest.isNotEmpty) {
    final List<String> lines = <String>[];
    for (final YogaFamily f in YogaFamily.values) {
      final List<YogaFinding> inFamily = rest
          .where((YogaFinding y) => y.family == f)
          .toList();
      if (inFamily.isEmpty) continue;
      lines.add(
        '${l.t(f.english, f.hindi)} (${inFamily.length}): ${_namesLine(l, inFamily, limit: namesPerFamily)}${l.t('.', '।')}',
      );
    }
    sections.add(
      AnswerSection(
        key: SectionKey.others,
        heading: l.t('The rest, by family', 'बाक़ी योग, समूह के अनुसार'),
        paragraphs: lines,
      ),
    );
  }

  // The doshas, with the relief the chart carries.
  if (doshas.isNotEmpty) {
    final List<YogaFinding> shown = doshas.take(leadingDoshas).toList();
    final List<YogaFinding> others = doshas.skip(leadingDoshas).toList();
    sections.add(
      AnswerSection(
        key: SectionKey.care,
        heading: l.t(
          'What asks for a little care',
          'जिन बातों पर थोड़ा ध्यान चाहिए',
        ),
        paragraphs: <String>[
          l.t(
            'A dosha is not a verdict. The tradition reads it as something that asks a little more of a person, and almost always names what eases it.',
            'दोष कोई फ़ैसला नहीं है। परंपरा इसे ऐसी बात मानती है जो इंसान से थोड़ा ज़्यादा माँगती है, और लगभग हमेशा यह भी बताती है कि उसे कैसे सँभाला जाए।',
          ),
          for (final YogaFinding y in shown) _withRelief(l, y),
          if (others.isNotEmpty)
            l.t(
              'Besides these: ${_namesLine(l, others, limit: namesPerFamily)}.',
              'इनके अलावा: ${_namesLine(l, others, limit: namesPerFamily)}।',
            ),
        ],
      ),
    );
  }

  // When they show: a yoga gives its results through the dasha of its grahas.
  if (ctx != null && ctx.maha != null && ctx.antar != null) {
    final String? running = _runningParagraph(l, ctx, good);
    if (running != null) {
      sections.add(
        AnswerSection(
          key: SectionKey.running,
          heading: l.t(
            'When these yogas come forward',
            'ये योग कब सामने आते हैं',
          ),
          paragraphs: <String>[running, ?_nextPeriodParagraph(l, ctx, top)],
        ),
      );
    }
  }

  sections.add(closeSection(l));
  return Answer(
    title: title,
    sections: sections,
    basis: <String>[
      l.t(
        '${findings.length} findings: ${good.length} yogas, ${doshas.length} doshas',
        '${findings.length} मिले: ${good.length} योग, ${doshas.length} दोष',
      ),
      if (top.isNotEmpty) _name(l, top.first),
      ...basisChips,
    ],
  );
}

Set<Graha> _membersOf(AskCtx c, YogaFinding y) {
  for (final ({YogaFinding yoga, Set<Graha> grahas}) m in c.pc.yogaMembers) {
    if (identical(m.yoga, y) || m.yoga.key == y.key) return m.grahas;
  }
  return const <Graha>{};
}

String? _runningParagraph(AskLang l, AskCtx c, List<YogaFinding> good) {
  final Graha maha = c.maha!.lord;
  final Graha antar = c.antar!.lord;
  final List<YogaFinding> withMaha = good
      .where((YogaFinding y) => _membersOf(c, y).contains(maha))
      .take(3)
      .toList();
  final List<YogaFinding> withAntar = good
      .where(
        (YogaFinding y) => antar != maha && _membersOf(c, y).contains(antar),
      )
      .take(3)
      .toList();
  final String lead = l.t(
    'A yoga gives its results through the dasha of the grahas that make it. You are in the ${c.name(maha)} mahadasha and the ${c.name(antar)} antardasha.',
    'योग का फल उन ग्रहों की दशा में सामने आता है जो उसे बनाते हैं। अभी आप ${c.name(maha)} की महादशा और ${c.name(antar)} की अंतर्दशा में हैं।',
  );
  if (withMaha.isEmpty && withAntar.isEmpty) {
    return l.t(
      '$lead Neither of them belongs to the yogas above, so those wait in the background for now.',
      '$lead इन दोनों में से कोई ऊपर के योगों में शामिल नहीं है, इसलिए वे योग अभी पीछे हैं।',
    );
  }
  final List<String> parts = <String>[
    if (withMaha.isNotEmpty)
      l.t(
        '${c.name(maha)} takes part in ${_namesLine(l, withMaha)}',
        '${c.name(maha)} ${_namesLine(l, withMaha)} में शामिल है',
      ),
    if (withAntar.isNotEmpty)
      l.t(
        '${c.name(antar)} takes part in ${_namesLine(l, withAntar)}',
        '${c.name(antar)} ${_namesLine(l, withAntar)} में शामिल है',
      ),
  ];
  return l.t(
    '$lead ${parts.join('; ')}, so these are the yogas that are nearest the front now.',
    '$lead ${parts.join('; ')}, इसलिए इस समय ये योग सबसे आगे हैं।',
  );
}

String? _nextPeriodParagraph(AskLang l, AskCtx c, List<YogaFinding> top) {
  if (top.isEmpty) return null;
  final YogaFinding y = top.first;
  final Set<Graha> members = _membersOf(c, y);
  if (members.isEmpty) return null;
  for (final PeriodReading m in c.p.dasha.mahadashas) {
    if (!m.end.isAfter(c.now) || !members.contains(m.lord)) continue;
    final bool running = !m.start.isAfter(c.now);
    return running
        ? l.t(
            'Take the first of them, ${_name(l, y)}: the ${c.name(m.lord)} mahadasha, which belongs to it, is running now and lasts until ${c.monthYear(m.end)}.',
            'पहले योग ${_name(l, y)} को ही लें: उससे जुड़े ${c.name(m.lord)} की महादशा अभी चल रही है और ${c.monthYear(m.end)} तक चलेगी।',
          )
        : l.t(
            'Take the first of them, ${_name(l, y)}: the ${c.name(m.lord)} mahadasha, which belongs to it, runs from ${c.monthYear(m.start)} to ${c.monthYear(m.end)}.',
            'पहले योग ${_name(l, y)} को ही लें: उससे जुड़े ${c.name(m.lord)} की महादशा ${c.monthYear(m.start)} से ${c.monthYear(m.end)} तक है।',
          );
  }
  return null;
}
