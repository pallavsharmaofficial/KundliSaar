import 'package:flutter/material.dart';

import '../engine/jyotish/yogas.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';

/// The yogas and doshas a chart carries, grouped by shelf, each in a panel
/// that names the rule that fired, what it governs, what cancels it or what the
/// tradition asks of the person, and (folded away) the exact chart factors and
/// the source it comes from.
class YogaFindingsList extends StatelessWidget {
  const YogaFindingsList({
    super.key,
    required this.findings,
    required this.hindi,
  });

  final List<YogaFinding> findings;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> children = <Widget>[];
    for (final YogaFamily family in YogaFamily.values) {
      final List<YogaFinding> inFamily = findings
          .where((YogaFinding f) => f.family == family)
          .toList(growable: false);
      if (inFamily.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text(
            '${hindi ? family.hindi : family.english} · ${inFamily.length}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
      children.addAll(
        inFamily.map(
          (YogaFinding f) => YogaFindingPanel(finding: f, hindi: hindi),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class YogaFindingPanel extends StatelessWidget {
  const YogaFindingPanel({
    super.key,
    required this.finding,
    required this.hindi,
  });

  final YogaFinding finding;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final YogaFinding f = finding;
    final List<String> factors = hindi ? f.factorsHindi : f.factorsEnglish;
    final String? source = hindi ? f.sourceHindi : f.sourceEnglish;
    return Panel(
      title: hindi ? f.nameHindi : f.nameEnglish,
      trailing: Icon(
        f.isDosha ? Icons.shield_outlined : Icons.star_outline,
        size: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Labelled(l.whyThis, hindi ? f.ruleHindi : f.ruleEnglish),
          _Labelled(l.whatItMeans, hindi ? f.meaningHindi : f.meaningEnglish),
          if (f.isCancelled)
            _Labelled(
              l.cancelledBy,
              hindi ? f.cancellationHindi! : f.cancellationEnglish!,
            ),
          if (f.mitigationEnglish != null)
            _Labelled(
              hindi ? 'यह आपसे क्या माँगता है' : 'What it asks of you',
              hindi ? f.mitigationHindi! : f.mitigationEnglish!,
            ),
          if (factors.isNotEmpty || source != null)
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                dense: true,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  hindi
                      ? 'कुंडली के कारक और स्रोत'
                      : 'The chart factors and the source',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                children: <Widget>[
                  for (final String factor in factors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(top: 6, right: 8),
                            child: Icon(Icons.circle, size: 5),
                          ),
                          Expanded(
                            child: Text(
                              factor,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (source != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      source,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        height: 1.45,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled(this.label, this.text);

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13.5,
              letterSpacing: 0.3,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
