import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/about_screen.dart';
import '../screens/ask_screen.dart';
import '../screens/birth_form_screen.dart';
import '../screens/chart_screen.dart';
import '../screens/home_screen.dart';
import '../screens/learn_screen.dart';
import '../screens/match_screen.dart';
import '../screens/panchang_screen.dart';
import '../screens/settings_screen.dart';

/// Routes are built per instance so tests can run several apps at once.
GoRouter createRouter() => GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (BuildContext context, GoRouterState state) => const HomeScreen()),
        GoRoute(path: '/new', builder: (BuildContext context, GoRouterState state) => const BirthFormScreen()),
        GoRoute(
          path: '/chart/:id',
          builder: (BuildContext context, GoRouterState state) =>
              ChartScreen(profileId: state.pathParameters['id']!),
          routes: <RouteBase>[
            GoRoute(
              path: 'ask',
              builder: (BuildContext context, GoRouterState state) =>
                  AskScreen(profileId: state.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(path: '/panchang', builder: (BuildContext context, GoRouterState state) => const PanchangScreen()),
        GoRoute(path: '/match', builder: (BuildContext context, GoRouterState state) => const MatchScreen()),
        GoRoute(path: '/learn', builder: (BuildContext context, GoRouterState state) => const LearnScreen()),
        GoRoute(path: '/settings', builder: (BuildContext context, GoRouterState state) => const SettingsScreen()),
        GoRoute(path: '/about', builder: (BuildContext context, GoRouterState state) => const AboutScreen()),
      ],
    );
