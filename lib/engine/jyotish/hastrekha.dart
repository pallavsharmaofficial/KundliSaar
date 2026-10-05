import 'dart:math' as math;

import '../astro/ephemeris.dart';
import 'chart.dart';
import 'graha_data.dart';

/// Hastrekha, palmistry as Samudrika Shastra sets it out.
///
/// There is no machine vision here and the app does not pretend otherwise:
/// the person traces their own lines over a palm outline, optionally on top of
/// a photograph of their hand, and the engine reads the shape they drew by the
/// classical rules. What it measures is stated beside every reading, so a
/// reader can see exactly which part of their trace produced which sentence.
class PalmPoint {
  const PalmPoint(this.x, this.y);

  /// Both normalised to the palm box, 0 to 1, origin at the top left.
  final double x;
  final double y;

  double distanceTo(PalmPoint other) =>
      math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));
}

enum PalmLine { life, head, heart, fate, sun, marriage }

enum HandType { earth, air, water, fire }

/// The mounts, each carrying its graha. This is where palmistry and the
/// kundli touch: the same nine names, read from two different places.
enum Mount { jupiter, saturn, sun, mercury, marsUpper, marsLower, venus, moon }

const Map<Mount, Graha> mountGraha = <Mount, Graha>{
  Mount.jupiter: Graha.jupiter,
  Mount.saturn: Graha.saturn,
  Mount.sun: Graha.sun,
  Mount.mercury: Graha.mercury,
  Mount.marsUpper: Graha.mars,
  Mount.marsLower: Graha.mars,
  Mount.venus: Graha.venus,
  Mount.moon: Graha.moon,
};

const Map<Mount, PalmPoint> mountCentres = <Mount, PalmPoint>{
  Mount.jupiter: PalmPoint(0.33, 0.30),
  Mount.saturn: PalmPoint(0.50, 0.27),
  Mount.sun: PalmPoint(0.66, 0.30),
  Mount.mercury: PalmPoint(0.80, 0.34),
  Mount.marsUpper: PalmPoint(0.84, 0.48),
  Mount.marsLower: PalmPoint(0.27, 0.45),
  Mount.venus: PalmPoint(0.28, 0.72),
  Mount.moon: PalmPoint(0.76, 0.72),
};

const Map<Mount, List<String>> mountNames = <Mount, List<String>>{
  Mount.jupiter: <String>['Jupiter', 'गुरु पर्वत'],
  Mount.saturn: <String>['Saturn', 'शनि पर्वत'],
  Mount.sun: <String>['Sun', 'सूर्य पर्वत'],
  Mount.mercury: <String>['Mercury', 'बुध पर्वत'],
  Mount.marsUpper: <String>['Upper Mars', 'उपरी मंगल'],
  Mount.marsLower: <String>['Lower Mars', 'निचला मंगल'],
  Mount.venus: <String>['Venus', 'शुक्र पर्वत'],
  Mount.moon: <String>['Moon', 'चंद्र पर्वत'],
};

const Map<PalmLine, List<String>> lineNames = <PalmLine, List<String>>{
  PalmLine.life: <String>['Life line', 'जीवन रेखा'],
  PalmLine.head: <String>['Head line', 'मस्तिष्क रेखा'],
  PalmLine.heart: <String>['Heart line', 'हृदय रेखा'],
  PalmLine.fate: <String>['Fate line', 'भाग्य रेखा'],
  PalmLine.sun: <String>['Sun line', 'सूर्य रेखा'],
  PalmLine.marriage: <String>['Marriage line', 'विवाह रेखा'],
};

/// The shape the app starts the user with, which they then drag into place.
const Map<PalmLine, List<PalmPoint>> defaultTrace = <PalmLine, List<PalmPoint>>{
  PalmLine.life: <PalmPoint>[
    PalmPoint(0.36, 0.34),
    PalmPoint(0.28, 0.48),
    PalmPoint(0.27, 0.66),
    PalmPoint(0.35, 0.86),
  ],
  PalmLine.head: <PalmPoint>[
    PalmPoint(0.32, 0.42),
    PalmPoint(0.48, 0.46),
    PalmPoint(0.62, 0.50),
    PalmPoint(0.74, 0.54),
  ],
  PalmLine.heart: <PalmPoint>[
    PalmPoint(0.84, 0.36),
    PalmPoint(0.68, 0.30),
    PalmPoint(0.52, 0.28),
    PalmPoint(0.38, 0.31),
  ],
  PalmLine.fate: <PalmPoint>[
    PalmPoint(0.52, 0.88),
    PalmPoint(0.52, 0.70),
    PalmPoint(0.51, 0.52),
    PalmPoint(0.50, 0.36),
  ],
  PalmLine.sun: <PalmPoint>[
    PalmPoint(0.70, 0.80),
    PalmPoint(0.68, 0.64),
    PalmPoint(0.67, 0.50),
    PalmPoint(0.66, 0.38),
  ],
  PalmLine.marriage: <PalmPoint>[PalmPoint(0.86, 0.26), PalmPoint(0.92, 0.26)],
};

