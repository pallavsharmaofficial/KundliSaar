import '../engine/astro/ephemeris.dart' show Graha;
import '../engine/jyotish/phaladesh.dart';

/// How far ahead a "better time" is looked for.
const Duration lookAhead = Duration(days: 365 * 30);

/// The experience of living in one antardasha window is the larger chapter
/// (the mahadasha) and the page (the antardasha) together, so the two scores
/// are blended equally. The scores come from phaladesh; the blend, and the
/// thresholds below, are this feature's own convention, like the weights in
/// phaladesh itself.
double blendScore(TimelineWindow w) =>
    0.5 * w.maha.score + 0.5 * w.period.score;

/// The same thresholds phaladesh uses to turn one score into a tone.
Tone blendTone(double score) => score >= 3.0
    ? Tone.supportive
    : (score <= 0.0 ? Tone.demanding : Tone.mixed);

enum StretchKind {
  /// The window running now is already one the chart supports.
  alreadyGood,

  /// A later window is clearly better than now.
  betterAhead,

  /// Nothing is clearly better, but a later window is somewhat easier.
  modestAhead,

  /// Nothing ahead, within the range read, is better than now.
  nothingAhead,

  /// The moment asked about is outside the chart's timeline.
  outside,
}

/// Where the person stands in the timeline and the next stretch that is better
/// than that. It holds windows only; the words are written elsewhere.
class Stretch {
  const Stretch({
    required this.kind,
    this.current,
    this.target,
    this.between = const <TimelineWindow>[],
    this.goodRun = const <TimelineWindow>[],
    this.after,
    this.nextGood,
  });

  final StretchKind kind;

  /// The window running at the moment asked.
  final TimelineWindow? current;

  /// For [StretchKind.betterAhead] and [StretchKind.modestAhead]: the window
  /// that is better than now.
  final TimelineWindow? target;

  /// The windows strictly between the current one and [target].
  final List<TimelineWindow> between;

  /// For [StretchKind.alreadyGood]: the current window and the supportive ones
  /// that follow it without a break.
  final List<TimelineWindow> goodRun;

  /// For [StretchKind.alreadyGood]: the first window after the run.
  final TimelineWindow? after;

  /// For [StretchKind.alreadyGood]: the next supportive window after [after].
  final TimelineWindow? nextGood;

  /// The window the explanation of "how" is about: the better one ahead, or
  /// the one running now when it is already good.
  TimelineWindow? get subject => target ?? current;
}

/// True when the periods in [w] concentrate on one of the houses in [focus],
/// or when the antardasha lord is itself a lord of one of them
/// ([concerns]). With no focus every window counts.
bool windowTouches(
  TimelineWindow w,
  Set<int> focus, {
  bool Function(Graha)? concerns,
}) =>
    focus.isEmpty ||
    w.period.areas.any((LifeArea a) => focus.contains(a.house)) ||
    w.maha.areas.any((LifeArea a) => focus.contains(a.house)) ||
    (concerns?.call(w.antarLord) ?? false);

/// Finds the next stretch that is better than now.
///
/// With [focus] empty the question is general and a stretch is good when the
/// blended score reads as supportive. With houses in [focus] the question is
/// about one part of life, and a stretch only counts when the periods in it
/// concentrate on one of those houses as well.
Stretch findStretch(
  LifeTimeline timeline,
  DateTime now, {
  Set<int> focus = const <int>{},
  bool Function(Graha)? concerns,
}) {
  final TimelineWindow? cur = timeline.windowAt(now);
  if (cur == null) return const Stretch(kind: StretchKind.outside);
  final List<TimelineWindow> all = timeline.windows;
  final int at = all.indexOf(cur);

  bool touches(TimelineWindow w) => windowTouches(w, focus, concerns: concerns);
  bool good(TimelineWindow w) =>
      touches(w) && blendTone(blendScore(w)) == Tone.supportive;

  if (good(cur)) {
    final List<TimelineWindow> run = <TimelineWindow>[cur];
    int j = at + 1;
    while (j < all.length && good(all[j])) {
      run.add(all[j]);
      j++;
    }
    TimelineWindow? next;
    for (int m = j + 1; m < all.length; m++) {
      if (good(all[m])) {
        next = all[m];
        break;
      }
    }
    return Stretch(
      kind: StretchKind.alreadyGood,
      current: cur,
      goodRun: run,
      after: j < all.length ? all[j] : null,
      nextGood: next,
    );
  }

  final double base = blendScore(cur);
  final DateTime horizon = now.add(lookAhead);

  int? found;
  var kind = StretchKind.betterAhead;
  if (focus.isEmpty) {
    // A general question: the first stretch the chart clearly supports and
    // that is clearly better than now; failing that, one that is a little
    // easier.
    for (int j = at + 1; j < all.length; j++) {
      final TimelineWindow w = all[j];
      if (w.start.isAfter(horizon)) break;
      if (good(w) && blendScore(w) >= base + 1.0) {
        found = j;
        break;
      }
    }
    if (found == null) {
      for (int j = at + 1; j < all.length; j++) {
        final TimelineWindow w = all[j];
        if (w.start.isAfter(horizon)) break;
        final double score = blendScore(w);
        if (score > 0 && score > base + 0.5) {
          found = j;
          kind = StretchKind.modestAhead;
          break;
        }
      }
    }
  } else {
    // One part of life: the soonest stretch that puts its weight on it and
    // is at least a fair one, not weaker than now when now already touches
    // it. It is "clearly better" when the chart fully supports it.
    final bool nowTouches = touches(cur);
    for (int j = at + 1; j < all.length; j++) {
      final TimelineWindow w = all[j];
      if (w.start.isAfter(horizon)) break;
      final double score = blendScore(w);
      if (touches(w) && score >= 2.0 && (!nowTouches || score >= base)) {
        found = j;
        kind = blendTone(score) == Tone.supportive
            ? StretchKind.betterAhead
            : StretchKind.modestAhead;
        break;
      }
    }
  }
  if (found == null) {
    return Stretch(kind: StretchKind.nothingAhead, current: cur);
  }
  return Stretch(
    kind: kind,
    current: cur,
    target: all[found],
    between: all.sublist(at + 1, found),
  );
}
