import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ask/ask_context.dart';
import '../ask/ask_story.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/rashifal.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Today, read for one chart rather than for a sun sign.
class RashifalScreen extends StatelessWidget {
  const RashifalScreen({super.key, this.profileId});

  final String? profileId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    return ChartScaffold(
      title: l.featureRashifal,
      profileId: profileId,
      builder: (BuildContext context, Kundli kundli, _) => DeferredBuilder<DailyReading>(
        message: l.computing,
        work: () => dailyReading(kundli, DateTime.now()),
        builder: (BuildContext context, DailyReading reading) {
          final bool hindi =
              context.watch<SettingsCubit>().state.languageCode == 'hi';
          final ThemeData theme = Theme.of(context);
          final (String, String) tip = _dayTips[reading.moonHouse - 1];
          final List<String> period = _periodLines(kundli, hindi);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              ToranaHeader(
                title: l.dailyReading,
                subtitle:
                    '${reading.date.day}/${reading.date.month}/${reading.date.year}',
              ),
              // The verdict, in one line, and what to do with the day.
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          reading.isGoodDay
                              ? Icons.wb_sunny_outlined
                              : Icons.cloud_outlined,
                          size: 34,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            reading.isGoodDay
                                ? (hindi
                                      ? 'आज का दिन आपके साथ है'
                                      : 'Today runs with you')
                                : (hindi
                                      ? 'आज सँभलकर चलने का दिन है'
                                      : 'Today, go carefully'),
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reading.isGoodDay
                          ? (hindi
                                ? 'ज़रूरी बातचीत, नए काम की शुरुआत और लोगों से मिलने-जुलने के लिए अच्छा दिन है।'
                                : 'A good day for important conversations, for starting something new and for meeting people.')
                          : (hindi
                                ? 'दिन सरल रखिए। बड़े फ़ैसले और नई शुरुआत टाल सकें तो टालिए; अधूरे काम पूरे कीजिए।'
                                : 'Keep the day simple. Put off big decisions and new starts if you can; finish what is pending.'),
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              Panel(
                title: hindi ? 'आज के लिए सलाह' : 'For today',
                trailing: Icon(
                  Icons.tips_and_updates_outlined,
                  color: theme.colorScheme.primary,
                ),
                child: Text(
                  hindi ? tip.$2 : tip.$1,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
              Panel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Text(l.luckyNumber, style: theme.textTheme.bodySmall),
                        Text(
                          '${reading.luckyNumber}',
                          style: theme.textTheme.displaySmall,
                        ),
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        Text(l.luckyColour, style: theme.textTheme.bodySmall),
                        Text(
                          hindi
                              ? reading.luckyColourHindi
                              : reading.luckyColour,
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (period.isNotEmpty)
                Panel(
                  title: hindi ? 'इन दिनों आपका समय' : 'Your time these days',
                  child: Text(
                    period.join(' '),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              // The tara, the transits and the dasha, for the shastri.
              Card(
                child: ExpansionTile(
                  key: const ValueKey<String>('today-detail'),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(
                    hindi ? 'शास्त्री जी के लिए' : 'For the astrologer',
                  ),
                  subtitle: Text(
                    hindi
                        ? 'तारा, गोचर और दशा का आधार'
                        : 'The tara, the transits and the dasha',
                    style: theme.textTheme.bodySmall,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: <Widget>[
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${l.tara}: ${hindi ? taraNamesHindi[reading.tara] : taraNames[reading.tara]}',
                          ),
                          if (reading.dashaChain.isNotEmpty)
                            Text(
                              '${l.mahadasha}: ${hindi ? grahaInfo(reading.dashaChain.first.lord).hindi : grahaInfo(reading.dashaChain.first.lord).english}',
                            ),
                        ],
                      ),
                    ),
                    for (final ReadingPoint point in reading.points)
                      Panel(
                        title: hindi ? point.areaHindi : point.area,
                        trailing: point.isCaution
                            ? Icon(
                                Icons.info_outline,
                                size: 18,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              )
                            : null,
                        child: Text(hindi ? point.textHindi : point.text),
                      ),
                  ],
                ),
              ),
              DisclaimerNote(l.disclaimer),
            ],
          );
        },
      ),
    );
  }
}

/// The bigger stretch of time in plain words, the same lines the chart's own
/// "For you" view opens with, less the remedy.
List<String> _periodLines(Kundli kundli, bool hindi) {
  final AskCtx c = AskCtx(kundli, DateTime.now(), hindi);
  final List<String> lines =
      composeStory(c, titleEn: '', titleHi: '').short?.paragraphs ??
      const <String>[];
  return lines.take(2).toList();
}

/// What the day asks, by the Moon's house from the natal Moon: the classical
/// reading of the Moon's transit, put as one thing to do.
const List<(String, String)> _dayTips = <(String, String)>[
  (
    'The mind feels light today. Spend time with your own people.',
    'आज मन हल्का रहता है। अपनों के साथ समय बिताइए।',
  ),
  (
    'Spend money with thought today, and keep your words soft.',
    'आज पैसा सोच-समझकर ख़र्च कीजिए और बोलने में नरमी रखिए।',
  ),
  (
    'A day for courage. Push forward the work that has been stuck.',
    'हिम्मत वाला दिन है। रुके हुए काम आगे बढ़ाइए।',
  ),
  (
    'The mind may be restless. Keep peace at home and avoid arguments.',
    'मन थोड़ा बेचैन रह सकता है। घर में शांति रखिए, बहस से बचिए।',
  ),
  (
    'Plans may move slowly. Do not decide in a hurry.',
    'योजनाएँ धीमी चल सकती हैं। जल्दबाज़ी में फ़ैसला न लीजिए।',
  ),
  (
    'A good day to deal with obstacles and rivals. Clear old pending work.',
    'रुकावटों और मुक़ाबले से निपटने का अच्छा दिन। पुराने अटके काम निपटाइए।',
  ),
  (
    'A good day to talk with your partner and the people you work with.',
    'जीवनसाथी और साझेदारों से बातचीत के लिए अच्छा दिन।',
  ),
  (
    'Go carefully today. Take care with risky work and on the road.',
    'आज सँभलकर चलिए। जोखिम वाले काम और रास्ते में सावधानी रखिए।',
  ),
  (
    'A day for prayer and for the blessing of elders. Hold big decisions a little.',
    'पूजा-पाठ और बड़ों का आशीर्वाद लेने का दिन। बड़े फ़ैसले थोड़ा रोकिए।',
  ),
  (
    'A day to move ahead at work. Do the important task today.',
    'काम-काज में आगे बढ़ने का दिन। ज़रूरी काम आज ही कीजिए।',
  ),
  (
    'A day of gains and of help from friends.',
    'फ़ायदे और दोस्तों से मदद का दिन।',
  ),
  (
    'Spending may rise. Rest, and avoid needless expense.',
    'ख़र्च बढ़ सकता है। आराम कीजिए और फ़ालतू ख़र्च से बचिए।',
  ),
];
