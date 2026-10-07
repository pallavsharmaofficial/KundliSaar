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
import 'varshphal_sections.dart';

/// Varshphal: the chart of the moment the Sun comes back to where it was at
/// birth, read for the year that starts there.
class VarshphalScreen extends StatefulWidget {
  const VarshphalScreen({super.key});

  @override
  State<VarshphalScreen> createState() => _VarshphalScreenState();
}

class _VarshphalScreenState extends State<VarshphalScreen> {
  int? _age;

  /// The age under the thumb while the slider is being dragged. The year is
  /// only worked out when the thumb is let go: a whole Tajika reading takes a
  /// moment, and doing it at every tick of a drag would pile the work up.
  double? _dragging;

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
        final double shown = _dragging ?? age.toDouble();
        return DeferredBuilder<Varshphal>(
          key: ValueKey<int>(age),
          message: l.computing,
          work: () =>
              computeVarshphal(kundli, age, ayanamsa: settings.ayanamsa),
          builder: (BuildContext context, Varshphal varshphal) {
            final DateTime moment = varshphal.returnMoment.add(
              kundli.birth.utcOffset,
            );
            final DateTime nextMoment = varshphal.nextReturnMoment.add(
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
                        value: shown,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: '${shown.round()}',
                        onChanged: (double value) =>
                            setState(() => _dragging = value),
                        onChangeEnd: (double value) => setState(() {
                          _age = value.round();
                          _dragging = null;
                        }),
                      ),
                    ),
                    Text('${shown.round()}'),
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
                        hindi ? 'वर्ष समाप्त' : 'Year ends',
                        '${nextMoment.day}/${nextMoment.month}/${nextMoment.year} '
                        '${nextMoment.hour.toString().padLeft(2, '0')}:${nextMoment.minute.toString().padLeft(2, '0')}',
                      ),
                      FactRow(
                        hindi ? 'प्रवेश का समय' : 'Pravesh falls',
                        varshphal.isDay
                            ? (hindi ? 'दिन में' : 'by day')
                            : (hindi ? 'रात्रि में' : 'by night'),
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
                        hindi ? 'मुन्था पति' : 'Muntha lord',
                        hindi
                            ? grahaInfo(varshphal.munthaLord).hindi
                            : grahaInfo(varshphal.munthaLord).english,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(munthaReading(varshphal.munthaHouse, hindi: hindi)),
                      const SizedBox(height: 8),
                      Text(
                        munthaLordReading(varshphal).of(hindi),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 13.5,
                          height: 1.4,
                        ),
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
                YearLordSection(
                  varshphal: varshphal,
                  hindi: hindi,
                  title: l.yearLord,
                ),
                YearTimelineSection(varshphal: varshphal, hindi: hindi),
                DashaSection(varshphal: varshphal, hindi: hindi),
                TajikaSection(varshphal: varshphal, hindi: hindi),
                SahamSection(varshphal: varshphal, hindi: hindi),
                DisclaimerNote(l.disclaimer),
              ],
            );
          },
        );
      },
    );
  }
}
