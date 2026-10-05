import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice in and voice out, in Hindi or English.
///
/// Both halves degrade quietly: a browser or a device without speech support
/// simply reports unavailable, and the screens fall back to typing and reading.
/// Nothing is recorded or uploaded by this app; the platform's own recogniser
/// does the work, and on the web that means the browser's.
class VoiceService extends ChangeNotifier {
  VoiceService();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechReady = false;
  bool _listening = false;
  bool _speaking = false;
  double _level = 0;
  String _partial = '';

  bool get isListening => _listening;
  bool get isSpeaking => _speaking;
  bool get speechAvailable => _speechReady;

  /// Loudness while listening, or a steady value while speaking, 0 to 1.
  double get level => _level;
  String get partialWords => _partial;

  Future<void> init() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (String status) {
          final bool listening = status == 'listening';
          if (listening != _listening) {
            _listening = listening;
            if (!listening) _level = 0;
            notifyListeners();
          }
        },
        onError: (dynamic _) {
          _listening = false;
          _level = 0;
          notifyListeners();
        },
      );
    } catch (_) {
      _speechReady = false;
    }
    _tts.setStartHandler(() {
      _speaking = true;
      _level = 0.6;
      notifyListeners();
    });
    _tts.setCompletionHandler(() {
      _speaking = false;
      _level = 0;
      notifyListeners();
    });
    _tts.setCancelHandler(() {
      _speaking = false;
      _level = 0;
      notifyListeners();
    });
    _tts.setErrorHandler((dynamic _) {
      _speaking = false;
      _level = 0;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Listens until the speaker stops, then hands over the words.
  Future<void> listen({
    required String languageCode,
    required void Function(String words) onResult,
  }) async {
    if (!_speechReady) return;
    _partial = '';
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: languageCode == 'hi' ? 'hi_IN' : 'en_IN',
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
      onSoundLevelChange: (double level) {
        _level = (level / 10).clamp(0.0, 1.0);
        notifyListeners();
      },
      onResult: (dynamic result) {
        _partial = result.recognizedWords as String;
        notifyListeners();
        if (result.finalResult as bool) {
          onResult(_partial);
          _partial = '';
          _listening = false;
          _level = 0;
          notifyListeners();
        }
      },
    );
    _listening = true;
    notifyListeners();
  }

  Future<void> stopListening() async {
    if (!_speechReady) return;
    await _speech.stop();
    _listening = false;
    _level = 0;
    notifyListeners();
  }

  /// Reads a passage aloud. Hindi gets a slightly slower rate, which the
  /// language needs to stay intelligible on small speakers.
  Future<void> speak(String text, {required String languageCode}) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setLanguage(languageCode == 'hi' ? 'hi-IN' : 'en-IN');
      await _tts.setSpeechRate(languageCode == 'hi' ? 0.42 : 0.48);
      await _tts.setPitch(0.92);
      await _tts.speak(text);
    } catch (_) {
      _speaking = false;
      notifyListeners();
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing to stop.
    }
    _speaking = false;
    _level = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    if (_speechReady) _speech.cancel();
    super.dispose();
  }
}
