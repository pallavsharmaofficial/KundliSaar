import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/profiles_cubit.dart';
import '../widgets/common.dart';
import '../widgets/feature_tile.dart';
import '../widgets/glyphs.dart';

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
                  // On the night theme the button is the accent's own colour, so the
                  // chart's lit diamond takes the button's label colour instead.
                  icon: KIcon(
                    KGlyph.kundli,
                    accent: theme.brightness == Brightness.dark
                        ? theme.colorScheme.onPrimary
                        : null,
                  ),
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
                    _Tile(KGlyph.phaladesh, l.featurePhaladesh, '/phaladesh'),
                    _Tile(KGlyph.rashifal, l.featureRashifal, '/today'),
                    _Tile(KGlyph.sudarshan, l.featureSudarshan, '/sudarshan'),
                    _Tile(
                      KGlyph.ghatChakra,
                      l.featureGhatChakra,
                      '/ghat-chakra',
                    ),
                    _Tile(
                      KGlyph.sarvatobhadra,
                      l.featureSarvatobhadra,
                      '/sarvatobhadra',
                    ),
                    _Tile(KGlyph.strengths, l.featureStrengths, '/strengths'),
                    _Tile(KGlyph.transits, l.featureTransits, '/transits'),
                    _Tile(KGlyph.varshphal, l.featureVarshphal, '/varshphal'),
                    _Tile(KGlyph.remedies, l.featureRemedies, '/remedies'),
                  ],
                ),
                _Section(
                  title: l.tabPanchang,
                  tiles: <_Tile>[
                    _Tile(KGlyph.panchang, l.tabPanchang, '/panchang'),
                    _Tile(KGlyph.muhurta, l.featureMuhurta, '/muhurta'),
                    _Tile(KGlyph.festivals, l.featureFestivals, '/festivals'),
                  ],
                ),
                _Section(
                  title: l.matchTitle,
                  tiles: <_Tile>[
                    _Tile(KGlyph.match, l.tabMatch, '/match'),
                    _Tile(KGlyph.namkaran, l.featureNamkaran, '/namkaran'),
                  ],
                ),
                _Section(
                  title: l.moreFeatures,
                  tiles: <_Tile>[
                    _Tile(KGlyph.hastrekha, l.featureHastrekha, '/hastrekha'),
                    _Tile(
                      KGlyph.numerology,
                      l.featureNumerology,
                      '/numerology',
                    ),
                    _Tile(KGlyph.prashna, l.featurePrashna, '/prashna'),
                    _Tile(KGlyph.learn, l.tabLearn, '/learn'),
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
  const _Tile(this.glyph, this.label, this.route);

  final KGlyph glyph;
  final String label;
  final String route;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tiles});

  final String title;
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionLabel(title),
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
    // Three to a row; two, then one, as the text grows, so a name such as
    // Sarvatobhadra Chakra is never broken in the middle of a word.
    final double scale = MediaQuery.textScalerOf(context).scale(1);
    final int columns = scale > 1.5 ? 1 : (scale > 1.2 ? 2 : 3);
    final double width =
        (MediaQuery.of(context).size.width - 32 - 10 * (columns - 1)) / columns;
    return FeatureTile(
      glyph: tile.glyph,
      label: tile.label,
      onTap: () => context.push(tile.route),
      width: columns == 3 ? width.clamp(96.0, 150.0) : width,
    );
  }
}
