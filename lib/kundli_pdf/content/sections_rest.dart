import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../engine/astro/ephemeris.dart';
import '../../engine/jyotish/chart.dart';
import '../../engine/jyotish/ghat_chakra.dart';
import '../../engine/jyotish/mat.dart';
import '../../engine/jyotish/nakshatra.dart';
import '../../engine/jyotish/numerology.dart';
import '../../engine/jyotish/phaladesh.dart';
import '../../engine/jyotish/remedies.dart';
import '../../engine/jyotish/saham.dart';
import '../../engine/jyotish/sudarshan.dart';
import '../../engine/jyotish/tajika_aspects.dart';
import '../../engine/jyotish/tajika_bala.dart';
import '../../engine/jyotish/rashi.dart';
import '../../engine/jyotish/tajika_common.dart'
    show compactNumber, tajikaGrahas;
import '../../engine/jyotish/varshphal.dart';
import '../../engine/jyotish/varshphal_dasha.dart';
import '../../engine/jyotish/varshphal_months.dart';
import '../../engine/jyotish/yogas.dart';
import '../design/ornament.dart';
import '../design/kit.dart';
import '../design/palette.dart';
import 'data.dart';
import 'hindi.dart';
import 'readings.dart';
import 'sections_charts.dart' show houseBoxes;

