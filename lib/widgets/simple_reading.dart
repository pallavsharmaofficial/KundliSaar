import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ask/answer_model.dart';
import '../ask/ask_context.dart';
import '../ask/ask_short.dart';
import '../ask/ask_story.dart';
import '../ask/ask_topics.dart';
import '../engine/jyotish/chart.dart';
import 'common.dart';

/// The kundli for the person it belongs to, not for the astrologer: who you
/// are, how your time is now and when it eases, the four parts of life people
/// ask about, and the two worries everyone has heard of. Every line is the
/// plain answer the Ask screen gives first, so the two never disagree, and no
/// line needs the word dasha to be understood.
class SimpleReading extends StatelessWidget {
  const SimpleReading({
    super.key,
    required this.kundli,
    required this.profileId,
    required this.hindi,
  });

  final Kundli kundli;
  final String profileId;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final AskCtx c = AskCtx(kundli, DateTime.now(), hindi);
    String t(String en, String hi) => hindi ? hi : en;

    List<String> plain(Answer a) => a.short?.paragraphs ?? const <String>[];

    final List<String> you = <String>[
      ...plain(lagnaAnswer(c)).take(2),
      ...plain(moonAnswer(c)),
    ];
    final List<String> now = plain(composeStory(c, titleEn: '', titleHi: ''));
    final List<(IconData, Topic)> topics = <(IconData, Topic)>[
      (Icons.work_outline, careerTopic),
      (Icons.favorite_border, marriageTopic),
      (Icons.account_balance_wallet_outlined, moneyTopic),
      (Icons.school_outlined, educationTopic),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (now.isNotEmpty)
          _PlainPanel(
            icon: Icons.wb_sunny_outlined,
            title: t('How your time is now', 'अभी आपका समय कैसा है'),
            lines: now,
            highlight: true,
          ),
        if (you.isNotEmpty)
          _PlainPanel(
            icon: Icons.person_outline,
            title: t('What you are like', 'आप कैसे हैं'),
            lines: you,
          ),
        Panel(
          title: t('Parts of your life', 'ज़िंदगी के हिस्से'),
          child: Column(
            children: <Widget>[
              for (final (IconData icon, Topic topic) in topics)
                _TopicTile(
                  icon: icon,
                  title: t(topic.titleEn, topic.titleHi),
                  lines: plain(
                    composeStory(
                      c,
                      topic: topic,
                      titleEn: topic.titleEn,
                      titleHi: topic.titleHi,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _PlainPanel(
          icon: Icons.brightness_3_outlined,
          title: t('Sade Sati', 'साढ़े साती'),
          lines: plain(sadeSatiAnswer(c)),
        ),
        _PlainPanel(
          icon: Icons.local_fire_department_outlined,
          title: t('Mangal dosha', 'मंगल दोष'),
          lines: plain(mangalAnswer(c)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: OutlinedButton.icon(
            key: const ValueKey<String>('simple-ask'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(
              t(
                'Ask anything else about your kundli',
                'कुंडली से जुड़ा कोई भी सवाल पूछिए',
              ),
            ),
            onPressed: () => context.push('/chart/$profileId/ask'),
          ),
        ),
      ],
    );
  }
}

class _PlainPanel extends StatelessWidget {
  const _PlainPanel({
    required this.icon,
    required this.title,
    required this.lines,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Panel(
      title: title,
      trailing: Icon(icon, color: theme.colorScheme.primary),
      child: _Lines(lines: lines, large: highlight),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(
        lines.first,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      children: <Widget>[_Lines(lines: lines)],
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.lines, this.large = false});

  final List<String> lines;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style =
        (large ? theme.textTheme.bodyLarge : theme.textTheme.bodyMedium)
            ?.copyWith(height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < lines.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 9, right: 10),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(child: Text(lines[i], style: style)),
              ],
            ),
          ),
      ],
    );
  }
}
