import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/core/theme.dart';
import 'package:kundlisaar/data/local_store.dart';
import 'package:kundlisaar/data/places_repository.dart';
import 'package:kundlisaar/data/profile_repository.dart';
import 'package:kundlisaar/data/time_zones.dart';
import 'package:kundlisaar/l10n/app_localizations.dart';
import 'package:kundlisaar/models/saved_profile.dart';
import 'package:kundlisaar/screens/varshphal_screen.dart';
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

/// Scrolls the whole page top to bottom, opening every expandable card it
/// passes, and fails on the first layout exception.
Future<int> _walk(WidgetTester tester, {required String reason}) async {
  final Finder scrollable = find.byType(Scrollable).first;
  int opened = 0;
  for (int step = 0; step < 400; step++) {
    final List<Element> tiles = find.byType(ExpansionTile).evaluate().toList();
    for (final Element tile in tiles) {
      final RenderObject? box = tile.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final Offset top = box.localToGlobal(Offset.zero);
      if (top.dy < 60 || top.dy > 700) continue;
      final Finder header = find.descendant(
        of: find.byWidget(tile.widget),
        matching: find.byType(ListTile),
      );
      if (header.evaluate().isEmpty) continue;
      final ExpansionTile widget = tile.widget as ExpansionTile;
      if (widget.initiallyExpanded) continue;
      await tester.tap(header.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      opened++;
      expect(tester.takeException(), isNull, reason: '$reason: opening a card');
    }
    final ScrollableState state = tester.state<ScrollableState>(scrollable);
    if (state.position.pixels >= state.position.maxScrollExtent - 1) break;
    await tester.drag(scrollable, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull, reason: '$reason: scrolling');
  }
  return opened;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();

  for (final String language in <String>['en', 'hi']) {
    testWidgets('the varshphal screen reads all five sections ($language)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(380, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await _wrap(const VarshphalScreen(), language: language),
      );
      await _advance(tester);
      expect(tester.takeException(), isNull);

      final bool hindi = language == 'hi';
      final List<String> headings = hindi
          ? <String>[
              'महीने दर महीने',
              'मुद्दा दशा',
              'पात्यायिनी दशा',
              'ताजिक दृष्टि',
              'सहम',
            ]
          : <String>[
              'Month by month',
              'Mudda dasha',
              'Patyayini dasha',
              'Tajika aspects',
              'Sahams',
            ];
      final Finder scrollable = find.byType(Scrollable).first;
      for (final String heading in headings) {
        await tester.scrollUntilVisible(
          find.text(heading),
          300,
          scrollable: scrollable,
        );
        expect(find.text(heading), findsWidgets, reason: heading);
        expect(tester.takeException(), isNull, reason: heading);
      }
    });

    testWidgets('every card opens without a layout error ($language)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(380, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await _wrap(const VarshphalScreen(), language: language),
      );
      await _advance(tester);
      final int opened = await _walk(tester, reason: language);
      expect(opened, greaterThan(10));
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
      await _wrap(const VarshphalScreen(), language: 'hi'),
    );
    await _advance(tester);
    await _walk(tester, reason: 'large text');
    expect(tester.takeException(), isNull);
  });
}
