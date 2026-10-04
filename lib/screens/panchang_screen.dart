import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/places_repository.dart';
import '../data/time_zones.dart';
import '../engine/astro/houses.dart';
import '../engine/astro/time.dart';
import '../engine/jyotish/panchang.dart';
import '../l10n/app_localizations.dart';
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
    final bool hindi = settings.languageCode == 'hi';
    final Place place = _effectivePlace;
    final Duration offset = TimeZones.offsetFor(place.timeZoneId, _date);
    final Panchang panchang = computePanchang(
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

    String clock(double? jdUt) {
      if (jdUt == null) return '—';
      final DateTime local = utcFromJulianDay(jdUt).add(offset);
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabPanchang),
        actions: <Widget>[
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
                  '${hindi ? panchang.tithi.nameHindi : panchang.tithi.name} · ${panchang.paksha} · ${l.untilTime(clock(panchang.tithi.endsAtJdUt))}',
                  emphasise: true,
                ),
                FactRow(
                  l.nakshatra,
                  '${hindi ? panchang.nakshatra.nameHindi : panchang.nakshatra.name} · ${l.untilTime(clock(panchang.nakshatra.endsAtJdUt))}',
                ),
                FactRow(
                  l.yoga,
                  '${panchang.yoga.name} · ${l.untilTime(clock(panchang.yoga.endsAtJdUt))}',
                ),
                FactRow(
                  l.karana,
                  '${panchang.karana.name} · ${l.untilTime(clock(panchang.karana.endsAtJdUt))}',
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
          Panel(
            title: l.choghadiyaDay,
            child: Column(
              children: <Widget>[
                for (final TimeSpan span in panchang.dayChoghadiya)
                  FactRow(
                    span.name,
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
                    span.name,
                    '${clock(span.startJdUt)} — ${clock(span.endJdUt)}',
                  ),
              ],
            ),
          ),
          Panel(
            title: l.hora,
            child: Column(
              children: <Widget>[
                for (final TimeSpan span in panchang.horas.take(12))
                  FactRow(
                    span.name,
                    '${clock(span.startJdUt)} — ${clock(span.endJdUt)}',
                  ),
              ],
            ),
          ),
          DisclaimerNote(l.accuracyNote),
        ],
      ),
    );
  }
}
