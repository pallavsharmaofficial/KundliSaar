import 'package:flutter/material.dart';

import '../engine/jyotish/mat.dart';
import '../engine/jyotish/tajika_common.dart' show Bi;

/// "दो मत" / "Two views": a disagreement between classical texts, shown with
/// every position, who holds it, the reason they give and what the chart comes
/// to under it. The computed results sit side by side so the difference can be
/// read at a glance; the longer argument of each view follows. The position the
/// app computes by default is marked, with the reason it was chosen.
class MatbhedCard extends StatelessWidget {
  const MatbhedCard({super.key, required this.matbhed, required this.hindi});

  final Matbhed matbhed;
  final bool hindi;

  static const List<Bi> _ordinal = <Bi>[
    Bi('First view', 'पहला मत'),
    Bi('Second view', 'दूसरा मत'),
    Bi('Third view', 'तीसरा मत'),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Matbhed m = matbhed;
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Card(
      key: ValueKey<String>('matbhed-${m.key}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Icon(
                    Icons.balance_outlined,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        m.title.of(hindi),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          letterSpacing: 0.3,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        m.topic.of(hindi),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (m.whyTheyDiffer != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                m.whyTheyDiffer!.of(hindi),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final bool wide = box.maxWidth >= 560;
                final bool sideBySide = wide || m.views.length == 2;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _label(
                      theme,
                      hindi ? 'गणना, साथ-साथ' : 'The sums, side by side',
                    ),
                    const SizedBox(height: 6),
                    _sideBySide(
                      sideBySide: sideBySide,
                      children: <Widget>[
                        for (int i = 0; i < m.views.length; i++)
                          _ResultTile(
                            view: m.views[i],
                            heading: _ordinal[i].of(hindi),
                            hindi: hindi,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _sideBySide(
                      sideBySide: wide,
                      children: <Widget>[
                        for (int i = 0; i < m.views.length; i++)
                          _ViewDetail(
                            view: m.views[i],
                            heading: _ordinal[i].of(hindi),
                            hindi: hindi,
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            _label(
              theme,
              hindi ? 'ऐप यही क्यों लेता है' : 'Why the app uses it',
            ),
            const SizedBox(height: 2),
            Text(m.defaultReason.of(hindi), style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Text(
    text,
    style: theme.textTheme.bodySmall?.copyWith(
      fontSize: 13.5,
      letterSpacing: 0.3,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    ),
  );

  /// Lays the children in a row of equal columns, or one above the other.
  Widget _sideBySide({
    required bool sideBySide,
    required List<Widget> children,
  }) {
    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// The computed result of one view, in a tile that can sit beside another.
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.view,
    required this.heading,
    required this.hindi,
  });

  final Mat view;
  final String heading;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: view.isDefault
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: view.isDefault
              ? scheme.primary.withValues(alpha: 0.6)
              : scheme.onSurface.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            heading,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (view.isDefault)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hindi ? 'ऐप इसी से गिनता है' : 'App computes this',
                key: const ValueKey<String>('matbhed-default'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(view.result.of(hindi), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Who holds a view, the rule as they state it, and the reason they give.
class _ViewDetail extends StatelessWidget {
  const _ViewDetail({
    required this.view,
    required this.heading,
    required this.hindi,
  });

  final Mat view;
  final String heading;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Widget line(String label, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          heading,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 4),
        line(hindi ? 'किसका मत' : 'Held by', view.holder.of(hindi)),
        line(hindi ? 'नियम' : 'The rule', view.position.of(hindi)),
        line(hindi ? 'उनका तर्क' : 'Their reasoning', view.reasoning.of(hindi)),
      ],
    );
  }
}

/// The disagreements for one screen, each as a card, under a short heading
/// that says why they are there.
class MatbhedList extends StatelessWidget {
  const MatbhedList({
    super.key,
    required this.items,
    required this.hindi,
    this.leftOut = const <LeftOut>[],
    this.withHeading = false,
  });

  final List<Matbhed> items;
  final List<LeftOut> leftOut;
  final bool hindi;

  /// Puts "Where the books differ" and a line of explanation above the cards.
  final bool withHeading;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && leftOut.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (withHeading) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
            child: Text(
              hindi ? 'जहाँ ग्रंथों में मतभेद है' : 'Where the books differ',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              hindi
                  ? 'यहाँ ग्रंथ एक राय नहीं रखते, इसलिए हर मत अपने तर्क और इस कुंडली पर अपनी गणना के साथ दिया है। ऐप जिससे गिनता है वह चिह्नित है।'
                  : 'The books do not agree here, so each view is given with its reasoning and its working on this chart. The one the app counts by is marked.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                height: 1.5,
                color: muted,
              ),
            ),
          ),
        ],
        for (final Matbhed m in items) MatbhedCard(matbhed: m, hindi: hindi),
        for (final LeftOut l in leftOut)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              '${l.name.of(hindi)}: ${l.reason.of(hindi)}',
              key: ValueKey<String>('leftout-${l.key}'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                height: 1.5,
                color: muted,
              ),
            ),
          ),
      ],
    );
  }
}