pw.Widget _band(Kit kit, List<pw.Widget> children, {bool strong = false}) =>
    pw.Inseparable(
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(9, 5, 9, 5),
        decoration: pw.BoxDecoration(
          color: Pal.panel,
          border: pw.Border(
            left: pw.BorderSide(
              color: strong ? Pal.maroon : Pal.gold,
              width: 2.6,
            ),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );

// ---------------------------------------------------------------------------
// योग और दोष
// ---------------------------------------------------------------------------

List<pw.Widget> yogaSection(Kit kit, KundliPdfData d) {
  final List<YogaFinding> all = d.yogas;
  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'yoga',
      number: 'भाग १२',
      title: 'योग और दोष',
      subtitle:
          'कुंडली में जो योग और दोष बनते हैं, हर एक अपने कारकों और परिहार के साथ',
    ),
    kit.para(
      'हर योग या दोष के साथ तीन बातें लिखी हैं: कुंडली का वह नियम जिससे वह बना, परंपरा उसे किस जीवन-क्षेत्र और स्वभाव से जोड़ती है, और कुंडली के कारक। जहाँ दोष है, वहाँ उसका परिहार (जो उसे कम करता है) या, परिहार न मिलने पर, यह लिखा है कि परंपरा उस समय आपसे क्या माँगती है। यह कोई फ़ैसला नहीं है।',
    ),
  ];

  out.add(kit.h2('साढ़ेसाती'));
  const List<String> phases = <String>['', 'पहला', 'दूसरा', 'तीसरा'];
  final String sade = d.sadeSati.detailHindi.replaceFirst(
    '${d.sadeSati.phase}रा चरण',
    '${phases[d.sadeSati.phase.clamp(0, 3)]} चरण',
  );
  out.add(
    kit.para('$sade (${Hi.localDate(d.now.toUtc().add(d.zone))} के अनुसार)'),
  );

  if (all.isEmpty) {
    out.add(kit.para('इस कुंडली में कोई बड़ा योग या दोष प्रमुख नहीं है।'));
    return out;
  }
  for (final YogaFamily fam in YogaFamily.values) {
    final List<YogaFinding> list = all
        .where((YogaFinding f) => f.family == fam)
        .toList();
    if (list.isEmpty) continue;
    out.add(kit.h2('${fam.hindi} · ${list.length}'));
    for (final YogaFinding f in list) {
      final List<String> pieces = <String>[
        f.nameHindi,
        f.ruleHindi,
        f.meaningHindi,
        ?f.cancellationHindi,
        ?f.mitigationHindi,
        ?f.sourceHindi,
        ...f.factorsHindi,
      ];
      if (pieces.any((String x) => kit.isRefused(x, yoga: true))) continue;
      out.add(pw.NewPage(freeSpace: 190));
      out.add(
        _band(kit, <pw.Widget>[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              kit.text(
                f.nameHindi,
                style: kit.style(
                  kit.fonts.semi,
                  12.4,
                  color: Pal.maroon,
                  spacing: 1.2,
                ),
              ),
              kit.chip(f.isDosha ? 'दोष' : 'योग'),
            ],
          ),
        ], strong: f.isDosha),
      );
      out.add(kit.gap(4));
      out.add(kit.labelled('कुंडली में आधार', f.ruleHindi));
      out.add(kit.labelled('परंपरा क्या कहती है', f.meaningHindi));
      if (f.isCancelled) {
        out.add(kit.labelled('किससे कम होता है', f.cancellationHindi!));
      }
      if (f.mitigationHindi != null) {
        out.add(kit.labelled('यह आपसे क्या माँगता है', f.mitigationHindi!));
      }
      if (f.factorsHindi.isNotEmpty) {
        out.add(
          kit.text(
            'कुंडली के कारक',
            style: kit.style_(kit.fonts.semi, 8.6, Pal.gold),
          ),
        );
        out.add(kit.gap(1.5));
        out.add(kit.bullets(f.factorsHindi));
      }
      if (f.sourceHindi != null) out.add(kit.note(f.sourceHindi!));
      out.add(kit.gap(8));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// दो मत
// ---------------------------------------------------------------------------

List<pw.Widget> matbhedSection(Kit kit, KundliPdfData d) {
  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'matbhed',
      number: 'भाग १३',
      title: 'दो मत',
      subtitle: 'जहाँ ग्रंथ एकमत नहीं हैं',
    ),
    kit.para(
      'जब परंपरा के ग्रंथ किसी नियम पर एकमत नहीं होते, तो यह ऐप चुपचाप एक पक्ष नहीं चुनता और बात छोड़ता भी नहीं। यहाँ हर मत उसके तर्क के साथ दिया गया है, और इस कुंडली पर हर मत से गणना भी। जिस मत से ऐप गिनता है उसे चिह्नित किया गया है, और यह भी कि क्यों।',
    ),
  ];
  final List<List<String>> agreeing = <List<String>>[];
  void group(
    String title,
    Iterable<Matbhed> items, {
    Iterable<String>? kickers,
  }) {
    final List<Matbhed> list = items.toList();
    if (list.isEmpty) return;
    final List<String> k = (kickers ?? const <String>[]).toList();
    final List<pw.Widget> cards = <pw.Widget>[];
    for (int i = 0; i < list.length; i++) {
      final Matbhed m = list[i];
      if (m.differs) {
        cards.addAll(matbhedCard(kit, m, kicker: i < k.length ? k[i] : null));
      } else if (!kit.isRefused(m.topic.hi) &&
          !kit.isRefused(m.defaultView.result.hi)) {
        // The books differ, but on this chart every view comes to the same
        // thing, so a line is enough.
        agreeing.add(<String>[title, m.topic.hi, m.defaultView.result.hi]);
      }
    }
    if (cards.isEmpty) return;
    out.add(kit.h2(title));
    out.addAll(cards);
  }

  group(
    'योगों पर मतभेद',
    d.yogaMatbhed.map((YogaMatbhed m) => m.matbhed),
    kickers: d.yogaMatbhed.map((YogaMatbhed m) => m.family.hindi),
  );
  group('सुदर्शन चक्र', <Matbhed>[d.sudarshanViews]);
  group('घात चक्र', d.ghatMatbhed);
  group('उपग्रह', d.upagrahaViews);
  group('जन्म के दिन का पंचांग', d.dayMatbhed);
  final Varshphal v = d.varshphal;
  group('वर्षफल: सहम', <Matbhed>[
    ?v.extraSign,
    for (final SahamMatbhed m in v.sahamMatbhed) m.matbhed,
  ]);
  group('वर्षफल: ताजिक दृष्टि और योग', v.tajikaMatbhed);
  group('वर्षफल: दशा', v.dashaMatbhed);

  if (agreeing.isNotEmpty) {
    out.add(pw.NewPage(freeSpace: 200));
    out.add(kit.h2('जहाँ मतभेद का असर इस कुंडली पर नहीं पड़ता'));
    out.add(
      kit.para(
        'नीचे के विषयों पर ग्रंथ अलग-अलग नियम देते हैं, पर इस कुंडली पर सभी नियम एक ही परिणाम पर पहुँचते हैं, इसलिए यहाँ मतभेद से कोई अंतर नहीं पड़ता। हर पंक्ति में वह परिणाम है जो ऐप ने लिया।',
      ),
    );
    out.add(
      kit.table(
        headers: <String>['विषय', 'वर्ग', 'सभी मतों का परिणाम'],
        rows: <List<String>>[
          for (final List<String> r in agreeing) <String>[r[1], r[0], r[2]],
        ],
        widths: <double>[2.4, 1.8, 3.8],
        size: 8.4,
        keep: false,
      ),
    );
  }
  return out;
}

// ---------------------------------------------------------------------------
// गोचर
// ---------------------------------------------------------------------------

