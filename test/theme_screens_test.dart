// Every screen in the new theme, at the sizes it is most likely to break:
// dark and light, Hindi and English, at 1.4x text (the most a phone can ask
// for under the app's clamp). Each must lay out without an overflow or any
// other exception, and must have come out of its loader.
//
// The same run can write the screens as 1080 x 1920 PNGs, the size of the
// store screenshots, for looking at. It does so only when asked:
//
//     KUNDLISAAR_SHOTS=/some/folder flutter test test/theme_screens_test.dart
//
// It uses the golden-test setup the store screenshots use (the real fonts,
// shadows switched back on, fixed pumps rather than pumpAndSettle because the
// loader and the swamiji animate for ever) but writes straight to the folder
// and compares nothing, since the panchang is computed for today and text
// rasterises a little differently on every OS.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/data/time_zones.dart';
import 'package:kundlisaar/screens/about_screen.dart';
import 'package:kundlisaar/screens/ask_screen.dart';
import 'package:kundlisaar/screens/birth_form_screen.dart';
import 'package:kundlisaar/screens/chart_screen.dart';
import 'package:kundlisaar/screens/festivals_screen.dart';
import 'package:kundlisaar/screens/ghat_chakra_screen.dart';
import 'package:kundlisaar/screens/hastrekha_screen.dart';
import 'package:kundlisaar/screens/home_screen.dart';
import 'package:kundlisaar/screens/learn_screen.dart';
import 'package:kundlisaar/screens/match_screen.dart';
import 'package:kundlisaar/screens/muhurta_screen.dart';
import 'package:kundlisaar/screens/namkaran_screen.dart';
import 'package:kundlisaar/screens/numerology_screen.dart';
import 'package:kundlisaar/screens/panchang_screen.dart';
import 'package:kundlisaar/screens/phaladesh_screen.dart';
import 'package:kundlisaar/screens/prashna_screen.dart';
import 'package:kundlisaar/screens/rashifal_screen.dart';
import 'package:kundlisaar/screens/remedies_screen.dart';
import 'package:kundlisaar/screens/sarvatobhadra_screen.dart';
import 'package:kundlisaar/screens/settings_screen.dart';
import 'package:kundlisaar/screens/strengths_screen.dart';
import 'package:kundlisaar/screens/sudarshan_screen.dart';
import 'package:kundlisaar/screens/transits_screen.dart';
import 'package:kundlisaar/screens/varshphal_screen.dart';
import 'package:kundlisaar/widgets/nakshatra_loader.dart';

import 'support/visual.dart';

/// Where to write PNGs, or null to write none.
final String? shotsDir = Platform.environment['KUNDLISAAR_SHOTS'];

typedef Variant = (Brightness, String, double);

const List<Variant> variants = <Variant>[
  (Brightness.dark, 'en', 1.4),
  (Brightness.light, 'hi', 1.4),
];

/// Extra variants drawn only when writing screenshots: the ordinary phone.
const List<Variant> shotVariants = <Variant>[
  (Brightness.light, 'hi', 1.0),
  (Brightness.dark, 'hi', 1.0),
  (Brightness.light, 'en', 1.0),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();

  setUpAll(() async {
    await loadAppFonts();
    // The voice service stops text-to-speech when it is disposed; there is no
    // plugin behind the channel on the test host, so answer for it.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (MethodCall call) async => 1,
        );
  });

  final Map<String, Widget Function()> screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'birth': () => const BirthFormScreen(),
    'ask': () => const AskScreen(profileId: 'reena'),
    'panchang': () => const PanchangScreen(),
    'match': () => const MatchScreen(),
    'learn': () => const LearnScreen(),
    'settings': () => const SettingsScreen(),
    'about': () => const AboutScreen(),
    'phaladesh': () => const PhaladeshScreen(),
    'ghat': () => const GhatChakraScreen(),
    'sarvatobhadra': () => const SarvatobhadraScreen(),
    'sudarshan': () => const SudarshanScreen(),
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
  };

  /// Shows [screen] as the app does: the home screen as the first route, any
  /// other screen pushed over it, so it gets the reading ground and not the
  /// home one.
  Future<void> show(
    WidgetTester tester,
    Widget screen,
    Variant variant, {
    bool overHome = true,
  }) async {
    final (Brightness brightness, String language, double scale) = variant;
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey<String>('shot'),
        child: await appWithProviders(
          home: overHome ? const Scaffold() : screen,
          brightness: brightness,
          locale: Locale(language),
          textScale: scale,
          navigatorKey: navigator,
        ),
      ),
    );
    if (overHome) {
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (BuildContext context) => screen),
      );
    }
    // Fixed pumps, not pumpAndSettle: the loader animates for ever.
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (i > 6 && find.byType(NakshatraLoadingView).evaluate().isEmpty) break;
    }
    for (int i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final MapEntry<String, Widget Function()> entry in screens.entries) {
    testWidgets('${entry.key} lays out in both themes and both languages at '
        '1.4x text', (WidgetTester tester) async {
      debugDisableShadows = false;
      addTearDown(tester.view.reset);
      try {
        for (final Variant v in <Variant>[
          ...variants,
          if (shotsDir != null) ...shotVariants,
        ]) {
          await show(tester, entry.value(), v, overHome: entry.key != 'home');
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} ${v.$1.name} ${v.$2} ${v.$3}x',
          );
          expect(
            find.byType(NakshatraLoadingView),
            findsNothing,
            reason: '${entry.key} is still showing its loader',
          );
          if (shotsDir != null) {
            await savePng(
              tester,
              find.byKey(const ValueKey<String>('shot')),
              '$shotsDir/${entry.key}_${v.$1.name}_${v.$2}_${v.$3}.png',
              pixelRatio: 3,
            );
          }
        }
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  // The chart screen is being reworked on its own; it is drawn for the
  // screenshots but is not asserted on here.
  if (shotsDir != null) {
    testWidgets('chart (screenshots only)', (WidgetTester tester) async {
      debugDisableShadows = false;
      addTearDown(tester.view.reset);
      try {
        for (final Variant v in <Variant>[...variants, ...shotVariants]) {
          await show(tester, const ChartScreen(profileId: 'reena'), v);
          tester.takeException();
          await savePng(
            tester,
            find.byKey(const ValueKey<String>('shot')),
            '$shotsDir/chart_${v.$1.name}_${v.$2}_${v.$3}.png',
            pixelRatio: 3,
          );
        }
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
