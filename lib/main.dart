import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'core/app.dart';
import 'data/local_store.dart';
import 'data/places_repository.dart';
import 'data/profile_repository.dart';
import 'data/time_zones.dart';
import 'services/voice_service.dart';
import 'state/profiles_cubit.dart';
import 'state/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();
  final LocalStore store = await LocalStore.open();
  final PlacesRepository places = PlacesRepository();
  final VoiceService voice = VoiceService();
  // Speech support is asked about once, at start, and never blocks the app.
  unawaited(voice.init());
  runApp(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<PlacesRepository>.value(value: places),
        RepositoryProvider<ProfileRepository>(
          create: (_) => ProfileRepository(store),
        ),
      ],
      child: ChangeNotifierProvider<VoiceService>.value(
        value: voice,
        child: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<SettingsCubit>(create: (_) => SettingsCubit(store)),
            BlocProvider<ProfilesCubit>(
              create: (BuildContext context) =>
                  ProfilesCubit(context.read<ProfileRepository>()),
            ),
          ],
          child: const KundliSaarApp(),
        ),
      ),
    ),
  );
}