List<pw.Widget> gocharSection(Kit kit, KundliPdfData d) {
  final GocharPhala g = d.gochar;
  final Duration zone = d.zone;
  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'gochar',
      number: 'भाग १४',
      title: 'गोचर',
      subtitle:
          '${Hi.localDate(g.moment.add(zone))} के अनुसार: धीमी चाल वाले ग्रह आपकी कुंडली के साथ पढ़े गए',
    ),
  ];
  final String? principle = clean(kit, g.principle);
  if (principle != null) out.add(kit.para(principle));
  final String? sade = clean(kit, g.sadeSati);
  if (sade != null) out.add(kit.labelled('साढ़ेसाती', sade));
  out.addAll(basisBlock(kit, g.basis));
  out.add(kit.gap(4));

  for (final GocharReading r in g.readings) {
    out.add(pw.NewPage(freeSpace: 300));
    out.add(
      _band(kit, <pw.Widget>[
        kit.text(
          Hi.graha(r.graha),
          style: kit.style(
            kit.fonts.display,
            15,
            color: Pal.maroon,
            spacing: 1.2,
          ),
        ),
        kit.text(
          '${Hi.sign(r.sign)}${r.isRetrograde ? ' · वक्री' : ''}',
          style: kit.small,
        ),
      ]),
    );
    out.add(kit.gap(4));
    out.add(toneChips(kit, r.tone, r.indication));
    out.add(kit.gap(5));
    out.add(kit.kv('चंद्र से', Hi.house(r.houseFromMoon)));
    out.add(kit.kv('लग्न से', Hi.house(r.houseFromLagna)));
    out.add(
      kit.kv(
        'राशि में प्रवेश',
        r.entered == null ? '—' : Hi.date(r.entered!, zone),
      ),
    );
    out.add(
      kit.kv(
        'राशि से प्रस्थान',
        r.leaves == null ? '—' : Hi.date(r.leaves!, zone),
      ),
    );
    out.add(
      kit.kv(
        'सर्वाष्टकवर्ग',
        '${r.signBindus} बिंदु${r.ownBindus == null ? '' : ' · अपने अष्टकवर्ग में ${r.ownBindus}'}',
      ),
    );
    out.add(kit.gap(4));
    final String? h = clean(kit, r.headline);
    if (h != null) out.add(kit.p(h, style: kit.bodyStrong));
    final String? rd = clean(kit, r.reading);
    if (rd != null) out.add(kit.para(rd));
    final String? tends = clean(kit, r.tends);
    if (tends != null) out.add(kit.labelled('अक्सर क्या सामने आता है', tends));
    final String? asks = clean(kit, r.asks);
    if (asks != null) out.add(kit.labelled('यह आपसे क्या माँगता है', asks));
    final String? relief = clean(kit, r.relief);
    if (relief != null) out.add(kit.labelled('राहत', relief));
    out.addAll(strengthBlock(kit, r.indication));
    out.addAll(remedyBlock(kit, r.remedies, brief: true));
    out.addAll(basisBlock(kit, r.basis));
    out.add(kit.gap(10));
  }
  return out;
}

// ---------------------------------------------------------------------------
// वर्षफल
// ---------------------------------------------------------------------------

