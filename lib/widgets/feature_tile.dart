import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';
import 'glyphs.dart';

/// One reading on the home screen: its own icon on a marigold plate over a
/// raised card, and its name beneath.
///
/// The card is the theme's, so it casts the same soft shadow as a [Panel];
/// the plate is what gives the grid its colour, so the icons can stay one
/// quiet weight and one quiet colour.
class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
    this.width,
  });

  final KGlyph glyph;
  final String label;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final KundliTones tones = KundliTones.of(context);
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tones.plate,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: KIcon(glyph, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A section's name on the home screen, set in the accent's text colour with
/// the chart's diamond before it and a rule after, so a section reads as a
/// chapter and not as more small print.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final KundliTones tones = KundliTones.of(context);
    // The name is capped rather than made flexible: two flexible children
    // would split the free space between them, and the rule would stop
    // halfway across the screen instead of running to the edge.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => Row(
          children: <Widget>[
            DiamondMark(color: tones.accent, size: 8),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.78),
              child: Text(
                text,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: tones.accentText,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
