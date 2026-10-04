import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../engine/astro/angles.dart';
import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/dasha.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/rashi.dart';
import '../engine/jyotish/varga.dart';
import '../engine/jyotish/yogas.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/profiles_cubit.dart';
import '../state/settings_cubit.dart';
import '../widgets/chart/chart_styles.dart';
import '../widgets/common.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key, required this.profileId});

  final String profileId;

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final AppSettings settings = context.watch<SettingsCubit>().state;
    final SavedProfile? profile = context.read<ProfilesCubit>().byId(
      widget.profileId,
    );
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.profileEmpty)),
      );
    }
    final Kundli kundli = computeKundli(
      profile.toBirthData(),
      ayanamsa: settings.ayanamsa,
    );
    final bool hindi = settings.languageCode == 'hi';

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.name),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: <Widget>[
            Tab(text: l.tabChart),
            Tab(text: l.planets),
            Tab(text: l.divisionalCharts),
            Tab(text: l.tabDasha),
            Tab(text: l.yogasAndDoshas),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chart/${profile.id}/ask'),
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(l.tabAsk),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          _ChartTab(kundli: kundli, profile: profile),
          _GrahaTab(kundli: kundli, hindi: hindi),
          _VargaTab(kundli: kundli, hindi: hindi),
          _DashaTab(kundli: kundli, hindi: hindi),
          _YogaTab(kundli: kundli, hindi: hindi),
        ],
      ),
    );
  }
}

class _ChartTab extends StatelessWidget {
  const _ChartTab({required this.kundli, required this.profile});

  final Kundli kundli;
  final SavedProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final AppSettings settings = context.watch<SettingsCubit>().state;
    final bool hindi = settings.languageCode == 'hi';
    final PlacedGraha moon = kundli.grahas[Graha.moon]!;
    final PlacedGraha sun = kundli.grahas[Graha.sun]!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        Center(
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
                context.read<SettingsCubit>().setChartStyle(value.first),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: KundliChart(
            kundli: kundli,
            style: settings.chartStyle,
            size: 340,
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          title: hindi ? 'मुख्य बातें' : 'The short version',
          child: Column(
            children: <Widget>[
              FactRow(
                l.lagna,
                '${hindi ? rashiInfo(kundli.lagnaRashi).hindi : rashiInfo(kundli.lagnaRashi).english}'
                ' · ${formatDegrees(kundli.ascendant % 30)}',
                emphasise: true,
              ),
              FactRow(
                l.moonSign,
                '${hindi ? rashiInfo(moon.rashi).hindi : rashiInfo(moon.rashi).english}'
                ' · ${formatDegrees(moon.degreesInSign)}',
                emphasise: true,
              ),
              FactRow(
                l.sunSign,
                hindi
                    ? rashiInfo(sun.rashi).hindi
                    : rashiInfo(sun.rashi).english,
              ),
              FactRow(
                l.nakshatra,
                '${hindi ? moon.nakshatra.hindi : moon.nakshatra.english}'
                ' · ${l.pada} ${moon.pada}',
              ),
              FactRow(
                hindi ? 'नक्षत्र स्वामी' : 'Nakshatra lord',
                hindi
                    ? grahaInfo(moon.nakshatra.lord).hindi
                    : grahaInfo(moon.nakshatra.lord).english,
              ),
            ],
          ),
        ),
        Panel(
          title: hindi ? 'जन्म विवरण' : 'The birth details used',
          child: Column(
            children: <Widget>[
              FactRow(
                l.birthDate,
                '${profile.localDateTime.day}/${profile.localDateTime.month}/${profile.localDateTime.year}',
              ),
              FactRow(
                l.birthTime,
                '${profile.localDateTime.hour.toString().padLeft(2, '0')}:'
                '${profile.localDateTime.minute.toString().padLeft(2, '0')}'
                '${profile.timeIsApproximate ? ' · ${l.timeNotSure}' : ''}',
              ),
              FactRow(l.birthPlace, profile.place.label),
              FactRow(l.ayanamsa, formatDegrees(kundli.ayanamsaValue)),
            ],
          ),
        ),
        if (profile.timeIsApproximate) Panel(child: Text(l.timeNotSureHelp)),
        DisclaimerNote(l.accuracyNote),
      ],
    );
  }
}

class _GrahaTab extends StatelessWidget {
  const _GrahaTab({required this.kundli, required this.hindi});

