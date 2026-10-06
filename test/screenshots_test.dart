// Phone screenshots for the Play listing, drawn by the app itself.
//
// Regenerate them with
//
//     flutter test --update-goldens test/screenshots_test.dart
//
// and they land in store/screenshots/ as 1080 x 1920 PNGs. No device or
// emulator is involved: each screen is pumped on a 360 x 640 dp phone at 3x
// with the app's real fonts, a saved profile and Hindi as the language.
//
// Without --update-goldens this file still runs, but it does not compare
// pixels. The panchang and the running dasha are computed for today, and text
// rasterises a little differently on every OS, so a byte-exact golden would
// start failing tomorrow and on the Linux CI runner. What it checks instead is
// what actually goes wrong: the screen must build without an exception or an
// overflow, must show its content rather than a loader, and the PNG already in
// store/screenshots/ must be present and 1080 x 1920.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/ask/answer_engine.dart';
import 'package:kundlisaar/core/theme.dart';
import 'package:kundlisaar/data/local_store.dart';
import 'package:kundlisaar/data/places_repository.dart';
import 'package:kundlisaar/data/profile_repository.dart';
import 'package:kundlisaar/data/time_zones.dart';
import 'package:kundlisaar/l10n/app_localizations.dart';
import 'package:kundlisaar/models/saved_profile.dart';
import 'package:kundlisaar/screens/ask_screen.dart';
import 'package:kundlisaar/screens/chart_screen.dart';
import 'package:kundlisaar/screens/hastrekha_screen.dart';
import 'package:kundlisaar/screens/home_screen.dart';
import 'package:kundlisaar/screens/panchang_screen.dart';
import 'package:kundlisaar/screens/strengths_screen.dart';
import 'package:kundlisaar/services/voice_service.dart';
import 'package:kundlisaar/state/profiles_cubit.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:kundlisaar/widgets/avatar/swamiji.dart';
import 'package:kundlisaar/widgets/nakshatra_loader.dart';
import 'package:kundlisaar/widgets/palm_canvas.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Play wants 1080 x 1920 portrait: a 360 x 640 dp phone at 3x.
const Size _physicalSize = Size(1080, 1920);
const double _pixelRatio = 3.0;

/// The folder the PNGs land in, relative to this file (test/).
const String _outDir = '../store/screenshots';

const String _profileId = 'reena';

/// Born with no planet retrograde, on purpose. The chart marks a retrograde
/// graha with the modifier letter U+1D3F, which none of the bundled fonts has;
/// a handset borrows it from a system font, the test engine has none to lend
/// and would draw a box. Rahu and Ketu are never marked.
SavedProfile _reena() => SavedProfile(
  id: _profileId,
  name: 'रीना',
  localDateTime: DateTime(1992, 5, 16, 6, 20),
  offsetMinutes: 330,
  place: const Place(
    name: 'Jaipur',
    admin: 'Rajasthan',
    country: 'IN',
    latitude: 26.9124,
    longitude: 75.7873,
    timeZoneId: 'Asia/Kolkata',
    population: 3046163,
  ),
);

/// A phone with working speech recognition, so the Ask screen shows the
/// microphone button a real handset shows. The test host has no speech
/// engine, so the real service reports it unavailable.
class _PhoneVoice extends VoiceService {
  @override
  bool get speechAvailable => true;
}

/// The fonts the theme asks for. The family names must be the ones in
/// pubspec.yaml and theme.dart; without them the test engine draws every
/// glyph as a box.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final FontLoader loader = FontLoader(family);
    for (final String file in files) {
      final Uint8List bytes = await File('assets/fonts/$file').readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  const List<String> mukta = <String>[
    'Mukta-Regular.ttf',
    'Mukta-SemiBold.ttf',
    'Mukta-Bold.ttf',
  ];
  await load('Mukta', mukta);
  // Anything the theme leaves unstyled (tab labels, small captions, chips)
  // falls back to Roboto on Android, with a system Devanagari font behind it.
  // The test host has neither, so Mukta, which covers both scripts, stands in.
  await load('Roboto', mukta);
  await load('Yatra', <String>['YatraOne-Regular.ttf']);
  await load('Tiro', <String>['TiroDevanagariHindi-Regular.ttf']);

  // Material's own icon font is bundled with the test assets because the
  // project uses material design; register it so icons are drawn, not boxes.
  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<Widget> _app(Widget home) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final LocalStore store = await LocalStore.open();
  final ProfileRepository repository = ProfileRepository(store);
  await repository.save(_reena());
  final SettingsCubit settings = SettingsCubit(store);
  await settings.setLanguage('hi');

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
        create: (_) => _PhoneVoice(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('hi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(brightness: Brightness.light),
          home: home,
        ),
      ),
    ),
  );
}

/// Pumps fixed durations instead of settling: the nakshatra loader and the
/// swamiji animate for ever, so pumpAndSettle would never return on them.
Future<void> _pump(WidgetTester tester, int millis) async {
  for (int elapsed = 0; elapsed < millis; elapsed += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Waits for deferred work to replace the loader with the real content, then
/// lets the entrance animations finish.
Future<void> _untilLoaded(WidgetTester tester) async {
  for (int i = 0; i < 200; i++) {
    if (find.byType(NakshatraLoadingView).evaluate().isEmpty) break;
    await tester.pump(const Duration(milliseconds: 50));
  }
  await _pump(tester, 600);
}

/// Pumps [home] on the Play phone and returns once it is on screen.
Future<void> _open(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = _physicalSize;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(await _app(home));
  await _untilLoaded(tester);
}

/// Checks the screen is real content, then writes (or checks) the PNG.
Future<void> _capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: '$name threw or overflowed');
  expect(
    find.byType(NakshatraLoadingView),
    findsNothing,
    reason: '$name is still showing the loader',
  );
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$_outDir/$name.png'),
  );
}

