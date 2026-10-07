import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/about_screen.dart';
import '../screens/ask_screen.dart';
import '../screens/birth_form_screen.dart';
import '../screens/chart_screen.dart';
import '../screens/festivals_screen.dart';
import '../screens/hastrekha_screen.dart';
import '../screens/home_screen.dart';
import '../screens/learn_screen.dart';
import '../screens/match_screen.dart';
import '../screens/muhurta_screen.dart';
import '../screens/namkaran_screen.dart';
import '../screens/numerology_screen.dart';
import '../screens/panchang_screen.dart';
import '../screens/phaladesh_screen.dart';
import '../screens/prashna_screen.dart';
import '../screens/rashifal_screen.dart';
import '../screens/remedies_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/strengths_screen.dart';
import '../screens/transits_screen.dart';
import '../screens/varshphal_screen.dart';

/// Routes are built per instance so tests can run several apps at once.
GoRouter createRouter() => GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: '/new',
      builder: (BuildContext context, GoRouterState state) =>
          const BirthFormScreen(),
    ),
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
    GoRoute(
      path: '/panchang',
      builder: (BuildContext context, GoRouterState state) =>
          const PanchangScreen(),
    ),
    GoRoute(
      path: '/match',
      builder: (BuildContext context, GoRouterState state) =>
          const MatchScreen(),
    ),
    GoRoute(
      path: '/learn',
      builder: (BuildContext context, GoRouterState state) =>
          const LearnScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) =>
          const SettingsScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (BuildContext context, GoRouterState state) =>
          const AboutScreen(),
    ),
    GoRoute(
      path: '/phaladesh',
      builder: (BuildContext context, GoRouterState state) =>
          const PhaladeshScreen(),
    ),
    GoRoute(
      path: '/strengths',
      builder: (BuildContext context, GoRouterState state) =>
          const StrengthsScreen(),
    ),
    GoRoute(
      path: '/transits',
      builder: (BuildContext context, GoRouterState state) =>
          const TransitsScreen(),
    ),
    GoRoute(
      path: '/today',
      builder: (BuildContext context, GoRouterState state) =>
          const RashifalScreen(),
    ),
    GoRoute(
      path: '/muhurta',
      builder: (BuildContext context, GoRouterState state) =>
          const MuhurtaScreen(),
    ),
    GoRoute(
      path: '/varshphal',
      builder: (BuildContext context, GoRouterState state) =>
          const VarshphalScreen(),
    ),
    GoRoute(
      path: '/numerology',
      builder: (BuildContext context, GoRouterState state) =>
          const NumerologyScreen(),
    ),
    GoRoute(
      path: '/prashna',
      builder: (BuildContext context, GoRouterState state) =>
          const PrashnaScreen(),
    ),
    GoRoute(
      path: '/festivals',
      builder: (BuildContext context, GoRouterState state) =>
          const FestivalsScreen(),
    ),
    GoRoute(
      path: '/namkaran',
      builder: (BuildContext context, GoRouterState state) =>
          const NamkaranScreen(),
    ),
    GoRoute(
      path: '/remedies',
      builder: (BuildContext context, GoRouterState state) =>
          const RemediesScreen(),
    ),
    GoRoute(
      path: '/hastrekha',
      builder: (BuildContext context, GoRouterState state) =>
          const HastrekhaScreen(),
    ),
  ],
);
