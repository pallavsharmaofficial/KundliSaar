import 'dart:collection';
import 'dart:math' as math;

import 'palm_geometry.dart';
import 'palm_types.dart';

/// What the person should do next. These messages are most of whether the
/// camera feels good, so each is one short instruction in plain words, in the
/// language the app is set to. They are in this file, not in the screen, so a
/// test can hold every one of them to both languages.
enum Guidance {
  noHand,
  tooDark,
  tooBright,
  tooFar,
  tooClose,
  partlyOut,
  showPalm,
  openFingers,
  holdSteady,
  blurry,
  ready,
}

class GuidanceText {
  const GuidanceText(this.english, this.hindi);

  final String english;
  final String hindi;

  String of(bool hindi) => hindi ? this.hindi : english;
}

const Map<Guidance, GuidanceText> guidanceText = <Guidance, GuidanceText>{
  Guidance.noHand: GuidanceText(
    'Show your open palm to the camera',
    'अपनी खुली हथेली कैमरे के सामने लाइए',
  ),
  Guidance.tooDark: GuidanceText(
    'Too dark. Move to a window or switch on a light',
    'रोशनी कम है। खिड़की के पास जाइए या बत्ती जलाइए',
  ),
  Guidance.tooBright: GuidanceText(
    'Too much glare. Turn away from the direct light',
    'चमक ज़्यादा है। सीधी रोशनी से हटकर दिखाइए',
  ),
  Guidance.tooFar: GuidanceText(
    'Move a little closer',
    'थोड़ा और पास लाइए',
  ),
  Guidance.tooClose: GuidanceText(
    'Move back a little',
    'थोड़ा पीछे कीजिए',
  ),
  Guidance.partlyOut: GuidanceText(
    'Bring your whole hand into the frame',
    'पूरा हाथ फ्रेम के अंदर लाइए',
  ),
  Guidance.showPalm: GuidanceText(
    'Show the palm, not the back of the hand',
    'हथेली दिखाइए, हाथ का पिछला हिस्सा नहीं',
  ),
  Guidance.openFingers: GuidanceText(
    'Open your fingers and keep them straight',
    'उँगलियाँ खोलकर सीधी रखिए',
  ),
  Guidance.holdSteady: GuidanceText(
    'Hold your hand steady',
    'हाथ को स्थिर रखिए',
  ),
  Guidance.blurry: GuidanceText(
    'The picture is soft. Hold still and let it focus',
    'तस्वीर धुँधली है। हाथ रोककर फ़ोकस होने दीजिए',
  ),
  Guidance.ready: GuidanceText(
    'Good. Stay just like that',
    'बहुत बढ़िया। ऐसे ही रुकिए',
  ),
};

/// Every number the guidance decides by, in one place so they can be tuned
/// against real phones without hunting.
class GuideTuning {
  const GuideTuning({
    this.minFill = 0.50,
    this.maxFill = 0.95,
    this.closeFill = 0.88,
    this.minExtension = 1.45,
    this.minPalmBrightness = 0.20,
    this.maxPalmBrightness = 0.90,
    this.maxClipped = 0.18,
    this.darkFrame = 0.12,
    this.minSharpness = 0.025,
    this.steadyWindowMs = 450,
    this.steadyMove = 0.10,
    this.steadyScale = 0.08,
  });

  /// The hand must cover at least this much of the frame along its tightest
  /// axis, and no more than [maxFill].
  final double minFill;
  final double maxFill;

  /// A hand cut by the edge of the picture and bigger than this is too close,
  /// not merely off to one side.
  final double closeFill;

  /// Fingertip-to-wrist over knuckle-to-wrist, below which the fingers are
  /// curled.
  final double minExtension;
  final double minPalmBrightness;
  final double maxPalmBrightness;
  final double maxClipped;

  /// With no hand found, a picture this dark is the reason.
  final double darkFrame;
  final double minSharpness;

  /// How long, and how far the hand may drift over it (as a share of the palm's
  /// length), for it to count as still.
  final int steadyWindowMs;
  final double steadyMove;
  final double steadyScale;
}

