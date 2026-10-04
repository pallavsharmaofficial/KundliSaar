import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../data/places_repository.dart';
import '../data/time_zones.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../state/profiles_cubit.dart';
import '../widgets/common.dart';

/// Three things are asked for and nothing else: a name, a moment, a place.
class BirthFormScreen extends StatefulWidget {
  const BirthFormScreen({super.key, this.initial});

  final SavedProfile? initial;

  @override
  State<BirthFormScreen> createState() => _BirthFormScreenState();
}

class _BirthFormScreenState extends State<BirthFormScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  DateTime _date = DateTime(1995, 1, 1);
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  Place? _place;
  bool _approximate = false;

  @override
  void initState() {
    super.initState();
    final SavedProfile? initial = widget.initial;
    if (initial != null) {
      _date = initial.localDateTime;
      _time = TimeOfDay(
        hour: initial.localDateTime.hour,
        minute: initial.localDateTime.minute,
      );
      _place = initial.place;
      _approximate = initial.timeIsApproximate;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPlace() async {
    final Place? picked = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          _PlacePicker(repository: context.read<PlacesRepository>()),
    );
    if (picked != null) setState(() => _place = picked);
  }

  Future<void> _submit() async {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final Place? place = _place;
    if (place == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.birthPlace)));
      return;
    }
    final DateTime local = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final Duration offset = TimeZones.offsetFor(place.timeZoneId, local);
    final SavedProfile profile = SavedProfile(
      id:
          widget.initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: _name.text.trim().isEmpty ? l.newChart : _name.text.trim(),
      localDateTime: local,
      offsetMinutes: offset.inMinutes,
      place: place,
      timeIsApproximate: _approximate,
    );
    await context.read<ProfilesCubit>().save(profile);
    if (!mounted) return;
    context.pushReplacement('/chart/${profile.id}');
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final Place? place = _place;
    final String offsetLabel = place == null
        ? ''
        : formatOffset(
            TimeZones.offsetFor(
              place.timeZoneId,
              DateTime(
                _date.year,
                _date.month,
                _date.day,
                _time.hour,
                _time.minute,
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(title: Text(l.newChart)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l.name),
          ),
          const SizedBox(height: 16),
          _FieldButton(
            label: l.birthDate,
            value: '${_date.day}/${_date.month}/${_date.year}',
            icon: Icons.event_outlined,
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1900),
                lastDate: DateTime(2069, 12, 31),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 12),
          _FieldButton(
            label: l.birthTime,
            value: _time.format(context),
            icon: Icons.schedule_outlined,
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (picked != null) setState(() => _time = picked);
            },
          ),
          const SizedBox(height: 12),
          _FieldButton(
            label: l.birthPlace,
            value: place?.label ?? l.searchPlace,
            icon: Icons.place_outlined,
            onTap: _pickPlace,
          ),
          if (place != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                '${place.timeZoneId} · UTC$offsetLabel',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
              ),
            ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _approximate,
            onChanged: (bool value) => setState(() => _approximate = value),
            title: Text(l.timeNotSure),
            subtitle: _approximate ? Text(l.timeNotSureHelp) : null,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: Text(l.computeChart)),
          DisclaimerNote(l.privacyNote),
        ],
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value, style: theme.textTheme.bodyLarge),
      ),
    );
  }
}

class _PlacePicker extends StatefulWidget {
  const _PlacePicker({required this.repository});

  final PlacesRepository repository;

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  final TextEditingController _query = TextEditingController();
  List<Place> _results = const <Place>[];

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String value) async {
    final List<Place> results = await widget.repository.search(value);
    if (mounted) setState(() => _results = results);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  labelText: l.searchPlace,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(child: Text(l.noResults))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Place place = _results[index];
                        return ListTile(
                          title: Text(place.name),
                          subtitle: Text(
                            '${place.admin}, ${place.country} · ${place.timeZoneId}',
                          ),
                          onTap: () => Navigator.of(context).pop(place),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
