import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ask/answer_engine.dart';
import '../engine/astro/ayanamsa.dart';
import '../engine/jyotish/chart.dart';
import '../l10n/app_localizations.dart';
import '../models/saved_profile.dart';
import '../services/voice_service.dart';
import '../state/profiles_cubit.dart';
import '../state/settings_cubit.dart';
import '../widgets/avatar/swamiji.dart';
import '../widgets/common.dart';

/// Questions answered from the computed chart, by hand-written templates in
/// both languages. Nothing is generated, so it works offline and cannot invent
/// a planet; the optional model, when it ships, will sit on top of this.
///
/// An answer is a few headed parts, each a few short paragraphs, so it can be
/// read aloud to someone sitting in front of you. The newest answer is brought
/// to its first line, not its last, because a full answer is longer than the
/// screen.
///
/// The swamiji is the app's face for the answer: he listens while the
/// microphone is open, closes his eyes while the chart is read, and speaks
/// when the answer is read aloud.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key, required this.profileId});

  final String profileId;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _newest = GlobalKey();

  /// Newest first.
  final List<(String, Answer)> _thread = <(String, Answer)>[];
  bool _thinking = false;

  /// Bumped whenever speech is stopped or a new answer starts, so a long
  /// answer being read in pieces knows to stop.
  int _speechRun = 0;

  Kundli? _kundli;
  String? _kundliKey;

  @override
  void dispose() {
    _speechRun++;
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The chart is worked out once and kept, so the readings built from it are
  /// reused by every question.
  Kundli _kundliFor(SavedProfile profile, Ayanamsa ayanamsa) {
    final String key = '${profile.id}|${ayanamsa.name}';
    if (_kundli == null || _kundliKey != key) {
      final Kundli fresh = computeKundli(
        profile.toBirthData(),
        ayanamsa: ayanamsa,
      );
      _kundli = fresh;
      _kundliKey = key;
      // The readings every answer is built from take a moment to work out.
      // Do it as soon as the screen is up, while the person is still reading
      // the suggestions, so the first answer does not wait for it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) phaladeshFor(fresh);
      });
    }
    return _kundli!;
  }

  Future<void> _ask(
    Kundli kundli,
    String question,
    bool hindi, {
    bool speakIt = false,
  }) async {
    if (question.trim().isEmpty) return;
    final VoiceService voice = context.read<VoiceService>();
    _speechRun++;
    if (voice.isSpeaking) await voice.stopSpeaking();
    if (!mounted) return;
    setState(() {
      _thinking = true;
      _input.clear();
    });
    // A beat of thought, so the avatar's change of face is readable.
    await Future<void>.delayed(const Duration(milliseconds: 420));
    Answer answer;
    try {
      answer = answerQuestion(kundli, question, hindi: hindi);
    } catch (_) {
      // A question must never take the screen down with it.
      answer = notYetAnswer(hindi);
    }
    if (!mounted) return;
    setState(() {
      _thread.insert(0, (question, answer));
      _thinking = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _newest.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
    if (speakIt) {
      // Asked by voice, answered by voice: the gist, not the whole.
      await _speakAnswer(voice, answer, hindi, brief: true);
    }
  }

  /// Reads an answer aloud in pieces the speech engine will take, one after
  /// the other. Stopping, or asking something new, ends the run.
  Future<void> _speakAnswer(
    VoiceService voice,
    Answer answer,
    bool hindi, {
    bool brief = false,
  }) async {
    final int run = ++_speechRun;
    final List<String> chunks = answer.spokenChunks(brief: brief);
    for (int i = 0; i < chunks.length; i++) {
      if (!mounted || run != _speechRun) return;
      await voice.speak(chunks[i], languageCode: hindi ? 'hi' : 'en');
      if (i < chunks.length - 1) await _untilSilent(voice, run);
    }
  }

  /// Waits for the voice to start and then finish, but not for ever if it
  /// never starts.
  Future<void> _untilSilent(VoiceService voice, int run) async {
    final Completer<void> done = Completer<void>();
    bool started = voice.isSpeaking;
    void listener() {
      if (run != _speechRun) {
        if (!done.isCompleted) done.complete();
      } else if (voice.isSpeaking) {
        started = true;
      } else if (started && !done.isCompleted) {
        done.complete();
      }
    }

    voice.addListener(listener);
    final Timer giveUp = Timer(const Duration(seconds: 5), () {
      if (!started && !done.isCompleted) done.complete();
    });
    try {
      await done.future;
    } finally {
      voice.removeListener(listener);
      giveUp.cancel();
    }
  }

  Future<void> _stopSpeaking(VoiceService voice) async {
    _speechRun++;
    await voice.stopSpeaking();
  }

  Future<void> _listen(Kundli kundli, bool hindi) async {
    final VoiceService voice = context.read<VoiceService>();
    if (voice.isListening) {
      await voice.stopListening();
      return;
    }
    await _stopSpeaking(voice);
    await voice.listen(
      languageCode: hindi ? 'hi' : 'en',
      onResult: (String words) => _ask(kundli, words, hindi, speakIt: true),
    );
  }

  SwamijiMood _mood(VoiceService voice) {
    if (voice.isListening) return SwamijiMood.listening;
    if (voice.isSpeaking) return SwamijiMood.speaking;
    if (_thinking) return SwamijiMood.thinking;
    return _thread.isEmpty ? SwamijiMood.idle : SwamijiMood.blessing;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final AppSettings settings = context.watch<SettingsCubit>().state;
    final VoiceService voice = context.watch<VoiceService>();
    final bool hindi = settings.languageCode == 'hi';
    final SavedProfile? profile = context.read<ProfilesCubit>().byId(
      widget.profileId,
    );
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.profileEmpty)),
      );
    }
    final Kundli kundli = _kundliFor(profile, settings.ayanamsa);

    final String caption = voice.isListening
        ? (voice.partialWords.isEmpty ? l.listening : voice.partialWords)
        : _thinking
        ? l.swamijiThinking
        : _thread.isEmpty
        ? l.swamijiIdle
        : _thread.first.$2.title;

    // Oldest first, so the thread reads top to bottom.
    final List<(String, Answer)> inOrder = _thread.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.askTitle),
        actions: <Widget>[
          if (voice.isSpeaking)
            IconButton(
              tooltip: l.stopSpeaking,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: () => _stopSpeaking(voice),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SwamijiPanel(
              mood: _mood(voice),
              level: voice.level,
              caption: caption,
            ),
          ),
          // Not a lazy list: the newest answer has to exist to be scrolled
          // to, wherever it sits below the older ones.
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_thread.isEmpty)
                    _Suggestions(
                      hindi: hindi,
                      onPick: (String q) => _ask(kundli, q, hindi),
                    ),
                  for (int i = 0; i < inOrder.length; i++)
                    _AnswerCard(
                      key: i == inOrder.length - 1 ? _newest : null,
                      question: inOrder[i].$1,
                      answer: inOrder[i].$2,
                      onSpeak: () => _speakAnswer(voice, inOrder[i].$2, hindi),
                    ),
                ],
              ),
            ),
          ),
          if (_thread.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: <Widget>[
                  for (final String q in suggestedQuestions(hindi))
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 6),
                      child: ActionChip(
                        label: Text(q),
                        onPressed: () => _ask(kundli, q, hindi),
                      ),
                    ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: <Widget>[
                  if (voice.speechAvailable)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton.filledTonal(
                        tooltip: voice.isListening ? l.listening : l.tapToSpeak,
                        onPressed: () => _listen(kundli, hindi),
                        icon: Icon(voice.isListening ? Icons.stop : Icons.mic),
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (String value) => _ask(kundli, value, hindi),
                      decoration: InputDecoration(hintText: l.askPlaceholder),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _ask(kundli, _input.text, hindi),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.hindi, required this.onPick});

  final bool hindi;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l.askPlaceholder, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final String q in suggestedQuestions(hindi))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onPressed: () => onPick(q),
              child: Align(alignment: Alignment.centerLeft, child: Text(q)),
            ),
          ),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    super.key,
    required this.question,
    required this.answer,
    required this.onSpeak,
  });

  final String question;
  final Answer answer;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(bottom: 8, top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(question, style: theme.textTheme.bodyMedium),
        ),
        Panel(
          title: answer.title,
          trailing: IconButton(
            tooltip: l.speakAnswer,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.volume_up_outlined, size: 20),
            onPressed: onSpeak,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final AnswerSection section in answer.sections)
                  _SectionView(section: section),
                if (answer.basis.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    l.askAnswerSource,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final String basis in answer.basis)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Text(
                            basis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One headed part of an answer.
class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final AnswerSection section;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool closing = section.key == SectionKey.close;
    final TextStyle? body = theme.textTheme.bodyMedium?.copyWith(
      height: 1.5,
      fontStyle: closing ? FontStyle.italic : null,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (section.heading.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                section.heading,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          for (int i = 0; i < section.paragraphs.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == section.paragraphs.length - 1 ? 0 : 8,
              ),
              child: Text(section.paragraphs[i], style: body),
            ),
        ],
      ),
    );
  }
}
