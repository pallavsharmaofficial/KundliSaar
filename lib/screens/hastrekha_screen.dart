import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../engine/jyotish/chart.dart';
import '../engine/jyotish/hastrekha.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import '../widgets/palm_canvas.dart';
import 'profile_scope.dart';

/// Hastrekha, read from a trace the person makes themselves.
///
/// The honest shape of this feature: no camera is asked to understand a hand.
/// The person drags the app's lines onto their own, optionally over a photo of
/// their palm, and the engine reads the geometry they drew by the classical
/// rules, saying which measurement produced which sentence.
class HastrekhaScreen extends StatefulWidget {
  const HastrekhaScreen({super.key});

  @override
  State<HastrekhaScreen> createState() => _HastrekhaScreenState();
}

class _HastrekhaScreenState extends State<HastrekhaScreen> {
  final Map<PalmLine, List<PalmPoint>> _trace = <PalmLine, List<PalmPoint>>{
    for (final MapEntry<PalmLine, List<PalmPoint>> entry
        in defaultTrace.entries)
      entry.key: List<PalmPoint>.from(entry.value),
  };
  final Map<PalmLine, Set<String>> _marks = <PalmLine, Set<String>>{
    for (final PalmLine line in PalmLine.values) line: <String>{},
  };
  final Map<Mount, int> _mounts = <Mount, int>{
    for (final Mount mount in Mount.values) mount: 1,
  };

  PalmLine _active = PalmLine.life;
  bool _squarePalm = true;
  bool _longFingers = false;
  Uint8List? _photo;
  HastrekhaReading? _reading;

  Future<void> _pickPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1400,
      imageQuality: 85,
    );
    final XFile? chosen =
        file ??
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1400);
    if (chosen == null) return;
    final Uint8List bytes = await chosen.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  HandType get _handType => handTypeFrom(
    palmWidth: _squarePalm ? 0.9 : 0.7,
    palmLength: 1.0,
    fingerLength: _longFingers ? 1.0 : 0.85,
  );

  void _read(Kundli kundli) {
    final Map<PalmLine, TracedLine> lines = <PalmLine, TracedLine>{
      for (final PalmLine line in PalmLine.values)
        line: TracedLine(
          line: line,
          points: _trace[line]!,
          isPresent: !_marks[line]!.contains('absent'),
          hasBreak: _marks[line]!.contains('break'),
          isChained: _marks[line]!.contains('chain'),
          isForked: _marks[line]!.contains('fork'),
        ),
    };
    setState(() {
      _reading = readPalm(
        lines: lines,
        mountProminence: _mounts,
        handType: _handType,
        kundli: kundli,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    final ThemeData theme = Theme.of(context);

    return ChartScaffold(
      title: l.featureHastrekha,
      builder: (BuildContext context, Kundli kundli, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          ToranaHeader(
            title: l.tracePalm,
            subtitle: hindi
                ? 'ऐप आपकी हथेली नहीं पढ़ता — आप अपनी रेखाएँ अंकित करते हैं, और शास्त्र के नियमों से पढ़ा जाता है।'
                : 'The app does not look at your hand. You put its lines onto yours, and the classical rules read what you drew.',
          ),
          Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: <Widget>[
                PalmCanvas(
                  trace: _trace,
                  active: _active,
                  mounts: _mounts,
                  photo: _photo,
                  absent: <PalmLine>{
                    for (final PalmLine line in PalmLine.values)
                      if (_marks[line]!.contains('absent')) line,
                  },
                  onMoved: (PalmLine line, int index, PalmPoint point) =>
                      setState(() => _trace[line]![index] = point),
                ),
                const SizedBox(height: 8),
                Text(
                  l.dragToTrace,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final PalmLine line in PalmLine.values)
                ChoiceChip(
                  label: Text(
                    hindi ? lineNames[line]![1] : lineNames[line]![0],
                  ),
                  selected: line == _active,
                  onSelected: (_) => setState(() => _active = line),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Panel(
            title: hindi ? lineNames[_active]![1] : lineNames[_active]![0],
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                for (final (String key, String label) in <(String, String)>[
                  ('break', l.markBreak),
                  ('chain', l.markChain),
                  ('fork', l.markFork),
                  ('absent', l.notPresent),
                ])
                  FilterChip(
                    label: Text(label),
                    selected: _marks[_active]!.contains(key),
                    onSelected: (bool on) => setState(() {
                      if (on) {
                        _marks[_active]!.add(key);
                      } else {
                        _marks[_active]!.remove(key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          Panel(
            title: l.palmMounts,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hindi
                      ? 'हथेली को रोशनी में देखें: जो भाग उभरा हुआ लगे, उसे चुनें।'
                      : 'Hold your palm to the light. Tap the ones that stand up.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final Mount mount in Mount.values)
                      FilterChip(
                        label: Text(
                          hindi ? mountNames[mount]![1] : mountNames[mount]![0],
                        ),
                        selected: _mounts[mount] == 2,
                        onSelected: (bool on) =>
                            setState(() => _mounts[mount] = on ? 2 : 1),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Panel(
            title: l.handType,
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _squarePalm,
                  onChanged: (bool value) =>
                      setState(() => _squarePalm = value),
                  title: Text(
                    hindi ? 'हथेली चौकोर लगती है' : 'The palm looks square',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _longFingers,
                  onChanged: (bool value) =>
                      setState(() => _longFingers = value),
                  title: Text(
                    hindi
                        ? 'उँगलियाँ हथेली जितनी लंबी हैं'
                        : 'The fingers are as long as the palm',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  handTypeText[_handType]![hindi ? 1 : 0],
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    _photo == null
                        ? Icons.photo_camera_outlined
                        : Icons.delete_outline,
                  ),
                  label: Text(_photo == null ? l.takePhoto : l.clearPhoto),
                  onPressed: () => _photo == null
                      ? _pickPhoto()
                      : setState(() => _photo = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            icon: const Icon(Icons.back_hand_outlined),
            label: Text(l.readMyPalm),
            onPressed: () => _read(kundli),
          ),
          if (_reading != null) ...<Widget>[
            const SizedBox(height: 20),
            Panel(
              title: l.handType,
              child: Text(hindi ? _reading!.summaryHindi : _reading!.summary),
            ),
            for (final LineReading line in _reading!.lines)
              Panel(
                title: hindi
                    ? lineNames[line.line]![1]
                    : lineNames[line.line]![0],
                trailing: Text(
                  hindi ? line.measuredHindi : line.measured,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
                ),
                child: Text(hindi ? line.readingHindi : line.reading),
              ),
            for (final MountReading mount in _reading!.mounts)
              Panel(
                title: hindi
                    ? mountNames[mount.mount]![1]
                    : mountNames[mount.mount]![0],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(hindi ? mount.readingHindi : mount.reading),
                    if (mount.chartAgreement != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        hindi
                            ? mount.chartAgreementHindi!
                            : mount.chartAgreement!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
          DisclaimerNote(l.disclaimer),
        ],
      ),
    );
  }
}