/// Re-encodes [png] as 8-bit RGB. The engine only writes RGBA, and Play wants
/// 24-bit PNGs with no alpha channel, as the other files in store/play are.
/// Every pixel of a screen is opaque, so nothing is lost.
Future<Uint8List> _withoutAlpha(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final int width = image.width;
  final int height = image.height;
  final ByteData rgba = (await image.toByteData())!;
  image.dispose();
  codec.dispose();

  // Every scanline is a filter byte (0, none) and then its RGB triples.
  final Uint8List raw = Uint8List(height * (1 + width * 3));
  int out = 0;
  for (int y = 0; y < height; y++) {
    raw[out++] = 0;
    for (int x = 0; x < width; x++) {
      final int at = (y * width + x) * 4;
      raw[out++] = rgba.getUint8(at);
      raw[out++] = rgba.getUint8(at + 1);
      raw[out++] = rgba.getUint8(at + 2);
    }
  }

  final BytesBuilder file = BytesBuilder()
    ..add(const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final Uint8List body = Uint8List.fromList(<int>[
      ...type.codeUnits,
      ...data,
    ]);
    file
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(body)
      ..add((ByteData(4)..setUint32(0, _crc32(body))).buffer.asUint8List());
  }

  chunk(
    'IHDR',
    (ByteData(13)
          ..setUint32(0, width)
          ..setUint32(4, height)
          ..setUint8(8, 8) // bits per channel
          ..setUint8(9, 2)) // colour type 2: RGB
        .buffer
        .asUint8List(),
  );
  chunk('IDAT', ZLibCodec().encode(raw));
  chunk('IEND', const <int>[]);
  return file.takeBytes();
}

int _crc32(List<int> bytes) {
  int crc = 0xFFFFFFFF;
  for (final int byte in bytes) {
    crc ^= byte;
    for (int bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// Writes the screenshots as 24-bit PNGs, and compares only what is stable
/// across days and operating systems: the stored PNG exists and is exactly the
/// size Play asks for, and the fresh render is the same size. See the note at
/// the top of the file.
class _StoreShotComparator extends LocalFileComparator {
  _StoreShotComparator(super.testFile);

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async =>
      super.update(golden, await _withoutAlpha(imageBytes));

  static (int, int) _size(Uint8List png) {
    final ByteData header = ByteData.sublistView(png);
    return (header.getUint32(16), header.getUint32(20));
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final File stored = File.fromUri(basedir.resolveUri(golden));
    if (!stored.existsSync()) {
      throw TestFailure(
        'Missing ${stored.path}. Generate it with: '
        'flutter test --update-goldens test/screenshots_test.dart',
      );
    }
    const (int, int) wanted = (1080, 1920);
    return _size(imageBytes) == wanted &&
        _size(await stored.readAsBytes()) == wanted;
  }
}

/// One screenshot. Tests draw every shadow as a hard black copy of the shape,
/// which turns the floating button into a black ring; a phone blurs it, so the
/// shadows are switched back on for the length of the test. The framework
/// insists the flag is restored before the test ends, hence the finally.
void _screenshot(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (WidgetTester tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();

  setUpAll(() async {
    await _loadFonts();
    // The voice service stops text-to-speech when it is disposed; there is no
    // plugin behind the channel on the test host, so answer for it.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (MethodCall call) async => 1,
        );
    final LocalFileComparator current =
        goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _StoreShotComparator(
      current.basedir.resolve('screenshots_test.dart'),
    );
  });

  group('store screenshots, 1080 x 1920, in Hindi', () {
    _screenshot('01-chart: the north Indian chart', (
      WidgetTester tester,
    ) async {
      await _open(tester, const ChartScreen(profileId: _profileId));
      expect(find.text('रीना'), findsWidgets);
      await _capture(tester, '01-chart');
    });

    _screenshot('02-panchang: today\'s five limbs', (
      WidgetTester tester,
    ) async {
      await _open(tester, const PanchangScreen());
      await _capture(tester, '02-panchang');
    });

    _screenshot('03-strengths: shadbala and ashtakavarga', (
      WidgetTester tester,
    ) async {
      await _open(tester, const StrengthsScreen());
      await _capture(tester, '03-strengths');
    });

    _screenshot('04-ask: the swamiji has answered', (
      WidgetTester tester,
    ) async {
      await _open(tester, const AskScreen(profileId: _profileId));
      expect(find.byType(SwamijiAvatar), findsOneWidget);
      // Ask the moon sign question and let the swamiji think and reply. The
      // list is reversed, so scroll the suggestion into view before tapping.
      final Finder question = find.text(suggestedQuestions(true)[0]);
      await tester.ensureVisible(question);
      await tester.pump();
      await tester.tap(question);
      await _pump(tester, 1500);
      expect(find.byType(OutlinedButton), findsNothing);
      await _capture(tester, '04-ask');
    });

    _screenshot('05-hastrekha: the palm tracer', (WidgetTester tester) async {
      await _open(tester, const HastrekhaScreen());
      expect(find.byType(PalmCanvas), findsOneWidget);
      await _capture(tester, '05-hastrekha');
    });

    _screenshot('06-home: a saved kundli and the features', (
      WidgetTester tester,
    ) async {
      await _open(tester, const HomeScreen());
      expect(find.text('रीना'), findsOneWidget);
      await _capture(tester, '06-home');
    });
  });
}
