import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme.dart';
import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/phaladesh.dart';
import '../engine/jyotish/rashi.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Phaladesh: what the chart says each stretch of life is about, in dated
/// windows from birth to about ninety, then the houses, the periods, the
/// grahas and the slow transits that deliver what the periods promise.
class PhaladeshScreen extends StatelessWidget {
  const PhaladeshScreen({super.key, this.profileId});

  final String? profileId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    return ChartScaffold(
      title: l.featurePhaladesh,
      profileId: profileId,
      builder: (BuildContext context, Kundli kundli, _) =>
          DeferredBuilder<Phaladesh>(
            // A different chart or ayanamsa is a different reading.
            key: ValueKey<String>(
              '${kundli.birth.name}-${kundli.birth.localDateTime.toIso8601String()}-${kundli.ayanamsa.name}',
            ),
            message: l.computing,
            work: () => computePhaladesh(kundli),
            builder: (BuildContext context, Phaladesh data) =>
                _PhaladeshBody(data: data),
          ),
    );
  }
}

/// Date and name formatting in the language and the birth zone.
class _Fmt {
  const _Fmt(this.zone, this.hindi);

  final Duration zone;
  final bool hindi;

  String bi(Bi text) => text.of(hindi);
  String date(DateTime utc) => phalaDate(utc, zone).of(hindi);
  String range(DateTime a, DateTime b) => '${date(a)} – ${date(b)}';
  String graha(Graha g) => hindi ? grahaInfo(g).hindi : grahaInfo(g).english;
  String sign(Rashi r) => hindi ? rashiInfo(r).hindi : rashiInfo(r).english;
  String grahas(List<Graha> gs) => gs.map(graha).join(hindi ? ', ' : ', ');
  String years(double value) => value.toStringAsFixed(value < 10 ? 1 : 0);
}

class _PhaladeshBody extends StatelessWidget {
  const _PhaladeshBody({required this.data});

  final Phaladesh data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    final _Fmt fmt = _Fmt(data.context.zone, hindi);
    return DefaultTabController(
      length: 5,
      child: Column(
        children: <Widget>[
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: l.phTimeline),
              Tab(text: l.phHouses),
              Tab(text: l.phPeriods),
              Tab(text: l.phGrahas),
              Tab(text: l.phGochar),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _KeepAlive(
                  child: _TimelineTab(data: data, fmt: fmt),
                ),
                _KeepAlive(
                  child: _HousesTab(data: data, fmt: fmt),
                ),
                _KeepAlive(
                  child: _PeriodsTab(data: data, fmt: fmt),
                ),
                _KeepAlive(
                  child: _GrahasTab(data: data, fmt: fmt),
                ),
                _KeepAlive(
                  child: _GocharTab(data: data, fmt: fmt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps a tab built while another is showing, so the timeline keeps its
/// place, open cards stay open and the transits are not worked out twice.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(16, 8, 16, 32);

class _ToneChip extends StatelessWidget {
  const _ToneChip(this.tone);

  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final (String, Color) look = switch (tone) {
      Tone.supportive => (l.phToneSupportive, theme.colorScheme.primary),
      Tone.mixed => (
        l.phToneMixed,
        theme.colorScheme.onSurface.withValues(alpha: 0.72),
      ),
      Tone.demanding => (
        l.phToneDemanding,
        dark ? const Color(0xFFFF9E80) : Palette.sindoor,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: look.$2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: look.$2.withValues(alpha: 0.45)),
      ),
      child: Text(
        look.$1,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 13.5,
          color: look.$2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A small label over a block of text, the way the chart screen shows a yoga.
class _Labelled extends StatelessWidget {
  const _Labelled(this.label, this.text);

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

/// The factors a reading came from, one to a line.
class _Factors extends StatelessWidget {
  const _Factors({required this.basis, required this.fmt});

  final List<Bi> basis;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final Bi factor in basis)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 9, right: 10),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
                Expanded(
                  child: Text(
                    fmt.bi(factor),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14.5,
                      height: 1.45,
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

/// What the period or house asks of the person, what eases it, and why the
/// chart says so. Collapsed by default so a long list stays readable.
class _WhyBlock extends StatelessWidget {
  const _WhyBlock({
    required this.asks,
    required this.relief,
    required this.basis,
    required this.fmt,
  });

  final Bi asks;
  final Bi? relief;
  final List<Bi> basis;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          l.whyThis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: <Widget>[
          _Labelled(l.phAsks, fmt.bi(asks)),
          if (relief != null) _Labelled(l.phRelief, fmt.bi(relief!)),
          _Factors(basis: basis, fmt: fmt),
        ],
      ),
    );
  }
}

class _AreaChips extends StatelessWidget {
  const _AreaChips({required this.areas, required this.fmt});

  final List<LifeArea> areas;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final LifeArea area in areas)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              fmt.bi(area.periodTitle),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
            ),
          ),
      ],
    );
  }
}

