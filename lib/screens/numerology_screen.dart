import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/jyotish/chart.dart';
import '../engine/jyotish/numerology.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Ank Jyotish, worked from the same birth details the kundli uses.
class NumerologyScreen extends StatelessWidget {
  const NumerologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    return ChartScaffold(
      title: l.featureNumerology,
      builder: (BuildContext context, Kundli kundli, SavedProfile profile) {
        final NumerologyReading reading = computeNumerology(
          birthDate: profile.localDateTime,
          name: profile.name,
        );
        final ThemeData theme = Theme.of(context);
        final NumberInfo mulank = numberInfo(reading.mulank);
        final NumberInfo bhagyank = numberInfo(reading.bhagyank);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            ToranaHeader(
              title: profile.name,
              subtitle:
                  '${profile.localDateTime.day}/${profile.localDateTime.month}/${profile.localDateTime.year}',
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: _BigNumber(
                    label: l.mulank,
                    value: reading.mulank,
                    planet: hindi ? mulank.planetHindi : mulank.planet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigNumber(
                    label: l.bhagyank,
                    value: reading.bhagyank,
                    planet: hindi ? bhagyank.planetHindi : bhagyank.planet,
                  ),
                ),
                if (reading.namank > 0) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigNumber(
                      label: l.namank,
                      value: reading.namank,
                      planet: hindi
                          ? numberInfo(reading.namank).planetHindi
                          : numberInfo(reading.namank).planet,
                    ),
                  ),
                ],
              ],
            ),
            Panel(
              title: '${l.mulank} · ${reading.mulank}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(hindi ? mulank.traitsHindi : mulank.traits),
                  const SizedBox(height: 10),
                  FactRow(l.luckyDays, mulank.luckyDays.join(', ')),
                  FactRow(
                    l.luckyColour,
                    (hindi ? mulank.luckyColoursHindi : mulank.luckyColours)
                        .join(', '),
                  ),
                  FactRow(l.gemstone, mulank.gemstone),
                ],
              ),
            ),
            Panel(
              title: '${l.bhagyank} · ${reading.bhagyank}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(hindi ? bhagyank.traitsHindi : bhagyank.traits),
                  const SizedBox(height: 10),
                  Text(
                    reading.mulankAndBhagyankAgree
                        ? (hindi
                              ? 'मूलांक और भाग्यांक मित्र हैं: स्वभाव और मार्ग एक दिशा में चलते हैं।'
                              : 'Mulank and bhagyank are friendly: temperament and path pull the same way.')
                        : (hindi
                              ? 'मूलांक और भाग्यांक अलग दिशा में हैं: जो स्वभाव चाहता है और जो जीवन माँगता है, उनमें अंतर रहता है।'
                              : 'Mulank and bhagyank pull differently: what the temperament wants and what the life asks for are not the same thing.'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Panel(
              title: l.loshuGrid,
              child: Column(
                children: <Widget>[
                  _LoShu(counts: reading.loshu),
                  const SizedBox(height: 12),
                  FactRow(
                    l.missingNumbers,
                    reading.missingNumbers.isEmpty
                        ? '—'
                        : reading.missingNumbers.join(', '),
                  ),
                  FactRow(
                    l.repeatedNumbers,
                    reading.repeatedNumbers.isEmpty
                        ? '—'
                        : reading.repeatedNumbers.join(', '),
                  ),
                ],
              ),
            ),
            DisclaimerNote(l.disclaimer),
          ],
        );
      },
    );
  }
}

class _BigNumber extends StatelessWidget {
  const _BigNumber({
    required this.label,
    required this.value,
    required this.planet,
  });

  final String label;
  final int value;
  final String planet;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: <Widget>[
          Text('$value', style: theme.textTheme.displaySmall),
          Text(planet, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Lo Shu square, with the count of each digit in the birth date.
class _LoShu extends StatelessWidget {
  const _LoShu({required this.counts});

  final Map<int, int> counts;

  static const List<List<int>> _grid = <List<int>>[
    <int>[4, 9, 2],
    <int>[3, 5, 7],
    <int>[8, 1, 6],
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        for (final List<int> row in _grid)
          Row(
            children: <Widget>[
              for (final int digit in row)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: counts[digit]! > 0
                          ? theme.colorScheme.primary.withValues(
                              alpha: 0.08 + 0.10 * counts[digit]!,
                            )
                          : Colors.transparent,
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.14,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        counts[digit]! == 0
                            ? '·'
                            : List<String>.filled(
                                counts[digit]!,
                                '$digit',
                              ).join(),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
