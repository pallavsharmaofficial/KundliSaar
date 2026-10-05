import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/namkaran.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// The syllable a name should start with, from the pada of the janma
/// nakshatra, with example names that carry the sound.
class NamkaranScreen extends StatelessWidget {
  const NamkaranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    return ChartScaffold(
      title: l.featureNamkaran,
      builder: (BuildContext context, Kundli kundli, _) {
        final NamkaranSuggestion suggestion = namkaranFor(
          kundli.grahas[Graha.moon]!.siderealLongitude,
        );
        final ThemeData theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            ToranaHeader(
              title: hindi
                  ? suggestion.nakshatra.hindi
                  : suggestion.nakshatra.english,
              subtitle:
                  '${l.pada} ${suggestion.pada} · ${hindi ? suggestion.nakshatra.deityHindi : suggestion.nakshatra.deityEnglish}',
            ),
            Panel(
              child: Column(
                children: <Widget>[
                  Text(l.syllable, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text(
                    hindi ? suggestion.syllableHindi : suggestion.syllable,
                    style: theme.textTheme.displaySmall?.copyWith(fontSize: 54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hindi
                        ? 'परंपरा में नाम इसी ध्वनि से आरंभ होता है।'
                        : 'The tradition starts the name on this sound.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (suggestion.names.isNotEmpty)
              Panel(
                title: l.suggestedNames,
                child: Column(
                  children: <Widget>[
                    for (final SuggestedName name in suggestion.names)
                      FactRow(
                        '${name.name} · ${name.hindi}',
                        hindi ? name.meaningHindi : name.meaning,
                      ),
                  ],
                ),
              ),
            Panel(
              title: l.otherPadas,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < suggestion.alternates.length; i++)
                    FactRow(
                      '${l.pada} ${i + 1}',
                      '${suggestion.alternates[i]} · ${padaSyllablesHindi[suggestion.nakshatra.index][i]}'
                          '${i + 1 == suggestion.pada ? (hindi ? '  (यही)' : '  (yours)') : ''}',
                      emphasise: i + 1 == suggestion.pada,
                    ),
                ],
              ),
            ),
            Panel(
              child: Text(
                hindi
                    ? 'अक्षर परंपरा है, नाम परिवार का चुनाव। जो नाम घर में पुकारा जाएगा, वही सबसे सही है।'
                    : 'The syllable is the tradition; the name is the family’s. The one that will actually be called out at home is the right one.',
              ),
            ),
            DisclaimerNote(l.disclaimer),
          ],
        );
      },
    );
  }
}
