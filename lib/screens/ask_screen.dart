import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ask/answer_engine.dart';
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
  final List<(String, Answer)> _thread = <(String, Answer)>[];
  bool _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _ask(
    Kundli kundli,
    String question,
    bool hindi, {
    bool speakIt = false,
  }) async {
    if (question.trim().isEmpty) return;
    final VoiceService voice = context.read<VoiceService>();
    setState(() {
      _thinking = true;
      _input.clear();
    });
    // A beat of thought, so the avatar's change of face is readable.
    await Future<void>.delayed(const Duration(milliseconds: 420));
    final Answer answer = answerQuestion(kundli, question, hindi: hindi);
    if (!mounted) return;
    setState(() {
      _thread.insert(0, (question, answer));
      _thinking = false;
    });
    if (speakIt) {
      await voice.speak(
        '${answer.title}. ${answer.body}',
        languageCode: hindi ? 'hi' : 'en',
      );
    }
  }

  Future<void> _listen(Kundli kundli, bool hindi) async {
    final VoiceService voice = context.read<VoiceService>();
    if (voice.isListening) {
      await voice.stopListening();
      return;
    }
    await voice.stopSpeaking();
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
    final Kundli kundli = computeKundli(
      profile.toBirthData(),
      ayanamsa: settings.ayanamsa,
    );

    final String caption = voice.isListening
        ? (voice.partialWords.isEmpty ? l.listening : voice.partialWords)
        : _thinking
        ? l.swamijiThinking
        : _thread.isEmpty
        ? l.swamijiIdle
        : _thread.first.$2.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.askTitle),
        actions: <Widget>[
          if (voice.isSpeaking)
            IconButton(
              tooltip: l.stopSpeaking,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: voice.stopSpeaking,
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
          Expanded(
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: <Widget>[
                for (final (String question, Answer answer) in _thread)
                  _AnswerCard(
                    question: question,
                    answer: answer,
                    onSpeak: () => voice.speak(
                      '${answer.title}. ${answer.body}',
                      languageCode: hindi ? 'hi' : 'en',
                    ),
                  ),
                if (_thread.isEmpty)
                  _Suggestions(
                    hindi: hindi,
                    onPick: (String q) => _ask(kundli, q, hindi),
                  ),
              ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(answer.body, style: theme.textTheme.bodyMedium),
              if (answer.basis.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  l.askAnswerSource,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
      ],
    );
  }
}
