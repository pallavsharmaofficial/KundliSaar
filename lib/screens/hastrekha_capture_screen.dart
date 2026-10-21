import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../palm/camera_source.dart';
import '../palm/capture_flow.dart';
import '../palm/guidance.dart';
import '../palm/hand_tracker.dart';
import '../palm/palm_scan.dart';
import '../palm/palm_types.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import '../widgets/hand_guide.dart';
import '../widgets/palm_reading_view.dart';

enum _Stage { intro, opening, aiming, analysing, result, trouble }

enum _Trouble {
  denied,
  unavailable,
  models,
  nothingSeen,
  cutOff,
  backOfHand,
  failed,
}

/// Hastrekha by camera: show the palm, and the reading follows.
///
/// The person is asked for nothing but the palm. The camera finds the hand,
/// says what to fix, counts down, takes the picture and reads it; the picture
/// is looked at on this phone and is never saved or sent anywhere.
class HastrekhaCaptureScreen extends StatefulWidget {
  const HastrekhaCaptureScreen({
    super.key,
    this.cameraFactory,
    this.trackerFactory,
    this.onManual,
  });

  /// For tests: a camera that plays a script instead of looking at anything.
  final CameraSource Function()? cameraFactory;

  /// For tests: a tracker that answers from a script.
  final HandTracker Function()? trackerFactory;

  /// For tests: where "trace by hand" goes. By default, the hand tracer.
  final VoidCallback? onManual;

  @override
  State<HastrekhaCaptureScreen> createState() => _HastrekhaCaptureScreenState();
}

