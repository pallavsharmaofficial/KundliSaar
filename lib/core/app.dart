import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import 'router.dart';
import 'theme.dart';

class KundliSaarApp extends StatefulWidget {
  const KundliSaarApp({super.key});

  @override
  State<KundliSaarApp> createState() => _KundliSaarAppState();
}

class _KundliSaarAppState extends State<KundliSaarApp> {
  final GoRouter _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, AppSettings>(
      builder: (BuildContext context, AppSettings settings) {
        return MaterialApp.router(
          title: 'KundliSaar',
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(brightness: Brightness.light),
          darkTheme: buildTheme(brightness: Brightness.dark),
          builder: (BuildContext context, Widget? child) {
            final MediaQueryData media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  (settings.largeText ? 1.25 : 1.0) *
                      media.textScaler.scale(1).clamp(0.9, 1.4),
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
