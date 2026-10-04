import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../engine/astro/ayanamsa.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/chart/chart_styles.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final SettingsCubit cubit = context.read<SettingsCubit>();
    final AppSettings settings = context.watch<SettingsCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Panel(
            title: l.language,
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'hi', label: Text('हिंदी')),
                ButtonSegment<String>(value: 'en', label: Text('English')),
              ],
              selected: <String>{settings.languageCode},
              onSelectionChanged: (Set<String> value) =>
                  cubit.setLanguage(value.first),
            ),
          ),
          Panel(
            title: l.chartStyle,
            child: SegmentedButton<ChartStyle>(
              segments: <ButtonSegment<ChartStyle>>[
                ButtonSegment<ChartStyle>(
                  value: ChartStyle.north,
                  label: Text(l.chartStyleNorth),
                ),
                ButtonSegment<ChartStyle>(
                  value: ChartStyle.south,
                  label: Text(l.chartStyleSouth),
                ),
                const ButtonSegment<ChartStyle>(
                  value: ChartStyle.wheel,
                  label: Text('Chakra'),
                ),
              ],
              selected: <ChartStyle>{settings.chartStyle},
              onSelectionChanged: (Set<ChartStyle> value) =>
                  cubit.setChartStyle(value.first),
            ),
          ),
          Panel(
            title: l.ayanamsa,
            child: Column(
              children: <Widget>[
                for (final Ayanamsa ayanamsa in Ayanamsa.values)
                  RadioListTile<Ayanamsa>(
                    contentPadding: EdgeInsets.zero,
                    value: ayanamsa,
                    // ignore: deprecated_member_use
                    groupValue: settings.ayanamsa,
                    // ignore: deprecated_member_use
                    onChanged: (Ayanamsa? value) {
                      if (value != null) cubit.setAyanamsa(value);
                    },
                    title: Text(ayanamsaNames[ayanamsa]!),
                  ),
              ],
            ),
          ),
          Panel(
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.largeText,
              onChanged: cubit.setLargeText,
              title: Text(l.showTheAstrology),
              subtitle: Text(l.readAloud),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(l.about),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/about'),
            ),
          ),
          DisclaimerNote(l.privacyNote),
        ],
      ),
    );
  }
}