/// What the person drew for one line, plus the marks they ticked on it.
class TracedLine {
  const TracedLine({
    required this.line,
    required this.points,
    this.isPresent = true,
    this.hasBreak = false,
    this.isChained = false,
    this.isForked = false,
  });

  final PalmLine line;
  final List<PalmPoint> points;

  /// A fate line or a sun line may simply not be there, which is itself read.
  final bool isPresent;
  final bool hasBreak;
  final bool isChained;
  final bool isForked;

  double get length {
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += points[i - 1].distanceTo(points[i]);
    }
    return total;
  }

  PalmPoint get start => points.first;
  PalmPoint get end => points.last;

  /// How far the middle of the drawn line bows away from a straight chord.
  double get curvature {
    if (points.length < 3) return 0;
    final PalmPoint a = points.first;
    final PalmPoint b = points.last;
    double worst = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final PalmPoint p = points[i];
      final double area =
          ((b.x - a.x) * (a.y - p.y) - (a.x - p.x) * (b.y - a.y)).abs();
      final double chord = a.distanceTo(b);
      if (chord > 0) worst = math.max(worst, area / chord);
    }
    return worst;
  }

  Mount? nearestMount(PalmPoint point) {
    Mount? best;
    double bestDistance = 0.14;
    mountCentres.forEach((Mount mount, PalmPoint centre) {
      final double distance = centre.distanceTo(point);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = mount;
      }
    });
    return best;
  }
}

class LineReading {
  const LineReading({
    required this.line,
    required this.measured,
    required this.measuredHindi,
    required this.reading,
    required this.readingHindi,
  });

  final PalmLine line;

  /// The measurement the reading came from, stated plainly.
  final String measured;
  final String measuredHindi;
  final String reading;
  final String readingHindi;
}

class MountReading {
  const MountReading({
    required this.mount,
    required this.prominence,
    required this.reading,
    required this.readingHindi,
    this.chartAgreement,
    this.chartAgreementHindi,
  });

  final Mount mount;

  /// 0 flat, 1 ordinary, 2 raised.
  final int prominence;
  final String reading;
  final String readingHindi;

  /// What the kundli says about the same graha, when a chart is at hand.
  final String? chartAgreement;
  final String? chartAgreementHindi;
}

class HastrekhaReading {
  const HastrekhaReading({
    required this.handType,
    required this.lines,
    required this.mounts,
    required this.summary,
    required this.summaryHindi,
  });

  final HandType handType;
  final List<LineReading> lines;
  final List<MountReading> mounts;
  final String summary;
  final String summaryHindi;
}

HandType handTypeFrom({
  required double palmWidth,
  required double palmLength,
  required double fingerLength,
}) {
  final bool squarePalm = palmWidth / palmLength > 0.82;
  final bool longFingers = fingerLength / palmLength > 0.95;
  if (squarePalm && !longFingers) return HandType.earth;
  if (squarePalm && longFingers) return HandType.air;
  if (!squarePalm && longFingers) return HandType.water;
  return HandType.fire;
}

const Map<HandType, List<String>> handTypeText = <HandType, List<String>>{
  HandType.earth: <String>[
    'Earth hand: a square palm with short fingers. Practical, steady, happier building than debating.',
    'पृथ्वी हस्त: व्यावहारिक, स्थिर और परिश्रमी।',
  ],
  HandType.air: <String>[
    'Air hand: a square palm with long fingers. Talks, analyses, needs the reason before the task.',
    'वायु हस्त: तर्क, संवाद और जिज्ञासा।',
  ],
  HandType.water: <String>[
    'Water hand: a long palm with long fingers. Feels first, decides later, reads people quickly.',
    'जल हस्त: भावुकता, संवेदनशीलता और कल्पना।',
  ],
  HandType.fire: <String>[
    'Fire hand: a long palm with short fingers. Moves first, enthusiastic, impatient with detail.',
    'अग्नि हस्त: उत्साह, गति और नेतृत्व।',
  ],
};

