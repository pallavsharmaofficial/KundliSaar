import 'package:pdf/widgets.dart' as pw;

import '../../engine/astro/time.dart';
import '../../engine/jyotish/chart.dart';
import '../../engine/jyotish/dasha.dart';
import '../../engine/jyotish/phaladesh.dart';
import '../design/kit.dart';
import '../design/palette.dart';
import 'data.dart';
import 'hindi.dart';
import 'readings.dart';

/// विंशोत्तरी दशा: the dates only.
List<pw.Widget> dashaSection(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final Duration zone = d.zone;
  final List<DashaPeriod> chain = k.dashaChainAt(d.now);
  final DashaPeriod first = k.vimshottari.first;
  final String running = chain.isEmpty ? '' : Hi.graha(chain.first.lord);

  String dt(DateTime utc) => Hi.date(utc, zone);
  String len(DashaPeriod p) => Hi.span(p.lengthDays);

  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'dasha',
      number: 'भाग ७',
      title: 'विंशोत्तरी दशा',
      subtitle: 'महादशा, अंतर्दशा और प्रत्यंतर्दशा, तिथियों सहित',
    ),
    kit.para(
      'विंशोत्तरी में 120 वर्ष का चक्र नौ ग्रहों में बँटा है। आपके जन्म के समय चंद्र ${k.janmaNakshatra.hindi} नक्षत्र में था, जिसके स्वामी ${Hi.graha(k.janmaNakshatra.lord)} हैं, इसलिए पहली महादशा ${Hi.graha(first.lord)} की रही। उसका जन्म के बाद का शेष भाग ${Hi.span(first.lengthDays)} था। पहली महादशा के अंतर्दशा-क्रम में जन्म बीच में आता है, इसलिए पहले के कुछ उप-काल यहाँ नहीं दिखते।',
    ),
    if (chain.isNotEmpty) ...<pw.Widget>[
      kit.h2('अभी कौन सी दशा चल रही है'),
      kit.table(
        headers: <String>['स्तर', 'स्वामी', 'कब तक'],
        rows: <List<String>>[
          for (int i = 0; i < chain.length; i++)
            <String>[
              const <String>['महादशा', 'अंतर्दशा', 'प्रत्यंतर्दशा'][i],
              Hi.graha(chain[i].lord),
              dt(chain[i].end),
            ],
        ],
        widths: <double>[1.4, 1.4, 2],
      ),
      kit.gap(4),
    ],
    kit.h2('महादशाएँ'),
    kit.table(
      headers: <String>['महादशा', 'आरंभ', 'समाप्ति', 'अवधि'],
      rows: <List<String>>[
        for (final DashaPeriod m in k.vimshottari)
          <String>[
            '${Hi.graha(m.lord)}${chain.isNotEmpty && m.lord == chain.first.lord && m.startJdUt == chain.first.startJdUt ? ' (अभी)' : ''}',
            dt(m.start),
            dt(m.end),
            len(m),
          ],
      ],
      widths: <double>[1.6, 2, 2, 1.6],
      highlightRows: <int>{
        for (int i = 0; i < k.vimshottari.length; i++)
          if (chain.isNotEmpty &&
              k.vimshottari[i].startJdUt == chain.first.startJdUt)
            i,
      },
    ),
    kit.gap(8),
    kit.h2('हर महादशा की अंतर्दशाएँ'),
  ];

  for (final DashaPeriod m in k.vimshottari) {
    final bool isRunning =
        chain.isNotEmpty && m.startJdUt == chain.first.startJdUt;
    out.add(pw.NewPage(freeSpace: 150));
    out.add(
      kit.h3(
        '${Hi.graha(m.lord)} महादशा · ${dt(m.start)} से ${dt(m.end)}${isRunning ? ' · अभी चल रही है' : ''}',
        color: Pal.maroon,
      ),
    );
    out.add(
      kit.table(
        headers: <String>['अंतर्दशा', 'आरंभ', 'समाप्ति', 'अवधि'],
        rows: <List<String>>[
          for (final DashaPeriod a in m.children)
            <String>[
              '${Hi.graha(m.lord)} – ${Hi.graha(a.lord)}',
              dt(a.start),
              dt(a.end),
              len(a),
            ],
        ],
        widths: <double>[1.8, 2, 2, 1.4],
        size: 8.9,
        highlightRows: <int>{
          for (int i = 0; i < m.children.length; i++)
            if (chain.length > 1 &&
                m.children[i].startJdUt == chain[1].startJdUt)
              i,
        },
      ),
    );
    out.add(kit.gap(6));
  }

  if (chain.length > 1 && chain[1].children.isNotEmpty) {
    out.add(pw.NewPage(freeSpace: 200));
    out.add(kit.h2('अभी की अंतर्दशा की प्रत्यंतर्दशाएँ'));
    out.add(
      kit.para(
        '$running महादशा की ${Hi.graha(chain[1].lord)} अंतर्दशा के भीतर के उप-काल:',
      ),
    );
    out.add(
      kit.table(
        headers: <String>['प्रत्यंतर्दशा', 'आरंभ', 'समाप्ति', 'अवधि'],
        rows: <List<String>>[
          for (final DashaPeriod p in chain[1].children)
            <String>[
              '${Hi.graha(chain[0].lord)} – ${Hi.graha(chain[1].lord)} – ${Hi.graha(p.lord)}',
              dt(p.start),
              dt(p.end),
              len(p),
            ],
        ],
        widths: <double>[2.6, 1.9, 1.9, 1.3],
        size: 8.9,
        highlightRows: <int>{
          for (int i = 0; i < chain[1].children.length; i++)
            if (chain.length > 2 &&
                chain[1].children[i].startJdUt == chain[2].startJdUt)
              i,
        },
      ),
    );
  }

  out.add(kit.gap(10));
  out.add(kit.h2('योगिनी दशा'));
  out.add(
    kit.para(
      'योगिनी दशा 36 वर्ष का चक्र है जो विंशोत्तरी के साथ मिलाकर देखा जाता है। नीचे जन्म से शुरू होने वाले आठ काल हैं।',
    ),
  );
  out.add(
    kit.table(
      headers: <String>['योगिनी', 'स्वामी', 'आरंभ', 'समाप्ति'],
      rows: <List<String>>[
        for (final YoginiPeriod y in d.yogini)
          <String>[
            Hi.yoginiNames[yoginiNames.indexOf(y.name)],
            Hi.graha(y.lord),
            dt(utcFromJd(y.startJdUt)),
            dt(utcFromJd(y.endJdUt)),
          ],
      ],
      widths: <double>[1.5, 1.4, 2, 2],
    ),
  );
  return out;
}

