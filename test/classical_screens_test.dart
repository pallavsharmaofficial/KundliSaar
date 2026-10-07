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
import 'package:kundlisaar/screens/chart_screen.dart';
import 'package:kundlisaar/screens/ghat_chakra_screen.dart';
import 'package:kundlisaar/screens/sarvatobhadra_screen.dart';
import 'package:kundlisaar/screens/sudarshan_screen.dart';
import 'package:kundlisaar/services/voice_service.dart';
import 'package:kundlisaar/state/profiles_cubit.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedProfile testProfile() => SavedProfile(
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

Future<Widget> wrap(Widget child, {String language = 'hi'}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final LocalStore store = await LocalStore.open();
  final ProfileRepository repository = ProfileRepository(store);
  await repository.save(testProfile());
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

/// The nakshatra loader animates for ever, so pumpAndSettle would never return.
Future<void> advance(WidgetTester tester, {int frames = 40}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();

  for (final String language in <String>['hi', 'en']) {
    group('classical screens build on a phone in $language', () {
      final Map<String, Widget Function()> screens =
          <String, Widget Function()>{
            'ghat chakra': () => const GhatChakraScreen(),
            'sarvatobhadra': () => const SarvatobhadraScreen(),
            'sudarshan': () => const SudarshanScreen(),
          };
      for (final MapEntry<String, Widget Function()> entry in screens.entries) {
        testWidgets(entry.key, (WidgetTester tester) async {
          tester.view.physicalSize = const Size(380, 820);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            await wrap(entry.value(), language: language),
          );
          await advance(tester);
          expect(tester.takeException(), isNull, reason: entry.key);
          expect(find.byType(Scaffold), findsWidgets);
          expect(find.byType(ListView), findsWidgets);
        });
      }
    });
  }

  testWidgets('the ghat chakra names the whole table and the native row', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(380, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await wrap(const GhatChakraScreen(), language: 'en'),
    );
    await advance(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Ghat Chakra'), findsWidgets);
    expect(find.textContaining('Ghat tithi'), findsOneWidget);
    // All twelve rows are listed further down the page.
    await tester.scrollUntilVisible(
      find.textContaining('Phalguna'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Phalguna'), findsWidgets);
  });

  testWidgets('the sarvatobhadra grid draws 81 cells', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(380, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await wrap(const SarvatobhadraScreen(), language: 'en'),
    );
    await advance(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(GestureDetector), findsAtLeastNWidgets(81));
  });

  testWidgets(
    'the chart screen lists the upagrahas and the larger yoga library',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(380, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await wrap(const ChartScreen(profileId: 'test'), language: 'en'),
      );
      await advance(tester, frames: 10);
      // The planets tab, then scroll to the end of it.
      await tester.tap(find.text('Grahas'));
      await advance(tester, frames: 10);
      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await advance(tester, frames: 10);
      expect(tester.takeException(), isNull);
      expect(find.text('Upagrahas'), findsOneWidget);
      expect(find.text('Gulika'), findsOneWidget);
      // The yoga tab names its families and keeps its cancellations visible.
      await tester.ensureVisible(find.text('Yogas and doshas'));
      await tester.pump();
      await tester.tap(find.text('Yogas and doshas'));
      await advance(tester, frames: 10);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Nabhasa yogas'), findsWidgets);
    },
  );
}