LineReading _readLife(TracedLine line) {
  final double length = line.length;
  final double curve = line.curvature;
  final String size = length > 0.60
      ? 'long'
      : length > 0.40
      ? 'of ordinary length'
      : 'short';
  final String sizeHindi = length > 0.60
      ? 'लंबी'
      : length > 0.40
      ? 'सामान्य'
      : 'छोटी';
  final bool wide = curve > 0.08;
  final StringBuffer english = StringBuffer()
    ..write(
      'A $size life line, sweeping ${wide ? 'wide around the Venus mount' : 'close to the thumb'}. ',
    )
    ..write(
      wide
          ? 'The texts read a wide sweep as warmth and physical stamina, the kind of person others lean on. '
          : 'A close curve is read as reserve: energy that is kept rather than spent on everyone. ',
    );
  if (line.hasBreak) {
    english.write(
      'The break you marked is read as a change of place or circumstance, not as danger. ',
    );
  }
  if (line.isChained) {
    english.write('Chaining is read as uneven energy; rest is the remedy. ');
  }
  final StringBuffer hindi = StringBuffer()
    ..write('$sizeHindi जीवन रेखा, ')
    ..write(
      wide
          ? 'शुक्र पर्वत के चारों ओर चौड़ी। यह उष्मा और शारीरिक स्फूर्ति का संकेत है। '
          : 'अंगूठे के पास। यह संयम और संचय का संकेत है। ',
    );
  if (line.hasBreak) {
    hindi.write('टूट को स्थान या परिस्थिति का बदलाव माना जाता है, खतरा नहीं। ');
  }
  return LineReading(
    line: PalmLine.life,
    measured:
        'Length ${(length * 100).round()} of the palm box, bow ${(curve * 100).round()}',
    measuredHindi:
        'लंबाई ${(length * 100).round()}, वक्रता ${(curve * 100).round()}',
    reading: english.toString().trim(),
    readingHindi: hindi.toString().trim(),
  );
}

LineReading _readHead(TracedLine line) {
  final double slope = line.end.y - line.start.y;
  final double length = line.length;
  final bool sloping = slope > 0.10;
  final bool straight = slope < 0.05;
  final String english = <String>[
    if (length > 0.45)
      'A long head line: thinking that goes all the way round a question before it settles.'
    else
      'A short head line: decisions made quickly, with little patience for circling.',
    if (sloping)
      'It slopes toward the Moon mount, which is read as imagination, and often as a pull toward writing, design or anything made up rather than measured.'
    else if (straight)
      'It runs straight across, which is read as a practical mind that wants the facts in order.'
    else
      'It falls gently, the balance between the practical and the imaginative.',
    if (line.isForked)
      'The fork at the end is the writer’s fork, read as the ability to hold two views at once.',
  ].join(' ');
  final String hindi = <String>[
    if (length > 0.45)
      'लंबी मस्तिष्क रेखा: गहरा और पूरा विचार।'
    else
      'छोटी मस्तिष्क रेखा: तेज़ निर्णय।',
    if (sloping)
      'यह चंद्र पर्वत की ओर झुकी है, जो कल्पना का संकेत है।'
    else if (straight)
      'यह सीधी जाती है, जो व्यावहारिक बुद्धि का संकेत है।'
    else
      'यह हल्की झुकी है, संतुलित बुद्धि।',
  ].join(' ');
  return LineReading(
    line: PalmLine.head,
    measured:
        'Slope ${(slope * 100).round()}, length ${(length * 100).round()}',
    measuredHindi:
        'झुकाव ${(slope * 100).round()}, लंबाई ${(length * 100).round()}',
    reading: english,
    readingHindi: hindi,
  );
}

