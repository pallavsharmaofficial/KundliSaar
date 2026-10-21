import 'package:pdf/widgets.dart' as pw;

import '../../engine/jyotish/mat.dart';
import '../../engine/jyotish/tajika_common.dart' as tajika show Bi;
import '../../engine/jyotish/phaladesh.dart';
import '../../engine/jyotish/remedies.dart';
import '../design/kit.dart';
import '../design/palette.dart';
import 'hindi.dart';

/// The parts every reading of the phaladesh is made of, set the same way
/// wherever it appears: its tone and strength, what tends to come up, what it
/// asks, what eases it, the remedies, and the factors it came from.

ToneLook toneLook(Tone t) => switch (t) {
  Tone.supportive => ToneLook.supportive,
  Tone.mixed => ToneLook.mixed,
  Tone.demanding => ToneLook.demanding,
};

String toneLabel(Tone t) => switch (t) {
  Tone.supportive => 'अनुकूल',
  Tone.mixed => 'मिला-जुला',
  Tone.demanding => 'परिश्रम माँगता है',
};

/// The Hindi side of an engine string. The engine has two classes for a
/// two-language string (the phaladesh one and the Tajika one), alike in shape.
String hindiOf(Object b) => b is Bi ? b.hi : (b as tajika.Bi).hi;

/// Text from the engine, or null when it carries a word the book never prints.
String? clean(Kit kit, Object? b) {
  if (b == null) return null;
  final String s = hindiOf(b);
  if (s.trim().isEmpty) return null;
  return kit.isRefused(s) ? null : s;
}

/// The tone and the strength of indication, side by side.
pw.Widget toneChips(
  Kit kit,
  Tone tone,
  Indication indication, {
  List<pw.Widget> extra = const <pw.Widget>[],
}) => kit.chips(<pw.Widget>[
  kit.chip(toneLabel(tone), tone: toneLook(tone)),
  kit.chip(indication.summary.hi),
  ...extra,
]);

/// The band, its caution and the factors that agree and disagree.
List<pw.Widget> strengthBlock(Kit kit, Indication ind) {
  final List<pw.Widget> out = <pw.Widget>[
    kit.labelled('संकेत कितना प्रबल है', ind.summary.hi, style: kit.bodyStrong),
  ];
  final String? caution = clean(kit, ind.caution);
  if (caution != null) out.add(kit.para(caution));
  List<String> texts(List<IndicatorFactor> fs) => <String>[
    for (final IndicatorFactor f in fs)
      if (clean(kit, f.text) != null) f.text.hi,
  ];
  final List<String> agree = texts(ind.agreeing);
  final List<String> against = texts(ind.disagreeing);
  out.add(kit.text(ind.agreeHeading.hi, style: kit.smallStrong));
  out.add(kit.gap(1.5));
  out.add(agree.isEmpty ? kit.note('कोई नहीं') : kit.bullets(agree));
  out.add(kit.gap(2));
  out.add(kit.text(ind.disagreeHeading.hi, style: kit.smallStrong));
  out.add(kit.gap(1.5));
  out.add(against.isEmpty ? kit.note('कोई नहीं') : kit.bullets(against));
  return out;
}

/// The remedies of a finding. [brief] leaves out the deity and the giving, for
/// the dated windows, where there are many.
List<pw.Widget> remedyBlock(
  Kit kit,
  List<Remedy> remedies, {
  bool brief = false,
}) {
  if (remedies.isEmpty) return const <pw.Widget>[];
  final List<pw.Widget> out = <pw.Widget>[
    kit.text(
      'परंपरा क्या उपाय बताती है',
      style: kit.style_(kit.fonts.semi, 8.6, Pal.gold),
    ),
    kit.gap(2),
  ];
  for (final Remedy r in remedies) {
    final GrahaRemedyKit k = r.kit;
    final String why = r.addresses.hi;
    final List<String> parts = <String>[
      'मंत्र: ${k.mantra.hi}',
      if (!brief) 'जप: ${k.japa.hi}',
      'व्रत: ${k.fast.hi}',
      if (!brief) 'दान: ${k.daan.hi}',
      if (!brief) 'देवता: ${k.deity.hi}',
      'एक सरल कार्य: ${k.simpleAct.hi}',
    ];
    if (kit.isRefused(why) || parts.any(kit.isRefused)) continue;
    kit.remedyLedger
      ..add(why)
      ..addAll(parts);
    // The box is wrapped in a Padding so that it is kept whole on one page.
    out.add(
      pw.Inseparable(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 4),
          padding: const pw.EdgeInsets.fromLTRB(7, 4, 7, 3),
          decoration: const pw.BoxDecoration(
            color: Pal.panel,
            border: pw.Border(left: pw.BorderSide(color: Pal.gold, width: 1.6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              kit.text(
                '${Hi.graha(r.graha)} के लिए',
                style: kit.style_(kit.fonts.semi, 9.4, Pal.maroon),
              ),
              kit.text(why, style: kit.small),
              kit.gap(2),
              for (final String p in parts)
                kit.text(
                  p,
                  style: kit.style(kit.fonts.regular, 9.0, spacing: 1.2),
                ),
            ],
          ),
        ),
      ),
    );
  }
  return out;
}