List<pw.Widget> varshphalSection(Kit kit, KundliPdfData d) {
  final Varshphal v = d.varshphal;
  final Kundli k = d.kundli;
  final Duration off = k.birth.utcOffset;
  final DateTime moment = v.returnMoment.add(off);
  final DateTime nextMoment = v.nextReturnMoment.add(off);
  DateTime local(double jd) => localOf(jd, off);
  String range(DateTime a, DateTime b) =>
      '${Hi.localDate(a)} – ${Hi.localDate(b)}';

  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'varshphal',
      number: 'भाग १५',
      title: 'वर्षफल',
      subtitle: 'आपके ${v.year} वर्ष पूरे होने का वर्ष, ताजिक पद्धति से',
    ),
    kit.para(
      'वर्षफल उस क्षण की कुंडली है जब सूर्य ठीक उसी अंश पर लौटता है जहाँ जन्म के समय था। उस कुंडली पर मुन्था, पाँच अधिकारी, ताजिक दृष्टि और योग, सहम और मुद्दा दशा बनाए जाते हैं। यह वर्ष इसी से पढ़ा गया है।',
    ),
    kit.h2('सूर्य की वापसी'),
    kit.kv(
      'क्षण',
      '${Hi.localDate(moment)}, ${Hi.clock(moment)}',
      strong: true,
    ),
    kit.kv(
      'वर्ष की समाप्ति',
      '${Hi.localDate(nextMoment)}, ${Hi.clock(nextMoment)}',
    ),
    kit.kv('प्रवेश', v.isDay ? 'दिन में' : 'रात्रि में'),
    kit.kv('वर्ष लग्न', Hi.sign(v.chart.lagnaRashi)),
    kit.kv('मुन्था', '${Hi.signAt(v.munthaSign)} · ${Hi.house(v.munthaHouse)}'),
    kit.kv('मुन्था पति', Hi.graha(v.munthaLord)),
    kit.kv('वर्षेश', Hi.graha(v.yearLord), strong: true),
    kit.gap(6),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Column(
          children: <pw.Widget>[
            kit.northChart(
              236,
              houseBoxes(v.chart, marks: true),
              labelSize: 10.4,
            ),
            kit.gap(3),
            kit.text('वर्ष कुंडली', style: kit.small),
          ],
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              kit.text(
                'वर्ष कुंडली के ग्रह',
                style: kit.style_(kit.fonts.semi, 9.6, Pal.maroon),
              ),
              kit.gap(3),
              for (final PlacedGraha p in v.chart.grahas.values)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2.4),
                  child: kit.text(
                    '${Hi.graha(p.graha)} · ${Hi.sign(p.rashi)} ${Hi.deg(p.degreesInSign)} · ${Hi.house(p.house)}',
                    style: kit.style(kit.fonts.regular, 8.8, spacing: 1.1),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    kit.gap(6),
    kit.h2('मुन्था'),
    kit.para(munthaReading(v.munthaHouse, hindi: true)),
  ];
  final String? ml = clean(kit, munthaLordReading(v));
  if (ml != null) out.add(kit.note(ml));

  // The lord of the year.
  out.add(kit.h2('वर्षेश: वर्ष का स्वामी'));
  final String? vr = clean(kit, v.varshesh.reading);
  if (vr != null) out.add(kit.para(vr));
  final String? rule = clean(kit, v.varshesh.rule);
  if (rule != null) out.add(kit.labelled('चुनाव का नियम', rule));
  out.addAll(basisBlock(kit, v.varshesh.factors));
  out.add(kit.gap(4));
  out.add(kit.h3('पाँच अधिकारी'));
  out.add(
    kit.table(
      headers: <String>['अधिकारी', 'ग्रह', 'विश्वा', 'लग्न पर दृष्टि', 'आधार'],
      rows: <List<String>>[
        for (final VarshaOfficer o in v.varshesh.officers)
          <String>[
            o.officeName.hi,
            Hi.graha(o.graha),
            compactNumber(o.vishwa),
            o.aspectsLagna
                ? 'है · ${signAspectBi(o.aspectToLagna!).hi}'
                : 'नहीं',
            o.basis.hi,
          ],
      ],
      widths: <double>[1.6, 1.1, 0.9, 1.9, 3.2],
      size: 8.2,
      highlightRows: <int>{
        for (int i = 0; i < v.varshesh.officers.length; i++)
          if (v.varshesh.officers[i].graha == v.yearLord) i,
      },
    ),
  );
  out.add(kit.gap(6));
  out.add(kit.h3('पंचवर्गीय बल (विश्वा)'));
  out.add(
    kit.note(
      'गृह 30, उच्च 20, हद्दा 15, द्रेष्काण 10, नवांश 5: कुल 80, चार से भाग देने पर 20 विश्वा। 5 से कम निर्बल, 5 से 10 दुर्बल, 10 से 15 मध्यम, 15 से ऊपर उत्तम।',
    ),
  );
  out.add(
    kit.table(
      headers: <String>[
        'ग्रह',
        'गृह',
        'उच्च',
        'हद्दा',
        'द्रेष्का.',
        'नवांश',
        'कुल',
        'विश्वा',
      ],
      rows: <List<String>>[
        for (final Graha g in tajikaGrahas)
          (() {
            final PanchaVargiyaBala b = v.bala[g]!;
            return <String>[
              Hi.graha(g),
              for (final PvComponent c in b.components)
                compactNumber(c.points, decimals: 2),
              compactNumber(b.total, decimals: 2),
              compactNumber(b.vishwa, decimals: 2),
            ];
          })(),
      ],
      widths: <double>[1.3, 1, 1, 1, 1.1, 1, 1, 1.1],
      align: <pw.TextAlign>[
        pw.TextAlign.left,
        ...List<pw.TextAlign>.filled(7, pw.TextAlign.right),
      ],
      size: 8.6,
    ),
  );

  // The year in dated windows.
  out.add(pw.NewPage(freeSpace: 240));
  out.add(kit.h2('महीने दर महीने'));
  out.add(
    kit.para(
      'वर्ष के दिनांकित खंड, हर मुद्दा दशा काल के लिए एक, उसकी ताजिक दृष्टियों और उसके सहमों के साथ।',
    ),
  );
  for (final YearWindow w in v.windows) {
    final List<String> texts = <String>[
      w.title.hi,
      w.reading.hi,
      for (final WindowEvent e in w.events) e.text.hi,
      for (final Object f in w.factors) hindiOf(f),
    ];
    if (texts.any(kit.isRefused)) continue;
    out.add(pw.NewPage(freeSpace: 150));
    out.add(
      _band(kit, <pw.Widget>[
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            kit.text(
              range(w.startLocal, w.endLocal),
              style: kit.style(
                kit.fonts.semi,
                11,
                color: Pal.maroon,
                spacing: 1.2,
              ),
            ),
            kit.text(
              Hi.graha(w.lord),
              style: kit.style(
                kit.fonts.semi,
                11,
                color: Pal.maroon,
                spacing: 1.2,
              ),
            ),
          ],
        ),
        kit.text(
          '${compactNumber(w.days)} दिन · ${w.title.hi}',
          style: kit.small,
        ),
      ]),
    );
    out.add(kit.gap(4));
    out.add(kit.para(w.reading.hi));
    for (final WindowEvent e in w.events) {
      out.add(kit.bullet(e.text.hi));
    }
    out.addAll(basisBlock(kit, w.factors));
    out.add(kit.gap(6));
  }

  // Mudda and Patyayini dashas.
  out.add(pw.NewPage(freeSpace: 240));
  out.add(kit.h2('मुद्दा दशा'));
  out.add(
    kit.para('विंशोत्तरी का क्रम, 120 वर्ष इस वर्ष की लंबाई में समेटे हुए।'),
  );
  out.addAll(basisBlock(kit, v.mudda.factors));
  out.add(
    kit.table(
      headers: <String>['स्वामी', 'दिन', 'आरंभ', 'समाप्ति', ''],
      rows: <List<String>>[
        for (final MuddaPeriod p in v.mudda.periods)
          <String>[
            Hi.graha(p.lord),
            compactNumber(p.days),
            Hi.localDate(local(p.startJd)),
            Hi.localDate(local(p.endJd)),
            p.isBalance ? 'शेष भाग' : (p.isCarryOver ? 'फिर से' : ''),
          ],
      ],
      widths: <double>[1.3, 0.9, 2, 2, 1.1],
      size: 8.8,
    ),
  );
  out.add(kit.gap(6));
  out.add(kit.h3('पात्यायिनी दशा'));
  out.add(
    kit.note(
      'सात ग्रह और लग्न अपनी राशि के भीतर के अंशों के क्रम में; वर्ष अंशों के अंतर के अनुपात में बँटता है।',
    ),
  );
  out.addAll(basisBlock(kit, v.patyayini.factors));
  for (final PatyayiniPeriod p in v.patyayini.periods) {
    if (kit.isRefused(p.reading.hi) || kit.isRefused(p.name.hi)) continue;
    out.add(
      kit.labelled(
        '${p.name.hi} · ${compactNumber(p.days)} दिन · ${Hi.localDate(local(p.startJd))} – ${Hi.localDate(local(p.endJd))}',
        p.reading.hi,
      ),
    );
  }

  // Tajika.
  out.add(pw.NewPage(freeSpace: 240));
  out.add(kit.h2('ताजिक दृष्टि और योग'));
  out.add(
    kit.para(
      'इत्थशाल (समीप आती) और ईसराफ (दूर जाती) दृष्टियाँ दीप्तांश के भीतर, तथा उनसे बनने वाले योग।',
    ),
  );
  for (final TajikaYoga y in v.tajika.chartYogas) {
    final List<String> t = <String>[y.indicates.hi, y.condition.hi];
    if (t.any(kit.isRefused)) continue;
    out.add(
      kit.labelled(y.name.hi, '${y.indicates.hi} शर्त: ${y.condition.hi}'),
    );
  }
  if (v.tajika.aspects.isEmpty) {
    out.add(kit.para('इस वर्ष कुंडली में कोई जोड़ी दीप्तांश के भीतर नहीं।'));
  }
  for (final TajikaAspect a in v.tajika.aspects) {
    if (kit.isRefused(a.reading.hi)) continue;
    out.add(pw.NewPage(freeSpace: 110));
    out.add(
      kit.h3(
        '${Hi.graha(a.faster)} · ${Hi.graha(a.slower)} — ${a.isApplying ? 'इत्थशाल, समीप आता' : 'ईसराफ, दूर जाता'}',
      ),
    );
    out.add(
      kit.note(
        '${Hi.deg(a.gap)} का अंतर · सीमा ${compactNumber(a.orb)}° · ${signAspectBi(a.signAspect).hi}',
      ),
    );
    out.add(kit.para(a.reading.hi));
    out.addAll(basisBlock(kit, a.factors));
  }
  out.add(kit.h3('विषय और योग'));
  out.add(
    kit.note(
      'लग्नेश और हर भाव के स्वामी का जोड़ा: योग वही बनते हैं जो उनके बीच की शर्तें पूरी करें।',
    ),
  );
  for (final TajikaMatter m in v.tajika.matters) {
    if (m.yogas.isEmpty) continue;
    final List<String> t = <String>[
      m.reading.hi,
      for (final TajikaYoga y in m.yogas) ...<String>[
        y.indicates.hi,
        y.condition.hi,
      ],
    ];
    if (t.any(kit.isRefused)) continue;
    out.add(
      kit.labelled(
        '${Hi.house(m.house)} · ${m.theme.hi} (लग्नेश ${Hi.graha(m.lagnesha)}, भावेश ${Hi.graha(m.karyesha)})',
        <String>[
          for (final TajikaYoga y in m.yogas) '${y.name.hi}: ${y.indicates.hi}',
        ].join(' '),
      ),
    );
  }

  // Sahams.
  out.add(pw.NewPage(freeSpace: 240));
  out.add(kit.h2('सहम'));
  out.add(
    kit.para(
      v.isDay
          ? 'प्रवेश दिन में हुआ, इसलिए सहम दिन के सूत्र से निकाले गए हैं। सूत्र A − B + C है: B से A तक का चाप C से आगे।'
          : 'प्रवेश रात्रि में हुआ, इसलिए सहम रात्रि के सूत्र से निकाले गए हैं। सूत्र A − B + C है: B से A तक का चाप C से आगे।',
    ),
  );
  final List<Saham> shown = <Saham>[
    for (final Saham s in v.sahams)
      if (!kit.isRefused(s.name.hi) &&
          !(s.reading != null && kit.isRefused(s.reading!.hi)))
        s,
  ];
  out.add(
    kit.table(
      headers: <String>['सहम', 'राशि · अंश', 'भाव', 'स्वामी', 'स्थिति'],
      rows: <List<String>>[
        for (final Saham s in shown)
          <String>[
            s.name.hi,
            '${Hi.sign(s.rashi)} ${Hi.deg(s.degreeInSign)}',
            Hi.house(s.house),
            Hi.graha(s.lord),
            switch (s.tone) {
              SahamTone.supported => 'सहारा पाता',
              SahamTone.mixed => 'मिला-जुला',
              SahamTone.strained => 'दबाव में',
              null => '—',
            },
          ],
      ],
      widths: <double>[2.3, 2, 1.4, 1.2, 1.4],
      size: 8.6,
    ),
  );
  out.add(kit.gap(6));
  for (final Saham s in shown) {
    if (s.reading == null) continue;
    out.add(kit.labelled(s.name.hi, s.reading!.hi));
  }
  return out;
}

