import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/about_screen.dart';
import '../screens/ask_screen.dart';
import '../screens/birth_form_screen.dart';
import '../screens/chart_screen.dart';
import '../screens/festivals_screen.dart';
import '../palm/hand_tracker.dart';
import '../screens/hastrekha_capture_screen.dart';
import '../screens/hastrekha_screen.dart';
import '../screens/home_screen.dart';
import '../screens/learn_screen.dart';
import '../screens/match_screen.dart';
import '../screens/muhurta_screen.dart';
import '../screens/namkaran_screen.dart';
import '../screens/numerology_screen.dart';
import '../screens/panchang_screen.dart';
import '../screens/ghat_chakra_screen.dart';
import '../screens/phaladesh_screen.dart';
import '../screens/sarvatobhadra_screen.dart';
import '../screens/sudarshan_screen.dart';
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
          PhaladeshScreen(profileId: state.uri.queryParameters['profile']),
    ),
    GoRoute(
      path: '/ghat-chakra',
      builder: (BuildContext context, GoRouterState state) =>
          GhatChakraScreen(profileId: state.uri.queryParameters['profile']),
    ),
    GoRoute(
      path: '/sarvatobhadra',
      builder: (BuildContext context, GoRouterState state) =>
          SarvatobhadraScreen(profileId: state.uri.queryParameters['profile']),
    ),
    GoRoute(
      path: '/sudarshan',
      builder: (BuildContext context, GoRouterState state) =>
          SudarshanScreen(profileId: state.uri.queryParameters['profile']),
    ),
    GoRoute(
      path: '/strengths',
      builder: (BuildContext context, GoRouterState state) =>
          StrengthsScreen(profileId: state.uri.queryParameters['profile']),
    ),
    GoRoute(
      path: '/transits',
      builder: (BuildContext context, GoRouterState state) =>
          TransitsScreen(profileId: state.uri.queryParameters['profile']),
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
      // The camera reads the palm wherever the hand models can run: on a phone,
      // and in a browser that has WebAssembly and may ask for a camera (a
      // secure page). Anywhere else the hand tracer is the screen.
      builder: (BuildContext context, GoRouterState state) =>
          handDetectionSupported
          ? const HastrekhaCaptureScreen()
          : const HastrekhaScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'manual',
          builder: (BuildContext context, GoRouterState state) =>
              const HastrekhaScreen(),
        ),
      ],
    ),
  ],
);
