import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/jyotish/chart.dart';
import '../engine/jyotish/matching.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/profiles_cubit.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  String? _brideId;
  String? _groomId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final AppSettings settings = context.watch<SettingsCubit>().state;
    final bool hindi = settings.languageCode == 'hi';
    final List<SavedProfile> profiles = context.watch<ProfilesCubit>().state;

    MatchResult? result;
    if (_brideId != null && _groomId != null) {
      final SavedProfile bride = profiles.firstWhere(
        (SavedProfile p) => p.id == _brideId,
      );
      final SavedProfile groom = profiles.firstWhere(
        (SavedProfile p) => p.id == _groomId,
      );
      result = matchCharts(
        computeKundli(bride.toBirthData(), ayanamsa: settings.ayanamsa),
        computeKundli(groom.toBirthData(), ayanamsa: settings.ayanamsa),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.matchTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          if (profiles.length < 2)
            Panel(child: Text(l.profileEmpty))
          else ...<Widget>[
            _Picker(
              label: l.bride,
              profiles: profiles,
              value: _brideId,
              onChanged: (String? id) => setState(() => _brideId = id),
            ),
            const SizedBox(height: 12),
            _Picker(
              label: l.groom,
              profiles: profiles,
              value: _groomId,
              onChanged: (String? id) => setState(() => _groomId = id),
            ),
          ],
          if (result != null) ...<Widget>[
            const SizedBox(height: 16),
            Panel(
              child: Column(
                children: <Widget>[
                  Text(
                    l.gunaScore(
                      result.total.toStringAsFixed(
                        result.total == result.total.roundToDouble() ? 0 : 1,
                      ),
                    ),
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: result.total / result.maximum,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
            Panel(
              title: hindi ? 'आठ कूट' : 'The eight kootas',
              child: Column(
                children: <Widget>[
                  for (final Koota koota in result.kootas)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  hindi ? koota.hindi : koota.english,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                '${koota.score.toStringAsFixed(koota.score == koota.score.roundToDouble() ? 0 : 1)} / ${koota.maximum.toStringAsFixed(0)}',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          Text(
                            hindi ? koota.reasonHindi : koota.reasonEnglish,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Panel(
              title: l.mangalDosha,
              child: Column(
                children: <Widget>[
                  FactRow(l.bride, result.brideMangal ? l.present : l.absent),
                  FactRow(l.groom, result.groomMangal ? l.present : l.absent),
                  if (result.brideMangal && result.groomMangal)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        hindi
                            ? 'दोनों की कुंडली में मंगल दोष है; परंपरा इसे परस्पर भंग मानती है।'
                            : 'Both charts carry it, which the tradition treats as cancelling out.',
                      ),
                    ),
                ],
              ),
            ),
            DisclaimerNote(l.matchNote),
          ],
        ],
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.profiles,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<SavedProfile> profiles;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: <DropdownMenuItem<String>>[
      for (final SavedProfile profile in profiles)
        DropdownMenuItem<String>(value: profile.id, child: Text(profile.name)),
    ],
    onChanged: onChanged,
  );
}
