import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/core/theme.dart';
import 'package:kundlisaar/data/local_store.dart';
import 'package:kundlisaar/l10n/app_localizations.dart';
import 'package:kundlisaar/palm/camera_source.dart';
import 'package:kundlisaar/palm/capture_flow.dart';
import 'package:kundlisaar/palm/crease_finder.dart';
import 'package:kundlisaar/palm/guidance.dart';
import 'package:kundlisaar/palm/palm_types.dart';
import 'package:kundlisaar/screens/hastrekha_capture_screen.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:kundlisaar/widgets/hand_guide.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/hands.dart';

Future<Widget> wrap(Widget child, {String language = 'en'}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final LocalStore store = await LocalStore.open();
  final SettingsCubit settings = SettingsCubit(store);
  await settings.setLanguage(language);
  return BlocProvider<SettingsCubit>.value(
    value: settings,
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
  );
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Lets the screen see a frame, waits a look's worth, and repeats.
Future<void> run(WidgetTester tester, FakeCamera camera, int millis) async {
  for (int t = 0; t < millis; t += 40) {
    if (t % 120 == 0) camera.push();
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  group('the guidance line', () {
    testWidgets('says each instruction in English', (WidgetTester tester) async {
      for (final Guidance g in Guidance.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GuidanceBanner(
                status: CaptureStatus(phase: CapturePhase.aiming, guidance: g),
                hindi: false,
              ),
            ),
          ),
        );
        expect(find.text(guidanceText[g]!.english), findsOneWidget, reason: '$g');
      }
    });

    testWidgets('and in Hindi', (WidgetTester tester) async {
      for (final Guidance g in Guidance.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GuidanceBanner(
                status: CaptureStatus(phase: CapturePhase.aiming, guidance: g),
                hindi: true,
              ),
            ),
          ),
        );
        expect(find.text(guidanceText[g]!.hindi), findsOneWidget, reason: '$g');
      }
    });

    testWidgets('counts down in words as well as in digits', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuidanceBanner(
              status: CaptureStatus(
                phase: CapturePhase.counting,
                guidance: Guidance.ready,
                digit: 2,
              ),
              hindi: false,
            ),
          ),
        ),
      );
      expect(find.text('Hold still… 2'), findsOneWidget);
    });
  });

  group('the count over the guide', () {
    testWidgets('shows the digit while counting', (WidgetTester tester) async {
      for (final int d in <int>[3, 2, 1]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountdownBadge(
                status: CaptureStatus(
                  phase: CapturePhase.counting,
                  guidance: Guidance.ready,
                  digit: d,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('$d'), findsOneWidget);
      }
    });

    testWidgets('shows a filling ring while the hand is being watched', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountdownBadge(
              status: CaptureStatus(
                phase: CapturePhase.steadying,
                guidance: Guidance.ready,
                progress: 0.5,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('steady-ring')), findsOneWidget);
    });

    testWidgets('shows nothing while the hand is wrong', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountdownBadge(
              status: CaptureStatus(phase: CapturePhase.aiming, guidance: Guidance.tooFar),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('steady-ring')), findsNothing);
      expect(find.text('3'), findsNothing);
    });
  });

  group('the camera screen', () {
    testWidgets('asks nothing before it has said why, and promises the photo stays', (
      WidgetTester tester,
    ) async {
      phone(tester);
      final FakeCamera camera = FakeCamera();
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            cameraFactory: () => camera,
            trackerFactory: () => ScriptedTracker(looks: <HandObservation?>[]),
          ),
        ),
      );
      await tester.pump();
      expect(camera.opened, isFalse);
      expect(find.text('Show your palm'), findsOneWidget);
      expect(find.textContaining('stays on this phone'), findsWidgets);
      expect(find.textContaining('Nothing is uploaded'), findsOneWidget);
      expect(find.text('Open the camera'), findsOneWidget);
      expect(find.text('Trace by hand instead'), findsOneWidget);
    });

    testWidgets('the explanation is in Hindi when the app is', (WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            cameraFactory: FakeCamera.new,
            trackerFactory: () => ScriptedTracker(looks: <HandObservation?>[]),
          ),
          language: 'hi',
        ),
      );
      await tester.pump();
      expect(find.text('अपनी हथेली दिखाइए'), findsOneWidget);
      expect(find.textContaining('इसी फ़ोन में रहती है'), findsWidgets);
      expect(find.text('कैमरा खोलिए'), findsOneWidget);
    });

    testWidgets('keeps the promise on the camera view too', (WidgetTester tester) async {
      phone(tester);
      final FakeCamera camera = FakeCamera();
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            cameraFactory: () => camera,
            trackerFactory: () => ScriptedTracker(looks: <HandObservation?>[]),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(camera.opened, isTrue);
      expect(
        find.text('Your photograph stays on this phone. Nothing is uploaded.'),
        findsOneWidget,
      );
      expect(find.text('Show your open palm to the camera'), findsOneWidget);
    });

    testWidgets('tells the person what to fix, as it changes', (WidgetTester tester) async {
      phone(tester);
      final FakeCamera camera = FakeCamera();
      final ScriptedTracker tracker = ScriptedTracker(
        looks: <HandObservation?>[
          syntheticHand(handLength: 300),
          syntheticHand(handLength: 300),
        ],
      );
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(cameraFactory: () => camera, trackerFactory: () => tracker),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await run(tester, camera, 600);
      expect(find.text('Move a little closer'), findsOneWidget);

      // Now too close.
      tracker.say(<HandObservation?>[syntheticHand(handLength: 1500)]);
      await run(tester, camera, 600);
      expect(find.text('Move back a little'), findsOneWidget);

      // The back of the hand.
      tracker.say(<HandObservation?>[
        syntheticHand(thumbLeft: true, rightProbability: 0.95),
      ]);
      await run(tester, camera, 600);
      expect(find.text('Show the palm, not the back of the hand'), findsOneWidget);

      // Curled fingers.
      tracker.say(<HandObservation?>[syntheticHand(curl: 0.9)]);
      await run(tester, camera, 600);
      expect(find.text('Open your fingers and keep them straight'), findsOneWidget);

      // No hand at all, in a dark room.
      tracker.say(<HandObservation?>[]);
      tracker.frameBrightness = 0.03;
      await run(tester, camera, 600);
      expect(
        find.text('Too dark. Move to a window or switch on a light'),
        findsOneWidget,
      );
    });

    testWidgets('counts down 3, 2, 1 and then reads the palm by itself', (
      WidgetTester tester,
    ) async {
      phone(tester);
      // Tall, so that the whole reading is built and can be looked through.
      tester.view.physicalSize = const Size(400, 3600);
      final FakeCamera camera = FakeCamera();
      final ScriptedTracker tracker = ScriptedTracker(
        looks: <HandObservation?>[syntheticHand()],
        scanHand: syntheticHand(),
        scanCreases: someLines(<FoundLineKind>[FoundLineKind.life, FoundLineKind.head]),
      );
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(cameraFactory: () => camera, trackerFactory: () => tracker),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final List<String> digits = <String>[];
      bool ready = false;
      for (int t = 0; t < 4000 && tracker.scans == 0; t += 40) {
        if (t % 120 == 0) camera.push();
        await tester.pump(const Duration(milliseconds: 40));
        ready = ready || find.text('Good. Stay just like that').evaluate().isNotEmpty;
        for (final String d in <String>['3', '2', '1']) {
          // The line above the guide says the same number as the big one.
          if (find.text('Hold still… $d').evaluate().isNotEmpty &&
              find.text(d).evaluate().isNotEmpty &&
              (digits.isEmpty || digits.last != d)) {
            digits.add(d);
          }
        }
      }
      expect(ready, isTrue, reason: 'the person is told the hand is good before the count');
      expect(digits, <String>['3', '2', '1'], reason: 'the count is seen, in order');
      expect(tracker.scans, 1, reason: 'one picture was taken, by itself');

      // The reading follows, with no button pressed.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Your palm'), findsOneWidget);
      expect(find.text('Left hand, seen from the palm side.'), findsOneWidget);
      expect(find.text('Hand type'), findsOneWidget);
      expect(find.text('Life line'), findsWidgets);
      expect(find.text('Head line'), findsWidgets);
      expect(find.text('Heart line'), findsNothing);
      expect(find.text('What the camera measured'), findsOneWidget);
      expect(camera.closed, isTrue, reason: 'the camera is let go once the picture is taken');
    });

    testWidgets('a hand that was not in the picture is not read', (
      WidgetTester tester,
    ) async {
      phone(tester);
      final FakeCamera camera = FakeCamera();
      final ScriptedTracker tracker = ScriptedTracker(
        looks: <HandObservation?>[syntheticHand()],
        scanHand: null,
      );
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(cameraFactory: () => camera, trackerFactory: () => tracker),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      for (int t = 0; t < 4000 && tracker.scans == 0; t += 40) {
        if (t % 120 == 0) camera.push();
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('The hand was not in that picture'), findsOneWidget);
      expect(find.text('Hand type'), findsNothing);
      expect(find.byKey(const ValueKey<String>('try-again')), findsOneWidget);
    });

    testWidgets('the back of the hand in the picture is not read', (
      WidgetTester tester,
    ) async {
      phone(tester);
      final FakeCamera camera = FakeCamera();
      final ScriptedTracker tracker = ScriptedTracker(
        looks: <HandObservation?>[syntheticHand()],
        scanHand: syntheticHand(thumbLeft: true, rightProbability: 0.95),
        scanCreases: someLines(FoundLineKind.values),
      );
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(cameraFactory: () => camera, trackerFactory: () => tracker),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      for (int t = 0; t < 4000 && tracker.scans == 0; t += 40) {
        if (t % 120 == 0) camera.push();
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('That was the back of your hand'), findsOneWidget);
      expect(find.text('Life line'), findsNothing);
    });

    testWidgets('a refused camera is handled kindly, with the other way offered', (
      WidgetTester tester,
    ) async {
      phone(tester);
      int manual = 0;
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            cameraFactory: () => FakeCamera(
              failWith: const CameraUnavailable(CameraProblem.denied, 'CameraAccessDenied'),
            ),
            trackerFactory: () => ScriptedTracker(looks: <HandObservation?>[]),
            onManual: () => manual++,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('The camera is off for this app'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('open-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('try-again')), findsOneWidget);
      expect(find.textContaining('Nothing is lost'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('trace-by-hand')));
      expect(manual, 1);
    });

    testWidgets('a camera that will not start is not blamed on the person', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            cameraFactory: () => FakeCamera(
              failWith: const CameraUnavailable(CameraProblem.unavailable),
            ),
            trackerFactory: () => ScriptedTracker(looks: <HandObservation?>[]),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('The camera could not be started'), findsOneWidget);
    });

    testWidgets('models that will not load send the person to the hand tracer', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            cameraFactory: FakeCamera.new,
            trackerFactory: () => ScriptedTracker(looks: <HandObservation?>[], failToStart: true),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Hand detection could not start on this phone'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('trace-by-hand')), findsOneWidget);
    });

    testWidgets('the hand tracer is one tap away from the camera', (
      WidgetTester tester,
    ) async {
      phone(tester);
      int manual = 0;
      final FakeCamera camera = FakeCamera();
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            cameraFactory: () => camera,
            trackerFactory: () => ScriptedTracker(looks: <HandObservation?>[]),
            onManual: () => manual++,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey<String>('trace-by-hand')));
      expect(manual, 1);
    });
  });
}
