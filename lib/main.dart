import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/app.dart';
import 'data/local_store.dart';
import 'data/places_repository.dart';
import 'data/profile_repository.dart';
import 'data/time_zones.dart';
import 'state/profiles_cubit.dart';
import 'state/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();
  final LocalStore store = await LocalStore.open();
  final PlacesRepository places = PlacesRepository();
  runApp(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<PlacesRepository>.value(value: places),
        RepositoryProvider<ProfileRepository>(
          create: (_) => ProfileRepository(store),
        ),
      ],
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
  );
}
