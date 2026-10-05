import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/ashtakavarga.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/rashi.dart';
import '../engine/jyotish/shadbala.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Shadbala and ashtakavarga: the two strength systems a practitioner checks
/// before saying anything else about a chart.
class StrengthsScreen extends StatelessWidget {
  const StrengthsScreen({super.key, this.profileId});

  final String? profileId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    return ChartScaffold(
      title: l.featureStrengths,
      profileId: profileId,
      builder: (BuildContext context, Kundli kundli, _) =>
          DeferredBuilder<(Map<Graha, BalaBreakdown>, AshtakavargaResult)>(
            message: l.computing,
            work: () => (computeShadbala(kundli), computeAshtakavarga(kundli)),
            builder:
                (
                  BuildContext context,
                  (Map<Graha, BalaBreakdown>, AshtakavargaResult) value,
                ) {
                  final bool hindi =
                      context.watch<SettingsCubit>().state.languageCode == 'hi';
                  final Map<Graha, BalaBreakdown> bala = value.$1;
                  final AshtakavargaResult ashtakavarga = value.$2;
                  final ThemeData theme = Theme.of(context);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: <Widget>[
                      ToranaHeader(
                        title: l.shadbala,
                        subtitle: hindi
                            ? 'छह बलों का योग, रूप में। हर ग्रह के लिए आवश्यक बल अलग है।'
                            : 'The six strengths added up in rupas. Each graha has its own bar to clear.',
                      ),
                      for (final Graha graha in shadbalaGrahas)
                        _BalaCard(breakdown: bala[graha]!, hindi: hindi),
                      const SizedBox(height: 8),
                      ToranaHeader(
                        title: l.sarvashtakavarga,
                        subtitle: hindi
                            ? 'हर राशि में बिंदु। 30 से ऊपर बलवान, 25 से नीचे कमज़ोर।'
                            : 'Bindus in each sign. Above thirty is strong, below twenty-five is thin.',
                      ),
                      Panel(
                        child: Column(
                          children: <Widget>[
                            for (int sign = 0; sign < 12; sign++)
                              _SarvaRow(
                                sign: sign,
                                bindus: ashtakavarga.sarva[sign],
                                isLagna: sign == kundli.lagnaRashi.index,
                                isMoon: sign == kundli.moonRashi.index,
                                hindi: hindi,
                              ),
                            const Divider(),
                            FactRow(
                              hindi ? 'कुल' : 'Total',
                              '${ashtakavarga.sarvaTotal} ${l.bindus}',
                              emphasise: true,
                            ),
                          ],
                        ),
                      ),
                      Panel(
                        title: l.ashtakavarga,
                        child: Column(
                          children: <Widget>[
                            for (final Graha graha in ashtakavargaGrahas)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    SizedBox(
                                      width: 76,
                                      child: Text(
                                        hindi
                                            ? grahaInfo(graha).hindi
                                            : grahaInfo(graha).english,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: <Widget>[
                                          for (int sign = 0; sign < 12; sign++)
                                            Expanded(
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 1,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  color: theme
                                                      .colorScheme
                                                      .primary
                                                      .withValues(
                                                        alpha:
                                                            ashtakavarga
                                                                .charts[graha]!
                                                                .bindus[sign] /
                                                            16,
                                                      ),
                                                ),
                                                child: Text(
                                                  '${ashtakavarga.charts[graha]!.bindus[sign]}',
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(fontSize: 12),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${ashtakavarga.charts[graha]!.total}',
                                        textAlign: TextAlign.right,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
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

class _BalaCard extends StatelessWidget {
  const _BalaCard({required this.breakdown, required this.hindi});

  final BalaBreakdown breakdown;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final GrahaInfo info = grahaInfo(breakdown.graha);
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                hindi ? info.hindi : info.english,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              '${breakdown.totalRupas.toStringAsFixed(2)} ${l.rupas}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: breakdown.isStrong
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: breakdown.ratio.clamp(0.0, 1.6) / 1.6,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 4),
            Text(
              '${breakdown.isStrong ? l.strong : l.weak} · ${l.needs} ${breakdown.requiredRupas}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
            ),
          ],
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: <Widget>[
                FactRow(
                  hindi ? 'स्थान बल' : 'Sthana bala',
                  breakdown.sthana.toStringAsFixed(1),
                ),
                FactRow(
                  hindi ? 'दिग् बल' : 'Dig bala',
                  breakdown.dig.toStringAsFixed(1),
                ),
                FactRow(
                  hindi ? 'काल बल' : 'Kala bala',
                  breakdown.kala.toStringAsFixed(1),
                ),
                FactRow(
                  hindi ? 'चेष्टा बल' : 'Chesta bala',
                  breakdown.chesta.toStringAsFixed(1),
                ),
                FactRow(
                  hindi ? 'नैसर्गिक बल' : 'Naisargika bala',
                  breakdown.naisargika.toStringAsFixed(1),
                ),
                FactRow(
                  hindi ? 'दृक् बल' : 'Drik bala',
                  breakdown.drik.toStringAsFixed(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SarvaRow extends StatelessWidget {
  const _SarvaRow({
    required this.sign,
    required this.bindus,
    required this.isLagna,
    required this.isMoon,
    required this.hindi,
  });

  final int sign;
  final int bindus;
  final bool isLagna;
  final bool isMoon;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RashiInfo info = rashiInfo(Rashi.values[sign]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              hindi ? info.hindi : info.english,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isLagna || isMoon ? FontWeight.w600 : null,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: bindus / 40,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$bindus',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 24,
            child: isLagna
                ? const Icon(Icons.star, size: 14)
                : (isMoon
                      ? const Icon(Icons.nightlight_round, size: 14)
                      : null),
          ),
        ],
      ),
    );
  }
}