/// Judges one look at the hand.
Guidance assess(
  HandObservation? observation, {
  bool steady = true,
  GuideTuning tuning = const GuideTuning(),
}) {
  if (observation == null) return Guidance.noHand;
  final HandGeometry g = HandGeometry.of(observation);
  final FrameLook look = observation.look;

  if (look.palmBrightness < tuning.minPalmBrightness) return Guidance.tooDark;
  if (look.palmBrightness > tuning.maxPalmBrightness ||
      look.clipped > tuning.maxClipped) {
    return Guidance.tooBright;
  }
  if (g.facing == Facing.back) return Guidance.showPalm;
  if (g.partlyOutside) {
    return g.fill >= tuning.closeFill ? Guidance.tooClose : Guidance.partlyOut;
  }
  if (g.fill < tuning.minFill) return Guidance.tooFar;
  if (g.fill > tuning.maxFill) return Guidance.tooClose;
  if (g.minExtension < tuning.minExtension) return Guidance.openFingers;
  if (!steady) return Guidance.holdSteady;
  if (look.sharpness < tuning.minSharpness) return Guidance.blurry;
  return Guidance.ready;
}

/// With no hand found, say why when the picture itself is the reason.
Guidance assessNothing(double frameBrightness, {GuideTuning? tuning}) {
  final GuideTuning t = tuning ?? const GuideTuning();
  return frameBrightness < t.darkFrame ? Guidance.tooDark : Guidance.noHand;
}

/// Decides whether the hand has been still for a moment, by how far its middle
/// and its size moved over the last few looks.
class SteadyTracker {
  SteadyTracker({this.tuning = const GuideTuning()});

  final GuideTuning tuning;
  final Queue<_Sample> _samples = Queue<_Sample>();

  void clear() => _samples.clear();

  void add(HandObservation observation) {
    final HandGeometry g = HandGeometry.of(observation);
    _samples.addLast(_Sample(observation.timeMs, g.centre, g.palmLength));
    while (_samples.isNotEmpty &&
        observation.timeMs - _samples.first.timeMs > tuning.steadyWindowMs) {
      _samples.removeFirst();
    }
  }

  /// True once the window holds enough looks and the hand barely moved in it.
  bool get steady {
    if (_samples.length < 3) return false;
    final _Sample last = _samples.last;
    if (last.timeMs - _samples.first.timeMs < tuning.steadyWindowMs * 0.6) {
      return false;
    }
    final double palm = last.palm <= 0 ? 1 : last.palm;
    double move = 0;
    double scale = 0;
    for (final _Sample a in _samples) {
      for (final _Sample b in _samples) {
        move = math.max(move, a.centre.distanceTo(b.centre) / palm);
        scale = math.max(scale, (a.palm - b.palm).abs() / palm);
      }
    }
    return move <= tuning.steadyMove && scale <= tuning.steadyScale;
  }
}

class _Sample {
  const _Sample(this.timeMs, this.centre, this.palm);

  final int timeMs;
  final Pt centre;
  final double palm;
}

/// Keeps the message from flickering. A new instruction is shown only once it
/// has come up on two looks running, so a single odd look does not make the
/// words jump; the hand is looked at about eight times a second, so this costs
/// a quarter of a second at most.
class GuidanceSmoother {
  GuidanceSmoother({this.needed = 2});

  final int needed;
  Guidance _shown = Guidance.noHand;
  Guidance? _candidate;
  int _count = 0;

  Guidance get shown => _shown;

  Guidance push(Guidance g) {
    if (g == _shown) {
      _candidate = null;
      _count = 0;
      return _shown;
    }
    if (g == _candidate) {
      _count++;
    } else {
      _candidate = g;
      _count = 1;
    }
    if (_count >= needed) {
      _shown = g;
      _candidate = null;
      _count = 0;
    }
    return _shown;
  }

  void reset() {
    _shown = Guidance.noHand;
    _candidate = null;
    _count = 0;
  }
}