/// The one line said under any set of remedies.
String remedyStanceHindi() => remedyStance.hi;

List<pw.Widget> basisBlock(
  Kit kit,
  Iterable<Object> basis, {
  bool inline = false,
}) {
  final List<String> items = <String>[
    for (final Object b in basis)
      if (clean(kit, b) != null) hindiOf(b),
  ];
  if (items.isEmpty) return const <pw.Widget>[];
  if (inline) {
    // One run of small print, for places where there are dozens of readings.
    return <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: kit.text('आधार: ${items.join(' · ')}', style: kit.small),
      ),
    ];
  }
  return <pw.Widget>[
    kit.text('आधार', style: kit.style_(kit.fonts.semi, 8.6, Pal.gold)),
    kit.gap(1.5),
    kit.bullets(items),
  ];
}

/// A card for one [Matbhed]: the topic, why the books differ, each position's
/// rule, who holds it, the reason, and what it comes to on this chart.
List<pw.Widget> matbhedCard(Kit kit, Matbhed m, {String? kicker}) {
  const List<String> ordinal = <String>['पहला मत', 'दूसरा मत', 'तीसरा मत'];
  final List<String> all = <String>[
    m.topic.hi,
    m.defaultReason.hi,
    if (m.whyTheyDiffer != null) m.whyTheyDiffer!.hi,
    for (final Mat v in m.views) ...<String>[
      v.position.hi,
      v.holder.hi,
      v.reasoning.hi,
      v.result.hi,
    ],
  ];
  if (all.any(kit.isRefused)) return const <pw.Widget>[];
  return <pw.Widget>[
    pw.NewPage(freeSpace: 150),
    pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 4),
      decoration: const pw.BoxDecoration(
        color: Pal.panel,
        border: pw.Border(left: pw.BorderSide(color: Pal.maroon, width: 2.4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          kit.text(
            '${m.title.hi}${kicker == null ? '' : ' · $kicker'}',
            style: kit.style_(kit.fonts.semi, 8.8, Pal.gold),
          ),
          kit.text(
            m.topic.hi,
            style: kit.style(
              kit.fonts.semi,
              11.6,
              color: Pal.maroon,
              spacing: 1.4,
            ),
          ),
        ],
      ),
    ),
    kit.gap(4),
    if (m.whyTheyDiffer != null) kit.para(m.whyTheyDiffer!.hi),
    kit.table(
      headers: <String>['मत', 'मान्यता', 'इस कुंडली पर'],
      rows: <List<String>>[
        for (int i = 0; i < m.views.length; i++)
          <String>[
            '${ordinal[i]}${m.views[i].isDefault ? '\n(ऐप इसी से गिनता है)' : ''}',
            m.views[i].position.hi,
            m.views[i].result.hi,
          ],
      ],
      widths: <double>[1.4, 3.3, 3],
      size: 8.8,
      highlightRows: <int>{
        for (int i = 0; i < m.views.length; i++)
          if (m.views[i].isDefault) i,
      },
    ),
    kit.gap(4),
    for (int i = 0; i < m.views.length; i++)
      kit.labelled(
        '${ordinal[i]} किसका है, और उसका तर्क',
        '${m.views[i].holder.hi}। ${m.views[i].reasoning.hi}',
      ),
    kit.labelled('ऐप यही क्यों लेता है', m.defaultReason.hi),
    kit.gap(6),
  ];
}
