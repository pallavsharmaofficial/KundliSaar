import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/astro/angles.dart';
import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/rashi.dart';
import '../engine/jyotish/transits.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Gochar: where the grahas are today, counted from the natal Moon, with the
/// sarvashtakavarga of the sign they are crossing.
class TransitsScreen extends StatelessWidget {
  const TransitsScreen({super.key, this.profileId});

  final String? profileId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    return ChartScaffold(
      title: l.featureTransits,
      profileId: profileId,
      builder: (BuildContext context, Kundli kundli, _) => DeferredBuilder<TransitReport>(
        message: l.computing,
        work: () => computeTransits(kundli, DateTime.now()),
        builder: (BuildContext context, TransitReport report) {
          final bool hindi =
              context.watch<SettingsCubit>().state.languageCode == 'hi';
          final ThemeData theme = Theme.of(context);
          String date(DateTime? value) =>
              value == null ? '—' : '${value.day}/${value.month}/${value.year}';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              ToranaHeader(
                title: hindi ? 'आज का गोचर' : 'Transits today',
                subtitle: hindi
                    ? 'गिनती जन्म चंद्र राशि से, जैसे परंपरा में होती है।'
                    : 'Counted from your natal Moon, the way gochar is read.',
              ),
              Panel(
                title: l.sadeSati,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      report.sadeSati.isRunning
                          ? l.runningPhase('${report.sadeSati.phase}')
                          : (hindi
                                ? 'अभी नहीं चल रही।'
                                : 'Not running at the moment.'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (report.sadeSati.isRunning) ...<Widget>[
                      FactRow(
                        hindi ? 'यह चरण' : 'This phase ends',
                        date(report.sadeSati.phaseEnd),
                      ),
                      FactRow(
                        hindi ? 'पूरी अवधि' : 'The whole passage ends',
                        date(report.sadeSati.end),
                      ),
                    ] else ...<Widget>[
                      FactRow(
                        hindi ? 'अगली बार' : 'Next begins',
                        date(report.sadeSati.start),
                      ),
                    ],
                  ],
                ),
              ),
              Panel(
                title: hindi ? 'ग्रहों की स्थिति' : 'Where the grahas stand',
                child: Column(
                  children: <Widget>[
                    for (final Graha graha in Graha.values)
                      _TransitRow(
                        position: report.positions[graha]!,
                        favourable: report.isFavourable(graha),
                        hindi: hindi,
                      ),
                  ],
                ),
              ),
              Panel(
                title: l.nextReturn,
                child: Column(
                  children: <Widget>[
                    FactRow(
                      hindi ? 'गुरु' : 'Jupiter',
                      date(report.jupiterReturn),
                    ),
                    FactRow(
                      hindi ? 'शनि' : 'Saturn',
                      date(report.saturnReturn),
                    ),
                  ],
                ),
              ),
              if (report.aspects.isNotEmpty)
                Panel(
                  title: l.aspectsOnNatal,
                  child: Column(
                    children: <Widget>[
                      for (final TransitAspect aspect in report.aspects.take(8))
                        FactRow(
                          '${hindi ? grahaInfo(aspect.transiting).hindi : grahaInfo(aspect.transiting).english}'
                              ' → '
                              '${hindi ? grahaInfo(aspect.natal).hindi : grahaInfo(aspect.natal).english}',
                          '${aspect.houseDistance == 1 ? (hindi ? 'युति' : 'conjunct') : (hindi ? '${aspect.houseDistance}वीं दृष्टि' : '${aspect.houseDistance}th aspect')}'
                              ' · ${formatDegrees(aspect.orb)}',
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

class _TransitRow extends StatelessWidget {
  const _TransitRow({
    required this.position,
    required this.favourable,
    required this.hindi,
  });

  final TransitPosition position;
  final bool favourable;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GrahaInfo info = grahaInfo(position.graha);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Text(
              hindi ? info.hindi : info.english,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${hindi ? rashiInfo(position.rashi).hindi : rashiInfo(position.rashi).english}'
                  '${position.isRetrograde ? (hindi ? ' (वक्री)' : ' (R)') : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '${hindi ? 'चंद्र से' : 'from Moon'} ${position.houseFromMoon}'
                  ' · ${position.bindusInSign} ${hindi ? 'बिंदु' : 'bindus'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            favourable ? Icons.trending_up : Icons.hourglass_bottom,
            size: 18,
            color: favourable
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}
