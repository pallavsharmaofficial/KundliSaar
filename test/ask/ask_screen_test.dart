import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/ask/answer_engine.dart';
import 'package:kundlisaar/core/theme.dart';
import 'package:kundlisaar/data/local_store.dart';
import 'package:kundlisaar/data/places_repository.dart';
import 'package:kundlisaar/data/profile_repository.dart';
import 'package:kundlisaar/data/time_zones.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/l10n/app_localizations.dart';
import 'package:kundlisaar/models/saved_profile.dart';
import 'package:kundlisaar/screens/ask_screen.dart';
import 'package:kundlisaar/services/voice_service.dart';
import 'package:kundlisaar/state/profiles_cubit.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The Ask screen shows an answer as headed parts, brings the newest answer to
// its first line, and never lets a long answer overflow a phone.

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

Future<Widget> app(String language) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final LocalStore store = await LocalStore.open();
  final ProfileRepository repository = ProfileRepository(store);
  await repository.save(profile());
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
          home: const AskScreen(profileId: 'test'),
        ),
      ),
    ),
  );
}

Future<void> advance(WidgetTester tester, {int frames = 60}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();

  for (final String language in <String>['hi', 'en']) {
    testWidgets(
      'a timing question shows all six parts, start first ($language)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(380, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(await app(language));
        await advance(tester, frames: 10);

        final bool hindi = language == 'hi';
        final String question = suggestedQuestions(hindi)[1];
        await tester.tap(find.text(question));
        await advance(tester);
        expect(tester.takeException(), isNull);

        // The same answer the screen composed, for the same chart.
        final Kundli kundli = computeKundli(profile().toBirthData());
        final Answer answer = answerQuestion(kundli, question, hindi: hindi);
        expect(answer.sections.map((AnswerSection s) => s.key), <String>[
          SectionKey.now,
          SectionKey.effect,
          SectionKey.remedy,
          SectionKey.better,
          SectionKey.how,
          SectionKey.close,
        ]);
        for (final AnswerSection s in answer.sections) {
          expect(find.text(s.heading), findsOneWidget, reason: s.key);
        }
        expect(
          find.text(hindi ? closingHindi : closingEnglish),
          findsOneWidget,
        );

        // The question and the start of the answer are on screen: the newest
        // answer is brought to its first line, not left at its last.
        final Rect asked = tester.getRect(find.text(question).last);
        expect(asked.top, greaterThanOrEqualTo(0));
        expect(asked.top, lessThan(820));
        final Rect first = tester.getRect(
          find.text(answer.sections.first.heading),
        );
        expect(first.top, lessThan(820), reason: 'the first part is in view');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a refusal stays a short refusal on screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(380, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await app('en'));
    await advance(tester, frames: 10);
    await tester.enterText(find.byType(TextField), 'will i pass my exam');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await advance(tester);
    expect(find.text('I will not answer that'), findsWidgets);
    expect(find.text('To close'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('several questions in a row stay in order and do not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await app('hi'));
    await advance(tester, frames: 10);
    final Finder list = find.byType(SingleChildScrollView).first;
    Rect bubble(String q) =>
        tester.getRect(find.descendant(of: list, matching: find.text(q)).last);

    await tester.tap(find.text(suggestedQuestions(true)[0]));
    await advance(tester);
    expect(tester.takeException(), isNull);
    for (final int i in <int>[2, 5]) {
      final String q = suggestedQuestions(true)[i];
      await tester.enterText(find.byType(TextField), q);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await advance(tester);
      expect(tester.takeException(), isNull, reason: 'question $i');
      // Each new answer is brought to its first line, so the question that
      // opens it is near the top of the list, not buried under the last one.
      expect(bubble(q).top, lessThan(400), reason: 'question $i');
      expect(bubble(q).top, greaterThanOrEqualTo(0), reason: 'question $i');
    }
    // The newest answer is the one in view, and it is a whole one.
    expect(find.text('अंत में'), findsWidgets);
    expect(find.text(closingHindi), findsWidgets);
  });
}
