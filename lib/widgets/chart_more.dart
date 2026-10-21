import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'feature_tile.dart';
import 'glyphs.dart';

/// Everything else this chart can be read through, reachable from the chart
/// itself.
///
/// Before this, the readings lived only on the home screen, so looking at
/// somebody's chart and wanting the phaladesh meant going back out, finding
/// the tile, and hoping it opened the same chart. The ones that can take a
/// chart are given this one by id; the rest are day or question readings that
/// do not belong to a chart at all, and are grouped apart so that is obvious.
class ChartMore extends StatelessWidget {
  const ChartMore({super.key, required this.profileId});

  /// The chart being looked at, passed on as `?profile=` so these open for
  /// the same person rather than for the saved default.
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi = Localizations.localeOf(context).languageCode == 'hi';

    final List<_Entry> ofThisChart = <_Entry>[
      _Entry(
        KGlyph.phaladesh,
        l.featurePhaladesh,
        '/phaladesh',
        hindi ? 'दशा के साथ पूरा जीवन फलादेश' : 'The dated life timeline',
      ),
      _Entry(
        KGlyph.strengths,
        l.featureStrengths,
        '/strengths',
        hindi ? 'षड्बल और अष्टकवर्ग' : 'Shadbala and ashtakavarga',
      ),
      _Entry(
        KGlyph.transits,
        l.featureTransits,
        '/transits',
        hindi ? 'आज के गोचर, इस कुंडली पर' : "Today's transits on this chart",
      ),
      _Entry(
        KGlyph.sudarshan,
        l.featureSudarshan,
        '/sudarshan',
        hindi
            ? 'लग्न, चंद्र और सूर्य से एक साथ'
            : 'From Lagna, Moon and Sun at once',
      ),
      _Entry(
        KGlyph.ghatChakra,
        l.featureGhatChakra,
        '/ghat-chakra',
        hindi ? 'शुरुआत के लिए टालने योग्य दिन' : 'Days to avoid beginning on',
      ),
      _Entry(
        KGlyph.sarvatobhadra,
        l.featureSarvatobhadra,
        '/sarvatobhadra',
        hindi
            ? 'नक्षत्र और नाम पर गोचर वेध'
            : 'Transit vedha on your nakshatra',
      ),
    ];

    // These read a day, a question or two charts, so a single chart's id
    // would mean nothing to them.
    final List<_Entry> other = <_Entry>[
      _Entry(
        KGlyph.varshphal,
        l.featureVarshphal,
        '/varshphal',
        hindi ? 'इस वर्ष का फल' : 'The year ahead',
      ),
      _Entry(
        KGlyph.remedies,
        l.featureRemedies,
        '/remedies',
        hindi ? 'ग्रहों के उपाय' : 'Remedies for the grahas',
      ),
      _Entry(
        KGlyph.rashifal,
        l.featureRashifal,
        '/today',
        hindi ? 'आज का दिन' : 'The day read for you',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Heading(hindi ? 'इसी कुंडली से' : 'From this chart'),
        ...ofThisChart.map((_Entry e) => _Tile(entry: e, profileId: profileId)),
        const SizedBox(height: 18),
        _Heading(hindi ? 'और भी' : 'More readings'),
        ...other.map((_Entry e) => _Tile(entry: e, profileId: null)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Entry {
  const _Entry(this.glyph, this.label, this.route, this.subtitle);

  final KGlyph glyph;
  final String label;
  final String route;
  final String subtitle;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
    child: SectionLabel(text),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entry, required this.profileId});

  final _Entry entry;

  /// Null for the readings that do not belong to one chart.
  final String? profileId;

  @override
  Widget build(BuildContext context) {
    final KundliTones tones = KundliTones.of(context);
    final String to = profileId == null
        ? entry.route
        : '${entry.route}?profile=${Uri.encodeQueryComponent(profileId!)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tones.plate,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: KIcon(entry.glyph, size: 26),
        ),
        title: Text(
          entry.label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(entry.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(to),
      ),
    );
  }
}