class _HastrekhaCaptureScreenState extends State<HastrekhaCaptureScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  _Stage _stage = _Stage.intro;
  _Trouble? _trouble;

  CameraSource? _camera;
  HandTracker? _tracker;
  StreamSubscription<CameraFrame>? _frames;
  late final Ticker _ticker;

  int _nowMs = 0;
  final CaptureFlow _flow = CaptureFlow();
  final SteadyTracker _steady = SteadyTracker();
  final GuidanceSmoother _smoother = GuidanceSmoother();
  final ValueNotifier<CaptureStatus> _status = ValueNotifier<CaptureStatus>(
    const CaptureStatus(phase: CapturePhase.aiming, guidance: Guidance.noHand),
  );
  final ValueNotifier<HandObservation?> _hand = ValueNotifier<HandObservation?>(
    null,
  );
  CameraFrame? _latest;
  bool _scanning = false;
  int _aimingSinceMs = 0;
  bool _slowHint = false;

  PalmScan? _scan;
  StillScan? _still;
  ui.Image? _photo;

  bool get _hindi => context.read<SettingsCubit>().state.languageCode == 'hi';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    unawaited(_closeCamera());
    unawaited(_tracker?.dispose());
    _photo?.dispose();
    _status.dispose();
    _hand.dispose();
    _orient(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera belongs to the foreground. If the person leaves, let it go,
    // and let them start again when they are back.
    if (state == AppLifecycleState.paused && _stage == _Stage.aiming) {
      unawaited(_closeCamera());
      if (mounted) setState(() => _stage = _Stage.intro);
    }
  }

  /// Holds the screen upright while the camera is in use (the frames are turned
  /// to upright on that assumption) and lets it go afterwards.
  void _orient(List<DeviceOrientation> orientations) {
    unawaited(
      SystemChrome.setPreferredOrientations(orientations).catchError((Object _) {}),
    );
  }

  // ---------------------------------------------------------------- the camera

  Future<void> _open() async {
    setState(() {
      _stage = _Stage.opening;
      _trouble = null;
    });
    _orient(<DeviceOrientation>[DeviceOrientation.portraitUp]);
    final CameraSource camera = (widget.cameraFactory ?? PluginCameraSource.new)();
    final HandTracker tracker =
        _tracker ?? (widget.trackerFactory ?? createHandTracker)();
    _tracker = tracker;
    _camera = camera;
    try {
      await tracker.start();
    } catch (_) {
      return _fail(_Trouble.models);
    }
    try {
      await camera.open();
    } on CameraUnavailable catch (e) {
      return _fail(
        e.problem == CameraProblem.denied
            ? _Trouble.denied
            : _Trouble.unavailable,
      );
    } catch (_) {
      return _fail(_Trouble.unavailable);
    }
    if (!mounted) return;
    _flow.reset();
    _steady.clear();
    _smoother.reset();
    _hand.value = null;
    _scanning = false;
    _slowHint = false;
    _status.value = const CaptureStatus(
      phase: CapturePhase.aiming,
      guidance: Guidance.noHand,
    );
    _frames = camera.frames.listen(_onFrame);
    _aimingSinceMs = 0;
    if (!_ticker.isActive) _ticker.start();
    setState(() => _stage = _Stage.aiming);
  }

  Future<void> _closeCamera() async {
    await _frames?.cancel();
    _frames = null;
    final CameraSource? c = _camera;
    _camera = null;
    _ticker.stop();
    await c?.close();
  }

  void _fail(_Trouble why) {
    unawaited(_closeCamera());
    if (!mounted) return;
    setState(() {
      _stage = _Stage.trouble;
      _trouble = why;
    });
  }

  // --------------------------------------------------------------- each moment

  void _onTick(Duration elapsed) {
    _nowMs = elapsed.inMilliseconds;
    if (_stage != _Stage.aiming) return;
    final CaptureStatus s = _flow.tick(_nowMs);
    if (s != _status.value) _status.value = s;
    if (s.phase == CapturePhase.captured && !_scanning) {
      unawaited(_capture());
    }
    // After a long while without success, say plainly that the hand tracer is
    // there.
    if (!_slowHint && _nowMs - _aimingSinceMs > 25000) {
      setState(() => _slowHint = true);
    }
  }

  void _onFrame(CameraFrame frame) {
    _latest = frame;
    if (_stage != _Stage.aiming || _scanning) return;
    final HandTracker? tracker = _tracker;
    if (tracker == null) return;
    final Future<TrackResult?> look = tracker.track(frame, _nowMs);
    unawaited(look.then(_onLook));
  }

  void _onLook(TrackResult? look) {
    if (look == null || !mounted || _stage != _Stage.aiming || _scanning) {
      return;
    }
    final Guidance raw;
    if (look.hand == null) {
      _steady.clear();
      raw = assessNothing(look.frameBrightness);
    } else {
      _steady.add(look.hand!);
      raw = assess(look.hand, steady: _steady.steady);
    }
    _hand.value = look.hand;
    final Guidance shown = _smoother.push(raw);
    _flow.observe(shown, _nowMs);
    final CaptureStatus s = _flow.status(_nowMs);
    if (s != _status.value) _status.value = s;
  }

  Future<void> _capture() async {
    _scanning = true;
    final CameraFrame? frame = _latest;
    final HandTracker? tracker = _tracker;
    if (frame == null || tracker == null) return _retry(_Trouble.failed);
    unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
    setState(() => _stage = _Stage.analysing);
    unawaited(_frames?.cancel());
    _frames = null;
    try {
      final StillScan still = await tracker.scan(frame, _nowMs);
      _latest = null;
      final PalmScan scan = buildScan(hand: still.hand, creases: still.creases);
      await _closeCamera();
      if (!mounted) return;
      if (scan.outcome == ScanOutcome.noHand) return _retry(_Trouble.nothingSeen);
      if (scan.outcome == ScanOutcome.cutOff) return _retry(_Trouble.cutOff);
      if (scan.outcome == ScanOutcome.backOfHand) {
        return _retry(_Trouble.backOfHand);
      }
      final ui.Image? photo = await _decode(still);
      if (!mounted) {
        photo?.dispose();
        return;
      }
      _photo?.dispose();
      setState(() {
        _scan = scan;
        _still = still;
        _photo = photo;
        _stage = _Stage.result;
      });
    } catch (_) {
      _retry(_Trouble.failed);
    }
  }

  /// The picture for showing the lines on. If it cannot be made, the reading is
  /// still given, without it.
  Future<ui.Image?> _decode(StillScan still) async {
    try {
      final Completer<ui.Image> done = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        still.previewRgba,
        still.previewWidth,
        still.previewHeight,
        ui.PixelFormat.rgba8888,
        done.complete,
      );
      return await done.future.timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  void _retry(_Trouble why) {
    unawaited(_closeCamera());
    if (!mounted) return;
    setState(() {
      _stage = _Stage.trouble;
      _trouble = why;
    });
  }

  void _manual() {
    final VoidCallback? custom = widget.onManual;
    if (custom != null) {
      custom();
    } else {
      context.push('/hastrekha/manual');
    }
  }

  // ------------------------------------------------------------------ the page

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi = context.watch<SettingsCubit>().state.languageCode == 'hi';
    final Widget body;
    switch (_stage) {
      case _Stage.intro:
        body = _intro(hindi);
      case _Stage.opening:
        body = _busy(
          hindi ? 'कैमरा शुरू हो रहा है…' : 'Starting the camera…',
        );
      case _Stage.aiming:
        body = _aiming(hindi);
      case _Stage.analysing:
        body = _busy(hindi ? 'आपकी हथेली पढ़ी जा रही है…' : 'Reading your palm…');
      case _Stage.result:
        body = _result(hindi, l);
      case _Stage.trouble:
        body = _troubleView(hindi);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.featureHastrekha)),
      body: SafeArea(child: body),
    );
  }

  Widget _privacyLine(bool hindi, {bool small = false}) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: small ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.lock_outline, size: small ? 16 : 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            small
                ? (hindi
                      ? 'आपकी तस्वीर इसी फ़ोन में रहती है। कुछ अपलोड नहीं होता।'
                      : 'Your photograph stays on this phone. Nothing is uploaded.')
                : (hindi
                      ? 'आपकी तस्वीर इसी फ़ोन में रहती है। उसे फ़ोन पर ही देखा जाता है; न अपलोड होती है, न सहेजी जाती है, और इस स्क्रीन से निकलते ही मिट जाती है।'
                      : 'Your photograph stays on this phone. It is looked at on the phone itself, never uploaded, never saved, and gone when you leave this screen.'),
            key: const ValueKey<String>('privacy-line'),
            style: small
                ? theme.textTheme.bodySmall?.copyWith(fontSize: 13)
                : theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _intro(bool hindi) {
    final ThemeData theme = Theme.of(context);
    final List<(String, String)> steps = <(String, String)>[
      (
        'Hold the phone in one hand. Open your other palm toward the back camera, about a foot away, fingers up.',
        'फ़ोन एक हाथ में पकड़िए। दूसरी हथेली खोलकर, उँगलियाँ ऊपर करके, पीछे के कैमरे के सामने लगभग एक फुट दूर रखिए।',
      ),
      (
        'The app tells you what to adjust: closer, further, more light, fingers open.',
        'ऐप बताता रहेगा कि क्या ठीक करना है: पास, दूर, ज़्यादा रोशनी, उँगलियाँ खुली।',
      ),
      (
        'When your hand is placed and steady, a 3, 2, 1 count runs and the photograph is taken.',
        'जब हाथ सही जगह पर और स्थिर होगा, तो 3, 2, 1 की गिनती चलेगी और तस्वीर ले ली जाएगी।',
      ),
    ];
    final Widget scroll = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: <Widget>[
        ToranaHeader(
          title: hindi ? 'अपनी हथेली दिखाइए' : 'Show your palm',
          subtitle: hindi
              ? 'कैमरा आपका हाथ खुद पहचानता है, तस्वीर खुद लेता है और उसे पढ़ता है। न कोई बटन दबाना, न कुछ भरना।'
              : 'The camera finds your hand, takes the picture by itself, and reads it. No button to press, nothing to fill in.',
        ),
        Panel(
          title: hindi ? 'कैसे काम करता है' : 'How it works',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(hindi ? steps[i].$2 : steps[i].$1)),
                    ],
                  ),
                ),
              Text(
                hindi
                    ? 'सादी, साफ़ हथेली और बराबर रोशनी में सबसे अच्छा चलता है: मेहँदी या भारी अँगूठियाँ न हों।'
                    : 'It works best on a bare, clean palm in even light: no henna or heavy rings.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _privacyLine(hindi),
              const SizedBox(height: 10),
              Text(
                hindi
                    ? 'कैमरा सिर्फ़ यहीं, सिर्फ़ आपकी हथेली देखने के लिए इस्तेमाल होता है। इसे चालू करने पर फ़ोन आपसे अनुमति पूछेगा।'
                    : 'The camera is used only here, only to look at your palm. Your phone will ask your permission when you open it.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
    // The two ways forward stay in view, whatever the screen's size.
    return Column(
      children: <Widget>[
        Expanded(child: scroll),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _privacyLine(hindi, small: true),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey<String>('open-camera'),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(hindi ? 'कैमरा खोलिए' : 'Open the camera'),
                onPressed: _open,
              ),
              TextButton(
                key: const ValueKey<String>('trace-by-hand'),
                onPressed: _manual,
                child: Text(
                  hindi
                      ? 'इसके बजाय हाथ से अंकित कीजिए'
                      : 'Trace by hand instead',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _busy(String text) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _privacyLine(_hindi, small: true),
        ),
      ],
    ),
  );

  Widget _aiming(bool hindi) {
    final CameraSource? camera = _camera;
    final double aspect = camera?.previewAspectRatio ?? 3 / 4;
    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (camera != null)
                      ColoredBox(
                        color: Colors.black,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: 100 * aspect,
                            height: 100,
                            child: camera.buildPreview(context),
                          ),
                        ),
                      ),
                    ValueListenableBuilder<CaptureStatus>(
                      valueListenable: _status,
                      builder: (BuildContext context, CaptureStatus s, _) {
                        final Color guide = s.phase != CapturePhase.aiming ||
                                s.guidance == Guidance.ready
                            ? const Color(0xFF66BB6A)
                            : Colors.white.withValues(alpha: 0.75);
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            CustomPaint(painter: HandGuidePainter(colour: guide)),
                            ValueListenableBuilder<HandObservation?>(
                              valueListenable: _hand,
                              builder: (BuildContext context, HandObservation? h, _) =>
                                  CustomPaint(
                                    painter: HandSkeletonPainter(
                                      hand: h,
                                      colour: guide,
                                    ),
                                  ),
                            ),
                            Center(child: CountdownBadge(status: s)),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: ValueListenableBuilder<CaptureStatus>(
            valueListenable: _status,
            builder: (BuildContext context, CaptureStatus s, _) =>
                GuidanceBanner(status: s, hindi: hindi),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _privacyLine(hindi, small: true),
        ),
        TextButton(
          key: const ValueKey<String>('trace-by-hand'),
          onPressed: _manual,
          child: Text(
            _slowHint
                ? (hindi
                      ? 'दिक़्क़त हो रही है? हाथ से अंकित कीजिए'
                      : 'Having trouble? Trace by hand')
                : (hindi ? 'हाथ से अंकित कीजिए' : 'Trace by hand instead'),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    required List<Widget> actions,
  }) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: <Widget>[
        Icon(icon, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 14),
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Text(body, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        ...actions,
      ],
    );
  }

  Widget _troubleView(bool hindi) {
    final _Trouble why = _trouble ?? _Trouble.failed;
    final Widget manual = TextButton(
      key: const ValueKey<String>('trace-by-hand'),
      onPressed: _manual,
      child: Text(hindi ? 'हाथ से अंकित कीजिए' : 'Trace by hand instead'),
    );
    final Widget again = FilledButton(
      key: const ValueKey<String>('try-again'),
      onPressed: _open,
      child: Text(hindi ? 'फिर कोशिश कीजिए' : 'Try again'),
    );
    switch (why) {
      case _Trouble.denied:
        return _card(
          icon: Icons.no_photography_outlined,
          title: hindi ? 'इस ऐप के लिए कैमरा बंद है' : 'The camera is off for this app',
          body: hindi
              ? 'इसके बिना हथेली अपने-आप नहीं पढ़ी जा सकती। आप फ़ोन की सेटिंग में कैमरा चालू कर सकते हैं, या हथेली हाथ से अंकित कर सकते हैं। दोनों तरह कुछ नहीं बिगड़ता।'
              : 'The palm cannot be read automatically without it. You can switch the camera on in your phone’s settings, or trace your palm by hand. Nothing is lost either way.',
          actions: <Widget>[
            again,
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey<String>('open-settings'),
              onPressed: openAppSettings,
              child: Text(hindi ? 'सेटिंग खोलिए' : 'Open settings'),
            ),
            manual,
          ],
        );
      case _Trouble.unavailable:
        return _card(
          icon: Icons.videocam_off_outlined,
          title: hindi ? 'कैमरा शुरू नहीं हो सका' : 'The camera could not be started',
          body: hindi
              ? 'शायद कोई दूसरा ऐप इसे इस्तेमाल कर रहा है। दूसरे कैमरा ऐप बंद करके फिर कोशिश कीजिए, या हथेली हाथ से अंकित कीजिए।'
              : 'Another app may be using it. Close other camera apps and try again, or trace your palm by hand.',
          actions: <Widget>[again, manual],
        );
      case _Trouble.models:
        return _card(
          icon: Icons.memory_outlined,
          title: hindi
              ? 'इस फ़ोन पर हाथ पहचानना शुरू नहीं हो सका'
              : 'Hand detection could not start on this phone',
          body: hindi
              ? 'आप फिर भी हथेली हाथ से अंकित कर सकते हैं, और पढ़ाई उसी तरह होगी।'
              : 'You can still trace your palm by hand, and it will be read the same way.',
          actions: <Widget>[manual],
        );
      case _Trouble.nothingSeen:
        return _card(
          icon: Icons.back_hand_outlined,
          title: hindi ? 'उस तस्वीर में हाथ नहीं मिला' : 'The hand was not in that picture',
          body: hindi
              ? 'फिर कोशिश कीजिए, और हाथ को रेखाचित्र के अंदर स्थिर रखिए। अगर बार-बार ऐसा हो, तो रोशनी बढ़ाइए या हाथ से अंकित कीजिए। ग़लत पढ़ने से बेहतर है कि न पढ़ा जाए।'
              : 'Try again, holding your hand steady inside the outline. If it keeps happening, add some light or trace by hand. Reading nothing is better than reading wrongly.',
          actions: <Widget>[again, manual],
        );
      case _Trouble.cutOff:
        return _card(
          icon: Icons.crop_free,
          title: hindi
              ? 'हाथ का एक हिस्सा तस्वीर से बाहर था'
              : 'Part of your hand was outside the picture',
          body: hindi
              ? 'फिर कोशिश कीजिए और पूरा हाथ, उँगलियों की नोक समेत, फ्रेम के अंदर रखिए। कटे हुए हाथ की बनावट नापी नहीं जा सकती।'
              : 'Try again with the whole hand, fingertips included, inside the frame. The shape of a cut-off hand cannot be measured.',
          actions: <Widget>[again, manual],
        );
      case _Trouble.backOfHand:
        return _card(
          icon: Icons.flip_camera_android_outlined,
          title: hindi ? 'वह हाथ का पिछला हिस्सा था' : 'That was the back of your hand',
          body: hindi
              ? 'हथेली कैमरे की ओर करके फिर कोशिश कीजिए। हाथ के पिछले हिस्से से कुछ नहीं पढ़ा जाता।'
              : 'Turn your hand over so the palm faces the camera and try again. Nothing is read from the back of the hand.',
          actions: <Widget>[again, manual],
        );
      case _Trouble.failed:
        return _card(
          icon: Icons.error_outline,
          title: hindi ? 'तस्वीर पढ़ी नहीं जा सकी' : 'The picture could not be read',
          body: hindi
              ? 'फिर कोशिश कीजिए, या हथेली हाथ से अंकित कीजिए।'
              : 'Try again, or trace your palm by hand.',
          actions: <Widget>[again, manual],
        );
    }
  }

  Widget _result(bool hindi, AppLocalizations l) {
    final PalmScan scan = _scan!;
    final StillScan still = _still!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        ToranaHeader(
          title: hindi ? 'आपकी हथेली' : 'Your palm',
          subtitle: hindi
              ? '${scan.sideSaid.hindi}, हथेली की ओर से देखा गया।'
              : '${scan.sideSaid.english}, seen from the palm side.',
        ),
        if (_photo != null)
          Panel(
            padding: const EdgeInsets.all(8),
            child: PalmPhotoView(
              image: _photo!,
              lines: scan.found,
              previewScale: still.previewScale,
              hindi: hindi,
            ),
          ),
        if (scan.outcome == ScanOutcome.shapeOnly)
          Panel(
            child: Text(
              hindi
                  ? 'इस तस्वीर में कोई रेखा पर्याप्त साफ़ नहीं दिखी, इसलिए सिर्फ़ हाथ की बनावट मापी गई। बराबर और तेज़ रोशनी में फिर कोशिश कीजिए, या रेखाएँ हाथ से अंकित कीजिए।'
                  : 'No line was clear enough in this photograph, so only the shape of your hand was measured. Try again in bright, even light, or trace the lines by hand.',
              key: const ValueKey<String>('shape-only'),
            ),
          ),
        if (scan.reading != null)
          PalmReadingPanels(reading: scan.reading!, hindi: hindi),
        Panel(
          title: hindi ? 'कैमरे ने क्या मापा' : 'What the camera measured',
          child: SayList(items: scan.measured, hindi: hindi),
        ),
        Panel(
          title: hindi ? 'क्या ध्यान रखें' : 'What to keep in mind',
          child: SayList(
            items: <Say>[
              ...scan.caveats,
              const Say(
                'Traditions differ on which hand to read. Many read the hand you write with for what you have made of yourself, and the other for what you began with. Scan the other hand too if you like.',
                'किस हाथ को देखना है, इस पर परंपराओं में मतभेद है। कई लोग जिस हाथ से लिखते हैं उसे आपके कर्म का और दूसरे को जन्म के संकेतों का मानते हैं। चाहें तो दूसरा हाथ भी दिखाइए।',
              ),
              const Say(
                'This is traditional palmistry, to reflect on, not a prediction. It says nothing about health, pregnancy, exams, court cases or investments.',
                'यह पारंपरिक हस्तरेखा-शास्त्र है, सोचने के लिए, भविष्यवाणी नहीं। यह स्वास्थ्य, गर्भ, परीक्षा, मुक़दमे या निवेश के बारे में कुछ नहीं कहता।',
              ),
            ],
            hindi: hindi,
          ),
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          key: const ValueKey<String>('scan-again'),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(hindi ? 'फिर से या दूसरा हाथ दिखाइए' : 'Scan again, or the other hand'),
          onPressed: _open,
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey<String>('trace-by-hand'),
          onPressed: _manual,
          child: Text(
            hindi ? 'रेखाएँ हाथ से अंकित कीजिए' : 'Trace the lines by hand',
          ),
        ),
        DisclaimerNote(l.disclaimer),
      ],
    );
  }
}