String _dignityName(AppLocalizations l, Dignity d) => switch (d) {
  Dignity.exalted => l.dignityExalted,
  Dignity.moolatrikona => l.dignityMoolatrikona,
  Dignity.own => l.dignityOwn,
  Dignity.friend => l.dignityFriend,
  Dignity.neutral => l.dignityNeutral,
  Dignity.enemy => l.dignityEnemy,
  Dignity.debilitated => l.dignityDebilitated,
};

String _ageRange(AppLocalizations l, double from, double to, _Fmt fmt) =>
    l.phAge(fmt.years(from), fmt.years(to));

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

class _TimelineTab extends StatefulWidget {
  const _TimelineTab({required this.data, required this.fmt});

  final Phaladesh data;
  final _Fmt fmt;

  @override
  State<_TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<_TimelineTab> {
  final GlobalKey _nowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Open on the window the person is living in, not on their birth.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _nowKey.currentContext;
      if (target != null && mounted) {
        Scrollable.ensureVisible(target, alignment: 0.12);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final _Fmt fmt = widget.fmt;
    final LifeTimeline timeline = widget.data.timeline;
    final DateTime now = DateTime.now();
    final TimelineWindow? current = timeline.windowAt(now);
    final bool approximate = widget.data.context.kundli.birth.timeIsApproximate;

    // Built eagerly rather than lazily: the window the person is living in is
    // far down the list and has to exist before the page can scroll to it.
    return SingleChildScrollView(
      padding: _pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ToranaHeader(title: l.phTimelineTitle, subtitle: l.phTimelineSub),
          if (approximate) Panel(child: Text(l.phApproxTime)),
          if (current != null)
            _NowPanel(
              chain: widget.data.dasha.chainAt(now),
              window: current,
              fmt: fmt,
            ),
          for (final TimelineChapter chapter in timeline.chapters) ...<Widget>[
            _ChapterHeader(chapter: chapter, fmt: fmt),
            for (final TimelineWindow window in chapter.windows)
              _WindowRow(
                key: identical(window, current) ? _nowKey : null,
                window: window,
                isCurrent: identical(window, current),
                isLast: identical(window, timeline.windows.last),
                fmt: fmt,
              ),
          ],
          DisclaimerNote(l.phScope),
          DisclaimerNote(l.disclaimer),
        ],
      ),
    );
  }
}

class _NowPanel extends StatelessWidget {
  const _NowPanel({
    required this.chain,
    required this.window,
    required this.fmt,
  });

  final List<PeriodReading> chain;
  final TimelineWindow window;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final List<String> labels = <String>[
      l.mahadasha,
      l.antardasha,
      l.pratyantardasha,
    ];
    return Panel(
      title: l.phNow,
      trailing: _ToneChip(window.tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < chain.length; i++)
            FactRow(
              labels[i],
              '${fmt.graha(chain[i].lord)} · ${l.phUntil(fmt.date(chain[i].end))}',
              emphasise: i == 0,
            ),
          const SizedBox(height: 8),
          Text(
            fmt.bi(window.headline),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(fmt.bi(window.expect)),
        ],
      ),
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.chapter, required this.fmt});

  final TimelineChapter chapter;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final PeriodReading maha = chapter.maha;
    final double from = chapter.windows.first.ageStartYears;
    final double to = chapter.windows.last.ageEndYears;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${fmt.graha(maha.lord)} ${l.mahadasha}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            '${fmt.range(maha.start, maha.end)} · ${_ageRange(l, from, to, fmt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 6),
          Text(fmt.bi(maha.headline), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// One dated window on the rail: a dot, the dates, the lords and the reading.
class _WindowRow extends StatelessWidget {
  const _WindowRow({
    super.key,
    required this.window,
    required this.isCurrent,
    required this.isLast,
    required this.fmt,
  });

  final TimelineWindow window;
  final bool isCurrent;
  final bool isLast;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final Color line = theme.colorScheme.onSurface.withValues(alpha: 0.18);
    final Color dot = switch (window.tone) {
      Tone.supportive => theme.colorScheme.primary,
      Tone.mixed => theme.colorScheme.onSurface.withValues(alpha: 0.45),
      Tone.demanding =>
        theme.brightness == Brightness.dark
            ? const Color(0xFFFF9E80)
            : Palette.sindoor,
    };
    final double size = isCurrent ? 16 : 11;
    return Container(
      margin: const EdgeInsets.only(left: 9),
      padding: const EdgeInsets.only(left: 18),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: isLast ? Colors.transparent : line, width: 2),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                width: isCurrent ? 1.6 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          fmt.range(window.start, window.end),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (isCurrent)
                        Text(
                          l.runningNow,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13.5,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmt.graha(window.mahaLord)} – ${fmt.graha(window.antarLord)}'
                    ' · ${_ageRange(l, window.ageStartYears, window.ageEndYears, fmt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fmt.bi(window.headline),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(fmt.bi(window.expect)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _ToneChip(window.tone),
                      _AreaChips(areas: window.areas, fmt: fmt),
                    ],
                  ),
                  _WhyBlock(
                    asks: window.asks,
                    relief: window.relief,
                    basis: window.basis,
                    fmt: fmt,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -25 - (size - 11) / 2,
            top: 20,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Houses
// ---------------------------------------------------------------------------

class _HousesTab extends StatelessWidget {
  const _HousesTab({required this.data, required this.fmt});

  final Phaladesh data;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    return ListView(
      padding: _pagePadding,
      children: <Widget>[
        ToranaHeader(title: l.phHousesTitle, subtitle: l.phHousesSub),
        for (final BhavaReading house in data.bhavas)
          _HouseCard(house: house, fmt: fmt),
        DisclaimerNote(l.phScope),
        DisclaimerNote(l.disclaimer),
      ],
    );
  }
}

