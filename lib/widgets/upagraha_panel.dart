import 'package:flutter/material.dart';

import '../engine/astro/angles.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/rashi.dart';
import '../engine/jyotish/upagrahas.dart';
import 'common.dart';

/// The eleven upagrahas under the grahas on the planetary-positions screen:
/// each its sign, degree and house, and, folded away, how its longitude is
/// found and what the tradition reads from it.
class UpagrahaSection extends StatelessWidget {
  const UpagrahaSection({super.key, required this.kundli, required this.hindi});

  final Kundli kundli;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UpagrahaResult result = computeUpagrahas(kundli);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
          child: Text(
            hindi ? 'उपग्रह' : 'Upagrahas',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            hindi
                ? 'सूर्य से और दिन-रात के आठ भागों से निकाले गए सूक्ष्म बिंदु। इन्हें केवल अपने भाव पर हल्की छाया की तरह पढ़ा जाता है।'
                : 'Minor points found from the Sun and from the eight parts of the day and night. They are read only as a faint overlay on the house they fall in.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        for (final PlacedUpagraha p in result.placed)
          _UpagrahaCard(placed: p, hindi: hindi),
        DisclaimerNote(
          hindi
              ? 'गुलिक शनि के भाग के आरंभ पर, मांदि उसके अंत पर, और काल, मृत्यु, अर्धप्रहर व यमघंटक अपने भाग के मध्य पर लिए गए हैं; पाठ-भेद की स्थिति में यही चुनाव किया गया है। जन्म ${result.isDayBirth ? 'दिन' : 'रात'} का है, इसलिए ${result.isDayBirth ? 'दिन' : 'रात'} को आठ भागों में बाँटा गया।'
              : 'Gulika is taken at the beginning of Saturn’s part, Mandi at its end, and Kaala, Mrityu, Ardha Prahara and Yama Ghantaka at the middle of theirs; the schools differ, and this is the choice made. The birth falls by ${result.isDayBirth ? 'day' : 'night'}, so the ${result.isDayBirth ? 'day' : 'night'} was divided into eight.',
        ),
      ],
    );
  }
}

class _UpagrahaCard extends StatelessWidget {
  const _UpagrahaCard({required this.placed, required this.hindi});

  final PlacedUpagraha placed;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UpagrahaInfo info = placed.info;
    final RashiInfo sign = rashiInfo(placed.rashi);
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Row(
          children: <Widget>[
            Expanded(
              flex: 4,
              child: Text(
                hindi ? info.hindi : info.english,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Expanded(
              flex: 6,
              child: Text(
                '${hindi ? sign.hindi : sign.english}  ${formatDegrees(placed.degreesInSign)}',
              ),
            ),
            Text(
              hindi ? '${placed.house}वाँ भाव' : 'House ${placed.house}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
            ),
          ],
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: <Widget>[
                FactRow(
                  hindi ? 'नक्षत्र' : 'Nakshatra',
                  hindi ? placed.nakshatra.hindi : placed.nakshatra.english,
                ),
                if (placed.partNumber != null)
                  FactRow(
                    hindi ? 'किस भाग से' : 'Taken from',
                    hindi
                        ? '${placed.partNumber}वाँ भाग, ${grahaInfo(placed.partLord!).hindi} का'
                        : 'Part ${placed.partNumber}, ruled by ${grahaInfo(placed.partLord!).english}',
                  ),
                FactRow(
                  hindi ? 'गणना' : 'How it is found',
                  hindi ? info.formulaHindi : info.formulaEnglish,
                ),
                FactRow(
                  hindi ? 'पाठ' : 'How it is read',
                  hindi ? info.readingHindi : info.readingEnglish,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