DateTime utcFromJd(double jd) => Instant.fromJulianDayUt(jd).utc;

// ---------------------------------------------------------------------------
// जीवन फलादेश
// ---------------------------------------------------------------------------

pw.Widget _band(
  Kit kit, {
  required List<pw.Widget> children,
  bool current = false,
}) => pw.Inseparable(
  child: pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.fromLTRB(9, 5, 9, 5),
    decoration: pw.BoxDecoration(
      color: Pal.panel,
      border: pw.Border(
        left: pw.BorderSide(color: current ? Pal.maroon : Pal.gold, width: 2.6),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    ),
  ),
);

List<pw.Widget> _windowBlock(
  Kit kit,
  TimelineWindow w,
  Duration zone, {
  required bool current,
}) {
  final List<pw.Widget> out = <pw.Widget>[
    pw.NewPage(freeSpace: 140),
    _band(
      kit,
      current: current,
      children: <pw.Widget>[
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            kit.text(
              '${Hi.date(w.start, zone)} – ${Hi.date(w.end, zone)}',
              style: kit.style(
                kit.fonts.semi,
                11.2,
                color: Pal.maroon,
                spacing: 1.2,
              ),
            ),
            if (current)
              kit.text(
                'अभी चल रही है',
                style: kit.style_(kit.fonts.semi, 8.8, Pal.maroon),
              ),
          ],
        ),
        kit.text(
          '${Hi.graha(w.mahaLord)} – ${Hi.graha(w.antarLord)} · उम्र ${Hi.years(w.ageStartYears).replaceAll(' वर्ष', '')} से ${Hi.years(w.ageEndYears)}',
          style: kit.small,
        ),
      ],
    ),
    kit.gap(4),
    toneChips(
      kit,
      w.tone,
      w.indication,
      extra: <pw.Widget>[
        for (final LifeArea a in w.areas) kit.chip(a.periodTitle.hi),
      ],
    ),
    kit.gap(4),
  ];
  final String? headline = clean(kit, w.headline);
  if (headline != null) out.add(kit.p(headline, style: kit.bodyStrong));
  final String? expect = clean(kit, w.expect);
  if (expect != null) out.add(kit.para(expect));
  final String? tends = clean(kit, w.tends);
  if (tends != null) out.add(kit.labelled('अक्सर क्या सामने आता है', tends));
  // A supportive window's "what it asks" only repeats the headline in other
  // words; the full reading of the running period carries it, so the long
  // timeline keeps it for the windows that are mixed or demanding.
  final String? asks = w.tone == Tone.supportive ? null : clean(kit, w.asks);
  if (asks != null) out.add(kit.labelled('यह आपसे क्या माँगता है', asks));
  final String? relief = clean(kit, w.relief);
  if (relief != null) out.add(kit.labelled('राहत', relief));
  final String? caution = clean(kit, w.indication.caution);
  if (caution != null) out.add(kit.note(caution));
  out.addAll(remedyBlock(kit, w.remedies, brief: true));
  out.addAll(basisBlock(kit, w.basis, inline: true));
  out.add(kit.gap(6));
  return out;
}

