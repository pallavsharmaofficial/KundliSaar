import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/astro/houses.dart';
import '../engine/jyotish/festivals.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/profiles_cubit.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import '../widgets/nakshatra_loader.dart';

/// The festival and vrat calendar, computed rather than listed: every date
/// comes from the tithi running at sunrise at the chosen place.
class FestivalsScreen extends StatefulWidget {
  const FestivalsScreen({super.key});

  @override
  State<FestivalsScreen> createState() => _FestivalsScreenState();
}

class _FestivalsScreenState extends State<FestivalsScreen> {
  late int _year = DateTime.now().year;
  bool _onlyMajor = true;
  Future<List<Festival>>? _future;
  int? _computedFor;

  Future<List<Festival>> _compute(GeoPlace place, Duration offset) async {
    await Future<void>.delayed(const Duration(milliseconds: 32));
    return festivalsForYear(year: _year, place: place, utcOffset: offset);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    final List<SavedProfile> profiles = context.watch<ProfilesCubit>().state;
    final SavedProfile? profile = profiles.firstOrNull;
    final GeoPlace place =
        profile?.place.toGeoPlace() ??
        const GeoPlace(
          name: 'Delhi',
          latitude: 28.6139,
          longitude: 77.2090,
          timeZoneId: 'Asia/Kolkata',
        );
    final Duration offset = profile == null
        ? const Duration(hours: 5, minutes: 30)
        : Duration(minutes: profile.offsetMinutes);

    if (_computedFor != _year) {
      _computedFor = _year;
      _future = _compute(place, offset);
    }

    final DateTime today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.featureFestivals),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year -= 1),
          ),
          Center(child: Text('$_year')),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _year += 1),
          ),
        ],
      ),
      body: FutureBuilder<List<Festival>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<Festival>> snapshot) {
          if (!snapshot.hasData) {
            return NakshatraLoadingView(message: l.computing);
          }
          final List<Festival> all = snapshot.data!;
          final List<Festival> shown = all
              .where((Festival f) => !_onlyMajor || f.isMajor)
              .toList(growable: false);
          final List<Festival> upcoming = shown
              .where(
                (Festival f) => !f.date.isBefore(
                  DateTime(today.year, today.month, today.day),
                ),
              )
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              ToranaHeader(title: '$_year', subtitle: place.name),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _onlyMajor,
                onChanged: (bool value) => setState(() => _onlyMajor = value),
                title: Text(
                  hindi ? 'केवल बड़े त्योहार' : 'Major festivals only',
                ),
                subtitle: Text(
                  hindi
                      ? 'बंद करने पर एकादशी, पूर्णिमा, अमावस्या और संक्रांति भी दिखेंगी'
                      : 'Turn off to include every Ekadashi, Purnima, Amavasya and Sankranti',
                ),
              ),
              if (upcoming.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  l.upcoming,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final Festival festival in upcoming.take(4))
                  _FestivalCard(
                    festival: festival,
                    hindi: hindi,
                    highlight: true,
                  ),
                const SizedBox(height: 16),
                Text(
                  l.wholeYear,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
              ],
              for (final Festival festival in shown)
                _FestivalCard(
                  festival: festival,
                  hindi: hindi,
                  highlight: false,
                ),
              DisclaimerNote(
                hindi
                    ? 'तिथि सूर्योदय के समय की ली गई है। क्षेत्रीय पंचांग में एक दिन का अंतर हो सकता है।'
                    : 'Dates use the tithi running at sunrise here. A regional panchang may differ by a day.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FestivalCard extends StatelessWidget {
  const _FestivalCard({
    required this.festival,
    required this.hindi,
    required this.highlight,
  });

  final Festival festival;
  final bool hindi;
  final bool highlight;

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '${festival.date.day}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: highlight ? theme.colorScheme.primary : null,
              ),
            ),
            Text(
              _months[festival.date.month - 1],
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
        title: Text(
          hindi ? festival.hindi : festival.english,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(hindi ? festival.detailHindi : festival.detail),
      ),
    );
  }
}
