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
import 'package:kundlisaar/screens/panchang_screen.dart';
import 'package:kundlisaar/state/profiles_cubit.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedProfile profile() => SavedProfile(
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

Future<Widget> app({required String language, required bool withChart}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final LocalStore store = await LocalStore.open();
  final ProfileRepository repository = ProfileRepository(store);
  if (withChart) await repository.save(profile());
  final SettingsCubit settings = SettingsCubit(store);
  await settings.setLanguage(language);
  return MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<SettingsCubit>.value(value: settings),
      BlocProvider<ProfilesCubit>(create: (_) => ProfilesCubit(repository)),
    ],
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
      home: const PanchangScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();

  for (final String language in <String>['hi', 'en']) {
    for (final bool withChart in <bool>[true, false]) {
      testWidgets(
        'the panchang opens every section on a phone ($language, ${withChart ? 'with' : 'without'} a saved chart)',
        (WidgetTester tester) async {
          // A phone wide and tall enough that the whole list is built at once.
          tester.view.physicalSize = const Size(380, 9000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            await app(language: language, withChart: withChart),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);

          final bool hindi = language == 'hi';
          // The five limbs stay where they were.
          expect(
            find.text(hindi ? 'पंचांग के पाँच अंग' : 'The five limbs'),
            findsOneWidget,
          );
          // The new groups are present and shut.
          final Finder sections = find.byType(ExpansionTile);
          expect(sections, findsNWidgets(6));
          expect(
            find.text(
              hindi
                  ? 'अशुभ योग और वर्ज्य काल'
                  : 'Inauspicious yogas and periods',
            ),
            findsOneWidget,
          );
          expect(
            find.text(hindi ? 'आनन्दादि योग' : 'Anandadi yoga'),
            findsOneWidget,
          );

          for (int i = 0; i < 6; i++) {
            await tester.tap(
              find.byType(ExpansionTile).at(i),
              warnIfMissed: false,
            );
            await tester.pump(const Duration(milliseconds: 400));
          }
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);

          // Opened: the calendar rows and the Disha Shool line are there.
          expect(
            find.text(hindi ? 'विक्रम संवत्' : 'Vikram Samvat'),
            findsOneWidget,
          );
          expect(
            find.textContaining(hindi ? 'दिशाशूल' : 'Disha Shool'),
            findsWidgets,
          );
          expect(
            find.text(hindi ? 'दिन की होरा' : 'Day horas'),
            findsOneWidget,
          );
          if (withChart) {
            expect(find.textContaining('Test person'), findsOneWidget);
          } else {
            expect(
              find.text(
                hindi
                    ? 'अपनी कुंडली सहेजने पर ये आपके लिए देखे जाएँगे।'
                    : 'Save your chart to see these read for you.',
              ),
              findsOneWidget,
            );
          }
        },
      );
    }
  }
}
