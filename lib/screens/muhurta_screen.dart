import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/astro/time.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/muhurta.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// The muhurta finder: it scores every choghadiya slot across a date range
/// against the rules for the chosen work, and shows what moved each score.
class MuhurtaScreen extends StatefulWidget {
  const MuhurtaScreen({super.key});

  @override
  State<MuhurtaScreen> createState() => _MuhurtaScreenState();
}

class _MuhurtaScreenState extends State<MuhurtaScreen> {
  Activity _activity = Activity.grihaPravesh;
  int _days = 15;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    return ChartScaffold(
      title: l.featureMuhurta,
      builder: (BuildContext context, Kundli kundli, SavedProfile profile) {
        final ActivityInfo info = activityInfo(_activity);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            ToranaHeader(
              title: l.chooseActivity,
              subtitle: hindi ? info.noteHindi : info.note,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final ActivityInfo a in activityTable)
                  ChoiceChip(
                    label: Text(hindi ? a.hindi : a.english),
                    selected: a.activity == _activity,
                    onSelected: (_) => setState(() => _activity = a.activity),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text(l.searchDays),
                Expanded(
                  child: Slider(
                    value: _days.toDouble(),
                    min: 7,
                    max: 45,
                    divisions: 38,
                    label: '$_days',
                    onChanged: (double value) =>
                        setState(() => _days = value.round()),
                  ),
                ),
                Text('$_days'),
              ],
            ),
            const SizedBox(height: 8),
            DeferredBuilder<List<MuhurtaWindow>>(
              key: ValueKey<String>('$_activity-$_days-${profile.id}'),
              message: l.computing,
              work: () => findMuhurta(
                activity: _activity,
                from: DateTime.now(),
                days: _days,
                utcOffset: profile.toBirthData().utcOffset,
                place: profile.place.toGeoPlace(),
                forPerson: kundli,
                ayanamsa: kundli.ayanamsa,
              ),
              builder: (BuildContext context, List<MuhurtaWindow> windows) =>
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        l.bestWindows,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final MuhurtaWindow window in windows)
                        _WindowCard(
                          window: window,
                          offset: profile.toBirthData().utcOffset,
                          hindi: hindi,
                        ),
                      DisclaimerNote(l.disclaimer),
                    ],
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.window,
    required this.offset,
    required this.hindi,
  });

  final MuhurtaWindow window;
  final Duration offset;
  final bool hindi;

  String _clock(double jdUt) {
    final DateTime local = utcFromJulianDay(jdUt).add(offset);
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _date(double jdUt) {
    final DateTime local = utcFromJulianDay(jdUt).add(offset);
    return '${local.day}/${local.month}';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${_date(window.startJdUt)} · ${_clock(window.startJdUt)}–${_clock(window.endJdUt)}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: window.isGood
                    ? theme.colorScheme.primary.withValues(alpha: 0.18)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              child: Text('${window.score}', style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
        subtitle: Text('${window.nakshatra} · ${window.tithiName}'),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.whyThisWindow,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                for (final String reason
                    in hindi ? window.reasonsHindi : window.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $reason', style: theme.textTheme.bodyMedium),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