LineReading _readHeart(TracedLine line) {
  final Mount? endMount = line.nearestMount(line.end);
  final bool underJupiter = endMount == Mount.jupiter;
  final bool underSaturn = endMount == Mount.saturn;
  final double curve = line.curvature;
  final String english = <String>[
    if (underJupiter)
      'The heart line ends on the Jupiter mount, read as loving by ideal: loyalty given whole, and disappointment when it is not returned.'
    else if (underSaturn)
      'The heart line stops under Saturn, read as a guarded heart that gives slowly and keeps its own counsel.'
    else
      'The heart line runs between the mounts, read as affection that is warm but kept in proportion.',
    if (curve > 0.06)
      'Its curve is read as feeling that shows on the face.'
    else
      'Its straightness is read as feeling that is held rather than shown.',
    if (line.isChained)
      'Chaining on this line is read as many attachments rather than one steady one.',
  ].join(' ');
  final String hindi = <String>[
    if (underJupiter)
      'हृदय रेखा गुरु पर्वत पर समाप्त होती है: आदर्शवादी प्रेम और पूर्ण निष्ठा।'
    else if (underSaturn)
      'हृदय रेखा शनि के नीचे रुकती है: संयमित और धीरे खुलने वाला मन।'
    else
      'हृदय रेखा मध्य में समाप्त होती है: संतुलित स्नेह।',
  ].join(' ');
  return LineReading(
    line: PalmLine.heart,
    measured:
        'Ends near ${endMount == null ? 'no mount' : mountNames[endMount]![0]}',
    measuredHindi:
        'अंत ${endMount == null ? 'मध्य' : mountNames[endMount]![1]} के पास',
    reading: english,
    readingHindi: hindi,
  );
}

LineReading _readFate(TracedLine line) {
  if (!line.isPresent) {
    return const LineReading(
      line: PalmLine.fate,
      measured: 'Not present',
      measuredHindi: 'अनुपस्थित',
      reading:
          'No clear fate line. Classically read not as a life without direction but as one not handed a track: the work is chosen rather than inherited.',
      readingHindi:
          'स्पष्ट भाग्य रेखा नहीं। इसे दिशाहीनता नहीं, बल्कि अपना मार्ग स्वयं चुनने का संकेत माना जाता है।',
    );
  }
  final Mount? startMount = line.nearestMount(line.start);
  final bool fromMoon = startMount == Mount.moon;
  final bool fromVenus = startMount == Mount.venus;
  final String english = <String>[
    if (fromMoon)
      'The fate line rises from the Moon mount, read as a career carried by other people: public work, or work that depends on being chosen.'
    else if (fromVenus)
      'It rises from the Venus mount, read as a path shaped by family and by those who raised you.'
    else
      'It rises from the base of the palm, read as a direction set by your own effort rather than inheritance.',
    if (line.hasBreak)
      'The break is read as a change of work, with the new line taking over.'
    else
      'It runs unbroken, read as steady direction.',
  ].join(' ');
  final String hindi = <String>[
    if (fromMoon)
      'भाग्य रेखा चंद्र पर्वत से उठती है: दूसरों के सहयोग से आगे बढ़ने वाला कर्म।'
    else if (fromVenus)
      'यह शुक्र पर्वत से उठती है: परिवार से बना मार्ग।'
    else
      'यह हथेली के आधार से उठती है: अपने परिश्रम से बना मार्ग।',
  ].join(' ');
  return LineReading(
    line: PalmLine.fate,
    measured:
        'Starts near ${startMount == null ? 'the wrist' : mountNames[startMount]![0]}',
    measuredHindi:
        'आरंभ ${startMount == null ? 'मणिबंध' : mountNames[startMount]![1]} के पास',
    reading: english,
    readingHindi: hindi,
  );
}

LineReading _readSun(TracedLine line) => line.isPresent
    ? LineReading(
        line: PalmLine.sun,
        measured: 'Length ${(line.length * 100).round()}',
        measuredHindi: 'लंबाई ${(line.length * 100).round()}',
        reading: line.length > 0.25
            ? 'A clear sun line, read as recognition for what you make: the work is seen, not only done.'
            : 'A short sun line, read as recognition that arrives late rather than never.',
        readingHindi: line.length > 0.25
            ? 'स्पष्ट सूर्य रेखा: कार्य को पहचान मिलती है।'
            : 'छोटी सूर्य रेखा: पहचान देर से मिलती है।',
      )
    : const LineReading(
        line: PalmLine.sun,
        measured: 'Not present',
        measuredHindi: 'अनुपस्थित',
        reading:
            'No sun line. Read as work done away from the light, which the texts do not treat as a lack.',
        readingHindi: 'सूर्य रेखा नहीं। यह कमी नहीं मानी जाती।',
      );

