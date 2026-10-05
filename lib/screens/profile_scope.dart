import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../engine/jyotish/chart.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/profiles_cubit.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import '../widgets/nakshatra_loader.dart';

/// Screens that read a chart share this: pick a saved profile, compute the
/// kundli once, and show the nakshatra loader while heavier work runs.
class ChartScaffold extends StatefulWidget {
  const ChartScaffold({
    super.key,
    required this.title,
    required this.builder,
    this.profileId,
    this.actions,
  });

  final String title;
  final String? profileId;
  final List<Widget>? actions;
  final Widget Function(
    BuildContext context,
    Kundli kundli,
    SavedProfile profile,
  )
  builder;

  @override
  State<ChartScaffold> createState() => _ChartScaffoldState();
}

class _ChartScaffoldState extends State<ChartScaffold> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final List<SavedProfile> profiles = context.watch<ProfilesCubit>().state;
    final AppSettings settings = context.watch<SettingsCubit>().state;

    if (profiles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const MandalaMark(size: 90),
                const SizedBox(height: 16),
                Text(l.profileEmpty, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/new'),
                  child: Text(l.newChart),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final String id = widget.profileId ?? _selected ?? profiles.first.id;
    final SavedProfile profile = profiles.firstWhere(
      (SavedProfile p) => p.id == id,
      orElse: () => profiles.first,
    );
    final Kundli kundli = computeKundli(
      profile.toBirthData(),
      ayanamsa: settings.ayanamsa,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          if (profiles.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.switch_account_outlined),
              onSelected: (String value) => setState(() => _selected = value),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                for (final SavedProfile p in profiles)
                  PopupMenuItem<String>(value: p.id, child: Text(p.name)),
              ],
            ),
          ...?widget.actions,
        ],
      ),
      body: widget.builder(context, kundli, profile),
    );
  }
}

/// Runs heavy work after one frame, so the loader is on screen first.
class DeferredBuilder<T> extends StatefulWidget {
  const DeferredBuilder({
    super.key,
    required this.work,
    required this.builder,
    this.message,
  });

  final T Function() work;
  final Widget Function(BuildContext context, T value) builder;
  final String? message;

  @override
  State<DeferredBuilder<T>> createState() => _DeferredBuilderState<T>();
}

class _DeferredBuilderState<T> extends State<DeferredBuilder<T>> {
  late final Future<T> _future = _run();

  Future<T> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 32));
    return widget.work();
  }

  // The work is deliberately not re-run when the parent rebuilds: a closure is
  // never equal to the one before it, so comparing them would restart the
  // computation on every frame. Callers that need a fresh run pass a new key,
  // which gives this a fresh state anyway.

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
      if (!snapshot.hasData) {
        return NakshatraLoadingView(message: widget.message);
      }
      return widget.builder(context, snapshot.data as T);
    },
  );
}