// ---------------------------------------------------------------------------
// सुदर्शन चक्र
// ---------------------------------------------------------------------------

String _verdict(HouseVerdict v) => switch (v) {
  HouseVerdict.strong => 'सहायक',
  HouseVerdict.mixed => 'मिश्र',
  HouseVerdict.weak => 'दबा',
};

String _agreement(SudarshanAgreement a) => switch (a) {
  SudarshanAgreement.all => 'तीनों से',
  SudarshanAgreement.two => 'दो से',
  SudarshanAgreement.one => 'एक से',
  SudarshanAgreement.none => 'किसी से नहीं',
};

List<pw.Widget> sudarshanSection(Kit kit, KundliPdfData d) {
  final SudarshanChakra c = d.sudarshan;
  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'sudarshan',
      number: 'भाग १६',
      title: 'सुदर्शन चक्र',
      subtitle: 'हर भाव लग्न, चंद्र और सूर्य, तीनों से',
    ),
    kit.para(
      'सुदर्शन चक्र में हर भाव को तीन संदर्भों से पढ़ा जाता है: लग्न (शरीर और बाहरी जीवन), चंद्र (मन और भावना) और सूर्य (आत्मा और प्रतिष्ठा)। जो भाव तीनों से अच्छा खड़ा हो, वह भरोसेमंद रूप से अच्छा क्षेत्र माना जाता है; जो केवल एक से अच्छा हो, वह उतना भरोसेमंद नहीं।',
    ),
    kit.para(c.noteHindi),
    kit.table(
      headers: <String>[
        'भाव',
        'क्षेत्र',
        'लग्न से',
        'चंद्र से',
        'सूर्य से',
        'सहमति',
      ],
      rows: <List<String>>[
        for (final SudarshanHouse h in c.houses)
          <String>[
            '${h.house}',
            h.areaHindi.split(':').first,
            _verdict(h.fromLagna.verdict),
            _verdict(h.fromChandra.verdict),
            _verdict(h.fromSurya.verdict),
            _agreement(h.agreement),
          ],
      ],
      widths: <double>[0.6, 3.6, 1.2, 1.2, 1.2, 1.4],
      size: 8.8,
      align: <pw.TextAlign>[
        pw.TextAlign.center,
        ...List<pw.TextAlign>.filled(5, pw.TextAlign.left),
      ],
    ),
    kit.gap(8),
    kit.h2('हर भाव का पाठ'),
  ];
  for (final SudarshanHouse h in c.houses) {
    if (kit.isRefused(h.readingHindi) || kit.isRefused(h.areaHindi)) continue;
    out.add(pw.NewPage(freeSpace: 130));
    out.add(kit.h3('${Hi.house(h.house)} · ${h.areaHindi}'));
    out.add(kit.para(h.readingHindi));
    final List<String> factors = <String>[
      for (final HouseStanding s in h.standings)
        for (final String f in s.factorsHindi)
          if (!kit.isRefused(f))
            '${s.reference.hindi} से · ${Hi.sign(s.rashi)}: $f',
    ];
    if (factors.isNotEmpty) {
      out.add(
        kit.text('आधार', style: kit.style_(kit.fonts.semi, 8.6, Pal.gold)),
      );
      out.add(kit.gap(1.5));
      out.add(kit.bullets(factors.take(9).toList()));
    }
    out.add(kit.gap(4));
  }
  return out;
}