class _HouseCard extends StatelessWidget {
  const _HouseCard({required this.house, required this.fmt});

  final BhavaReading house;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          '${house.house} · ${fmt.bi(house.area.title)}',
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _ToneChip(house.tone),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FactRow(l.sign, fmt.sign(house.sign)),
          FactRow(l.phLord, fmt.graha(house.lord), emphasise: true),
          FactRow(
            l.phLordStands,
            '${l.house} ${house.lordHouse} · ${fmt.sign(house.lordSign)}'
            ' · ${_dignityName(l, house.lordDignity)}'
            '${house.lordCombust ? ' · ${l.combust}' : ''}'
            '${house.lordRetrograde ? ' · ${l.retrograde}' : ''}',
          ),
          FactRow(
            l.phOccupants,
            house.occupants.isEmpty ? l.phNone : fmt.grahas(house.occupants),
          ),
          FactRow(
            l.phAspects,
            house.aspectedBy.isEmpty ? l.phNone : fmt.grahas(house.aspectedBy),
          ),
          FactRow(l.sarvashtakavarga, '${house.signBindus} ${l.bindus}'),
          const SizedBox(height: 10),
          Text(
            fmt.bi(house.headline),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(fmt.bi(house.reading)),
          _WhyBlock(
            asks: house.asks,
            relief: house.relief,
            basis: house.basis,
            fmt: fmt,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Periods
// ---------------------------------------------------------------------------

class _PeriodsTab extends StatelessWidget {
  const _PeriodsTab({required this.data, required this.fmt});

  final Phaladesh data;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final DateTime now = DateTime.now();
    final List<PeriodReading> chain = data.dasha.chainAt(now);
    return ListView(
      padding: _pagePadding,
      children: <Widget>[
        ToranaHeader(title: l.phPeriodsTitle, subtitle: l.phPeriodsSub),
        for (final PeriodReading maha in data.dasha.mahadashas)
          _PeriodCard(
            period: maha,
            fmt: fmt,
            now: now,
            running: chain,
            depth: 0,
          ),
        DisclaimerNote(l.phScope),
        DisclaimerNote(l.disclaimer),
      ],
    );
  }
}

/// A period as an expansion tile; its children are the periods inside it.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.period,
    required this.fmt,
    required this.now,
    required this.running,
    required this.depth,
  });

  final PeriodReading period;
  final _Fmt fmt;
  final DateTime now;
  final List<PeriodReading> running;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final bool isRunning = running.any(
      (PeriodReading p) => identical(p, period),
    );
    final String name = switch (period.level) {
      1 => l.mahadasha,
      2 => l.antardasha,
      _ => l.pratyantardasha,
    };
    final Widget tile = ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      initiallyExpanded: isRunning && period.level < 3,
      tilePadding: EdgeInsets.symmetric(horizontal: depth == 0 ? 16 : 8),
      childrenPadding: EdgeInsets.fromLTRB(depth == 0 ? 16 : 8, 0, 8, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(
        '${fmt.graha(period.lord)} $name',
        style: period.level == 1
            ? theme.textTheme.titleMedium
            : theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isRunning ? FontWeight.w700 : FontWeight.w600,
              ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              fmt.range(period.start, period.end),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            _ToneChip(period.tone),
          ],
        ),
      ),
      children: <Widget>[
        Text(
          fmt.bi(period.headline),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _AreaChips(areas: period.areas, fmt: fmt),
        const SizedBox(height: 10),
        Text(fmt.bi(period.summary)),
        const SizedBox(height: 10),
        _Labelled(l.phPromise, fmt.bi(period.promise)),
        if (period.modifier != null)
          _Labelled(l.phModifier, fmt.bi(period.modifier!)),
        _Labelled(l.phContext, fmt.bi(period.context)),
        _WhyBlock(
          asks: period.asks,
          relief: period.relief,
          basis: period.basis,
          fmt: fmt,
        ),
        if (period.children.isNotEmpty) ...<Widget>[
          const Divider(),
          for (final PeriodReading child in period.children)
            _PeriodCard(
              period: child,
              fmt: fmt,
              now: now,
              running: running,
              depth: depth + 1,
            ),
        ],
      ],
    );
    return depth == 0 ? Card(child: tile) : tile;
  }
}

