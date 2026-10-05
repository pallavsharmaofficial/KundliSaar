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
import 'package:kundlisaar/screens/ask_screen.dart';
import 'package:kundlisaar/screens/festivals_screen.dart';
import 'package:kundlisaar/screens/hastrekha_screen.dart';
import 'package:kundlisaar/screens/muhurta_screen.dart';
import 'package:kundlisaar/screens/namkaran_screen.dart';
import 'package:kundlisaar/screens/numerology_screen.dart';
import 'package:kundlisaar/screens/prashna_screen.dart';
import 'package:kundlisaar/screens/rashifal_screen.dart';
import 'package:kundlisaar/screens/remedies_screen.dart';
import 'package:kundlisaar/screens/strengths_screen.dart';
import 'package:kundlisaar/screens/transits_screen.dart';
import 'package:kundlisaar/screens/varshphal_screen.dart';
import 'package:kundlisaar/services/voice_service.dart';
import 'package:kundlisaar/state/profiles_cubit.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:kundlisaar/widgets/avatar/swamiji.dart';
import 'package:kundlisaar/widgets/nakshatra_loader.dart';
import 'package:kundlisaar/widgets/palm_canvas.dart';
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

/// Pumps frames without settling: the nakshatra loader animates for ever, so
/// pumpAndSettle would never return while one is on screen.
Future<void> advance(WidgetTester tester, {int frames = 40}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();

  group('every feature screen builds on a phone', () {
    final Map<String, Widget Function()> screens = <String, Widget Function()>{
      'strengths': () => const StrengthsScreen(),
      'transits': () => const TransitsScreen(),
      'today': () => const RashifalScreen(),
      'muhurta': () => const MuhurtaScreen(),
      'varshphal': () => const VarshphalScreen(),
      'numerology': () => const NumerologyScreen(),
      'prashna': () => const PrashnaScreen(),
      'festivals': () => const FestivalsScreen(),
      'namkaran': () => const NamkaranScreen(),
      'remedies': () => const RemediesScreen(),
      'hastrekha': () => const HastrekhaScreen(),
      'ask': () => const AskScreen(profileId: 'test'),
    };

    for (final MapEntry<String, Widget Function()> entry in screens.entries) {
      testWidgets(entry.key, (WidgetTester tester) async {
        tester.view.physicalSize = const Size(380, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(await wrap(entry.value()));
        await advance(tester);
        expect(tester.takeException(), isNull, reason: entry.key);
        expect(find.byType(Scaffold), findsWidgets);
      });
    }
  });

  testWidgets('the nakshatra loader names the mansion it is drawing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      await wrap(
        const Scaffold(body: NakshatraLoadingView(message: 'test')),
        language: 'en',
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ashwini'), findsOneWidget);
    expect(find.text('Ashwini Kumaras'), findsOneWidget);
    await advance(tester, frames: 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the swamiji changes face with the mood', (
    WidgetTester tester,
  ) async {
    for (final SwamijiMood mood in SwamijiMood.values) {
      await tester.pumpWidget(
        await wrap(
          Scaffold(
            body: Center(child: SwamijiAvatar(mood: mood, level: 0.5)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(SwamijiAvatar), findsOneWidget);
      expect(tester.takeException(), isNull, reason: mood.name);
    }
  });

  testWidgets('the palm screen traces, marks and reads', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(380, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await wrap(const HastrekhaScreen(), language: 'en'),
    );
    await advance(tester);

    // Drag a control point of the life line across the palm.
    final Offset canvasCentre = tester.getCenter(find.byType(PalmCanvas));
    await tester.dragFrom(canvasCentre, const Offset(12, 16));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Mark a break on the active line, then read the palm.
    await tester.scrollUntilVisible(
      find.text('Break'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Break'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Read my palm'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Read my palm'));
    await advance(tester, frames: 10);
    expect(tester.takeException(), isNull);
    expect(find.text('Hand type'), findsWidgets);
  });
}