// ---------------------------------------------------------------------------
// अन्य विधियाँ
// ---------------------------------------------------------------------------

List<pw.Widget> otherSection(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final GhatChakraReading gh = d.ghat;
  final NumerologyReading n = d.numerology;
  final NumberInfo mul = numberInfo(n.mulank);
  final NumberInfo bha = numberInfo(n.bhagyank);

  const List<List<int>> loshu = <List<int>>[
    <int>[4, 9, 2],
    <int>[3, 5, 7],
    <int>[8, 1, 6],
  ];

  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'other',
      number: 'भाग १७',
      title: 'अन्य विधियाँ',
      subtitle: 'घात चक्र, अंक ज्योतिष और मिलान के आधार',
    ),
    kit.h2('घात चक्र'),
  ];
  if (!kit.isRefused(gh.statementHindi) && !kit.isRefused(gh.cautionHindi)) {
    out.add(kit.para(gh.statementHindi));
    out.add(kit.note(gh.cautionHindi));
  }

  out.add(kit.h2('अंक ज्योतिष'));
  out.add(
    kit.table(
      headers: <String>['अंक', 'संख्या', 'स्वामी ग्रह', 'स्वभाव'],
      rows: <List<String>>[
        <String>[
          'मूलांक (जन्म की तारीख़ से)',
          '${n.mulank}',
          mul.planetHindi,
          mul.traitsHindi,
        ],
        <String>[
          'भाग्यांक (पूरी तिथि से)',
          '${n.bhagyank}',
          bha.planetHindi,
          bha.traitsHindi,
        ],
        // The name number is worked from the letters of the Latin spelling; a
        // name written only in Devanagari has none to count.
        if (n.namank > 0 && RegExp(r'[A-Za-z]').hasMatch(k.birth.name))
          <String>[
            'नामांक (नाम की अंग्रेज़ी वर्तनी से)',
            '${n.namank}',
            numberInfo(n.namank).planetHindi,
            numberInfo(n.namank).traitsHindi,
          ],
      ],
      widths: <double>[2.4, 0.9, 1.3, 4],
      size: 8.8,
    ),
  );
  out.add(kit.gap(4));
  out.add(
    kit.para(
      n.mulankAndBhagyankAgree
          ? 'मूलांक और भाग्यांक मित्र हैं: स्वभाव और मार्ग एक दिशा में चलते हैं।'
          : 'मूलांक और भाग्यांक अलग दिशा में हैं: जो स्वभाव चाहता है और जो जीवन माँगता है, उनमें अंतर रहता है।',
    ),
  );
  out.add(kit.h3('लो शू ग्रिड'));
  out.add(
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Table(
          border: pw.TableBorder.all(color: Pal.gold, width: 0.8),
          columnWidths: <int, pw.TableColumnWidth>{
            for (int i = 0; i < 3; i++) i: const pw.FixedColumnWidth(46),
          },
          children: <pw.TableRow>[
            for (final List<int> row in loshu)
              pw.TableRow(
                children: <pw.Widget>[
                  for (final int digit in row)
                    pw.Container(
                      height: 40,
                      alignment: pw.Alignment.center,
                      child: kit.text(
                        n.loshu[digit]! == 0
                            ? ''
                            : List<String>.filled(
                                n.loshu[digit]!,
                                '$digit',
                              ).join(' '),
                        style: kit.style(
                          kit.fonts.semi,
                          13,
                          color: Pal.maroon,
                          spacing: 0,
                        ),
                        align: pw.TextAlign.center,
                      ),
                    ),
                ],
              ),
          ],
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              kit.kv(
                'अनुपस्थित अंक',
                n.missingNumbers.isEmpty ? '—' : n.missingNumbers.join(', '),
              ),
              kit.kv(
                'बार-बार आने वाले',
                n.repeatedNumbers.isEmpty ? '—' : n.repeatedNumbers.join(', '),
              ),
              kit.kv('मूलांक के रंग', mul.luckyColoursHindi.join(', ')),
              kit.kv('भाग्यांक के रंग', bha.luckyColoursHindi.join(', ')),
              kit.gap(4),
              kit.note(
                'ग्रिड में हर खाने में जन्म-तिथि के अंक, मूलांक और भाग्यांक जितनी बार आते हैं उतनी बार लिखे हैं।',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final NakshatraInfo nak = k.janmaNakshatra;
  out.add(kit.h2('मिलान के आधार'));
  out.add(
    kit.para(
      'विवाह-मिलान में कुंडलियों का मिलान दो व्यक्तियों के बीच किया जाता है, इसलिए यहाँ केवल वे आधार रखे गए हैं जो आपके अपने जन्म-नक्षत्र से बनते हैं।',
    ),
  );
  out.add(
    kit.table(
      headers: <String>['आधार', 'आपका'],
      rows: <List<String>>[
        <String>[
          'चंद्र राशि',
          '${Hi.sign(k.moonRashi)} (स्वामी ${Hi.graha(rashiInfo(k.moonRashi).lord)})',
        ],
        <String>[
          'जन्म नक्षत्र और पाद',
          '${nak.hindi} · पाद ${k.grahas[Graha.moon]!.pada}',
        ],
        <String>['गण', Hi.gana(nak.gana)],
        <String>['योनि', Hi.yoni(nak.yoni)],
        <String>['नाड़ी', Hi.nadi(nak.nadi)],
        <String>['नक्षत्र स्वामी', Hi.graha(nak.lord)],
      ],
      widths: <double>[2, 3.4],
    ),
  );
  out.add(kit.gap(4));
  out.add(
    kit.note(
      'मंगल दोष का विचार इस पत्रिका में \'योग और दोष\' भाग में उसके परिहार के साथ है।',
    ),
  );
  return out;
}

// ---------------------------------------------------------------------------
// उपाय
// ---------------------------------------------------------------------------

List<pw.Widget> upayaSection(Kit kit, KundliPdfData d) {
  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'upaya',
      number: 'भाग १८',
      title: 'उपाय',
      subtitle:
          'परंपरा के सरल उपाय, उन ग्रहों के लिए जिन पर इस कुंडली में सबसे अधिक दबाव है',
    ),
    kit.para(remedyStanceHindi()),
  ];
  if (d.remedies.isEmpty) {
    out.add(
      kit.para(
        'इस कुंडली में किसी ग्रह पर विशेष दबाव नहीं मिला, इसलिए अलग से कोई उपाय नहीं चुना गया। भाव, ग्रह, दशा और गोचर के पाठों में जहाँ कहीं उपाय आए हैं, वे वहीं दिए हैं।',
      ),
    );
    return out;
  }
  for (final RemedySet r in d.remedies) {
    final GrahaRemedyKit kitOf = grahaRemedyKits[r.graha]!;
    final List<String> items = <String>[
      'कारण: ${r.reasonHindi.replaceFirst('कारण: ', '')}',
      'मंत्र: ${kitOf.mantra.hi}',
      'जप: ${kitOf.japa.hi}',
      'व्रत: ${kitOf.fast.hi}',
      'दान: ${kitOf.daan.hi}',
      'देवता: ${kitOf.deity.hi}',
      'एक सरल कार्य: ${kitOf.simpleAct.hi}',
    ];
    if (items.any(kit.isRefused)) continue;
    kit.remedyLedger.addAll(items);
    out.add(pw.NewPage(freeSpace: 220));
    out.add(
      _band(kit, <pw.Widget>[
        kit.text(
          Hi.graha(r.graha),
          style: kit.style(
            kit.fonts.display,
            15,
            color: Pal.maroon,
            spacing: 1.2,
          ),
        ),
      ]),
    );
    out.add(kit.gap(4));
    for (final String s in items) {
      out.add(kit.bullet(s, style: kit.body));
    }
    out.add(kit.gap(8));
  }
  return out;
}

