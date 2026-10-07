import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme.dart';
import '../data/places_repository.dart';
import '../data/time_zones.dart';
import '../engine/astro/houses.dart';
import '../engine/astro/time.dart';
import '../engine/jyotish/nakshatra.dart';
import '../engine/jyotish/panchang.dart';
import '../engine/jyotish/panchang_calendar.dart';
import '../engine/jyotish/panchang_details.dart';
import '../engine/jyotish/panchang_tables.dart';
import '../engine/jyotish/rashi.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/profiles_cubit.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';

class PanchangScreen extends StatefulWidget {
  const PanchangScreen({super.key});

  @override
  State<PanchangScreen> createState() => _PanchangScreenState();
}

class _PanchangScreenState extends State<PanchangScreen> {
  DateTime _date = DateTime.now();
  Place? _place;

  /// The saved chart the personal balas are read for; the first one until the
  /// user picks another.
  String? _profileId;

  // The panchang and its details cost a few hundred milliseconds between
  // them, so they are kept until the day, place or zodiac changes rather than
  // rebuilt with every frame.
  String? _cacheKey;
  Panchang? _panchang;
  PanchangDetails? _details;
  String? _natalKey;
  NatalMoon? _natal;

  Place get _effectivePlace =>
      _place ??
      context.read<ProfilesCubit>().state.firstOrNull?.place ??
      const Place(
        name: 'Delhi',
        admin: 'Delhi',
        country: 'IN',
        latitude: 28.6139,
        longitude: 77.2090,
        timeZoneId: 'Asia/Kolkata',
        population: 10927986,
      );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final AppSettings settings = context.watch<SettingsCubit>().state;
    final List<SavedProfile> profiles = context.watch<ProfilesCubit>().state;
    final bool hindi = settings.languageCode == 'hi';
    final Place place = _effectivePlace;
    final Duration offset = TimeZones.offsetFor(place.timeZoneId, _date);

    final String key =
        '${_date.year}-${_date.month}-${_date.day}|${place.latitude}|${place.longitude}|${offset.inMinutes}|${settings.ayanamsa.name}';
    if (_cacheKey != key || _panchang == null || _details == null) {
      final Panchang computed = computePanchang(
        localDate: _date,
        utcOffset: offset,
        place: GeoPlace(
          name: place.label,
          latitude: place.latitude,
          longitude: place.longitude,
          timeZoneId: place.timeZoneId,
        ),
        ayanamsa: settings.ayanamsa,
      );
      _panchang = computed;
      _details = computePanchangDetails(computed);
      _cacheKey = key;
    }
    final Panchang panchang = _panchang!;
    final PanchangDetails details = _details!;

    // The Moon of the chart the balas are read for. It is taken from the birth
    // moment directly, with the same longitude the panchang itself uses.
    SavedProfile? profile;
    if (profiles.isNotEmpty) {
      profile = profiles.firstWhere(
        (SavedProfile p) => p.id == _profileId,
        orElse: () => profiles.first,
      );
    }
    NatalMoon? natal;
    if (profile != null) {
      final String natalKey = '${profile.id}|${settings.ayanamsa.name}';
      if (_natalKey != natalKey || _natal == null) {
        _natal = natalMoonAt(
          localDateTime: profile.localDateTime,
          utcOffset: Duration(minutes: profile.offsetMinutes),
          ayanamsa: settings.ayanamsa,
        );
        _natalKey = natalKey;
      }
      natal = _natal;
    }

