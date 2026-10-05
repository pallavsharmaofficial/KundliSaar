import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      builder: (BuildContext context, Kundli kundli, _) =>
          DeferredBuilder<DailyReading>(
            message: l.computing,
            work: () => dailyReading(kundli, DateTime.now()),
            builder: (BuildContext context, DailyReading reading) {
              final bool hindi =
                  context.watch<SettingsCubit>().state.languageCode == 'hi';
              final ThemeData theme = Theme.of(context);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  ToranaHeader(
                    title: l.dailyReading,
                    subtitle:
                        '${reading.date.day}/${reading.date.month}/${reading.date.year}',
                  ),
                  Panel(
                    child: Row(
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                reading.isGoodDay
                                    ? (hindi
                                          ? 'दिन अनुकूल है'
                                          : 'The day runs with you')
                                    : (hindi
                                          ? 'दिन धैर्य माँगता है'
                                          : 'The day asks for patience'),
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                '${l.tara}: ${hindi ? taraNamesHindi[reading.tara] : taraNames[reading.tara]}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
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
                  Panel(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Text(
                              l.luckyNumber,
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '${reading.luckyNumber}',
                              style: theme.textTheme.displaySmall,
                            ),
                          ],
                        ),
                        Column(
                          children: <Widget>[
                            Text(
                              l.luckyColour,
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              hindi
                                  ? reading.luckyColourHindi
                                  : reading.luckyColour,
                              style: theme.textTheme.titleLarge,
                            ),
                          ],
                        ),
                        if (reading.dashaChain.isNotEmpty)
                          Column(
                            children: <Widget>[
                              Text(
                                l.mahadasha,
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                hindi
                                    ? grahaInfo(
                                        reading.dashaChain.first.lord,
                                      ).hindi
                                    : grahaInfo(
                                        reading.dashaChain.first.lord,
                                      ).english,
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
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