  final Kundli kundli;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: <Widget>[
        for (final Graha graha in Graha.values)
          Builder(
            builder: (BuildContext context) {
              final PlacedGraha p = kundli.grahas[graha]!;
              final GrahaInfo info = grahaInfo(graha);
              return Card(
                child: ExpansionTile(
                  shape: const Border(),
                  title: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 4,
                        child: Text(
                          hindi ? info.hindi : info.english,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Text(
                          '${hindi ? rashiInfo(p.rashi).hindi : rashiInfo(p.rashi).english}'
                          '  ${formatDegrees(p.degreesInSign)}',
                        ),
                      ),
                      Text(
                        '${l.house} ${p.house}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Wrap(
                    spacing: 6,
                    children: <Widget>[
                      if (p.isRetrograde) _Pill(l.retrograde),
                      if (p.isCombust) _Pill(l.combust),
                      _Pill(_dignityLabel(l, p.dignity)),
                    ],
                  ),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: <Widget>[
                          FactRow(
                            l.nakshatra,
                            '${hindi ? p.nakshatra.hindi : p.nakshatra.english}'
                            ' · ${l.pada} ${p.pada}',
                          ),
                          FactRow(hindi ? 'कारक' : 'Signifies', info.karaka),
                          FactRow(
                            l.deity,
                            hindi ? info.deityHindi : info.deityEnglish,
                          ),
                          FactRow(
                            hindi ? 'दैनिक गति' : 'Daily motion',
                            '${p.speed.toStringAsFixed(3)}°',
                          ),
                          FactRow(l.mantra, info.mantra),
                          FactRow(
                            l.gemstone,
                            hindi ? info.gemstoneHindi : info.gemstone,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String _dignityLabel(AppLocalizations l, Dignity dignity) =>
      switch (dignity) {
        Dignity.exalted => l.dignityExalted,
        Dignity.debilitated => l.dignityDebilitated,
        Dignity.own => l.dignityOwn,
        Dignity.moolatrikona => l.dignityMoolatrikona,
        Dignity.friend => l.dignityFriend,
        Dignity.neutral => l.dignityNeutral,
        Dignity.enemy => l.dignityEnemy,
      };
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 13.5,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _VargaTab extends StatefulWidget {
  const _VargaTab({required this.kundli, required this.hindi});

  final Kundli kundli;
  final bool hindi;

  @override
  State<_VargaTab> createState() => _VargaTabState();
}

class _VargaTabState extends State<_VargaTab> {
  Varga _varga = Varga.d9;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<SettingsCubit>().state;
    final VargaInfo info = vargaInfo(_varga);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final VargaInfo v in vargaTable)
              ChoiceChip(
                label: Text('D${v.divisions}'),
                selected: v.varga == _varga,
                onSelected: (_) => setState(() => _varga = v.varga),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: KundliChart(
            kundli: widget.kundli,
            style: settings.chartStyle,
            overrideSigns: widget.kundli.vargaPlacements(_varga),
            overrideLagna: widget.kundli.vargaLagna(_varga),
            size: 330,
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: widget.hindi ? info.hindi : info.english,
          child: Text(info.reads),
        ),
      ],
    );
  }
}

class _DashaTab extends StatelessWidget {
  const _DashaTab({required this.kundli, required this.hindi});

  final Kundli kundli;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final List<DashaPeriod> chain = kundli.dashaChainAt(now);
    String date(DateTime d) => '${d.day}/${d.month}/${d.year}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        if (chain.isNotEmpty)
          Panel(
            title: l.runningNow,
            child: Column(
              children: <Widget>[
                FactRow(
                  l.mahadasha,
                  '${hindi ? grahaInfo(chain[0].lord).hindi : grahaInfo(chain[0].lord).english}'
                  ' · ${l.to} ${date(chain[0].end)}',
                  emphasise: true,
                ),
                if (chain.length > 1)
                  FactRow(
                    l.antardasha,
                    '${hindi ? grahaInfo(chain[1].lord).hindi : grahaInfo(chain[1].lord).english}'
                    ' · ${l.to} ${date(chain[1].end)}',
                  ),
                if (chain.length > 2)
                  FactRow(
                    l.pratyantardasha,
                    '${hindi ? grahaInfo(chain[2].lord).hindi : grahaInfo(chain[2].lord).english}'
                    ' · ${l.to} ${date(chain[2].end)}',
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(l.mahadasha, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final DashaPeriod maha in kundli.vimshottari)
          Card(
            child: ExpansionTile(
              shape: const Border(),
              initiallyExpanded: chain.isNotEmpty && maha.lord == chain[0].lord,
              title: Text(
                hindi
                    ? grahaInfo(maha.lord).hindi
                    : grahaInfo(maha.lord).english,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text('${date(maha.start)} — ${date(maha.end)}'),
              children: <Widget>[
                for (final DashaPeriod antar in maha.children)
                  ListTile(
                    dense: true,
                    title: Text(
                      hindi
                          ? grahaInfo(antar.lord).hindi
                          : grahaInfo(antar.lord).english,
                    ),
                    trailing: Text(
                      '${date(antar.start)} — ${date(antar.end)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _YogaTab extends StatelessWidget {
  const _YogaTab({required this.kundli, required this.hindi});

  final Kundli kundli;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final List<YogaFinding> findings = findYogas(kundli);
    final SadeSati sadeSati = sadeSatiStatus(kundli, DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        Panel(
          title: hindi ? 'साढ़े साती' : 'Sade Sati',
          child: Text(hindi ? sadeSati.detailHindi : sadeSati.detail),
        ),
        if (findings.isEmpty)
          Panel(child: Text(l.noYogasFound))
        else
          ...findings.map(
            (YogaFinding f) => Panel(
              title: hindi ? f.nameHindi : f.nameEnglish,
              trailing: Icon(
                f.isDosha ? Icons.shield_outlined : Icons.star_outline,
                size: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Labelled(l.whyThis, hindi ? f.ruleHindi : f.ruleEnglish),
                  _Labelled(
                    l.whatItMeans,
                    hindi ? f.meaningHindi : f.meaningEnglish,
                  ),
                  if (f.isCancelled)
                    _Labelled(
                      l.cancelledBy,
                      hindi ? f.cancellationHindi! : f.cancellationEnglish!,
                    ),
                ],
              ),
            ),
          ),
        DisclaimerNote(l.disclaimer),
      ],
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled(this.label, this.text);

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13.5,
              letterSpacing: 0.3,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
