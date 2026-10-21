// What a look at a hand comes to, as plain data. No Flutter in here: the same
// file is compiled to JavaScript for the web probe (web_probe.dart), so the
// browser's pipeline and the phone's can be summed up by the very same code.
import 'package:kundlisaar/palm/crease_finder.dart';
import 'package:kundlisaar/palm/frame.dart';
import 'package:kundlisaar/palm/palm_geometry.dart';
import 'package:kundlisaar/palm/palm_scan.dart';
import 'package:kundlisaar/palm/palm_types.dart';

/// The lines of the palm, searched for only when a hand was found and it is
/// not the back of the hand (as the trackers do).
CreaseResult? creasesFor(PalmFrame frame, HandObservation? hand) {
  if (hand == null) return null;
  final HandGeometry g = HandGeometry.of(hand);
  return g.facing == Facing.back
      ? null
      : findCreases(frame, hand.points, thumbOnLeft: g.thumbOnLeft);
}

/// What the measurements come to, so two paths can be compared and one can be
/// kept in a file.
Map<String, Object?> summarise(HandObservation? hand, CreaseResult? creases) {
  final PalmScan scan = buildScan(hand: hand, creases: creases);
  return <String, Object?>{
    'found': hand != null,
    'points': <double>[
      if (hand != null)
        for (final Pt p in hand.points) ...<double>[p.x, p.y],
    ],
    'presence': hand?.presence,
    'rightProbability': hand?.rightProbability,
    'outcome': scan.outcome.name,
    'side': scan.side.name,
    'facing': scan.facing.name,
    'widthRatio': scan.widthRatio,
    'fingerRatio': scan.fingerRatio,
    'handType': scan.handType.name,
    'borderline': scan.borderline,
    'lines': <String>[for (final FoundLineKind k in scan.found.keys) k.name]
      ..sort(),
    // How much of each route sat on real crease evidence, found or not.
    'cover': <String, double>{
      if (creases != null)
        for (final MapEntry<FoundLineKind, double> t in creases.tried.entries)
          t.key.name: t.value,
    },
  };
}