    final _Clock clockOf = _Clock(
      offset: offset,
      day: DateTime(_date.year, _date.month, _date.day),
      hindi: hindi,
    );
    String clock(double? jdUt) => jdUt == null ? '—' : clockOf.hm(jdUt);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabPanchang),
        actions: <Widget>[
          if (profiles.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.switch_account_outlined),
              tooltip: hindi
                  ? 'किसकी कुंडली से बल देखें'
                  : 'Whose chart for the balas',
              onSelected: (String value) => setState(() => _profileId = value),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                for (final SavedProfile p in profiles)
                  PopupMenuItem<String>(value: p.id, child: Text(p.name)),
              ],
            ),
          IconButton(
            tooltip: l.birthDate,
            icon: const Icon(Icons.event_outlined),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1900),
                lastDate: DateTime(2069, 12, 31),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          ToranaHeader(
            title: '${_date.day}/${_date.month}/${_date.year}',
            subtitle:
                '${place.label} · ${hindi ? weekdayNamesHindi[panchang.weekday] : weekdayNames[panchang.weekday]}',
          ),
          Panel(
            title: hindi ? 'पंचांग के पाँच अंग' : 'The five limbs',
            child: Column(
              children: <Widget>[
                FactRow(
                  l.tithi,
                  '${hindi ? panchang.tithi.nameHindi : panchang.tithi.name} · ${hindi ? pakshaNameHindi(panchang.paksha) : panchang.paksha} · ${l.untilTime(clock(panchang.tithi.endsAtJdUt))}',
                  emphasise: true,
                ),
                FactRow(
                  l.nakshatra,
                  '${hindi ? panchang.nakshatra.nameHindi : panchang.nakshatra.name} · ${l.untilTime(clock(panchang.nakshatra.endsAtJdUt))}',
                ),
                FactRow(
                  l.yoga,
                  '${hindi ? panchang.yoga.nameHindi : panchang.yoga.name} · ${l.untilTime(clock(panchang.yoga.endsAtJdUt))}',
                ),
                FactRow(
                  l.karana,
                  '${hindi ? panchang.karana.nameHindi : panchang.karana.name} · ${l.untilTime(clock(panchang.karana.endsAtJdUt))}',
                ),
                FactRow(
                  l.vara,
                  hindi
                      ? weekdayNamesHindi[panchang.weekday]
                      : weekdayNames[panchang.weekday],
                ),
              ],
            ),
          ),
          _CalendarSection(calendar: details.calendar, hindi: hindi),
          Panel(
            title: hindi ? 'सूर्य और चंद्र' : 'Sun and Moon',
            child: Column(
              children: <Widget>[
                FactRow(l.sunrise, clock(panchang.sunrise), emphasise: true),
                FactRow(l.sunset, clock(panchang.sunset), emphasise: true),
                FactRow(l.moonrise, clock(panchang.moonrise)),
                FactRow(l.moonset, clock(panchang.moonset)),
                FactRow(
                  l.ayanamsa,
                  l.ayanamsaValue(panchang.ayanamsaDegrees.toStringAsFixed(4)),
                ),
              ],
            ),
          ),
          Panel(
            title: hindi ? 'शुभ और अशुभ काल' : 'Auspicious and inauspicious',
            child: Column(
              children: <Widget>[
                FactRow(
                  l.abhijit,
                  '${clock(panchang.abhijit?.startJdUt)} — ${clock(panchang.abhijit?.endJdUt)}',
                ),
                FactRow(
                  l.rahuKaal,
                  '${clock(panchang.rahuKaal?.startJdUt)} — ${clock(panchang.rahuKaal?.endJdUt)}',
                ),
                FactRow(
                  l.yamaganda,
                  '${clock(panchang.yamaganda?.startJdUt)} — ${clock(panchang.yamaganda?.endJdUt)}',
                ),
                FactRow(
                  l.gulika,
                  '${clock(panchang.gulika?.startJdUt)} — ${clock(panchang.gulika?.endJdUt)}',
                ),
              ],
            ),
          ),
          _WindowSection(
            storageKey: 'inauspicious',
            title: hindi
                ? 'अशुभ योग और वर्ज्य काल'
                : 'Inauspicious yogas and periods',
            icon: Icons.warning_amber_rounded,
            windows: details.inauspicious,
            allNotes: const <RuleNote>[
              panchakNote,
              bhadraNote,
              gandMoolNote,
              vinchhudoNote,
              jwalamukhiNote,
              aadalNote,
              vidaalNote,
            ],
            emptyText: hindi
                ? 'आज कोई अशुभ योग या वर्ज्य काल नहीं है।'
                : 'No inauspicious yoga or period today.',
            clock: clockOf,
          ),
          _WindowSection(
            storageKey: 'auspicious',
            title: hindi ? 'शुभ योग' : 'Auspicious yogas',
            icon: Icons.auto_awesome_outlined,
            windows: details.auspicious,
            allNotes: const <RuleNote>[
              sarvarthaSiddhiNote,
              amritSiddhiNote,
              raviPushyaNote,
              guruPushyaNote,
              raviYogaNote,
              dwipushkarNote,
              tripushkarNote,
            ],
            emptyText: hindi
                ? 'आज कोई विशेष शुभ योग नहीं है।'
                : 'No special auspicious yoga today.',
            clock: clockOf,
          ),
          _BalaSection(
            details: details,
            natal: natal,
            profileName: profile?.name,
            clock: clockOf,
          ),
          _AnandadiSection(details: details, clock: clockOf),
          Panel(
            title: l.choghadiyaDay,
            child: Column(
              children: <Widget>[
                for (final TimeSpan span in panchang.dayChoghadiya)
                  FactRow(
                    hindi ? span.titleHindi : span.title,
                    '${clock(span.startJdUt)} — ${clock(span.endJdUt)}',
                  ),
              ],
            ),
          ),
          Panel(
            title: l.choghadiyaNight,
            child: Column(
              children: <Widget>[
                for (final TimeSpan span in panchang.nightChoghadiya)
                  FactRow(
                    hindi ? span.titleHindi : span.title,
                    '${clock(span.startJdUt)} — ${clock(span.endJdUt)}',
                  ),
              ],
            ),
          ),
          _HoraSection(panchang: panchang, clock: clockOf),
          DisclaimerNote(l.accuracyNote),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time formatting
