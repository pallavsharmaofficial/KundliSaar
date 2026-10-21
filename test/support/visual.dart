import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kundlisaar/data/local_store.dart';
import 'package:kundlisaar/data/places_repository.dart';
import 'package:kundlisaar/data/profile_repository.dart';
import 'package:kundlisaar/models/saved_profile.dart';
import 'package:kundlisaar/services/voice_service.dart';
import 'package:kundlisaar/state/profiles_cubit.dart';
import 'package:kundlisaar/state/settings_cubit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/core/theme.dart';
import 'package:kundlisaar/l10n/app_localizations.dart';

/// Registers the fonts the theme asks for. Without them the test engine draws
/// every glyph as a box, Devanagari included. The family names are the ones
/// in pubspec.yaml and lib/core/theme.dart.
Future<void> loadAppFonts() async {
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
  // Whatever the theme leaves unstyled falls back to Roboto on a handset; the
  // test host has none, so Mukta, which has both scripts, stands in.
  await load('Roboto', mukta);
  await load('Yatra', <String>['YatraOne-Regular.ttf']);
  await load('Tiro', <String>['TiroDevanagariHindi-Regular.ttf']);
  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

/// A [MaterialApp] around [home], in the app's own theme, language and text
/// scale, so a widget is seen as it is on a phone.
Widget themedApp({
  required Widget home,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('hi'),
  double textScale = 1.0,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: buildTheme(brightness: Brightness.light),
    darkTheme: buildTheme(brightness: Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child ?? const SizedBox.shrink(),
    ),
    home: home,
  );
}

/// Writes whatever [boundary] shows as a PNG at [path]. For looking at: it is
/// not a golden and nothing compares against it.
Future<void> savePng(
  WidgetTester tester,
  Finder boundary,
  String path, {
  double pixelRatio = 3,
}) async {
  final RenderRepaintBoundary render = tester
      .renderObject<RenderRepaintBoundary>(boundary);
  await tester.runAsync(() async {
    final ui.Image image = await render.toImage(pixelRatio: pixelRatio);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

/// A saved profile for screens that need one. Born with no retrograde planet,
/// so the chart never asks for a glyph the test fonts lack.
SavedProfile sampleProfile() => SavedProfile(
  id: 'reena',
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

/// [home] with the providers every screen reads, a saved profile, and the
/// app's own theme.
Future<Widget> appWithProviders({
  required Widget home,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('hi'),
  double textScale = 1.0,
  bool withProfile = true,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final LocalStore store = await LocalStore.open();
  final ProfileRepository repository = ProfileRepository(store);
  if (withProfile) await repository.save(sampleProfile());
  final SettingsCubit settings = SettingsCubit(store);
  await settings.setLanguage(locale.languageCode);
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
        child: themedApp(
          home: home,
          brightness: brightness,
          locale: locale,
          textScale: textScale,
          navigatorKey: navigatorKey,
        ),
      ),
    ),
  );
}
