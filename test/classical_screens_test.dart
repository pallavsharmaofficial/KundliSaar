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
import 'package:kundlisaar/engine/jyotish/mat.dart';
import 'package:kundlisaar/engine/jyotish/tajika_common.dart' show Bi;
import 'package:kundlisaar/engine/jyotish/yogas.dart';
import 'package:kundlisaar/l10n/app_localizations.dart';
import 'package:kundlisaar/models/saved_profile.dart';
import 'package:kundlisaar/screens/chart_screen.dart';
import 'package:kundlisaar/screens/ghat_chakra_screen.dart';
import 'package:kundlisaar/screens/sarvatobhadra_screen.dart';
import 'package:kundlisaar/screens/sudarshan_screen.dart';
import 'package:kundlisaar/services/voice_service.dart';
import 'package:kundlisaar/state/profiles_cubit.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:kundlisaar/widgets/matbhed_card.dart';
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
      // The astrologer's view, the planets tab, then scroll to its end.
      await tester.tap(find.text('For the astrologer'));
      await advance(tester, frames: 10);
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

  Matbhed sample({required bool three}) => Matbhed(
    key: 'sample',
    topic: const Bi('Mitra saham', 'मित्र सहम'),
    whyTheyDiffer: const Bi(
      'The books read “teacher” differently.',
      'ग्रंथ “गुरु” को अलग-अलग पढ़ते हैं।',
    ),
    defaultReason: const Bi(
      'The app follows the first text.',
      'ऐप पहले ग्रंथ का अनुसरण करता है।',
    ),
    views: <Mat>[
      for (int i = 0; i < (three ? 3 : 2); i++)
        Mat(
          isDefault: i == 0,
          position: Bi('Rule number $i', 'नियम संख्या $i'),
          holder: Bi('Holder number $i', 'धारक संख्या $i'),
          reasoning: Bi('Reason number $i', 'तर्क संख्या $i'),
          result: Bi(
            'Result number $i: ${i * 10 + 12}°',
            'परिणाम संख्या $i: ${i * 10 + 12}°',
          ),
          value: i * 10 + 12.0,
        ),
    ],
  );

  for (final String language in <String>['en', 'hi']) {
    for (final bool three in <bool>[false, true]) {
      testWidgets(
        'a ${three ? 'three' : 'two'}-view card shows every position and marks the default ($language)',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(380, 1400);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = 1.4;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final bool hindi = language == 'hi';
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(brightness: Brightness.light),
              home: Scaffold(
                body: ListView(
                  children: <Widget>[
                    MatbhedCard(
                      matbhed: sample(three: three),
                      hindi: hindi,
                    ),
                  ],
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final String title = three
              ? (hindi ? 'तीन मत' : 'Three views')
              : (hindi ? 'दो मत' : 'Two views');
          expect(find.text(title), findsOneWidget);
          expect(
            find.text(hindi ? 'ऐप इसी से गिनता है' : 'App computes this'),
            findsOneWidget,
            reason: 'exactly one position is marked as the default',
          );
          for (int i = 0; i < (three ? 3 : 2); i++) {
            expect(
              find.text(
                hindi
                    ? 'परिणाम संख्या $i: ${i * 10 + 12}°'
                    : 'Result number $i: ${i * 10 + 12}°',
              ),
              findsOneWidget,
              reason: 'the computation of position $i is shown',
            );
            expect(
              find.text(hindi ? 'धारक संख्या $i' : 'Holder number $i'),
              findsOneWidget,
            );
            expect(
              find.text(hindi ? 'तर्क संख्या $i' : 'Reason number $i'),
              findsOneWidget,
            );
          }
          expect(
            find.text(hindi ? 'ऐप यही क्यों लेता है' : 'Why the app uses it'),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets(
      'the ghat chakra and the sudarshan chakra show their two views ($language)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(380, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final bool hindi = language == 'hi';
        final String title = hindi ? 'दो मत' : 'Two views';
        final String three = hindi ? 'तीन मत' : 'Three views';
        await tester.pumpWidget(
          await wrap(const GhatChakraScreen(), language: language),
        );
        await advance(tester);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('matbhed-ghat_lagna')),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(title), findsWidgets);
        expect(tester.takeException(), isNull);
        // The month card loads after the table cards.
        await tester.scrollUntilVisible(
          find.text(
            hindi
                ? 'मास का स्तंभ किसी दिन से कैसे मिलाया जाए'
                : 'How the month column is matched to a day',
          ),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          await wrap(const SudarshanScreen(), language: language),
        );
        await advance(tester, frames: 60);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('matbhed-sudarshan_nodes')),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(three), findsOneWidget);
        expect(
          find.text(
            hindi
                ? 'क्या राहु और केतु दृष्टि डालते हैं?'
                : 'Do Rahu and Ketu aspect?',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the chart screen shows the upagraha and yoga disputes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(380, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final Kundli k = computeKundli(
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
    await tester.pumpWidget(
      await wrap(const ChartScreen(profileId: 'test'), language: 'en'),
    );
    await advance(tester, frames: 10);
    await tester.tap(find.text('For the astrologer'));
    await advance(tester, frames: 10);
    await tester.tap(find.text('Grahas'));
    await advance(tester, frames: 10);
    for (int i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -700));
      await advance(tester, frames: 4);
    }
    expect(
      find.byKey(const ValueKey<String>('matbhed-upagraha_mandi')),
      findsOneWidget,
    );
    expect(find.text('Where the books differ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Yogas and doshas'));
    await tester.pump();
    await tester.tap(find.text('Yogas and doshas'));
    await advance(tester, frames: 10);
    final List<YogaMatbhed> disputed = findYogaMatbhed(k);
    expect(disputed, isNotEmpty);
    for (int i = 0; i < 25; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -900));
      await advance(tester, frames: 4);
    }
    expect(find.text('Where the texts differ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
