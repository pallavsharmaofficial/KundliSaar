import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/profiles_cubit.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final List<SavedProfile> profiles = context.watch<ProfilesCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle, style: theme.textTheme.displaySmall),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.settings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          ToranaHeader(title: l.tagline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => context.push('/new'),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(l.newChart),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Tile(
                        icon: Icons.calendar_month_outlined,
                        label: l.tabPanchang,
                        onTap: () => context.push('/panchang'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Tile(
                        icon: Icons.favorite_outline,
                        label: l.tabMatch,
                        onTap: () => context.push('/match'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Tile(
                        icon: Icons.menu_book_outlined,
                        label: l.tabLearn,
                        onTap: () => context.push('/learn'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(l.savedCharts, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (profiles.isEmpty)
                  Panel(
                    child: Row(
                      children: <Widget>[
                        const MandalaMark(size: 56),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l.profileEmpty)),
                      ],
                    ),
                  )
                else
                  ...profiles.map(
                    (SavedProfile profile) => Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        title: Text(
                          profile.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          '${profile.localDateTime.day}/${profile.localDateTime.month}/${profile.localDateTime.year}'
                          ' · ${profile.place.name}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/chart/${profile.id}'),
                        onLongPress: () =>
                            context.read<ProfilesCubit>().remove(profile.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          DisclaimerNote(l.disclaimer),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
