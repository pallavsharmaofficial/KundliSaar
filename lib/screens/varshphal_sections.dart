import 'package:flutter/material.dart';

import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/saham.dart';
import '../engine/jyotish/tajika_aspects.dart';
import '../engine/jyotish/tajika_bala.dart';
import '../engine/jyotish/tajika_common.dart';
import '../engine/jyotish/varshphal.dart';
import '../engine/jyotish/varshphal_dasha.dart';
import '../engine/jyotish/varshphal_months.dart';
import '../widgets/common.dart';

/// The sections of the varshphal screen that read the year the Tajika way.
/// Each takes the computed [Varshphal] and the language and draws with the
/// app's own Panel, FactRow and ToranaHeader.

String _name(Graha graha, bool hindi) =>
    hindi ? grahaInfo(graha).hindi : grahaInfo(graha).english;

String _range(DateTime a, DateTime b, bool hindi) =>
    '${dateBi(a).of(hindi)} – ${dateBi(b).of(hindi)}';

/// "Why this": the chart factors a reading was built from.
class _WhyThis extends StatelessWidget {
  const _WhyThis({required this.factors, required this.hindi});

  final List<Bi> factors;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        dense: true,
        title: Text(
          hindi ? 'यह क्यों' : 'Why this',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        children: <Widget>[
          for (final Bi factor in factors)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('· ', style: theme.textTheme.bodySmall),
                  Expanded(
                    child: Text(
                      factor.of(hindi),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

TextStyle? _small(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(fontSize: 13.5, height: 1.4);

// ---------------------------------------------------------------------------
// The lord of the year and its working.
// ---------------------------------------------------------------------------

class YearLordSection extends StatelessWidget {
  const YearLordSection({
    super.key,
    required this.varshphal,
    required this.hindi,
    required this.title,
  });

  final Varshphal varshphal;
  final bool hindi;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VarsheshResult result = varshphal.varshesh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ToranaHeader(
          title: title,
          subtitle: hindi
              ? 'पाँच अधिकारियों में से, लग्न को देखने वाला और पंचवर्गीय बल में सबसे आगे।'
              : 'Chosen from the five office-bearers: the one that aspects the Lagna and leads in five-fold strength.',
        ),
        Panel(
          title: _name(result.lord, hindi),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(result.reading.of(hindi)),
              _WhyThis(factors: result.factors, hindi: hindi),
            ],
          ),
        ),
        Panel(
          title: hindi ? 'पाँच अधिकारी' : 'The five office-bearers',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final VarshaOfficer o in result.officers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 4,
                        child: Text(
                          o.officeName.of(hindi),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${_name(o.graha, hindi)} · '
                              '${compactNumber(o.vishwa)} ${hindi ? 'विश्वा' : 'vishwa'}',
                              style: o.graha == result.lord
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.bodyMedium,
                            ),
                            Text(
                              o.aspectsLagna
                                  ? (hindi
                                        ? 'लग्न को देखता है · ${signAspectBi(o.aspectToLagna!).hi}'
                                        : 'aspects the Lagna · ${signAspectBi(o.aspectToLagna!).en}')
                                  : (hindi
                                        ? 'लग्न को नहीं देखता'
                                        : 'does not aspect the Lagna'),
                              style: _small(context),
                            ),
                            Text(o.basis.of(hindi), style: _small(context)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Panel(
          title: hindi
              ? 'पंचवर्गीय बल (विश्वा)'
              : 'Five-fold strength (vishwa)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                hindi
                    ? 'गृह 30, उच्च 20, हद्दा 15, द्रेष्काण 10, नवांश 5: कुल 80, चार से भाग देने पर 20 विश्वा।'
                    : 'Griha 30, uchcha 20, hadda 15, drekkana 10, navamsha 5: eighty in all, quartered to twenty vishwa.',
                style: _small(context),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _BalaTable(varshphal: varshphal, hindi: hindi),
              ),
              const SizedBox(height: 6),
              Text(
                hindi
                    ? 'विश्वा: 5 से कम निर्बल, 5 से 10 दुर्बल, 10 से 15 मध्यम, 15 से ऊपर उत्तम (हायनरत्न 2.5)।'
                    : 'Vishwa: under 5 powerless, 5 to 10 weak, 10 to 15 middling, above 15 excellent (Hayanaratna 2.5).',
                style: _small(context),
              ),
              _WhyThis(
                hindi: hindi,
                factors: <Bi>[
                  const Bi(
                    'Each division gives a graha its full weight when the graha is the lord of the sign, hadda, decan or navamsha it stands in, three quarters when that lord is its friend, half when neutral and a quarter when an enemy.',
                    'हर विभाजन में ग्रह को पूरा भार तब मिलता है जब वह जिस राशि, हद्दे, द्रेष्काण या नवांश में है उसका स्वामी वह स्वयं हो; स्वामी मित्र हो तो तीन चौथाई, सम हो तो आधा, शत्रु हो तो चौथाई।',
                  ),
                  const Bi(
                    'Friendship is the Tajika positional one: the lord’s sign is a friend if it is the 3rd, 5th, 9th or 11th from the graha’s own, neutral if the 2nd, 6th, 8th or 12th, an enemy if the 1st, 4th, 7th or 10th.',
                    'मित्रता ताजिक स्थानिक है: स्वामी की राशि ग्रह की राशि से 3, 5, 9, 11वीं हो तो मित्र, 2, 6, 8, 12वीं हो तो सम, 1, 4, 7, 10वीं हो तो शत्रु।',
                  ),
                  const Bi(
                    'Uchcha is the arc from the graha’s deepest fall, out of 20. The hadda is the Tajika term table and the drekkana the Tajika decan (Mars, Sun, Venus, Mercury, Moon, Saturn, Jupiter in turn from Mesha).',
                    'उच्च बल ग्रह के परम नीच बिंदु से चाप है, 20 में। हद्दा ताजिक हद्दा सारणी है और द्रेष्काण ताजिक द्रेष्काण (मेष से मंगल, सूर्य, शुक्र, बुध, चंद्र, शनि, गुरु क्रम से)।',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalaTable extends StatelessWidget {
  const _BalaTable({required this.varshphal, required this.hindi});

  final Varshphal varshphal;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Set<Graha> officers = varshphal.varshesh.officers
        .map((VarshaOfficer o) => o.graha)
        .toSet();
    TextStyle? head = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    Widget cell(String text, {TextStyle? style, double width = 46}) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: style ?? theme.textTheme.bodySmall?.copyWith(fontSize: 13),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 70,
              child: Text(hindi ? 'ग्रह' : 'Graha', style: head),
            ),
            cell(hindi ? 'गृह' : 'Griha', style: head),
            cell(hindi ? 'उच्च' : 'Uchcha', style: head),
            cell(hindi ? 'हद्दा' : 'Hadda', style: head),
            cell(hindi ? 'द्रे.' : 'Drek.', style: head),
            cell(hindi ? 'नवां.' : 'Nav.', style: head),
            cell(hindi ? 'कुल' : 'Total', style: head, width: 50),
            cell(hindi ? 'विश्वा' : 'Vishwa', style: head, width: 56),
          ],
        ),
        const Divider(height: 1),
        for (final Graha graha in tajikaGrahas)
          Builder(
            builder: (BuildContext context) {
              final PanchaVargiyaBala b = varshphal.bala[graha]!;
              final bool isLord = graha == varshphal.varshesh.lord;
              final TextStyle? strong = theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isLord ? theme.colorScheme.primary : null,
              );
              return Row(
                children: <Widget>[
                  SizedBox(
                    width: 70,
                    child: Text(
                      _name(graha, hindi) +
                          (officers.contains(graha) ? ' ◆' : ''),
                      style: isLord
                          ? strong
                          : theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                    ),
                  ),
                  for (final PvComponent c in b.components)
                    cell(compactNumber(c.points, decimals: 2)),
                  cell(compactNumber(b.total, decimals: 2), width: 50),
                  cell(
                    compactNumber(b.vishwa, decimals: 2),
                    style: strong,
                    width: 56,
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 4),
        Text(
          hindi
              ? '◆ पाँच अधिकारियों में से'
              : '◆ one of the five office-bearers',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Month by month.
// ---------------------------------------------------------------------------

class YearTimelineSection extends StatelessWidget {
  const YearTimelineSection({
    super.key,
    required this.varshphal,
    required this.hindi,
  });

  final Varshphal varshphal;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ToranaHeader(
          title: hindi ? 'महीने दर महीने' : 'Month by month',
          subtitle: hindi
              ? 'वर्ष के दिनांकित खंड, हर मुद्दा दशा के लिए एक। हर खंड में उसकी ताजिक दृष्टियाँ और सहम।'
              : 'The year in dated stretches, one for each Mudda dasha period, with the Tajika aspects and sahams that belong to it.',
        ),
        for (final YearWindow w in varshphal.windows)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _range(w.startLocal, w.endLocal, hindi),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _name(w.lord, hindi),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hindi
                      ? '${compactNumber(w.days)} दिन · ${w.title.hi}'
                      : '${compactNumber(w.days)} days · ${w.title.en}',
                  style: _small(context),
                ),
                const SizedBox(height: 10),
                Text(w.reading.of(hindi)),
                if (w.events.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  for (final WindowEvent e in w.events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.event_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.text.of(hindi),
                              style: _small(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                _WhyThis(factors: w.factors, hindi: hindi),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mudda and Patyayini dashas.
// ---------------------------------------------------------------------------

class DashaSection extends StatelessWidget {
  const DashaSection({super.key, required this.varshphal, required this.hindi});

  final Varshphal varshphal;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Duration offset = varshphal.chart.birth.utcOffset;
    DateTime local(double jd) => localOf(jd, offset);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ToranaHeader(
          title: hindi ? 'मुद्दा दशा' : 'Mudda dasha',
          subtitle: hindi
              ? 'विंशोत्तरी का क्रम, 120 वर्ष इस वर्ष की लंबाई में समेटे हुए।'
              : 'The Vimshottari order with its 120 years compressed into the length of this year.',
        ),
        Panel(
          child: _WhyThis(factors: varshphal.mudda.factors, hindi: hindi),
        ),
        for (final MuddaPeriod p in varshphal.mudda.periods)
          Card(
            child: ExpansionTile(
              shape: const Border(),
              title: Text(
                _name(p.lord, hindi),
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                '${compactNumber(p.days)} ${hindi ? 'दिन' : 'days'} · '
                '${_range(local(p.startJd), local(p.endJd), hindi)}'
                '${p.isBalance ? (hindi ? ' · शेष भाग' : ' · what remains') : (p.isCarryOver ? (hindi ? ' · फिर से' : ' · comes round again') : '')}',
                style: _small(context),
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hindi ? 'अंतर्दशा' : 'Antardashas',
                        style: _small(
                          context,
                        )?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      for (final MuddaSub s in p.subPeriods)
                        FactRow(
                          _name(s.lord, hindi),
                          _range(local(s.startJd), local(s.endJd), hindi),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ToranaHeader(
          title: hindi ? 'पात्यायिनी दशा' : 'Patyayini dasha',
          subtitle: hindi
              ? 'सात ग्रह और लग्न अपनी राशि के भीतर के अंशों के क्रम में; वर्ष अंशों के अंतर के अनुपात में बँटता है।'
              : 'The seven grahas and the lagna by their degrees within their signs; the year is shared in proportion to the gaps between them.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final PatyayiniPeriod p in varshphal.patyayini.periods)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              p.name.of(hindi),
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            '${compactNumber(p.days)} ${hindi ? 'दिन' : 'days'}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Text(
                        _range(local(p.startJd), local(p.endJd), hindi),
                        style: _small(context),
                      ),
                      Text(p.reading.of(hindi), style: _small(context)),
                    ],
                  ),
                ),
              _WhyThis(factors: varshphal.patyayini.factors, hindi: hindi),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tajika aspects and yogas.
// ---------------------------------------------------------------------------

class TajikaSection extends StatelessWidget {
  const TajikaSection({
    super.key,
    required this.varshphal,
    required this.hindi,
  });

  final Varshphal varshphal;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TajikaReport report = varshphal.tajika;
    final Duration offset = varshphal.chart.birth.utcOffset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ToranaHeader(
          title: hindi ? 'ताजिक दृष्टि' : 'Tajika aspects',
          subtitle: hindi
              ? 'इत्थशाल (समीप आती) और ईसराफ (दूर जाती) दृष्टियाँ दीप्तांश के भीतर, तथा उनसे बनने वाले योग।'
              : 'Applying (Ittasala) and separating (Ishrafa) aspects within orb, and the yogas built on them.',
        ),
        Panel(
          title: hindi ? 'दीप्तांश' : 'Deeptamsha (orbs)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: <Widget>[
                  for (final Graha g in tajikaGrahas)
                    Text(
                      '${_name(g, hindi)} ${compactNumber(deeptamsha[g]!, decimals: 0)}°',
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                hindi
                    ? 'दो ग्रहों की साझा सीमा उनके दीप्तांशों के योग का आधा है। दृष्टि तभी जब राशियाँ युति, 3, 4, 5, 7, 9, 10, 11 में हों; अंश राशि के भीतर गिने जाते हैं।'
                    : 'A pair shares half the sum of its two orbs. There is an aspect only if the signs are in conjunction or the 3rd, 4th, 5th, 7th, 9th, 10th or 11th from each other; degrees are counted within the sign.',
                style: _small(context),
              ),
            ],
          ),
        ),
        if (report.chartYogas.isNotEmpty)
          for (final TajikaYoga y in report.chartYogas)
            Panel(
              title: y.name.of(hindi),
              child: _YogaBody(yoga: y, hindi: hindi),
            ),
        ToranaHeader(
          title: hindi ? 'ग्रहों के बीच' : 'Between the grahas',
          subtitle: hindi
              ? 'सबसे निकट पहले। जिस तारीख को योग पूरा होता है वह ग्रहों की वास्तविक गति से निकाली गई है।'
              : 'Closest first. The date an aspect becomes exact comes from the grahas’ real motion.',
        ),
        if (report.aspects.isEmpty)
          Panel(
            child: Text(
              hindi
                  ? 'इस वर्ष कुंडली में कोई जोड़ी दीप्तांश के भीतर नहीं।'
                  : 'No pair of grahas is inside its orb in this year chart.',
            ),
          ),
        for (final TajikaAspect a in report.aspects)
          Card(
            child: ExpansionTile(
              shape: const Border(),
              title: Text(
                '${_name(a.faster, hindi)} · ${_name(a.slower, hindi)}',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    a.isApplying
                        ? (hindi ? 'इत्थशाल · समीप आता' : 'Ittasala · applying')
                        : (hindi ? 'ईसराफ · दूर जाता' : 'Ishrafa · separating'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: a.isApplying
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hindi
                        ? '${degText(a.gap)} का अंतर · सीमा ${compactNumber(a.orb)}° · ${signAspectBi(a.signAspect).hi}'
                        : '${degText(a.gap)} apart · orb ${compactNumber(a.orb)}° · ${signAspectBi(a.signAspect).en}',
                    style: _small(context),
                  ),
                ],
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(a.reading.of(hindi)),
                      if (a.event != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.event_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _eventLine(a, offset, hindi),
                                style: _small(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                      _WhyThis(factors: a.factors, hindi: hindi),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ToranaHeader(
          title: hindi ? 'विषय और योग' : 'Matters and yogas',
          subtitle: hindi
              ? 'लग्नेश और हर भाव के स्वामी का जोड़ा: योग वही बनते हैं जो उनके बीच की शर्तें पूरी करें।'
              : 'The lagna lord with the lord of each house: a yoga is named only where its condition is met.',
        ),
        for (final TajikaMatter m in report.matters)
          Card(
            child: ExpansionTile(
              shape: const Border(),
              title: Text(
                '${houseBi(m.house).of(hindi)} · ${m.theme.of(hindi)}',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                m.yogas.isEmpty
                    ? (hindi ? 'कोई योग नहीं' : 'no yoga')
                    : m.yogas
                          .map((TajikaYoga y) => y.name.of(hindi))
                          .join(', '),
                style: _small(context),
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hindi
                            ? 'लग्नेश ${_name(m.lagnesha, hindi)}, ${houseBi(m.house).hi} का स्वामी ${_name(m.karyesha, hindi)}।'
                            : 'Lagna lord ${_name(m.lagnesha, hindi)}; lord of ${houseBi(m.house).en}: ${_name(m.karyesha, hindi)}.',
                        style: _small(context),
                      ),
                      if (m.lagnesha == m.karyesha)
                        Text(
                          hindi
                              ? 'दोनों एक ही ग्रह हैं, इसलिए जोड़ा नहीं बनता।'
                              : 'It is one graha holding both, so there is no pair to read.',
                          style: _small(context),
                        ),
                      for (final TajikaYoga y in m.yogas) ...<Widget>[
                        const SizedBox(height: 8),
                        _YogaBody(yoga: y, hindi: hindi, showName: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        DisclaimerNote(
          hindi
              ? 'सोलह ताजिक योगों में से बारह यहाँ गिने गए हैं। गैरी-कम्बूल, ताम्बीर, कुत्थ और दुरुफ नहीं, क्योंकि ग्रंथों की उनकी परिभाषा बिना अनुमान के पूरी नहीं होती।'
              : 'Twelve of the sixteen Tajika yogas are worked out here. Gairi-kamboola, Tambira, Kuttha and Durapha are not, because their definitions in the texts cannot be met without guessing.',
        ),
      ],
    );
  }
}

String _eventLine(TajikaAspect a, Duration offset, bool hindi) {
  final TajikaEvent e = a.event!;
  final Bi when = dateBi(localOf(e.jd, offset));
  switch (e.kind) {
    case TajikaEventKind.perfects:
      return hindi
          ? 'लगभग ${when.hi} को दोनों एक ही अंश पर पहुँचते हैं।'
          : 'Around ${when.en} the two reach the same degree.';
    case TajikaEventKind.leavesOrb:
      return hindi
          ? 'लगभग ${when.hi} को जोड़ी दीप्तांश से बाहर निकल जाती है।'
          : 'Around ${when.en} the pair drifts out of its orb.';
    case TajikaEventKind.signChange:
      return hindi
          ? 'लगभग ${when.hi} को एक ग्रह राशि बदलता है और दृष्टि समाप्त होती है।'
          : 'Around ${when.en} one of them changes sign and the aspect ends.';
  }
}

class _YogaBody extends StatelessWidget {
  const _YogaBody({
    required this.yoga,
    required this.hindi,
    this.showName = false,
  });

  final TajikaYoga yoga;
  final bool hindi;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showName)
          Text(
            yoga.name.of(hindi),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        Text(yoga.indicates.of(hindi)),
        const SizedBox(height: 4),
        Text(
          (hindi ? 'शर्त: ' : 'Condition: ') + yoga.condition.of(hindi),
          style: _small(context),
        ),
        _WhyThis(factors: yoga.factors, hindi: hindi),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sahams.
// ---------------------------------------------------------------------------

class SahamSection extends StatelessWidget {
  const SahamSection({super.key, required this.varshphal, required this.hindi});

  final Varshphal varshphal;
  final bool hindi;

  String _toneWord(SahamTone tone) => switch (tone) {
    SahamTone.supported => hindi ? 'सहारा पाता' : 'supported',
    SahamTone.mixed => hindi ? 'मिला-जुला' : 'mixed',
    SahamTone.strained => hindi ? 'दबाव में' : 'strained',
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Duration offset = varshphal.chart.birth.utcOffset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ToranaHeader(
          title: hindi ? 'सहम' : 'Sahams',
          subtitle: hindi
              ? 'वर्ष कुंडली के संवेदनशील बिंदु। हर बिंदु अपने स्वामी की स्थिति और बल से पढ़ा जाता है।'
              : 'The sensitive points of the year chart. Each is read through the placement and strength of its lord.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                varshphal.isDay
                    ? (hindi
                          ? 'प्रवेश दिन में हुआ, इसलिए सहम दिन के सूत्र से निकाले गए हैं।'
                          : 'The pravesh fell by day, so the sahams use their day formulas.')
                    : (hindi
                          ? 'प्रवेश रात्रि में हुआ, इसलिए सहम रात्रि के सूत्र से निकाले गए हैं।'
                          : 'The pravesh fell by night, so the sahams use their night formulas.'),
              ),
              const SizedBox(height: 6),
              Text(
                hindi
                    ? 'सूत्र A − B + C है: B से A तक का चाप C से आगे। लग्न B से A के चाप में न हो तो एक राशि (30°) और जुड़ती है (हायनरत्न 4.2)।'
                    : 'The formula is A − B + C: the arc from B to A laid off from C. If the lagna is not in the arc from B to A, one sign (30°) is added (Hayanaratna 4.2).',
                style: _small(context),
              ),
            ],
          ),
        ),
        for (final Saham s in varshphal.sahams)
          Card(
            child: ExpansionTile(
              shape: const Border(),
              title: Text(s.name.of(hindi), style: theme.textTheme.titleMedium),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${rashiBi(s.sign).of(hindi)} ${degText(s.degreeInSign)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    hindi
                        ? '${houseBi(s.house).hi} · स्वामी ${_name(s.lord, hindi)}'
                              '${s.tone == null ? '' : ' · ${_toneWord(s.tone!)}'}'
                        : '${houseBi(s.house).en} · lord ${_name(s.lord, hindi)}'
                              '${s.tone == null ? '' : ' · ${_toneWord(s.tone!)}'}',
                    style: _small(context),
                  ),
                ],
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (s.reading != null)
                        Text(s.reading!.of(hindi))
                      else
                        Text(
                          hindi
                              ? 'यह बिंदु परंपरा के सूत्र से निकाला गया है; यह ऐप इसका कोई पठन नहीं करता।'
                              : 'The point is computed as the tradition prescribes; this app makes no reading of it.',
                        ),
                      const SizedBox(height: 8),
                      FactRow(
                        hindi ? 'दिन का सूत्र' : 'Day formula',
                        s.formulaDay.of(hindi),
                        emphasise: s.isDay,
                      ),
                      FactRow(
                        hindi ? 'रात्रि का सूत्र' : 'Night formula',
                        s.formulaNight.of(hindi),
                        emphasise: !s.isDay,
                      ),
                      FactRow(
                        hindi ? 'स्वामी की स्थिति' : 'Lord’s placement',
                        '${_name(s.lord, hindi)} · '
                        '${rashiBi(s.lordPlaced.rashi.index).of(hindi)} · '
                        '${houseBi(s.lordPlaced.house).of(hindi)}',
                      ),
                      if (s.sunFromJd != null && s.sunToJd != null)
                        FactRow(
                          hindi ? 'सूर्य इस राशि में' : 'Sun in this sign',
                          _range(
                            localOf(s.sunFromJd!, offset),
                            localOf(s.sunToJd!, offset),
                            hindi,
                          ),
                        ),
                      if (s.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            s.note!.of(hindi),
                            style: _small(context),
                          ),
                        ),
                      _WhyThis(factors: s.factors, hindi: hindi),
                    ],
                  ),
                ),
              ],
            ),
          ),
        DisclaimerNote(
          hindi
              ? 'मित्र, वाणिज्य, विवाह, संताप, श्रद्धा, प्रीति, व्यापार और बंधु सहम यहाँ नहीं हैं: ग्रंथों और सॉफ़्टवेयर में उनके सूत्र या रात्रि के उलटाव पर मतभेद है। विश्वासघात सहम का सूत्र स्थापित नहीं हो सका।'
              : 'The Mitra, Vanik, Vivaha, Santapa, Shraddha, Preeti, Vyapara and Bandhu sahams are left out: the texts and the software disagree on their formulas or on whether they reverse at night. A formula for the Vishwasghata saham could not be established.',
        ),
      ],
    );
  }
}
