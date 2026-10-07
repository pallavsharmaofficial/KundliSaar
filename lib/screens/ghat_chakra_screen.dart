import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/jyotish/chart.dart';
import '../engine/jyotish/ghat_chakra.dart';
import '../engine/jyotish/rashi.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Ghat Chakra: the month, tithi, weekday, nakshatra, yoga, karana, prahar and
/// Moon sign that the tradition advises against for beginning something
/// important, by the janma rashi. A muhurta aid, never a statement about a life.
class GhatChakraScreen extends StatelessWidget {
  const GhatChakraScreen({super.key, this.profileId});

  final String? profileId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    return ChartScaffold(
      title: hindi ? 'घात चक्र' : 'Ghat Chakra',
      profileId: profileId,
      builder: (BuildContext context, Kundli kundli, _) {
        final GhatChakraReading reading = ghatChakraOf(kundli);
        final GhatRow row = reading.row;
        final RashiInfo rashi = rashiInfo(row.rashi);
        final RashiInfo chandra = rashiInfo(row.chandra);
        final ThemeData theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            ToranaHeader(
              title: hindi ? 'घात चक्र' : 'Ghat Chakra',
              subtitle: hindi
                  ? 'जन्म राशि के अनुसार वे समय-तत्व जिनमें कोई महत्वपूर्ण कार्य आरंभ करना परंपरा में टाला जाता है।'
                  : 'The elements of a day the tradition avoids for beginning something important, by your janma rashi.',
            ),
            Panel(
              title: hindi
                  ? '${rashi.hindi} राशि की पंक्ति'
                  : 'Your row: ${rashi.english} Moon',
              child: Column(
                children: <Widget>[
                  FactRow(
                    hindi ? 'जन्म चंद्र' : 'Janma Moon',
                    hindi
                        ? '${rashi.hindi} · ${kundli.janmaNakshatra.hindi}'
                        : '${rashi.english} · ${kundli.janmaNakshatra.english}',
                  ),
                  FactRow(
                    hindi ? 'घात मास' : 'Ghat month',
                    hindi ? row.monthHindi : row.monthEnglish,
                    emphasise: true,
                  ),
                  FactRow(
                    hindi ? 'घात तिथि' : 'Ghat tithi',
                    hindi
                        ? '${row.tithiGroup.hindi} (${row.tithiGroup.tithis.join(', ')})'
                        : '${row.tithiGroup.english} (${row.tithiGroup.tithis.join(', ')})',
                    emphasise: true,
                  ),
                  FactRow(
                    hindi ? 'घात वार' : 'Ghat weekday',
                    hindi ? row.weekdayHindi : row.weekdayEnglish,
                    emphasise: true,
                  ),
                  FactRow(
                    hindi ? 'घात नक्षत्र' : 'Ghat nakshatra',
                    hindi ? row.nakshatra.hindi : row.nakshatra.english,
                    emphasise: true,
                  ),
                  FactRow(
                    hindi ? 'घात योग' : 'Ghat yoga',
                    hindi ? row.yogaHindi : row.yogaEnglish,
                  ),
                  FactRow(
                    hindi ? 'घात करण' : 'Ghat karana',
                    hindi ? row.karanaHindi : row.karanaEnglish,
                  ),
                  FactRow(
                    hindi ? 'घात प्रहर' : 'Ghat prahar',
                    hindi
                        ? '${row.prahar}${row.praharIsNight ? ' (रात्रि)' : ' (दिन)'}'
                        : '${row.prahar}${row.praharIsNight ? ' (night)' : ' (day)'}',
                  ),
                  FactRow(
                    hindi ? 'घात चंद्र' : 'Ghat Moon',
                    hindi ? chandra.hindi : chandra.english,
                  ),
                ],
              ),
            ),
            Panel(
              title: hindi ? 'इसका अर्थ' : 'What this says',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hindi ? reading.statementHindi : reading.statementEnglish,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hindi ? reading.cautionHindi : reading.cautionEnglish,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Panel(
              title: hindi ? 'बारहों राशियों की तालिका' : 'The whole table',
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final GhatRow r in ghatChakraTable)
                    _TableRow(
                      row: r,
                      hindi: hindi,
                      isYours: r.rashi == row.rashi,
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

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.row,
    required this.hindi,
    required this.isYours,
  });

  final GhatRow row;
  final bool hindi;
  final bool isYours;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RashiInfo rashi = rashiInfo(row.rashi);
    final RashiInfo chandra = rashiInfo(row.chandra);
    final String line = hindi
        ? '${row.monthHindi} · ${row.tithiGroup.hindi} · ${row.weekdayHindi} · ${row.nakshatra.hindi} · ${row.yogaHindi} · ${row.karanaHindi} · प्रहर ${row.prahar} · ${chandra.hindi}'
        : '${row.monthEnglish} · ${row.tithiGroup.english} · ${row.weekdayEnglish} · ${row.nakshatra.english} · ${row.yogaEnglish} · ${row.karanaEnglish} · prahar ${row.prahar} · ${chandra.english}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isYours
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : null,
        border: isYours
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            hindi ? rashi.hindi : rashi.english,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: isYours ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            line,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