// ---------------------------------------------------------------------------
// समापन
// ---------------------------------------------------------------------------

pw.Widget closingPage(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final DateTime now = d.now.toUtc().add(k.birth.utcOffset);
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(92, 0, 92, 0),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: <pw.Widget>[
        pw.SizedBox(height: 366),
        kit.text(
          'समापन',
          style: kit.style(
            kit.fonts.display,
            30,
            color: Pal.maroon,
            spacing: 1,
          ),
          align: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        kit.text(
          'कुछ बातें जो याद रहें',
          style: kit.style(kit.fonts.serif, 12, color: Pal.inkSoft, spacing: 1),
          align: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 14),
        kit.para(
          'यह जन्म पत्रिका परंपरागत वैदिक ज्योतिष की पराशरी और ताजिक पद्धतियों पर आधारित मार्गदर्शन और सांस्कृतिक सामग्री है। यह किसी घटना, तिथि-विशेष या परिणाम की भविष्यवाणी नहीं है, और किसी पेशेवर परामर्श का विकल्प भी नहीं।',
          style: kit.style(kit.fonts.regular, 10, spacing: 3),
        ),
        kit.para(
          'हर फल के साथ उसका आधार लिखा है, ताकि आप जाँच सकें कि बात कहाँ से आई। जहाँ ग्रंथ एकमत नहीं थे, वहाँ दोनों मत रखे गए हैं।',
          style: kit.style(kit.fonts.regular, 10, spacing: 3),
        ),
        kit.para(
          'ग्रहों की स्थितियाँ इस ऐप के अपने गणित से, आपके उपकरण पर ही निकाली गई हैं, जो JPL DE440s की तुलना में लगभग एक विकला तक सटीक हैं। आपका जन्म विवरण इस उपकरण से बाहर नहीं गया।',
          style: kit.style(kit.fonts.regular, 10, spacing: 3),
        ),
        kit.para(
          'जन्म का समय जितना ठीक होगा, लग्न और भाव उतने ही भरोसेमंद होंगे। चंद्र, नक्षत्र और दशा थोड़े से अंतर से अधिक नहीं बदलते।',
          style: kit.style(kit.fonts.regular, 10, spacing: 3),
        ),
        pw.Spacer(),
        pw.SizedBox(
          height: 14,
          width: 220,
          child: pw.CustomPaint(
            painter: (PdfGraphics g, PdfPoint s) =>
                Ornament.divider(g, 110, 7, 100),
          ),
        ),
        pw.SizedBox(height: 6),
        kit.text(
          'कुंडलीसार · निःशुल्क वैदिक कुंडली',
          style: kit.style(kit.fonts.semi, 10, color: Pal.maroon, spacing: 1),
          align: pw.TextAlign.center,
        ),
        kit.text(
          'तैयार की गई: ${Hi.localDate(now)}',
          style: kit.style(
            kit.fonts.regular,
            8.6,
            color: Pal.inkSoft,
            spacing: 1,
          ),
          align: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 112),
      ],
    ),
  );
}
