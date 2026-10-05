import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/astro/angles.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/rashi.dart';
import '../engine/jyotish/varshphal.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/chart/chart_styles.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Varshphal: the chart of the moment the Sun comes back to where it was at
/// birth, read for the year that starts there.
class VarshphalScreen extends StatefulWidget {
  const VarshphalScreen({super.key});

  @override
  State<VarshphalScreen> createState() => _VarshphalScreenState();
}

class _VarshphalScreenState extends State<VarshphalScreen> {
  int? _age;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final AppSettings settings = context.watch<SettingsCubit>().state;
    final bool hindi = settings.languageCode == 'hi';

    return ChartScaffold(
      title: l.featureVarshphal,
      builder: (BuildContext context, Kundli kundli, _) {
        final int currentAge =
            DateTime.now().year - kundli.birth.localDateTime.year;
        final int age = _age ?? (currentAge < 0 ? 0 : currentAge);
        return DeferredBuilder<Varshphal>(
          key: ValueKey<int>(age),
          message: l.computing,
          work: () =>
              computeVarshphal(kundli, age, ayanamsa: settings.ayanamsa),
          builder: (BuildContext context, Varshphal varshphal) {
            final ThemeData theme = Theme.of(context);
            final DateTime moment = varshphal.returnMoment.add(
              kundli.birth.utcOffset,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(l.chooseYear),
                    Expanded(
                      child: Slider(
                        value: age.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: '$age',
                        onChanged: (double value) =>
                            setState(() => _age = value.round()),
                      ),
                    ),
                    Text('$age'),
                  ],
                ),
                Center(
                  child: KundliChart(
                    kundli: varshphal.chart,
                    style: settings.chartStyle,
                    size: 320,
                  ),
                ),
                const SizedBox(height: 16),
                Panel(
                  title: l.solarReturn,
                  child: Column(
                    children: <Widget>[
                      FactRow(
                        hindi ? 'क्षण' : 'Moment',
                        '${moment.day}/${moment.month}/${moment.year} '
                        '${moment.hour.toString().padLeft(2, '0')}:${moment.minute.toString().padLeft(2, '0')}',
                        emphasise: true,
                      ),
                      FactRow(
                        l.lagna,
                        hindi
                            ? rashiInfo(varshphal.chart.lagnaRashi).hindi
                            : rashiInfo(varshphal.chart.lagnaRashi).english,
                      ),
                      FactRow(
                        l.muntha,
                        '${hindi ? rashiInfo(Rashi.values[varshphal.munthaSign]).hindi : rashiInfo(Rashi.values[varshphal.munthaSign]).english}'
                        ' · ${l.house} ${varshphal.munthaHouse}',
                      ),
                      FactRow(
                        l.yearLord,
                        hindi
                            ? grahaInfo(varshphal.yearLord).hindi
                            : grahaInfo(varshphal.yearLord).english,
                        emphasise: true,
                      ),
                    ],
                  ),
                ),
                Panel(
                  title: l.muntha,
                  child: Text(
                    munthaReading(varshphal.munthaHouse, hindi: hindi),
                  ),
                ),
                Panel(
                  title: l.yearLord,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(yearLordReading(varshphal.yearLord, hindi: hindi)),
                      const SizedBox(height: 10),
                      Text(
                        hindi
                            ? 'पाँच दावेदारों में से षड्बल के आधार पर चुना गया:'
                            : 'Chosen from the five contenders by shadbala:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final MapEntry<dynamic, double> entry
                          in varshphal.candidates.entries)
                        FactRow(
                          hindi
                              ? grahaInfo(entry.key).hindi
                              : grahaInfo(entry.key).english,
                          '${entry.value.toStringAsFixed(2)} ${l.rupas}',
                        ),
                    ],
                  ),
                ),
                Panel(
                  title: hindi
                      ? 'वर्ष कुंडली के ग्रह'
                      : 'Grahas in the year chart',
                  child: Column(
                    children: <Widget>[
                      for (final PlacedGraha graha
                          in varshphal.chart.grahas.values)
                        FactRow(
                          hindi
                              ? grahaInfo(graha.graha).hindi
                              : grahaInfo(graha.graha).english,
                          '${hindi ? rashiInfo(graha.rashi).hindi : rashiInfo(graha.rashi).english}'
                          ' ${formatDegrees(graha.degreesInSign)} · ${l.house} ${graha.house}',
                        ),
                    ],
                  ),
                ),
                DisclaimerNote(l.disclaimer),
              ],
            );
          },
        );
      },
    );
  }
}