// ---------------------------------------------------------------------------
// Grahas
// ---------------------------------------------------------------------------

class _GrahasTab extends StatelessWidget {
  const _GrahasTab({required this.data, required this.fmt});

  final Phaladesh data;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: _pagePadding,
      children: <Widget>[
        ToranaHeader(title: l.phGrahasTitle, subtitle: l.phGrahasSub),
        for (final GrahaReading g in data.grahas)
          Card(
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                fmt.graha(g.graha),
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${fmt.sign(g.sign)} · ${l.house} ${g.house}'
                      ' · ${_dignityName(l, g.dignity)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    _ToneChip(g.tone),
                  ],
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (g.isCombust || g.isRetrograde)
                  FactRow(
                    l.planet,
                    <String>[
                      if (g.isCombust) l.combust,
                      if (g.isRetrograde) l.retrograde,
                    ].join(' · '),
                  ),
                if (g.companions.isNotEmpty)
                  FactRow(l.phOccupants, fmt.grahas(g.companions)),
                if (g.aspectedBy.isNotEmpty)
                  FactRow(l.phAspects, fmt.grahas(g.aspectedBy)),
                const SizedBox(height: 6),
                Text(fmt.bi(g.reading)),
                if (g.yogas.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _Labelled(
                    l.phYogas,
                    g.yogas.map((Bi y) => fmt.bi(y)).join('\n\n'),
                  ),
                ],
                _WhyBlock(
                  asks: g.asks,
                  relief: g.relief,
                  basis: g.basis,
                  fmt: fmt,
                ),
              ],
            ),
          ),
        DisclaimerNote(l.phScope),
        DisclaimerNote(l.disclaimer),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gochar
// ---------------------------------------------------------------------------

class _GocharTab extends StatelessWidget {
  const _GocharTab({required this.data, required this.fmt});

  final Phaladesh data;
  final _Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    // The transits need the ephemeris and are asked for a moment, so they are
    // computed here rather than with the rest.
    return DeferredBuilder<GocharPhala>(
      message: l.computing,
      work: () => data.gochar(now: DateTime.now()),
      builder: (BuildContext context, GocharPhala gochar) => ListView(
        padding: _pagePadding,
        children: <Widget>[
          ToranaHeader(title: l.phGocharTitle, subtitle: l.phGocharSub),
          Panel(child: Text(fmt.bi(gochar.principle))),
          if (gochar.sadeSati != null)
            Panel(title: l.sadeSati, child: Text(fmt.bi(gochar.sadeSati!))),
          for (final GocharReading r in gochar.readings)
            Panel(
              title: fmt.graha(r.graha),
              trailing: _ToneChip(r.tone),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FactRow(l.sign, fmt.sign(r.sign), emphasise: true),
                  FactRow(l.phFromMoon, '${l.house} ${r.houseFromMoon}'),
                  FactRow(l.phFromLagna, '${l.house} ${r.houseFromLagna}'),
                  FactRow(
                    l.phEntered,
                    r.entered == null ? '—' : fmt.date(r.entered!),
                  ),
                  FactRow(
                    l.phLeaves,
                    r.leaves == null ? '—' : fmt.date(r.leaves!),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fmt.bi(r.headline),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(fmt.bi(r.reading)),
                  _WhyBlock(
                    asks: r.asks,
                    relief: r.relief,
                    basis: r.basis,
                    fmt: fmt,
                  ),
                ],
              ),
            ),
          DisclaimerNote(l.phScope),
          DisclaimerNote(l.disclaimer),
        ],
      ),
    );
  }
}