// ---------------------------------------------------------------------------

/// Clock times in the place's own zone as HH:mm, and the windows built from
/// them. A time that falls on another civil day than the panchang's is marked,
/// and a window that crosses midnight says so.
class _Clock {
  const _Clock({required this.offset, required this.day, required this.hindi});

  final Duration offset;

  /// The civil date the panchang is for, at midnight.
  final DateTime day;
  final bool hindi;

  DateTime _local(double jdUt) => utcFromJulianDay(jdUt).add(offset);

  DateTime _civil(double jdUt) {
    final DateTime l = _local(jdUt);
    return DateTime(l.year, l.month, l.day);
  }

  String hm(double jdUt) {
    final DateTime l = _local(jdUt);
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  /// The day marker for a time, empty when it falls on the panchang's own day.
  String tag(double jdUt) {
    final DateTime civil = _civil(jdUt);
    final int diff = DateTime.utc(
      civil.year,
      civil.month,
      civil.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
    if (diff == 0) return '';
    if (diff == 1) return hindi ? ' (अगला दिन)' : ' (next day)';
    if (diff == -1) return hindi ? ' (पिछला दिन)' : ' (previous day)';
    return ' (${civil.day}/${civil.month})';
  }

  String timeWithTag(double jdUt) => '${hm(jdUt)}${tag(jdUt)}';

  /// "from 22:10 to 03:05 (next day)".
  String span(double startJdUt, double endJdUt) => hindi
      ? '${timeWithTag(startJdUt)} से ${timeWithTag(endJdUt)} तक'
      : 'from ${timeWithTag(startJdUt)} to ${timeWithTag(endJdUt)}';

  bool crossesMidnight(double startJdUt, double endJdUt) =>
      _civil(startJdUt) != _civil(endJdUt);
}

// ---------------------------------------------------------------------------
// Collapsible sections
// ---------------------------------------------------------------------------

/// The app's collapsible group: a card that opens to its rows, with a line of
/// summary showing under the title while it is shut.
class _Section extends StatelessWidget {
  const _Section({
    required this.storageKey,
    required this.title,
    required this.summary,
    required this.icon,
    required this.children,
  });

  final String storageKey;
  final String title;
  final String summary;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        key: PageStorageKey<String>('panchang-$storageKey'),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: summary.isEmpty
            ? null
            : Text(
                summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 14,
          height: 1.45,
          fontWeight: strong ? FontWeight.w600 : null,
          color: theme.colorScheme.onSurface.withValues(
            alpha: strong ? 0.85 : 0.68,
          ),
        ),
      ),
    );
  }
}

Color _toneColor(BuildContext context, PanchangTone tone) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    PanchangTone.auspicious => scheme.primary,
    PanchangTone.inauspicious => Palette.sindoor,
    PanchangTone.neutral => scheme.onSurface.withValues(alpha: 0.55),
  };
}

IconData _toneIcon(PanchangTone tone) => switch (tone) {
  PanchangTone.auspicious => Icons.check_circle_outline,
  PanchangTone.inauspicious => Icons.error_outline,
  PanchangTone.neutral => Icons.remove_circle_outline,
};

