import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/nakshatra.dart';
import '../engine/jyotish/rashi.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';

/// The vocabulary, with the story that goes with each piece. This is the
/// material the tradition carries and the thing the calculation apps leave out.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.learnTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l.learnGrahas),
              Tab(text: l.learnRashis),
              Tab(text: l.learnNakshatras),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                for (final GrahaInfo info in grahaTable)
                  Panel(
                    title: hindi ? info.hindi : info.english,
                    child: Column(
                      children: <Widget>[
                        FactRow(hindi ? 'संस्कृत' : 'Sanskrit', info.sanskrit),
                        FactRow(hindi ? 'कारक' : 'Signifies', info.karaka),
                        FactRow(
                          l.deity,
                          hindi ? info.deityHindi : info.deityEnglish,
                        ),
                        FactRow(l.mantra, info.mantra),
                        FactRow(
                          l.gemstone,
                          hindi ? info.gemstoneHindi : info.gemstone,
                        ),
                        FactRow(
                          l.fastingDay,
                          <String>[
                            'Sunday',
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                            'Saturday',
                          ][info.weekday],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                for (final RashiInfo info in rashiTable)
                  Panel(
                    title:
                        '${info.rashi.index + 1}. ${hindi ? info.hindi : info.english}',
                    child: Column(
                      children: <Widget>[
                        FactRow(
                          hindi ? 'प्रतीक' : 'Symbol',
                          hindi ? info.symbolHindi : info.symbolEnglish,
                        ),
                        FactRow(
                          hindi ? 'स्वामी' : 'Lord',
                          hindi
                              ? grahaInfo(info.lord).hindi
                              : grahaInfo(info.lord).english,
                        ),
                        FactRow(hindi ? 'तत्व' : 'Element', info.element.name),
                        FactRow(
                          hindi ? 'स्वभाव' : 'Quality',
                          info.quality.name,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                for (final NakshatraInfo info in nakshatraTable)
                  Panel(
                    title:
                        '${info.index + 1}. ${hindi ? info.hindi : info.english}',
                    child: Column(
                      children: <Widget>[
                        FactRow(
                          l.deity,
                          hindi ? info.deityHindi : info.deityEnglish,
                        ),
                        FactRow(
                          hindi ? 'प्रतीक' : 'Symbol',
                          info.symbolEnglish,
                        ),
                        FactRow(
                          hindi ? 'स्वामी' : 'Lord',
                          hindi
                              ? grahaInfo(info.lord).hindi
                              : grahaInfo(info.lord).english,
                        ),
                        FactRow(hindi ? 'गण' : 'Gana', info.gana.name),
                        FactRow(hindi ? 'योनि' : 'Yoni', info.yoni),
                        FactRow(hindi ? 'नाड़ी' : 'Nadi', info.nadi.name),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
