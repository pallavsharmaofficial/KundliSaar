import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/profiles_cubit.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final List<SavedProfile> profiles = context.watch<ProfilesCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle, style: theme.textTheme.displaySmall),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.settings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          ToranaHeader(title: l.tagline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => context.push('/new'),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(l.newChart),
                ),
                if (profiles.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(l.savedCharts, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...profiles.map(
                    (SavedProfile profile) => Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        title: Text(
                          profile.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          '${profile.localDateTime.day}/${profile.localDateTime.month}/${profile.localDateTime.year}'
                          ' · ${profile.place.name}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/chart/${profile.id}'),
                        onLongPress: () =>
                            context.read<ProfilesCubit>().remove(profile.id),
                      ),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Panel(
                      child: Row(
                        children: <Widget>[
                          const MandalaMark(size: 56),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l.profileEmpty)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                _Section(
                  title: l.tabChart,
                  tiles: <_Tile>[
                    _Tile(
                      Icons.timeline_outlined,
                      l.featurePhaladesh,
                      '/phaladesh',
                    ),
                    _Tile(Icons.today_outlined, l.featureRashifal, '/today'),
                    _Tile(
                      Icons.speed_outlined,
                      l.featureStrengths,
                      '/strengths',
                    ),
                    _Tile(
                      Icons.sync_alt_outlined,
                      l.featureTransits,
                      '/transits',
                    ),
                    _Tile(
                      Icons.cake_outlined,
                      l.featureVarshphal,
                      '/varshphal',
                    ),
                    _Tile(
                      Icons.healing_outlined,
                      l.featureRemedies,
                      '/remedies',
                    ),
                  ],
                ),
                _Section(
                  title: l.tabPanchang,
                  tiles: <_Tile>[
                    _Tile(
                      Icons.calendar_month_outlined,
                      l.tabPanchang,
                      '/panchang',
                    ),
                    _Tile(
                      Icons.schedule_outlined,
                      l.featureMuhurta,
                      '/muhurta',
                    ),
                    _Tile(
                      Icons.celebration_outlined,
                      l.featureFestivals,
                      '/festivals',
                    ),
                  ],
                ),
                _Section(
                  title: l.matchTitle,
                  tiles: <_Tile>[
                    _Tile(Icons.favorite_outline, l.tabMatch, '/match'),
                    _Tile(
                      Icons.child_care_outlined,
                      l.featureNamkaran,
                      '/namkaran',
                    ),
                  ],
                ),
                _Section(
                  title: l.moreFeatures,
                  tiles: <_Tile>[
                    _Tile(
                      Icons.back_hand_outlined,
                      l.featureHastrekha,
                      '/hastrekha',
                    ),
                    _Tile(
                      Icons.pin_outlined,
                      l.featureNumerology,
                      '/numerology',
                    ),
                    _Tile(Icons.help_outline, l.featurePrashna, '/prashna'),
                    _Tile(Icons.menu_book_outlined, l.tabLearn, '/learn'),
                  ],
                ),
              ],
            ),
          ),
          DisclaimerNote(l.disclaimer),
        ],
      ),
    );
  }
}

class _Tile {
  const _Tile(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tiles});

  final String title;
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13.5,
              letterSpacing: 0.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final _Tile tile in tiles) _FeatureTile(tile: tile),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.tile});

  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = (MediaQuery.of(context).size.width - 32 - 20) / 3;
    return InkWell(
      onTap: () => context.push(tile.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width.clamp(96.0, 150.0),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(tile.icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              tile.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
