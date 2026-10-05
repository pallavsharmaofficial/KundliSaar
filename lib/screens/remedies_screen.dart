import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/jyotish/chart.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/panchang.dart';
import '../engine/jyotish/remedies.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Upay, chosen from the chart rather than offered to everyone, with the
/// reason each graha came up stated plainly.
class RemediesScreen extends StatelessWidget {
  const RemediesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    return ChartScaffold(
      title: l.featureRemedies,
      builder: (BuildContext context, Kundli kundli, _) => DeferredBuilder<List<RemedySet>>(
        message: l.computing,
        work: () => remediesFor(kundli),
        builder: (BuildContext context, List<RemedySet> remedies) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            ToranaHeader(
              title: l.remedies,
              subtitle: hindi
                  ? 'ये उपाय इसी कुंडली से चुने गए हैं, सबके लिए एक जैसे नहीं।'
                  : 'Chosen from this chart, not handed to everyone alike.',
            ),
            if (remedies.isEmpty)
              Panel(
                child: Text(
                  hindi
                      ? 'इस कुंडली में कोई ग्रह विशेष दबाव में नहीं है। मंत्र और दान फिर भी किए जा सकते हैं।'
                      : 'No graha in this chart is under particular pressure. Mantra and giving remain open to anyone.',
                ),
              ),
            for (final RemedySet remedy in remedies)
              Panel(
                title: hindi
                    ? grahaInfo(remedy.graha).hindi
                    : grahaInfo(remedy.graha).english,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hindi ? remedy.reasonHindi : remedy.reason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FactRow(
                      l.mantra,
                      grahaInfo(remedy.graha).mantra,
                      emphasise: true,
                    ),
                    FactRow(l.japaCount, '${remedy.japaCount}'),
                    FactRow(
                      l.fastingDay,
                      hindi
                          ? weekdayNamesHindi[remedy.fastDay]
                          : weekdayNames[remedy.fastDay],
                    ),
                    FactRow(l.daan, hindi ? remedy.daanHindi : remedy.daan),
                    FactRow(l.yantra, remedy.yantra),
                    FactRow(
                      l.gemstone,
                      '${hindi ? grahaInfo(remedy.graha).gemstoneHindi : grahaInfo(remedy.graha).gemstone}'
                      ' · ${remedy.gemstoneWeight} · ${hindi ? remedy.fingerHindi : remedy.finger}',
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.10),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.wb_twilight, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  l.simpleAct,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(fontSize: 13),
                                ),
                                Text(
                                  hindi
                                      ? remedy.simpleActHindi
                                      : remedy.simpleAct,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Panel(child: Text(l.gemstoneWarning)),
            DisclaimerNote(l.disclaimer),
          ],
        ),
      ),
    );
  }
}
