import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/core/theme.dart';
import 'package:kundlisaar/data/local_store.dart';
import 'package:kundlisaar/data/places_repository.dart';
import 'package:kundlisaar/data/profile_repository.dart';
import 'package:kundlisaar/data/time_zones.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/phaladesh.dart';
import 'package:kundlisaar/engine/jyotish/remedies.dart';
import 'package:kundlisaar/l10n/app_localizations.dart';
import 'package:kundlisaar/models/saved_profile.dart';
import 'package:kundlisaar/screens/phaladesh_screen.dart';
import 'package:kundlisaar/services/voice_service.dart';
import 'package:kundlisaar/state/profiles_cubit.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedProfile _profile() => SavedProfile(
  id: 'test',
  name: 'Test person',
  localDateTime: DateTime(1988, 8, 14, 9, 35),
  offsetMinutes: 330,
  place: const Place(
    name: 'Delhi',
    admin: 'Delhi',
    country: 'IN',
    latitude: 28.6139,
    longitude: 77.2090,
    timeZoneId: 'Asia/Kolkata',
    population: 10927986,
  ),
);

Future<Widget> _wrap(Widget child, {required String language}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final LocalStore store = await LocalStore.open();
  final ProfileRepository repository = ProfileRepository(store);
  await repository.save(_profile());
  final SettingsCubit settings = SettingsCubit(store);
  await settings.setLanguage(language);

  return MultiRepositoryProvider(
    providers: <RepositoryProvider<dynamic>>[
      RepositoryProvider<PlacesRepository>(create: (_) => PlacesRepository()),
      RepositoryProvider<ProfileRepository>.value(value: repository),
    ],
    child: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<SettingsCubit>.value(value: settings),
        BlocProvider<ProfilesCubit>(create: (_) => ProfilesCubit(repository)),
      ],
      child: ChangeNotifierProvider<VoiceService>(
        create: (_) => VoiceService(),
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(brightness: Brightness.light),
          home: child,
        ),
      ),
    ),
  );
}