List<pw.Widget> timelineSection(Kit kit, KundliPdfData d) {
  final LifeTimeline t = d.phala.timeline;
  final Duration zone = d.zone;
  final TimelineWindow? now = t.windowAt(d.now);
  final bool approx = d.kundli.birth.timeIsApproximate;

  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'timeline',
      number: 'भाग ८',
      title: 'जीवन फलादेश',
      subtitle:
          'आपका जीवन, चरण-दर-चरण: जन्म से लगभग नब्बे वर्ष तक की अवधियाँ, तिथियों सहित',
    ),
    kit.para(
      'हर अंतर्दशा एक चरण है। हर चरण को उसके स्वामियों, उनकी राशि, भाव, बल और अष्टकवर्ग के आधार पर पढ़ा गया है, और आगे-पीछे के चरणों से जोड़कर। बचपन के चरणों में बात बच्चे के अपने चुनावों से ज़्यादा घर और परिवार की स्थितियों की है।',
    ),
    kit.para(
      'ये फलादेश जीवन के क्षेत्रों और समय के स्वभाव का वर्णन करते हैं; किसी घटना, तिथि-विशेष या परिणाम की भविष्यवाणी नहीं हैं। कठिन चरण का वर्णन इस रूप में है कि वह आपसे क्या माँगता है, किसी फ़ैसले के रूप में नहीं।',
    ),
    if (approx)
      kit.para(
        'आपने जन्म का समय अनुमानित बताया है। दशा की तिथियाँ चंद्र की ठीक स्थिति पर टिकी होती हैं, इसलिए यहाँ की हर तिथि महीनों खिसक सकती है। तिथियों से अधिक अवधियों के क्रम पर भरोसा करें।',
      ),
    kit.h3('इस समय-रेखा का आधार'),
    ...basisBlock(kit, t.basis),
    kit.gap(6),
  ];

  if (now != null) {
    out.add(kit.h2('अभी आप यहाँ हैं'));
    out.addAll(_windowBlock(kit, now, zone, current: true));
  }

  for (final TimelineChapter c in t.chapters) {
    out.add(pw.NewPage(freeSpace: 200));
    out.add(kit.gap(4));
    final double from = c.windows.first.ageStartYears;
    final double to = c.windows.last.ageEndYears;
    out.add(
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: const pw.BoxDecoration(color: Pal.maroon),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            kit.text(
              '${Hi.graha(c.maha.lord)} महादशा',
              style: kit.style(
                kit.fonts.display,
                17,
                color: Pal.white,
                spacing: 1,
              ),
            ),
            kit.text(
              '${Hi.date(c.start, zone)} – ${Hi.date(c.end, zone)} · उम्र ${from.toStringAsFixed(from < 10 ? 1 : 0)} से ${Hi.years(to)}',
              style: kit.style(
                kit.fonts.regular,
                9.2,
                color: Pal.goldLight,
                spacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
    out.add(kit.gap(5));
    final String? h = clean(kit, c.maha.headline);
    if (h != null && h != clean(kit, c.windows.first.headline)) {
      out.add(kit.para(h, style: kit.bodyStrong));
    }
    for (final TimelineWindow w in c.windows) {
      out.addAll(_windowBlock(kit, w, zone, current: identical(w, now)));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// दशा फल
// ---------------------------------------------------------------------------

List<pw.Widget> _periodBlock(
  Kit kit,
  PeriodReading p,
  Duration zone, {
  required String name,
  bool full = true,
}) {
  final List<pw.Widget> out = <pw.Widget>[
    pw.NewPage(freeSpace: 170),
    _band(
      kit,
      children: <pw.Widget>[
        kit.text(
          '${Hi.graha(p.lord)} $name',
          style: kit.style(
            kit.fonts.semi,
            12.4,
            color: Pal.maroon,
            spacing: 1.2,
          ),
        ),
        kit.text(
          '${Hi.date(p.start, zone)} – ${Hi.date(p.end, zone)}',
          style: kit.small,
        ),
      ],
    ),
    kit.gap(4),
    toneChips(
      kit,
      p.tone,
      p.indication,
      extra: <pw.Widget>[
        for (final LifeArea a in p.areas) kit.chip(a.periodTitle.hi),
      ],
    ),
    kit.gap(4),
  ];
  void add(String label, Bi? b) {
    final String? s = clean(kit, b);
    if (s != null) out.add(kit.labelled(label, s));
  }

  final String? headline = clean(kit, p.headline);
  if (headline != null) out.add(kit.p(headline, style: kit.bodyStrong));
  final String? summary = clean(kit, p.summary);
  if (summary != null) out.add(kit.para(summary));
  add('यह स्वामी क्या संकेत देता है', p.promise);
  add('ऊपर की दशा के स्वामी से गिनने पर', p.modifier);
  add('आगे-पीछे की अवधियाँ', p.context);
  add('अक्सर क्या सामने आता है', p.tends);
  add('यह आपसे क्या माँगता है', p.asks);
  add('राहत', p.relief);
  if (full) out.addAll(strengthBlock(kit, p.indication));
  out.addAll(remedyBlock(kit, p.remedies, brief: true));
  out.addAll(basisBlock(kit, p.basis));
  out.add(kit.gap(8));
  return out;
}

List<pw.Widget> dashaPhalaSection(Kit kit, KundliPdfData d) {
  final Duration zone = d.zone;
  final List<PeriodReading> chain = d.phala.dasha.chainAt(d.now);
  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'dashaphala',
      number: 'भाग ९',
      title: 'दशा फल',
      subtitle: 'हर महादशा का फल, और अभी चल रही दशाओं का विस्तार से',
    ),
    kit.para(
      'हर महादशा अकेली नहीं पढ़ी गई: उसके आगे और पीछे की दशा, और जिस अवधि के भीतर वह आती है, उन सबको साथ लेकर पढ़ी गई है। दशा वादा करती है और गोचर उसे निभाता है, इसलिए गोचर अलग भाग में इन्हीं दशाओं के सामने रखा गया है।',
    ),
    kit.h3('इस पूरे क्रम का आधार'),
    ...basisBlock(kit, d.phala.dasha.basis),
  ];
  if (chain.isNotEmpty) {
    out.add(kit.h2('अभी चल रही दशाएँ'));
    const List<String> names = <String>['महादशा', 'अंतर्दशा', 'प्रत्यंतर्दशा'];
    for (int i = 0; i < chain.length; i++) {
      out.addAll(_periodBlock(kit, chain[i], zone, name: names[i]));
    }
  }
  out.add(kit.h2('नौ महादशाएँ'));
  for (final PeriodReading m in d.phala.dasha.mahadashas) {
    out.addAll(_periodBlock(kit, m, zone, name: 'महादशा', full: false));
  }
  return out;
}

// ---------------------------------------------------------------------------
// भाव फल
// ---------------------------------------------------------------------------

List<pw.Widget> bhavaSection(Kit kit, KundliPdfData d) {
  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'bhava',
      number: 'भाग १०',
      title: 'भाव फल',
      subtitle:
          'हर भाव को उसकी राशि, उसके स्वामी, उसमें बैठे और उस पर दृष्टि डालने वाले ग्रहों के आधार पर पढ़ा गया है',
    ),
  ];
  for (final BhavaReading b in d.phala.bhavas) {
    final List<String> lordFlags = <String>[
      Hi.dignity(b.lordDignity),
      if (b.lordCombust) 'अस्त',
      if (b.lordRetrograde) 'वक्री',
    ];
    out.add(pw.NewPage(freeSpace: 240));
    out.add(
      _band(
        kit,
        children: <pw.Widget>[
          kit.text(
            '${b.house}. ${b.area.title.hi}',
            style: kit.style(
              kit.fonts.display,
              15,
              color: Pal.maroon,
              spacing: 1.2,
            ),
          ),
          kit.text(Hi.house(b.house), style: kit.small),
        ],
      ),
    );
    out.add(kit.gap(4));
    out.add(toneChips(kit, b.tone, b.indication));
    out.add(kit.gap(5));
    out.add(kit.kv('राशि', Hi.sign(b.sign)));
    out.add(kit.kv('स्वामी', Hi.graha(b.lord), strong: true));
    out.add(
      kit.kv(
        'स्वामी की स्थिति',
        '${Hi.house(b.lordHouse)} · ${Hi.sign(b.lordSign)} · ${lordFlags.join(' · ')}',
      ),
    );
    out.add(
      kit.kv(
        'भाव में स्थित ग्रह',
        b.occupants.isEmpty ? 'कोई नहीं' : b.occupants.map(Hi.graha).join(', '),
      ),
    );
    out.add(
      kit.kv(
        'दृष्टि डालने वाले ग्रह',
        b.aspectedBy.isEmpty
            ? 'कोई नहीं'
            : b.aspectedBy.map(Hi.graha).join(', '),
      ),
    );
    out.add(kit.kv('सर्वाष्टकवर्ग', '${b.signBindus} बिंदु'));
    out.add(kit.gap(4));
    final String? h = clean(kit, b.headline);
    if (h != null) out.add(kit.p(h, style: kit.bodyStrong));
    final String? r = clean(kit, b.reading);
    if (r != null) out.add(kit.para(r));
    final String? tends = clean(kit, b.tends);
    if (tends != null) out.add(kit.labelled('अक्सर क्या सामने आता है', tends));
    final String? asks = clean(kit, b.asks);
    if (asks != null) out.add(kit.labelled('यह आपसे क्या माँगता है', asks));
    final String? relief = clean(kit, b.relief);
    if (relief != null) out.add(kit.labelled('राहत', relief));
    out.addAll(strengthBlock(kit, b.indication));
    out.addAll(remedyBlock(kit, b.remedies, brief: true));
    out.addAll(basisBlock(kit, b.basis));
    out.add(kit.gap(10));
  }
  return out;
}

// ---------------------------------------------------------------------------
// ग्रह फल
// ---------------------------------------------------------------------------

List<pw.Widget> grahaSection(Kit kit, KundliPdfData d) {
  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'graha',
      number: 'भाग ११',
      title: 'ग्रह फल',
      subtitle: 'हर ग्रह अपनी राशि और भाव में, अपनी स्थिति और युति के साथ',
    ),
  ];
  for (final GrahaReading g in d.phala.grahas) {
    final GrahaStanding st = d.phala.context.standing[g.graha]!;
    final List<String> flags = <String>[
      Hi.dignity(g.dignity),
      if (g.isCombust) 'अस्त',
      if (g.isRetrograde) 'वक्री',
    ];
    out.add(pw.NewPage(freeSpace: 240));
    out.add(
      _band(
        kit,
        children: <pw.Widget>[
          kit.text(
            Hi.graha(g.graha),
            style: kit.style(
              kit.fonts.display,
              16,
              color: Pal.maroon,
              spacing: 1.2,
            ),
          ),
          kit.text(
            '${Hi.sign(g.sign)} · ${Hi.house(g.house)} · ${flags.join(' · ')}',
            style: kit.small,
          ),
        ],
      ),
    );
    out.add(kit.gap(4));
    out.add(toneChips(kit, g.tone, g.indication));
    out.add(kit.gap(5));
    if (g.ruled.isNotEmpty) {
      out.add(kit.kv('किन भावों का स्वामी', g.ruled.map(Hi.house).join(', ')));
    }
    final String? nature = clean(kit, st.natureWhy);
    if (nature != null) {
      out.add(kit.labelled('इस लग्न के लिए इसका स्वभाव', nature));
    }
    if (g.companions.isNotEmpty) {
      out.add(kit.kv('साथ बैठे ग्रह', g.companions.map(Hi.graha).join(', ')));
    }
    if (g.aspectedBy.isNotEmpty) {
      out.add(
        kit.kv('दृष्टि डालने वाले ग्रह', g.aspectedBy.map(Hi.graha).join(', ')),
      );
    }
    out.add(kit.gap(3));
    final String? h = clean(kit, g.headline);
    if (h != null) out.add(kit.p(h, style: kit.bodyStrong));
    final String? r = clean(kit, g.reading);
    if (r != null) out.add(kit.para(r));
    final List<String> yogas = <String>[
      for (final Bi y in g.yogas)
        if (clean(kit, y) != null) y.hi,
    ];
    if (yogas.isNotEmpty) {
      out.add(
        kit.text(
          'जिन योगों में यह शामिल है',
          style: kit.style_(kit.fonts.semi, 8.6, Pal.gold),
        ),
      );
      out.add(kit.gap(1.5));
      out.add(kit.bullets(yogas));
      out.add(kit.gap(3));
    }
    for (final YogaNote n in g.yogaNotes) {
      out.addAll(remedyBlock(kit, n.remedies));
    }
    final String? asks = clean(kit, g.asks);
    if (asks != null) out.add(kit.labelled('यह आपसे क्या माँगता है', asks));
    final String? relief = clean(kit, g.relief);
    if (relief != null) out.add(kit.labelled('राहत', relief));
    out.addAll(strengthBlock(kit, g.indication));
    out.addAll(remedyBlock(kit, g.remedies));
    out.addAll(basisBlock(kit, g.basis));
    out.add(kit.gap(10));
  }
  return out;
}
