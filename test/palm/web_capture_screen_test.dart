// The camera screen as the browser build shows it. The screen takes a flag for
// this (the app passes none and gets kIsWeb), so the web wording and the web
// order of things can be held to account on the same machine as the rest.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/core/theme.dart';
import 'package:kundlisaar/data/local_store.dart';
import 'package:kundlisaar/l10n/app_localizations.dart';
import 'package:kundlisaar/palm/camera_source.dart';
import 'package:kundlisaar/palm/hand_tracker.dart';
import 'package:kundlisaar/palm/palm_types.dart';
import 'package:kundlisaar/screens/hastrekha_capture_screen.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
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

void screen(WidgetTester tester, {double height = 860}) {
  tester.view.physicalSize = Size(400, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _LoggedCamera extends FakeCamera implements MirroredPreview {
  _LoggedCamera(this.log, {this.mirrored = false, super.failWith});

  final List<String> log;
  final bool mirrored;

  @override
  bool get previewMirrored => mirrored;

  @override
  Future<void> open() async {
    log.add('camera');
    return super.open();
  }
}

class _LoggedTracker extends ScriptedTracker {
  _LoggedTracker(this.log, {this.gate, List<HandObservation?>? looks})
    : super(looks: looks ?? <HandObservation?>[]);

  final List<String> log;
  final Completer<void>? gate;

  @override
  Future<void> start() async {
    log.add('models');
    await gate?.future;
    return super.start();
  }
}

class _WideCamera extends FakeCamera {
  _WideCamera(this.aspect);

  final double aspect;

  @override
  double get previewAspectRatio => aspect;
}

/// A tracker whose first [failures] looks throw, as a runtime that has trapped
/// would, and which then answers that there is no hand.
class _FailingTracker extends ScriptedTracker {
  _FailingTracker({required this.failures})
    : super(looks: <HandObservation?>[]);

  final int failures;
  int _thrown = 0;

  @override
  Future<TrackResult?> track(CameraFrame frame, int timeMs) async {
    tracked++;
    if (_thrown < failures) {
      _thrown++;
      throw StateError('the runtime trapped');
    }
    return TrackResult(hand: null, frameBrightness: 0.5, timeMs: timeMs);
  }
}

Future<void> tapOpen(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('open-camera')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('the camera screen in a browser', () {
    testWidgets(
      'says it is the browser that keeps the picture, and asks nothing yet',
      (WidgetTester tester) async {
        // Tall, so that the whole page is built and can be looked through.
        screen(tester, height: 2600);
        final List<String> log = <String>[];
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              web: true,
              cameraFactory: () => _LoggedCamera(log),
              trackerFactory: () => _LoggedTracker(log),
            ),
          ),
        );
        await tester.pump();
        expect(
          log,
          isEmpty,
          reason:
              'neither the camera nor the download is touched before the tap',
        );
        expect(find.textContaining('stays in this browser'), findsWidgets);
        expect(find.textContaining('Nothing is uploaded'), findsOneWidget);
        expect(find.textContaining('stays on this phone'), findsNothing);
        expect(
          find.textContaining('browser will ask your permission'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('download-note')),
          findsOneWidget,
        );
        expect(find.textContaining('17 MB'), findsOneWidget);
        expect(find.text('Open the camera'), findsOneWidget);
        expect(find.text('Trace by hand instead'), findsOneWidget);
      },
    );

    testWidgets('says the same in Hindi', (WidgetTester tester) async {
      screen(tester, height: 2600);
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            web: true,
            cameraFactory: FakeCamera.new,
            trackerFactory: () => ScriptedTracker(looks: <HandObservation?>[]),
          ),
          language: 'hi',
        ),
      );
      await tester.pump();
      expect(find.textContaining('इसी ब्राउज़र में'), findsWidgets);
      expect(
        find.textContaining('ब्राउज़र आपसे अनुमति पूछेगा'),
        findsOneWidget,
      );
      expect(find.textContaining('17 एमबी'), findsOneWidget);
      expect(find.text('कैमरा खोलिए'), findsOneWidget);
    });

    testWidgets(
      'has no download note on the phone, where the models are in the app',
      (WidgetTester tester) async {
        screen(tester, height: 2600);
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              cameraFactory: FakeCamera.new,
              trackerFactory: () =>
                  ScriptedTracker(looks: <HandObservation?>[]),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('download-note')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'asks for the camera first, and fetches the hand detector after it is allowed',
      (WidgetTester tester) async {
        screen(tester);
        final List<String> log = <String>[];
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              web: true,
              cameraFactory: () => _LoggedCamera(log),
              trackerFactory: () => _LoggedTracker(log),
            ),
          ),
        );
        await tapOpen(tester);
        expect(log, <String>['camera', 'models']);
        expect(find.text('Show your open palm to the camera'), findsOneWidget);
      },
    );

    testWidgets(
      'keeps the phone\'s order on the phone: the models, then the camera',
      (WidgetTester tester) async {
        screen(tester);
        final List<String> log = <String>[];
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              cameraFactory: () => _LoggedCamera(log),
              trackerFactory: () => _LoggedTracker(log),
            ),
          ),
        );
        await tapOpen(tester);
        expect(log, <String>['models', 'camera']);
      },
    );

    testWidgets(
      'says what it is waiting for while the download runs, and nothing is fetched if the camera is refused',
      (WidgetTester tester) async {
        screen(tester);
        final List<String> log = <String>[];
        final Completer<void> gate = Completer<void>();
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              web: true,
              cameraFactory: () => _LoggedCamera(log),
              trackerFactory: () => _LoggedTracker(log, gate: gate),
            ),
          ),
        );
        await tapOpen(tester);
        expect(
          find.textContaining('Loading the hand detector'),
          findsOneWidget,
        );
        expect(find.textContaining('first time only'), findsOneWidget);
        expect(find.textContaining('stays in this browser'), findsOneWidget);
        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Show your open palm to the camera'), findsOneWidget);

        final List<String> refused = <String>[];
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              key: UniqueKey(),
              web: true,
              cameraFactory: () => _LoggedCamera(
                refused,
                failWith: const CameraUnavailable(
                  CameraProblem.denied,
                  'NotAllowedError',
                ),
              ),
              trackerFactory: () => _LoggedTracker(refused),
            ),
          ),
        );
        await tapOpen(tester);
        expect(refused, <String>[
          'camera',
        ], reason: 'a person who says no costs nothing to download');
      },
    );

    testWidgets(
      'on a refusal, explains the browser\'s way of allowing it, with no phone settings button',
      (WidgetTester tester) async {
        screen(tester);
        int manual = 0;
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              web: true,
              cameraFactory: () => FakeCamera(
                failWith: const CameraUnavailable(
                  CameraProblem.denied,
                  'NotAllowedError',
                ),
              ),
              trackerFactory: () =>
                  ScriptedTracker(looks: <HandObservation?>[]),
              onManual: () => manual++,
            ),
          ),
        );
        await tapOpen(tester);
        expect(
          find.text('The camera is blocked for this page'),
          findsOneWidget,
        );
        expect(find.textContaining('beside the address'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('open-settings')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey<String>('try-again')), findsOneWidget);
        expect(find.textContaining('Nothing is lost'), findsOneWidget);
        // The hand tracer is one tap away, and that is where it goes.
        await tester.tap(find.byKey(const ValueKey<String>('trace-by-hand')));
        expect(manual, 1);
      },
    );

    testWidgets('on a refusal, says so in Hindi', (WidgetTester tester) async {
      screen(tester);
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            web: true,
            cameraFactory: () => FakeCamera(
              failWith: const CameraUnavailable(
                CameraProblem.denied,
                'NotAllowedError',
              ),
            ),
            trackerFactory: () => ScriptedTracker(looks: <HandObservation?>[]),
          ),
          language: 'hi',
        ),
      );
      await tapOpen(tester);
      expect(find.text('इस पेज के लिए कैमरा बंद है'), findsOneWidget);
      expect(find.text('हाथ से अंकित कीजिए'), findsOneWidget);
    });

    testWidgets(
      'a camera that is not there, or is busy, is not blamed on the person',
      (WidgetTester tester) async {
        screen(tester);
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              web: true,
              cameraFactory: () => FakeCamera(
                failWith: const CameraUnavailable(
                  CameraProblem.unavailable,
                  'NotFoundError',
                ),
              ),
              trackerFactory: () =>
                  ScriptedTracker(looks: <HandObservation?>[]),
            ),
          ),
        );
        await tapOpen(tester);
        expect(find.text('The camera could not be started'), findsOneWidget);
        expect(find.textContaining('browser tab'), findsOneWidget);
      },
    );

    testWidgets(
      'a download that fails sends the person to the hand tracer, and lets them try again',
      (WidgetTester tester) async {
        screen(tester);
        final FakeCamera camera = FakeCamera();
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              web: true,
              cameraFactory: () => camera,
              trackerFactory: () => ScriptedTracker(
                looks: <HandObservation?>[],
                failToStart: true,
              ),
            ),
          ),
        );
        await tapOpen(tester);
        expect(
          find.text('Hand detection could not start in this browser'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('trace-by-hand')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey<String>('try-again')), findsOneWidget);
        expect(
          camera.closed,
          isTrue,
          reason: 'the camera is let go, so its light goes out',
        );
      },
    );

    testWidgets('a phone that cannot run the models is not offered a retry', (
      WidgetTester tester,
    ) async {
      screen(tester);
      await tester.pumpWidget(
        await wrap(
          HastrekhaCaptureScreen(
            cameraFactory: FakeCamera.new,
            trackerFactory: () =>
                ScriptedTracker(looks: <HandObservation?>[], failToStart: true),
          ),
        ),
      );
      await tapOpen(tester);
      expect(find.byKey(const ValueKey<String>('try-again')), findsNothing);
    });

    testWidgets(
      'a runtime that keeps failing sends the person to the hand tracer, one bad look is forgiven',
      (WidgetTester tester) async {
        screen(tester);
        final FakeCamera camera = FakeCamera();
        final _FailingTracker tracker = _FailingTracker(failures: 2);
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              web: true,
              cameraFactory: () => camera,
              trackerFactory: () => tracker,
            ),
          ),
        );
        await tapOpen(tester);
        for (int t = 0; t < 1200; t += 40) {
          if (t % 120 == 0) camera.push();
          await tester.pump(const Duration(milliseconds: 40));
        }
        expect(tracker.tracked, greaterThan(2));
        expect(
          find.text('Hand detection could not start in this browser'),
          findsNothing,
          reason: 'two failures and then looks that work are forgiven',
        );

        final _FailingTracker broken = _FailingTracker(failures: 1000);
        final FakeCamera camera2 = FakeCamera();
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              key: UniqueKey(),
              web: true,
              cameraFactory: () => camera2,
              trackerFactory: () => broken,
            ),
          ),
        );
        await tapOpen(tester);
        for (int t = 0; t < 1200; t += 40) {
          if (t % 120 == 0) camera2.push();
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        expect(
          find.text('Hand detection could not start in this browser'),
          findsOneWidget,
        );
        expect(camera2.closed, isTrue);
        expect(
          find.byKey(const ValueKey<String>('trace-by-hand')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keeps the hand outline to a portrait shape on a wide preview, and fills a portrait one',
      (WidgetTester tester) async {
        screen(tester);
        for (final double aspect in <double>[16 / 9, 0.5625]) {
          await tester.pumpWidget(
            await wrap(
              HastrekhaCaptureScreen(
                key: UniqueKey(),
                web: true,
                cameraFactory: () => _WideCamera(aspect),
                trackerFactory: () =>
                    ScriptedTracker(looks: <HandObservation?>[]),
              ),
            ),
          );
          await tapOpen(tester);
          final Finder portraitBox = find.byWidgetPredicate(
            (Widget w) => w is AspectRatio && w.aspectRatio == 3 / 4,
          );
          expect(
            portraitBox,
            aspect > 1 ? findsOneWidget : findsNothing,
            reason: '$aspect',
          );
        }
      },
    );

    bool flipped(Widget w) =>
        w is Transform &&
        w.transform.getRow(0).x == -1 &&
        w.transform.getRow(1).y == 1;

    testWidgets(
      'turns the drawn hand to sit on a mirrored preview, and leaves it alone otherwise',
      (WidgetTester tester) async {
        screen(tester);
        for (final bool mirrored in <bool>[true, false]) {
          final List<String> log = <String>[];
          final _LoggedCamera camera = _LoggedCamera(log, mirrored: mirrored);
          await tester.pumpWidget(
            await wrap(
              HastrekhaCaptureScreen(
                key: UniqueKey(),
                web: true,
                cameraFactory: () => camera,
                trackerFactory: () => _LoggedTracker(
                  log,
                  looks: <HandObservation?>[syntheticHand()],
                ),
              ),
            ),
          );
          await tapOpen(tester);
          expect(
            find.byWidgetPredicate(flipped),
            mirrored ? findsOneWidget : findsNothing,
            reason: mirrored ? 'mirrored preview' : 'plain preview',
          );
        }
      },
    );

    testWidgets(
      'lets go of the camera when the tab is hidden, and is ready to start again',
      (WidgetTester tester) async {
        screen(tester);
        final List<String> log = <String>[];
        final _LoggedCamera camera = _LoggedCamera(log);
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              web: true,
              cameraFactory: () => camera,
              trackerFactory: () => _LoggedTracker(log),
            ),
          ),
        );
        await tapOpen(tester);
        expect(camera.closed, isFalse);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        expect(camera.closed, isTrue);
        expect(
          find.byKey(const ValueKey<String>('open-camera')),
          findsOneWidget,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      },
    );

    testWidgets(
      'does not take a phone\'s hidden state for leaving, which is only the app switcher coming up',
      (WidgetTester tester) async {
        screen(tester);
        final List<String> log = <String>[];
        final _LoggedCamera camera = _LoggedCamera(log);
        await tester.pumpWidget(
          await wrap(
            HastrekhaCaptureScreen(
              cameraFactory: () => camera,
              trackerFactory: () => _LoggedTracker(log),
            ),
          ),
        );
        await tapOpen(tester);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        expect(camera.closed, isFalse);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      },
    );
  });
}
