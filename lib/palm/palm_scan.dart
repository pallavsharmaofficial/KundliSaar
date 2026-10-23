import '../engine/jyotish/hastrekha.dart';
import 'crease_finder.dart';
import 'palm_geometry.dart';
import 'palm_types.dart';

/// What came of the photograph.
enum ScanOutcome {
  /// A palm was seen and at least one of the great lines was clear.
  read,

  /// A palm was seen and measured, but no line was clear enough to name.
  shapeOnly,

  /// The hand was the back of the hand.
  backOfHand,

  /// No hand could be found in the chosen frame.
  noHand,

  /// Part of the hand was outside the picture, so its shape cannot be
  /// measured.
  cutOff,
}

/// The palm knuckle span over palm length at which the app calls a palm
/// square. The engine's rule is that a palm is square above 0.82 of its width
/// to its length, measured on the whole palm. The span between the knuckles is
/// narrower than that, and was found on a handful of photographs to run about
/// four fifths of it, so the span is scaled by 1.25 before it reaches the
/// engine. The raw number and the raw cut-off are what the person is shown.
const double palmWidthScale = 1.25;
const double squareFromRaw = 0.82 / palmWidthScale;

/// The engine's own rule for long fingers: the finger as long as the palm.
const double longFingerFrom = 0.95;

/// How near a cut-off counts as "too close for a photograph to say". Hand
/// landmarks are good to a few percent of the palm.
const double borderlineBand = 0.04;

class Say {
  const Say(this.english, this.hindi);

  final String english;
  final String hindi;

  String of(bool hindi) => hindi ? this.hindi : english;
}

/// Everything the capture found, turned into what the existing engine reads
/// and the plain words about what was and was not measured.
class PalmScan {
  const PalmScan({
    required this.outcome,
    required this.side,
    required this.facing,
    required this.widthRatio,
    required this.fingerRatio,
    required this.handType,
    required this.borderline,
    required this.found,
    required this.notMadeOut,
    required this.reading,
    required this.measured,
    required this.caveats,
  });

  final ScanOutcome outcome;

  /// Which hand it was, by where the thumb sat and which side faced the
  /// camera.
  final HandSide side;
  final Facing facing;

  /// Knuckle span over palm length, and finger over palm, as measured.
  final double widthRatio;
  final double fingerRatio;
  final HandType handType;

  /// True when either measure sat too near its cut-off for a photograph to
  /// settle the hand type.
  final bool borderline;

  final Map<FoundLineKind, FoundLine> found;
  final List<PalmLine> notMadeOut;

  /// Null when nothing could be read.
  final HastrekhaReading? reading;

  /// Plain statements of what was measured from the photograph.
  final List<Say> measured;

  /// What was not measured, or not clear, and what to take care over.
  final List<Say> caveats;

  Say get sideSaid => side == HandSide.left
      ? const Say('Left hand', 'बायाँ हाथ')
      : const Say('Right hand', 'दायाँ हाथ');
}

PalmLine _engineLine(FoundLineKind kind) {
  switch (kind) {
    case FoundLineKind.life:
      return PalmLine.life;
    case FoundLineKind.head:
      return PalmLine.head;
    case FoundLineKind.heart:
      return PalmLine.heart;
  }
}

const Map<PalmLine, Say> _lineWords = <PalmLine, Say>{
  PalmLine.life: Say('life line', 'जीवन रेखा'),
  PalmLine.head: Say('head line', 'मस्तिष्क रेखा'),
  PalmLine.heart: Say('heart line', 'हृदय रेखा'),
};

String _two(double v) => v.toStringAsFixed(2);