const Map<Mount, List<String>> _mountHigh = <Mount, List<String>>{
  Mount.jupiter: <String>[
    'A raised Jupiter mount: ambition and the wish to lead, which the texts warn can turn to pride if the head line is short.',
    'गुरु पर्वत उभरा हुआ: महत्वाकांक्षा और नेतृत्व।',
  ],
  Mount.saturn: <String>[
    'A raised Saturn mount: discipline, solitude, and patience with slow work.',
    'शनि पर्वत उभरा हुआ: अनुशासन और धैर्य।',
  ],
  Mount.sun: <String>[
    'A raised Sun mount: an eye for beauty and a wish to be seen for the work.',
    'सूर्य पर्वत उभरा हुआ: कला और प्रतिष्ठा।',
  ],
  Mount.mercury: <String>[
    'A raised Mercury mount: quick speech, trade sense, and the ability to persuade.',
    'बुध पर्वत उभरा हुआ: वाणी और व्यापार कुशलता।',
  ],
  Mount.marsUpper: <String>[
    'A raised upper Mars: the courage that endures rather than attacks.',
    'उपरी मंगल उभरा हुआ: सहनशील साहस।',
  ],
  Mount.marsLower: <String>[
    'A raised lower Mars: the courage that acts, and a temper that needs somewhere to go.',
    'निचला मंगल उभरा हुआ: सक्रिय साहस।',
  ],
  Mount.venus: <String>[
    'A full Venus mount: physical vitality, affection, and a love of good food and company.',
    'शुक्र पर्वत भरा हुआ: स्नेह, स्फूर्ति और रसिकता।',
  ],
  Mount.moon: <String>[
    'A raised Moon mount: imagination, dreams that stay with you, and a pull toward water and travel.',
    'चंद्र पर्वत उभरा हुआ: कल्पना और यात्रा प्रेम।',
  ],
};

/// Reads the trace, and where a kundli is supplied, says whether the two
/// traditions agree about the same graha.
HastrekhaReading readPalm({
  required Map<PalmLine, TracedLine> lines,
  required Map<Mount, int> mountProminence,
  required HandType handType,
  Kundli? kundli,
}) {
  final List<LineReading> readings = <LineReading>[
    if (lines[PalmLine.life] != null) _readLife(lines[PalmLine.life]!),
    if (lines[PalmLine.head] != null) _readHead(lines[PalmLine.head]!),
    if (lines[PalmLine.heart] != null) _readHeart(lines[PalmLine.heart]!),
    if (lines[PalmLine.fate] != null) _readFate(lines[PalmLine.fate]!),
    if (lines[PalmLine.sun] != null) _readSun(lines[PalmLine.sun]!),
  ];

  final List<MountReading> mounts = <MountReading>[];
  mountProminence.forEach((Mount mount, int prominence) {
    if (prominence < 2) return;
    final Graha graha = mountGraha[mount]!;
    String? agreement;
    String? agreementHindi;
    if (kundli != null) {
      final PlacedGraha placed = kundli.grahas[graha]!;
      final bool strong =
          placed.dignity == Dignity.exalted ||
          placed.dignity == Dignity.own ||
          placed.dignity == Dignity.moolatrikona;
      final bool weak =
          placed.dignity == Dignity.debilitated || placed.isCombust;
      agreement = strong
          ? 'Your kundli agrees: ${grahaInfo(graha).english} is strong there too, in ${placed.rashi.name}.'
          : weak
          ? 'Your kundli reads it differently: ${grahaInfo(graha).english} is under pressure in the chart. Two traditions, two answers, both worth hearing.'
          : 'In the kundli ${grahaInfo(graha).english} is ordinary in strength, so the hand is saying more than the chart here.';
      agreementHindi = strong
          ? 'कुंडली भी यही कहती है: ${grahaInfo(graha).hindi} बलवान हैं।'
          : weak
          ? 'कुंडली में ${grahaInfo(graha).hindi} दुर्बल हैं — दो परंपराएँ, दो उत्तर।'
          : 'कुंडली में ${grahaInfo(graha).hindi} सामान्य बल में हैं।';
    }
    mounts.add(
      MountReading(
        mount: mount,
        prominence: prominence,
        reading: _mountHigh[mount]![0],
        readingHindi: _mountHigh[mount]![1],
        chartAgreement: agreement,
        chartAgreementHindi: agreementHindi,
      ),
    );
  });

  return HastrekhaReading(
    handType: handType,
    lines: readings,
    mounts: mounts,
    summary: handTypeText[handType]![0],
    summaryHindi: handTypeText[handType]![1],
  );
}