Future<void> _advance(WidgetTester tester, {int frames = 40}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// Opens every expandable card in view, and the ones that appear inside them,
/// failing on the first layout exception. Returns how many it opened.
Future<int> _openInView(WidgetTester tester, {required String reason}) async {
  int opened = 0;
  for (int round = 0; round < 4; round++) {
    int thisRound = 0;
    final List<Element> tiles = find.byType(ExpansionTile).evaluate().toList();
    for (final Element tile in tiles) {
      final RenderObject? box = tile.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final Offset top = box.localToGlobal(Offset.zero);
      if (top.dy < 60 || top.dy > 700) continue;
      final ExpansionTile widget = tile.widget as ExpansionTile;
      if (widget.initiallyExpanded) continue;
      final Finder header = find.descendant(
        of: find.byWidget(tile.widget),
        matching: find.byType(ListTile),
      );
      if (header.evaluate().isEmpty) continue;
      // Skip a tile that is already open.
      final bool open = find
          .descendant(
            of: find.byWidget(tile.widget),
            matching: find.byIcon(Icons.expand_less),
          )
          .evaluate()
          .isNotEmpty;
      if (open) continue;
      await tester.tap(header.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      thisRound++;
      expect(tester.takeException(), isNull, reason: '$reason: opening a card');
    }
    opened += thisRound;
    if (thisRound == 0) break;
  }
  return opened;
}

/// Scrolls a tab top to bottom (up to [steps] screens), opening what it passes.
Future<int> _walk(
  WidgetTester tester, {
  required String reason,
  int steps = 14,
}) async {
  final Finder scrollable = find.byType(Scrollable).last;
  int opened = 0;
  for (int step = 0; step < steps; step++) {
    opened += await _openInView(tester, reason: reason);
    final ScrollableState state = tester.state<ScrollableState>(scrollable);
    if (state.position.pixels >= state.position.maxScrollExtent - 1) break;
    await tester.drag(scrollable, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull, reason: '$reason: scrolling');
  }
  return opened;
}

const Map<String, List<String>> _tabs = <String, List<String>>{
  'en': <String>['Timeline', 'Houses', 'Periods', 'Grahas', 'Transits'],
  'hi': <String>['समय-रेखा', 'भाव फल', 'दशा फल', 'ग्रह फल', 'गोचर फल'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();

  for (final String language in <String>['en', 'hi']) {
    final bool hindi = language == 'hi';

    testWidgets('every tab shows its band and opens without a layout error '
        '($language)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(380, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await _wrap(const PhaladeshScreen(), language: language),
      );
      await _advance(tester, frames: 60);
      expect(tester.takeException(), isNull);

      final String band = hindi ? 'संकेत' : 'indication';
      for (final String tab in _tabs[language]!) {
        await tester.tap(find.text(tab).first);
        await _advance(tester, frames: 25);
        expect(tester.takeException(), isNull, reason: tab);
        // The band is on the card before anything is opened.
        expect(find.textContaining(band), findsWidgets, reason: tab);
        final int opened = await _walk(tester, reason: '$language $tab');
        expect(opened, greaterThan(0), reason: tab);
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }

  testWidgets('a house opens onto its tendencies, its band and its remedies', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(380, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await _wrap(const PhaladeshScreen(), language: 'en'),
    );
    await _advance(tester, frames: 60);
    await tester.tap(find.text('Houses').first);
    await _advance(tester, frames: 25);

    /// Drags the list until the first match of [finder] is on screen.
    Future<void> reveal(Finder finder) async {
      for (int i = 0; i < 40; i++) {
        if (finder.evaluate().isNotEmpty) {
          final double y = tester.getCenter(finder.first).dy;
          if (y > 90 && y < 740) return;
        }
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 100));
      }
      fail('never reached $finder');
    }

    // The first house, then its "Why the chart says this" block.
    await tester.tap(find.text('1 · Self and direction'));
    await tester.pump(const Duration(milliseconds: 300));
    await reveal(find.text('Why the chart says this'));
    await tester.tap(find.text('Why the chart says this').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    for (final String label in <String>[
      'What tends to come up',
      'What it asks of you',
      'Strength of indication',
    ]) {
      await reveal(find.text(label));
      expect(find.text(label), findsWidgets, reason: label);
    }
    // The scale is named on the screen where the band is shown.
    await reveal(find.textContaining('not a probability'));
    expect(find.textContaining('not a classical measure'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final String language in <String>['en', 'hi']) {
    testWidgets('a strained house shows its remedies under it ($language)', (
      WidgetTester tester,
    ) async {
      final bool hindi = language == 'hi';
      final Kundli kundli = computeKundli(
        BirthData(
          name: 'Test person',
          localDateTime: DateTime(1988, 8, 14, 9, 35),
          utcOffset: const Duration(hours: 5, minutes: 30),
          place: const GeoPlace(
            name: 'Delhi',
            latitude: 28.6139,
            longitude: 77.2090,
            timeZoneId: 'Asia/Kolkata',
          ),
        ),
      );
      final BhavaReading strained = computePhaladesh(
        kundli,
      ).bhavas.firstWhere((BhavaReading b) => b.remedies.isNotEmpty);
      final Remedy remedy = strained.remedies.first;

      tester.view.physicalSize = const Size(380, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await _wrap(const PhaladeshScreen(), language: language),
      );
      await _advance(tester, frames: 60);
      await tester.tap(find.text(_tabs[language]![1]).first);
      await _advance(tester, frames: 25);

      Future<void> reveal(Finder finder) async {
        for (int i = 0; i < 80; i++) {
          if (finder.evaluate().isNotEmpty) {
            final double y = tester.getCenter(finder.first).dy;
            if (y > 90 && y < 740) return;
          }
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, -200),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        fail('never reached $finder');
      }

      final String title =
          '${strained.house} · ${strained.area.title.of(hindi)}';
      await reveal(find.text(title));
      await tester.tap(find.text(title));
      await tester.pump(const Duration(milliseconds: 300));
      final Finder why = find.text(
        hindi ? 'कुंडली में आधार' : 'Why the chart says this',
      );
      await reveal(why);
      await tester.tap(why.first);
      await tester.pump(const Duration(milliseconds: 300));

      // The remedies sit under the finding: the heading, which graha and why,
      // the mantra, and the plain statement of what they are.
      await reveal(
        find.text(
          hindi ? 'परंपरा क्या उपाय बताती है' : 'What the tradition offers',
        ),
      );
      await reveal(find.text(remedy.addresses.of(hindi)));
      await reveal(find.text(remedy.kit.mantra.of(hindi)));
      await reveal(find.text(remedy.kit.japa.of(hindi)));
      await reveal(find.text(remedyStance.of(hindi)));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the page still lays out at a larger text size', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(380, 820);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      await _wrap(const PhaladeshScreen(), language: 'hi'),
    );
    await _advance(tester, frames: 60);
    for (final String tab in _tabs['hi']!) {
      await tester.tap(find.text(tab).first);
      await _advance(tester, frames: 25);
      await _walk(tester, reason: 'large text $tab', steps: 8);
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