/// One named window: its name, what it is, when it runs, and what it means.
class _WindowTile extends StatelessWidget {
  const _WindowTile({required this.window, required this.clock});

  final PanchangWindow window;
  final _Clock clock;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hindi = clock.hindi;
    final String label = hindi ? window.labelHindi : window.label;
    final String detail = hindi ? window.detailHindi : window.detail;
    final bool crosses = clock.crossesMidnight(
      window.startJdUt,
      window.endJdUt,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(
              _toneIcon(window.tone),
              size: 22,
              color: _toneColor(context, window.tone),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hindi ? window.nameHindi : window.name,
                  style: theme.textTheme.titleMedium,
                ),
                if (label.isNotEmpty)
                  Text(label, style: theme.textTheme.bodyMedium),
                Text(
                  clock.span(window.startJdUt, window.endJdUt),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (crosses)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.nights_stay_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            hindi
                                ? 'मध्यरात्रि पार करता है'
                                : 'Crosses midnight',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _Caption(hindi ? window.meaningHindi : window.meaning),
                if (detail.isNotEmpty) _Caption(detail, strong: true),
                for (final WindowPart part in window.parts)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: _Caption(
                      '${clock.span(part.startJdUt, part.endJdUt)}: ${hindi ? part.detailHindi : part.detail}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A group of windows, with the names of the ones not running today listed in
/// one quiet line so the absence is as readable as the presence.
class _WindowSection extends StatelessWidget {
  const _WindowSection({
    required this.storageKey,
    required this.title,
    required this.icon,
    required this.windows,
    required this.allNotes,
    required this.emptyText,
    required this.clock,
  });

  final String storageKey;
  final String title;
  final IconData icon;
  final List<PanchangWindow> windows;
  final List<RuleNote> allNotes;
  final String emptyText;
  final _Clock clock;

  @override
  Widget build(BuildContext context) {
    final bool hindi = clock.hindi;
    final Set<String> running = <String>{
      for (final PanchangWindow w in windows) w.key,
    };
    final List<String> absent = <String>[
      for (final RuleNote n in allNotes)
        if (!running.contains(n.key)) hindi ? n.nameHindi : n.name,
    ];
    final String summary = windows.isEmpty
        ? emptyText
        : <String>{
            for (final PanchangWindow w in windows)
              hindi ? w.nameHindi : w.name,
          }.join(' · ');
    return _Section(
      storageKey: storageKey,
      title: title,
      summary: summary,
      icon: icon,
      children: <Widget>[
        if (windows.isEmpty) _Caption(emptyText),
        for (final PanchangWindow w in windows)
          _WindowTile(window: w, clock: clock),
        if (windows.isNotEmpty && absent.isNotEmpty)
          _Caption('${hindi ? 'आज नहीं' : 'Not today'}: ${absent.join(' · ')}'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar
// ---------------------------------------------------------------------------

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({required this.calendar, required this.hindi});

  final PanchangCalendar calendar;
  final bool hindi;

  String _degrees(double d) {
    final int whole = d.floor();
    final int minutes = ((d - whole) * 60).floor();
    return '$whole°${minutes.toString().padLeft(2, '0')}′';
  }

  @override
  Widget build(BuildContext context) {
    final PanchangCalendar c = calendar;
    String pick(String en, String hi) => hindi ? hi : en;
    final String amanta = pick(c.amanta.name, c.amanta.nameHindi);
    final String purnimanta = pick(c.purnimanta.name, c.purnimanta.nameHindi);
    final String samvatsara = pick(c.samvatsara.name, c.samvatsara.nameHindi);
    String note(RuleNote n) => hindi ? n.meaningHindi : n.meaning;
    return _Section(
      storageKey: 'calendar',
      title: hindi ? 'संवत्, मास और ऋतु' : 'Samvat, month and season',
      summary: hindi
          ? 'विक्रम संवत् ${c.vikramSamvat} · $purnimanta (पूर्णिमांत) · $amanta (अमांत)'
          : 'Vikram ${c.vikramSamvat} · $purnimanta (purnimanta) · $amanta (amanta)',
      icon: Icons.calendar_month_outlined,
      children: <Widget>[
        FactRow(pick('Vikram Samvat', 'विक्रम संवत्'), '${c.vikramSamvat}'),
        _Caption(note(vikramSamvatNote)),
        FactRow(
          pick('Shaka Samvat', 'शक संवत्'),
          '${c.shakaSamvat} · ${pick('samvatsara', 'संवत्सर')} $samvatsara',
        ),
        _Caption(note(shakaSamvatNote)),
        FactRow(
          pick('Kali Samvat', 'कलि संवत्'),
          '${c.kaliSamvat} · ${pick('Ahargana', 'अहर्गण')} ${c.kaliAhargana}',
        ),
        _Caption(note(kaliSamvatNote)),
        const Divider(),
        FactRow(pick('Month, Amanta', 'मास, अमांत'), amanta, emphasise: true),
        FactRow(
          pick('Month, Purnimanta', 'मास, पूर्णिमांत'),
          purnimanta,
          emphasise: true,
        ),
        _Caption(
          c.monthsDiffer
              ? pick(
                  'Today is in the dark half, so the two reckonings name the month differently.',
                  'आज कृष्ण पक्ष है, इसलिए दोनों गणनाओं में मास का नाम अलग है।',
                )
              : pick(
                  'Today is in the bright half, so both reckonings give the same month.',
                  'आज शुक्ल पक्ष है, इसलिए दोनों गणनाओं में मास एक ही है।',
                ),
        ),
        _Caption(note(lunarMonthNote)),
        FactRow(
          pick('Paksha', 'पक्ष'),
          pick(c.paksha.name, c.paksha.nameHindi),
        ),
        _Caption(note(pakshaNote)),
        const Divider(),
        FactRow(
          pick('Ritu, Vedic', 'ऋतु, वैदिक'),
          pick(c.vedicRitu.name, c.vedicRitu.nameHindi),
        ),
        FactRow(
          pick('Ritu, Drik', 'ऋतु, दृक्'),
          pick(c.drikRitu.name, c.drikRitu.nameHindi),
        ),
        _Caption(note(rituNote)),
        FactRow(
          pick('Ayana, Vedic', 'अयन, वैदिक'),
          pick(c.vedicAyana.name, c.vedicAyana.nameHindi),
        ),
        FactRow(
          pick('Ayana, Drik', 'अयन, दृक्'),
          pick(c.drikAyana.name, c.drikAyana.nameHindi),
        ),
        _Caption(note(ayanaNote)),
        const Divider(),
        FactRow(
          pick('Solar month, nirayana', 'सौर मास, निरयण'),
          '${pick(c.nirayanaSun.name, c.nirayanaSun.nameHindi)} · ${_degrees(c.nirayanaSun.degrees)}',
        ),
        FactRow(
          pick('Solar month, sayana', 'सौर मास, सायन'),
          '${pick(c.sayanaSun.name, c.sayanaSun.nameHindi)} · ${_degrees(c.sayanaSun.degrees)}',
        ),
        _Caption(note(solarMonthNote)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Disha Shool and the balas
// ---------------------------------------------------------------------------

class _BalaSection extends StatelessWidget {
  const _BalaSection({
    required this.details,
    required this.natal,
    required this.profileName,
    required this.clock,
  });

  final PanchangDetails details;
  final NatalMoon? natal;
  final String? profileName;
  final _Clock clock;

  @override
  Widget build(BuildContext context) {
    final bool hindi = clock.hindi;
    final ThemeData theme = Theme.of(context);
    String pick(String en, String hi) => hindi ? hi : en;
    final DishaShool disha = details.dishaShool;
    final String direction = pick(disha.direction, disha.directionHindi);

    final List<Widget> children = <Widget>[
      // Disha Shool.
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${pick(dishaShoolNote.name, dishaShoolNote.nameHindi)}: $direction',
          style: theme.textTheme.titleMedium,
        ),
      ),
      _Caption(pick(dishaShoolNote.meaning, dishaShoolNote.meaningHindi)),
      _Caption(
        pick(
          'Avoid travelling $direction. If you must, first take: ${disha.parihar}.',
          '$direction दिशा की यात्रा वर्जित। आवश्यक हो तो ${disha.pariharHindi} निकलें।',
        ),
        strong: true,
      ),
      const Divider(),
    ];

    final NatalMoon? n = natal;
    if (n != null) {
      children.add(
        _Caption(
          pick(
            'Read for ${profileName ?? ''}: Moon in ${rashiTable[n.rashi].english}, ${nakshatraTable[n.nakshatra].english} pada ${n.pada}.',
            '${profileName ?? ''} की कुंडली से: चंद्रमा ${rashiTable[n.rashi].hindi} में, ${nakshatraTable[n.nakshatra].hindi} चरण ${n.pada}।',
          ),
          strong: true,
        ),
      );
      children
        ..add(
          Text(
            pick(chandraBalaNote.name, chandraBalaNote.nameHindi),
            style: theme.textTheme.titleMedium,
          ),
        )
        ..add(
          _Caption(pick(chandraBalaNote.meaning, chandraBalaNote.meaningHindi)),
        );
      for (final BalaSegment<ChandraBala> s in chandraBalaForDay(
        details,
        natalMoonRashi: n.rashi,
      )) {
        children.add(
          _BalaRow(
            clock: clock,
            segment: _Seg(s.startJdUt, s.endJdUt),
            tone: s.value.tone,
            title: pick(s.value.name, s.value.nameHindi),
            meaning: pick(s.value.meaning, s.value.meaningHindi),
            showSpan: details.moonSegments.length > 1,
          ),
        );
      }
      children
        ..add(const SizedBox(height: 8))
        ..add(
          Text(
            pick(taraBalaNote.name, taraBalaNote.nameHindi),
            style: theme.textTheme.titleMedium,
          ),
        )
        ..add(_Caption(pick(taraBalaNote.meaning, taraBalaNote.meaningHindi)));
      for (final BalaSegment<TaraBala> s in taraBalaForDay(
        details,
        natalNakshatra: n.nakshatra,
      )) {
        children.add(
          _BalaRow(
            clock: clock,
            segment: _Seg(s.startJdUt, s.endJdUt),
            tone: s.value.tone,
            title:
                '${pick(s.value.tara.name, s.value.tara.nameHindi)} (${s.value.count})',
            meaning: pick(s.value.tara.meaning, s.value.tara.meaningHindi),
            showSpan: details.moonSegments.length > 1,
          ),
        );
      }
    } else {
      // No chart: the lists a printed panchang gives for everyone.
      children
        ..add(
          Text(
            pick(chandraBalaNote.name, chandraBalaNote.nameHindi),
            style: theme.textTheme.titleMedium,
          ),
        )
        ..add(
          _Caption(pick(chandraBalaNote.meaning, chandraBalaNote.meaningHindi)),
        );
      final List<BalaSegment<List<int>>> signLists = chandraBalaListForDay(
        details,
      );
      for (final BalaSegment<List<int>> s in signLists) {
        children.add(
          _Caption(
            '${signLists.length > 1 ? '${clock.span(s.startJdUt, s.endJdUt)}: ' : ''}'
            '${pick('favourable for Moon signs', 'अनुकूल राशियाँ')}: '
            '${s.value.map((int r) => pick(rashiTable[r].english, rashiTable[r].hindi)).join(', ')}',
            strong: true,
          ),
        );
      }
      children
        ..add(const SizedBox(height: 8))
        ..add(
          Text(
            pick(taraBalaNote.name, taraBalaNote.nameHindi),
            style: theme.textTheme.titleMedium,
          ),
        )
        ..add(_Caption(pick(taraBalaNote.meaning, taraBalaNote.meaningHindi)));
      final List<BalaSegment<List<int>>> starLists = taraBalaListForDay(
        details,
      );
      for (final BalaSegment<List<int>> s in starLists) {
        children.add(
          _Caption(
            '${starLists.length > 1 ? '${clock.span(s.startJdUt, s.endJdUt)}: ' : ''}'
            '${pick('favourable for birth nakshatras', 'अनुकूल जन्म नक्षत्र')}: '
            '${s.value.map((int k) => pick(nakshatraTable[k].english, nakshatraTable[k].hindi)).join(', ')}',
            strong: true,
          ),
        );
      }
      children.add(
        _Caption(
          pick(
            'Save your chart to see these read for you.',
            'अपनी कुंडली सहेजने पर ये आपके लिए देखे जाएँगे।',
          ),
        ),
      );
    }

    final String summary = n == null
        ? '${pick(dishaShoolNote.name, dishaShoolNote.nameHindi)}: $direction'
        : '${pick(dishaShoolNote.name, dishaShoolNote.nameHindi)}: $direction · '
              '${pick(chandraBalaNote.name, chandraBalaNote.nameHindi)}: '
              '${chandraBalaForDay(details, natalMoonRashi: n.rashi).map((BalaSegment<ChandraBala> s) => pick(s.value.name, s.value.nameHindi)).join(' → ')}';
    return _Section(
      storageKey: 'balas',
      title: hindi
          ? 'दिशाशूल, चंद्र बल और तारा बल'
          : 'Disha Shool, Chandra bala and Tara bala',
      summary: summary,
      icon: Icons.explore_outlined,
      children: children,
    );
  }
}

/// A stretch of the day for the bala rows.
class _Seg {
  const _Seg(this.startJdUt, this.endJdUt);

  final double startJdUt;
  final double endJdUt;
}

class _BalaRow extends StatelessWidget {
  const _BalaRow({
    required this.clock,
    required this.segment,
    required this.tone,
    required this.title,
    required this.meaning,
    required this.showSpan,
  });

  final _Clock clock;
  final _Seg segment;
  final PanchangTone tone;
  final String title;
  final String meaning;
  final bool showSpan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(
              _toneIcon(tone),
              size: 20,
              color: _toneColor(context, tone),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showSpan)
                  Text(
                    clock.span(segment.startJdUt, segment.endJdUt),
                    style: theme.textTheme.bodyMedium,
                  ),
                _Caption(meaning),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Anandadi and Hora
// ---------------------------------------------------------------------------

class _AnandadiSection extends StatelessWidget {
  const _AnandadiSection({required this.details, required this.clock});

  final PanchangDetails details;
  final _Clock clock;

  @override
  Widget build(BuildContext context) {
    final bool hindi = clock.hindi;
    final ThemeData theme = Theme.of(context);
    String name(AnandadiInfo i) => hindi ? i.nameHindi : i.name;
    return _Section(
      storageKey: 'anandadi',
      title: hindi ? 'आनन्दादि योग' : 'Anandadi yoga',
      summary: details.anandadi
          .map((AnandadiSpan a) => name(a.info))
          .join(' → '),
      icon: Icons.brightness_5_outlined,
      children: <Widget>[
        _Caption(hindi ? anandadiNote.meaningHindi : anandadiNote.meaning),
        for (final AnandadiSpan span in details.anandadi)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    _toneIcon(span.info.tone),
                    size: 22,
                    color: _toneColor(context, span.info.tone),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(name(span.info), style: theme.textTheme.titleMedium),
                      Text(
                        clock.span(span.startJdUt, span.endJdUt),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _Caption(
                        hindi ? span.info.meaningHindi : span.info.meaning,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HoraSection extends StatelessWidget {
  const _HoraSection({required this.panchang, required this.clock});

  final Panchang panchang;
  final _Clock clock;

  @override
  Widget build(BuildContext context) {
    final bool hindi = clock.hindi;
    final ThemeData theme = Theme.of(context);
    final List<TimeSpan> horas = panchang.horas;
    Widget row(TimeSpan span) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 14,
            children: <Widget>[
              Text(
                hindi ? span.titleHindi : '${span.title} hora',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${clock.hm(span.startJdUt)} — ${clock.hm(span.endJdUt)}${clock.tag(span.endJdUt)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          _Caption(hindi ? span.meaningHindi : span.meaning),
        ],
      ),
    );
    return _Section(
      storageKey: 'hora',
      title: hindi ? 'होरा, दिन और रात' : 'Hora, day and night',
      summary: hindi
          ? 'पहली होरा: ${horas.first.titleHindi}'
          : 'First hora: ${horas.first.title}',
      icon: Icons.schedule_outlined,
      children: <Widget>[
        _Caption(
          hindi
              ? 'दिन और रात के बारह-बारह भाग। पहली होरा वार के स्वामी की है; आगे की शनि से चंद्र तक के कक्षा-क्रम में चलती हैं।'
              : "Twelve parts of the day and twelve of the night. The first belongs to the weekday's lord; the rest follow in the Chaldean order, from Saturn to the Moon.",
        ),
        Text(
          hindi ? 'दिन की होरा' : 'Day horas',
          style: theme.textTheme.titleMedium,
        ),
        for (final TimeSpan span in horas.take(12)) row(span),
        const SizedBox(height: 8),
        Text(
          hindi ? 'रात की होरा' : 'Night horas',
          style: theme.textTheme.titleMedium,
        ),
        for (final TimeSpan span in horas.skip(12)) row(span),
      ],
    );
  }
}
