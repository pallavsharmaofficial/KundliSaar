import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/core/app.dart';
import 'package:kundlisaar/data/local_store.dart';
import 'package:kundlisaar/data/places_repository.dart';
import 'package:kundlisaar/data/profile_repository.dart';
import 'package:kundlisaar/data/time_zones.dart';
import 'package:kundlisaar/models/saved_profile.dart';
import 'package:kundlisaar/state/profiles_cubit.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A profile that exercises the whole chain: a 1944 Indian birth, which only
/// comes out right if war time is applied.
SavedProfile warTimeProfile() => SavedProfile(
      id: 'test',
      name: 'Test person',
      localDateTime: DateTime(1944, 6, 12, 6, 0),
      offsetMinutes: TimeZones.offsetFor('Asia/Kolkata', DateTime(1944, 6, 12, 6))
          .inMinutes,
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

Future<Widget> buildApp({List<SavedProfile> profiles = const <SavedProfile>[]}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final LocalStore store = await LocalStore.open();
  final ProfileRepository repository = ProfileRepository(store);
  for (final SavedProfile profile in profiles) {
    await repository.save(profile);
  }
  return MultiRepositoryProvider(
    providers: <RepositoryProvider<dynamic>>[
      RepositoryProvider<PlacesRepository>(create: (_) => PlacesRepository()),
      RepositoryProvider<ProfileRepository>.value(value: repository),
    ],
    child: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit(store)),
        BlocProvider<ProfilesCubit>(create: (_) => ProfilesCubit(repository)),
      ],
      child: const KundliSaarApp(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();

  testWidgets('the home screen offers a new kundli in Hindi by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    expect(find.text('कुंडलीसार'), findsOneWidget);
    expect(find.text('नई कुंडली'), findsOneWidget);
  });

  testWidgets('a saved kundli opens and shows its lagna and moon sign',
      (WidgetTester tester) async {
    await tester.pumpWidget(await buildApp(profiles: <SavedProfile>[warTimeProfile()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test person'));
    await tester.pumpAndSettle();
    expect(find.text('लग्न'), findsWidgets);
    expect(find.text('चंद्र राशि'), findsWidgets);
  });

  testWidgets('war time is applied to a 1944 Indian birth',
      (WidgetTester tester) async {
    // IST+1 ran from 1 September 1942 to 15 October 1945.
    expect(
      TimeZones.offsetFor('Asia/Kolkata', DateTime(1944, 6, 12, 6)),
      const Duration(hours: 6, minutes: 30),
    );
    expect(
      TimeZones.offsetFor('Asia/Kolkata', DateTime(1946, 6, 12, 6)),
      const Duration(hours: 5, minutes: 30),
    );
  });

  testWidgets('every top-level screen lays out on a phone without overflowing',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final String label in <String>['पंचांग', 'मिलान', 'सीखें']) {
      // A fresh key forces a new router; pumping the same widget type would
      // keep the previous state and leave us on the screen we just opened.
      await tester.pumpWidget(KeyedSubtree(
        key: ValueKey<String>(label),
        child: await buildApp(profiles: <SavedProfile>[warTimeProfile()]),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'opening $label');
      expect(find.byType(Scaffold), findsWidgets);
    }
  });

  testWidgets('the chart screen draws and switches style on a phone',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(await buildApp(profiles: <SavedProfile>[warTimeProfile()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('दक्षिण भारतीय'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the language switch changes the interface to English',
      (WidgetTester tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });
}