/// Turns one look at the hand, and what was found on its palm, into a reading.
///
/// Honesty rules, kept here where they can be tested:
///  * a line that was not clear is listed as not made out, never supplied;
///  * the fate and sun lines, breaks, chains, forks and the heights of the
///    mounts are said outright not to be judged from a photograph;
///  * the back of a hand gives no reading, and a palm that could not be told
///    from the back needs two lines before any are believed.
PalmScan buildScan({required HandObservation? hand, CreaseResult? creases}) {
  if (hand == null) {
    return const PalmScan(
      outcome: ScanOutcome.noHand,
      side: HandSide.right,
      facing: Facing.unclear,
      widthRatio: 0,
      fingerRatio: 0,
      handType: HandType.earth,
      borderline: false,
      found: <FoundLineKind, FoundLine>{},
      notMadeOut: <PalmLine>[],
      reading: null,
      measured: <Say>[],
      caveats: <Say>[],
    );
  }
  final HandGeometry g = HandGeometry.of(hand);
  final HandSide side = g.palmSide;
  if (g.partlyOutside) {
    return PalmScan(
      outcome: ScanOutcome.cutOff,
      side: side,
      facing: g.facing,
      widthRatio: g.widthRatio,
      fingerRatio: g.fingerRatio,
      handType: HandType.earth,
      borderline: false,
      found: const <FoundLineKind, FoundLine>{},
      notMadeOut: const <PalmLine>[],
      reading: null,
      measured: const <Say>[],
      caveats: const <Say>[],
    );
  }
  if (g.facing == Facing.back) {
    return PalmScan(
      outcome: ScanOutcome.backOfHand,
      side: side,
      facing: g.facing,
      widthRatio: g.widthRatio,
      fingerRatio: g.fingerRatio,
      handType: HandType.earth,
      borderline: false,
      found: const <FoundLineKind, FoundLine>{},
      notMadeOut: const <PalmLine>[],
      reading: null,
      measured: const <Say>[],
      caveats: const <Say>[],
    );
  }

  final HandType type = handTypeFrom(
    palmWidth: g.widthRatio * palmWidthScale,
    palmLength: 1,
    fingerLength: g.fingerRatio,
  );
  final bool borderline =
      (g.widthRatio - squareFromRaw).abs() < borderlineBand ||
      (g.fingerRatio - longFingerFrom).abs() < borderlineBand;

  Map<FoundLineKind, FoundLine> found = creases?.lines ?? const <FoundLineKind, FoundLine>{};
  // A palm that could not be told from a back needs more than one line before
  // any is believed: the back of a hand has creases and veins of its own.
  if (g.facing == Facing.unclear && found.length < 2) {
    found = const <FoundLineKind, FoundLine>{};
  }

  final Map<PalmLine, TracedLine> traced = <PalmLine, TracedLine>{
    for (final FoundLine line in found.values)
      _engineLine(line.kind): TracedLine(
        line: _engineLine(line.kind),
        points: <PalmPoint>[
          for (final Pt p in line.box) PalmPoint(p.x, p.y),
        ],
      ),
  };
  final List<PalmLine> missing = <PalmLine>[
    for (final PalmLine l in const <PalmLine>[
      PalmLine.life,
      PalmLine.head,
      PalmLine.heart,
    ])
      if (!traced.containsKey(l)) l,
  ];

  final HastrekhaReading reading = readPalm(
    lines: traced,
    // The height of a mount cannot be seen in a flat picture, so none is
    // claimed: the engine reads a mount only when it is told it is raised.
    mountProminence: const <Mount, int>{},
    handType: type,
  );

  final List<Say> measured = <Say>[
    Say(
      '${g.palmSide == HandSide.left ? 'Left' : 'Right'} hand, palm toward the camera.',
      '${g.palmSide == HandSide.left ? 'बायाँ' : 'दायाँ'} हाथ, हथेली कैमरे की ओर।',
    ),
    Say(
      'Palm: the knuckles span ${_two(g.widthRatio)} of the palm’s length. '
          'The app calls a palm square from ${_two(squareFromRaw)}.',
      'हथेली: उँगलियों की जड़ों की चौड़ाई, हथेली की लंबाई की ${_two(g.widthRatio)} है। '
          'ऐप ${_two(squareFromRaw)} से ऊपर को चौकोर मानता है।',
    ),
    Say(
      'Fingers: the middle finger is ${_two(g.fingerRatio)} of the palm’s length. '
          'The app calls fingers long from ${_two(longFingerFrom)}.',
      'उँगलियाँ: बीच की उँगली हथेली की लंबाई की ${_two(g.fingerRatio)} है। '
          'ऐप ${_two(longFingerFrom)} से ऊपर को लंबी मानता है।',
    ),
    if (found.isNotEmpty)
      Say(
        'Lines the app traced on the photograph: '
            '${_names(found.keys.map(_engineLine), false)}.',
        'तस्वीर पर ऐप ने ये रेखाएँ खींचीं: '
            '${_names(found.keys.map(_engineLine), true)}।',
      ),
  ];

  final List<Say> caveats = <Say>[
    if (borderline)
      const Say(
        'The hand type sits close to a dividing line, so a photograph cannot settle it.',
        'हस्त-प्रकार विभाजन-रेखा के बहुत पास है, इसलिए तस्वीर से पक्का नहीं कहा जा सकता।',
      ),
    if (creases != null && !creases.usable)
      const Say(
        'The photograph showed too little fine detail on the palm for any line to be traced: '
            'it may be too far, too soft, or too flat in the light.',
        'तस्वीर में हथेली पर इतना बारीक ब्योरा नहीं दिखा कि कोई रेखा खींची जा सके: '
            'हाथ दूर, तस्वीर धुँधली या रोशनी बहुत सपाट हो सकती है।',
      ),
    for (final FoundLine f in found.values)
      if (f.faint)
        Say(
          'The ${_lineWords[_engineLine(f.kind)]!.english} showed only faintly in this photograph '
              '(drawn dashed), so what is said about it is less sure.',
          '${_lineWords[_engineLine(f.kind)]!.hindi} इस तस्वीर में हल्की दिखी (टूटी लकीर से दिखाई गई), '
              'इसलिए उसके बारे में कही बात कम पक्की है।',
        ),
    for (final PalmLine l in missing)
      Say(
        'The ${_lineWords[l]!.english} was not clear enough in this photograph to read, '
            'so nothing is said about it.',
        '${_lineWords[l]!.hindi} इस तस्वीर में पर्याप्त साफ़ नहीं दिखी, इसलिए उसके बारे में कुछ नहीं कहा गया।',
      ),
    if (g.facing == Facing.unclear)
      const Say(
        'The camera could not be sure which side of the hand faced it. '
            'It was taken to be the palm.',
        'कैमरा पक्का नहीं कर पाया कि हाथ का कौन-सा हिस्सा सामने था। इसे हथेली माना गया है।',
      ),
    if (found.isNotEmpty)
      const Say(
        'The lines were traced by the app from your photograph. If they do not sit on '
            'your own lines, trust your eyes, not the app, and trace by hand.',
        'रेखाएँ ऐप ने आपकी तस्वीर से खींची हैं। अगर वे आपकी अपनी रेखाओं पर न बैठें, '
            'तो अपनी आँखों पर भरोसा कीजिए, ऐप पर नहीं, और हाथ से अंकित कीजिए।',
      ),
    const Say(
      'Not judged from a photograph: the fate and sun lines, any break, chain or fork in a '
          'line, and how raised each mount is. Trace those by hand if you want them read.',
      'तस्वीर से नहीं आँका गया: भाग्य और सूर्य रेखा, रेखाओं में टूट, जंजीर या काँटा, '
          'और पर्वतों का उभार। इन्हें पढ़वाना हो तो हाथ से अंकित कीजिए।',
    ),
  ];

  return PalmScan(
    outcome: found.isEmpty ? ScanOutcome.shapeOnly : ScanOutcome.read,
    side: side,
    facing: g.facing,
    widthRatio: g.widthRatio,
    fingerRatio: g.fingerRatio,
    handType: type,
    borderline: borderline,
    found: found,
    notMadeOut: missing,
    reading: reading,
    measured: measured,
    caveats: caveats,
  );
}

String _names(Iterable<PalmLine> lines, bool hindi) => lines
    .map((PalmLine l) => hindi ? _lineWords[l]!.hindi : _lineWords[l]!.english)
    .join(hindi ? ', ' : ', ');
