import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/jyotish/chart.dart';
import '../engine/jyotish/prashna.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/settings_cubit.dart';
import '../widgets/avatar/swamiji.dart';
import '../widgets/chart/chart_styles.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Prashna: the chart of the moment the question is asked.
class PrashnaScreen extends StatefulWidget {
  const PrashnaScreen({super.key});

  @override
  State<PrashnaScreen> createState() => _PrashnaScreenState();
}

class _PrashnaScreenState extends State<PrashnaScreen> {
  final TextEditingController _question = TextEditingController();
  PrashnaReading? _reading;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final AppSettings settings = context.watch<SettingsCubit>().state;
    final bool hindi = settings.languageCode == 'hi';

    return ChartScaffold(
      title: l.featurePrashna,
      builder: (BuildContext context, Kundli kundli, SavedProfile profile) {
        final PrashnaReading? reading = _reading;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            SwamijiPanel(
              mood: reading == null ? SwamijiMood.idle : SwamijiMood.blessing,
              caption: reading == null
                  ? (hindi
                        ? 'जो प्रश्न मन में है वही पूछिए। कुंडली उसी क्षण की बनेगी जिस क्षण आप पूछते हैं।'
                        : 'Ask the question you are actually holding. The chart is cast for the moment you ask it.')
                  : reading.verdict(hindi: hindi),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _question,
              decoration: InputDecoration(labelText: l.prashnaHint),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(l.castNow),
              onPressed: () => setState(() {
                _reading = castPrashna(
                  question: _question.text.trim(),
                  moment: DateTime.now(),
                  utcOffset: profile.toBirthData().utcOffset,
                  place: profile.place.toGeoPlace(),
                  ayanamsa: settings.ayanamsa,
                );
              }),
            ),
            if (reading != null) ...<Widget>[
              const SizedBox(height: 20),
              Center(
                child: KundliChart(
                  kundli: reading.chart,
                  style: settings.chartStyle,
                  size: 300,
                ),
              ),
              const SizedBox(height: 16),
              Panel(
                title: l.theLeaning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      reading.verdict(hindi: hindi),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hindi
                          ? 'यह उत्तर नहीं, संकेत है। प्रश्न कुंडली वही देखती है जो उस क्षण आकाश में है।'
                          : 'This is a leaning, not an answer. A prashna chart reads the sky at the moment of asking, nothing more.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Panel(
                title: l.whatItReads,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final String factor
                        in hindi ? reading.factorsHindi : reading.factors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• $factor'),
                      ),
                  ],
                ),
              ),
            ],
            DisclaimerNote(l.disclaimer),
          ],
        );
      },
    );
  }
}
