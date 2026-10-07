/// Sarvatobhadra Chakra: the nine-by-nine grid of eighty-one cells, and vedha,
/// the lines along which a transiting graha "strikes" the cells it passes.
///
/// The grid. Eighty-one cells in five nested squares, as the printed chakra
/// and the published descriptions give it:
///
///  * the outer ring of 32 cells holds the 28 nakshatras (the 27 and Abhijit),
///    seven on each side, and a vowel in each of the four corners;
///  * the next ring holds 20 consonants and four vowels;
///  * the next holds the 12 rashis and four vowels;
///  * the next holds four of the five tithi groups (with the weekdays paired
///    to them) and four vowels;
///  * the centre cell holds the fifth tithi group and its weekday.
///
/// The sixteen vowels sit on the two diagonals, four to an arm, dealt out in
/// the order a ā i ī, u ū ṛ ṝ, ḷ ḹ e ai, o au aṃ aḥ, one group to each square
/// from the outside in, clockwise from the north-east corner. North is at the
/// top and east at the right, and the nakshatras run clockwise from Krittika,
/// the first beside the north-east (Ishana) corner.
///
/// Where the layout was checked. The nakshatra ring, the rashi ring (three to a
/// side, Taurus first on the east), the sixteen vowels and the weekday groups
/// (Sunday and Tuesday; Monday and Wednesday; Thursday; Friday; Saturday) come
/// from the published grid in the Wikipedia article "Sarvatobhadra Chakra"
/// (which cites M. K. Aggarwal, Mystics of Sarvatobhadra Chakra). The ring
/// alignment (Krittika first beside the north-east corner, seven nakshatras to
/// a side, Abhijit between Uttara Ashadha and Shravana), the rashi ring and the
/// diagonal vowels agree with the layout descriptions at panchangbodh.com,
/// hindupad.com and ayurastro.com. The weekday groups agree with the grouping
/// used by the open-source numastastrology/SARVATOBHADRA-CHAKRA project (whose
/// ring is aligned differently, so only the grouping is compared, not its
/// positions). The vowel dealing was checked for internal consistency: the
/// published table follows it in every one of its sixteen cells, apart from
/// two long vowels it prints in their short forms. Three things rest on less:
///
///  * The published table lists the cell north of the east vowel pair as the
///    vowel "a" where the consonant set needs one more consonant. The twenty
///    name consonants are ka kha ga ca ja ṭa ḍa ta da na pa ba bha ma ya ra la
///    va sa ha, which the table has nineteen of; the missing one is ba, which
///    sits beside va in the table exactly where the published "ba and va"
///    pairing puts it. The cell is marked `inferred`.
///  * Which tithi group sits in which of the four inner cells is read from the
///    weekday labels the table prints there and the standard pairing of each
///    weekday group with its tithis. Those four cells are marked `inferred`.
///  * Letters that the chakra does not carry (the aspirates, the nasals, the
///    sibilants sha and ṣa) are placed on the nearest letter that it does
///    carry, and the result says so (`exact` is false).
///
/// Vedha. A graha standing in a nakshatra sends up to three lines from that
/// rim cell through the grid: straight across (front), diagonally in the
/// direction of the zodiac (the left, forward diagonal) and diagonally against
/// it (the right, backward diagonal). Every cell on a line, up to the rim cell
/// where it ends, is struck. Which line a graha casts depends on its motion:
///
///  * retrograde: the right (backward) line;
///  * Rahu and Ketu, which always move backward: the right line;
///  * the Sun and the Moon: the left (forward) line (the sources that give this
///    agree with each other on the Moon and differ on the Sun, where the left
///    line is the one both allow);
///  * any other graha in direct motion: the left line when it is moving faster
///    than its own mean daily motion ("swift"), and the front line otherwise.
///
/// The texts say "swift" and "ordinary" without a number. Using each graha's
/// mean daily motion as the divide is this file's convention, and each active
/// vedha says which basis it used.
///
/// The result is read against the native's own points: the janma nakshatra, the
/// consonant and the vowel of the name syllable, the Moon sign and the lagna
/// sign. A strike by Jupiter, Venus or Mercury is read as supportive and one by
/// the Sun, Mars, Saturn, Rahu or Ketu as pressing; the Moon is read as mixed.
/// Each is a passing influence and says so. None of it is an event.
library;

import '../astro/angles.dart';
import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'ghat_chakra.dart';
import 'graha_data.dart';
import 'namkaran.dart';
import 'nakshatra.dart';
import 'rashi.dart';

enum SbcCellKind { nakshatra, vowel, consonant, rashi, tithi }

/// A line a graha casts from its rim cell.
enum VedhaLine { front, left, right }

extension VedhaLineNames on VedhaLine {
  String get english => switch (this) {
    VedhaLine.front => 'front',
    VedhaLine.left => 'left',
    VedhaLine.right => 'right',
  };

  String get hindi => switch (this) {
    VedhaLine.front => 'सम्मुख',
    VedhaLine.left => 'वाम',
    VedhaLine.right => 'दक्षिण',
  };
}

/// One of the 81 cells.
class SbcCell {
  const SbcCell({
    required this.row,
    required this.col,
    required this.kind,
    required this.english,
    required this.hindi,
    this.nakshatra28,
    this.rashi,
    this.letter,
    this.tithiGroup,
    this.weekdays = const <int>[],
    this.inferred = false,
  });

  /// 0 to 8 from the top (north).
  final int row;

  /// 0 to 8 from the left (west).
  final int col;
  final SbcCellKind kind;

  /// A short label for the cell, in both languages.
  final String english;
  final String hindi;

  /// For a nakshatra cell: 0 to 27 in zodiacal order with Abhijit at 21.
  final int? nakshatra28;

  /// For a rashi cell: 0 (Mesha) to 11.
  final int? rashi;

  /// For a vowel or consonant cell: the letter in Devanagari.
  final String? letter;

  /// For a tithi cell: the group, and the weekdays paired with it (0 = Sunday).
  final TithiGroup? tithiGroup;
  final List<int> weekdays;

  /// True where this cell's content is inferred rather than printed in the
  /// layout that was checked (see the library comment).
  final bool inferred;

  bool get isRim => row == 0 || row == 8 || col == 0 || col == 8;
}

/// Names of the 28 nakshatras in zodiacal order, Abhijit at index 21.
String sbcNakshatraEnglish(int index28) =>
    index28 == 21 ? 'Abhijit' : nakshatraTable[_to27(index28)].english;

String sbcNakshatraHindi(int index28) =>
    index28 == 21 ? 'अभिजित्' : nakshatraTable[_to27(index28)].hindi;

int _to27(int index28) => index28 > 21 ? index28 - 1 : index28;

/// The Abhijit span: the last quarter of Uttara Ashadha and the first four
/// ghatis of Shravana, 276°40′ to 280°53′20″ sidereal.
const double _abhijitStart = 276.0 + 40.0 / 60.0;
const double _abhijitEnd = 280.0 + 53.0 / 60.0 + 20.0 / 3600.0;

/// Index 0 to 27 of the nakshatra, counting Abhijit, for a sidereal longitude.
int sbcNakshatraIndexOf(double siderealLongitude) {
  final double l = norm360(siderealLongitude);
  if (l >= _abhijitStart && l < _abhijitEnd) return 21;
  final int i27 = (l / nakshatraSpan).floor() % 27;
  return i27 >= 21 ? i27 + 1 : i27;
}

class SbcGrid {
  SbcGrid._(this.cells);

  /// Nine rows of nine cells, north at the top.
  final List<List<SbcCell>> cells;

  SbcCell at(int row, int col) => cells[row][col];

  Iterable<SbcCell> get all => cells.expand((List<SbcCell> r) => r);

  SbcCell nakshatraCell(int index28) =>
      all.firstWhere((SbcCell c) => c.nakshatra28 == index28);

  SbcCell rashiCell(int rashiIndex) =>
      all.firstWhere((SbcCell c) => c.rashi == rashiIndex);

  /// The cell holding [letter] (a vowel, or one of the twenty consonants).
  SbcCell? letterCell(String letter) {
    for (final SbcCell c in all) {
      if (c.letter == letter) return c;
    }
    return null;
  }
}

// -----------------------------------------------------------------------------
// The grid itself.
// -----------------------------------------------------------------------------

const Map<String, String> _vowelRoman = <String, String>{
  'अ': 'a',
  'आ': 'ā',
  'इ': 'i',
  'ई': 'ī',
  'उ': 'u',
  'ऊ': 'ū',
  'ऋ': 'ṛ',
  'ॠ': 'ṝ',
  'ऌ': 'ḷ',
  'ॡ': 'ḹ',
  'ए': 'e',
  'ऐ': 'ai',
  'ओ': 'o',
  'औ': 'au',
  'अं': 'aṃ',
  'अः': 'aḥ',
};

const Map<String, String> _consonantRoman = <String, String>{
  'क': 'ka',
  'ख': 'kha',
  'ग': 'ga',
  'च': 'ca',
  'ज': 'ja',
  'ट': 'ṭa',
  'ड': 'ḍa',
  'त': 'ta',
  'द': 'da',
  'न': 'na',
  'प': 'pa',
  'ब': 'ba',
  'भ': 'bha',
  'म': 'ma',
  'य': 'ya',
  'र': 'ra',
  'ल': 'la',
  'व': 'va',
  'स': 'sa',
  'ह': 'ha',
};

/// The grid as tokens, row by row, north at the top. `n:` a nakshatra (index
/// 0 to 27), `v:` a vowel, `c:` a consonant, `c*` an inferred consonant, `r:` a
/// rashi (0 to 11), `t:` a tithi group (by index of [TithiGroup]).
const List<List<String>> _layout = <List<String>>[
  <String>['v:ई', 'n:23', 'n:24', 'n:25', 'n:26', 'n:27', 'n:0', 'n:1', 'v:अ'],
  <String>['n:22', 'v:ॠ', 'c:ग', 'c:स', 'c:द', 'c:च', 'c:ल', 'v:उ', 'n:2'],
  <String>['n:21', 'c:ख', 'v:ऐ', 'r:10', 'r:11', 'r:0', 'v:ऌ', 'c*:ब', 'n:3'],
  <String>['n:20', 'c:ज', 'r:9', 'v:अः', 't:3', 'v:ओ', 'r:1', 'c:व', 'n:4'],
  <String>['n:19', 'c:भ', 'r:8', 't:2', 't:4', 't:0', 'r:2', 'c:क', 'n:5'],
  <String>['n:18', 'c:य', 'r:7', 'v:अं', 't:1', 'v:औ', 'r:3', 'c:ह', 'n:6'],
  <String>['n:17', 'c:न', 'v:ए', 'r:6', 'r:5', 'r:4', 'v:ॡ', 'c:ड', 'n:7'],
  <String>['n:16', 'v:ऋ', 'c:त', 'c:र', 'c:प', 'c:ट', 'c:म', 'v:ऊ', 'n:8'],
  <String>['v:इ', 'n:15', 'n:14', 'n:13', 'n:12', 'n:11', 'n:10', 'n:9', 'v:आ'],
];

/// Weekdays paired with each tithi group, 0 = Sunday: Nanda with Sunday and
/// Tuesday, Bhadra with Monday and Wednesday, Jaya with Thursday, Rikta with
/// Friday, Poorna with Saturday.
const Map<TithiGroup, List<int>> _groupWeekdays = <TithiGroup, List<int>>{
  TithiGroup.nanda: <int>[0, 2],
  TithiGroup.bhadra: <int>[1, 3],
  TithiGroup.jaya: <int>[4],
  TithiGroup.rikta: <int>[5],
  TithiGroup.poorna: <int>[6],
};

SbcCell _buildCell(int row, int col, String token) {
  final String kind = token.substring(0, token.indexOf(':'));
  final String value = token.substring(token.indexOf(':') + 1);
  switch (kind) {
    case 'n':
      final int i = int.parse(value);
      return SbcCell(
        row: row,
        col: col,
        kind: SbcCellKind.nakshatra,
        english: sbcNakshatraEnglish(i),
        hindi: sbcNakshatraHindi(i),
        nakshatra28: i,
      );
    case 'v':
      return SbcCell(
        row: row,
        col: col,
        kind: SbcCellKind.vowel,
        english: _vowelRoman[value]!,
        hindi: value,
        letter: value,
      );
    case 'c':
    case 'c*':
      return SbcCell(
        row: row,
        col: col,
        kind: SbcCellKind.consonant,
        english: _consonantRoman[value]!,
        hindi: value,
        letter: value,
        inferred: kind == 'c*',
      );
    case 'r':
      final int i = int.parse(value);
      return SbcCell(
        row: row,
        col: col,
        kind: SbcCellKind.rashi,
        english: rashiInfo(Rashi.values[i]).english,
        hindi: rashiInfo(Rashi.values[i]).hindi,
        rashi: i,
      );
    default:
      final TithiGroup g = TithiGroup.values[int.parse(value)];
      final List<int> days = _groupWeekdays[g]!;
      return SbcCell(
        row: row,
        col: col,
        kind: SbcCellKind.tithi,
        english:
            '${g.english} (${g.tithis.join(', ')}): ${days.map((int d) => ghatWeekdaysEnglish[d]).join(' / ')}',
        hindi:
            '${g.hindi} (${g.tithis.join(', ')}): ${days.map((int d) => ghatWeekdaysHindi[d]).join(' / ')}',
        tithiGroup: g,
        weekdays: days,
        // The centre cell is Poorna in every layout; the four around it are
        // read from the printed weekday labels.
        inferred: !(row == 4 && col == 4),
      );
  }
}

/// The Sarvatobhadra grid.
final SbcGrid sarvatobhadraGrid = SbcGrid._(<List<SbcCell>>[
  for (int r = 0; r < 9; r++)
    <SbcCell>[for (int c = 0; c < 9; c++) _buildCell(r, c, _layout[r][c])],
]);

// -----------------------------------------------------------------------------
// Vedha geometry.
// -----------------------------------------------------------------------------

/// Direction of each line from a rim cell, as (row step, column step). "Left"
/// is the diagonal that runs in the direction of the zodiac, which is clockwise
/// around the ring: on the north side that is eastward, on the east side
/// southward, and so on.
(int, int) _step(SbcCell from, VedhaLine line) {
  if (from.row == 0) {
    return switch (line) {
      VedhaLine.front => (1, 0),
      VedhaLine.left => (1, 1),
      VedhaLine.right => (1, -1),
    };
  }
  if (from.col == 8) {
    return switch (line) {
      VedhaLine.front => (0, -1),
      VedhaLine.left => (1, -1),
      VedhaLine.right => (-1, -1),
    };
  }
  if (from.row == 8) {
    return switch (line) {
      VedhaLine.front => (-1, 0),
      VedhaLine.left => (-1, -1),
      VedhaLine.right => (-1, 1),
    };
  }
  return switch (line) {
    VedhaLine.front => (0, 1),
    VedhaLine.left => (-1, 1),
    VedhaLine.right => (1, 1),
  };
}

/// The cells a line from a rim nakshatra cell passes through, in order, ending
/// with the rim cell where it leaves the grid. The origin itself is not
/// included.
List<SbcCell> vedhaPath(SbcGrid grid, SbcCell origin, VedhaLine line) {
  final (int, int) step = _step(origin, line);
  final List<SbcCell> path = <SbcCell>[];
  int r = origin.row + step.$1;
  int c = origin.col + step.$2;
  while (r >= 0 && r <= 8 && c >= 0 && c <= 8) {
    final SbcCell cell = grid.at(r, c);
    path.add(cell);
    if (cell.isRim) break;
    r += step.$1;
    c += step.$2;
  }
  return path;
}

// -----------------------------------------------------------------------------
// The native's own points: nakshatra and name syllable.
// -----------------------------------------------------------------------------

/// The syllable of a name placed on the chakra.
class SbcSyllable {
  const SbcSyllable({
    required this.syllableHindi,
    required this.consonant,
    required this.vowel,
    required this.exact,
    required this.basisEnglish,
    required this.basisHindi,
  });

  /// The syllable as given (Devanagari), such as "चू".
  final String syllableHindi;

  /// The consonant cell letter it was placed on, or null for a pure vowel.
  final String? consonant;

  /// The vowel cell letter.
  final String vowel;

  /// False when the consonant is not on the chakra and the nearest letter it
  /// does carry was used instead.
  final bool exact;
  final String basisEnglish;
  final String basisHindi;
}

const Map<String, String> _matraVowel = <String, String>{
  'ा': 'आ',
  'ि': 'इ',
  'ी': 'ई',
  'ु': 'उ',
  'ू': 'ऊ',
  'ृ': 'ऋ',
  'े': 'ए',
  'ै': 'ऐ',
  'ो': 'ओ',
  'ौ': 'औ',
};

/// Letters the chakra does not carry, with the nearest letter that it does:
/// each aspirate on its plain letter, the nasals on the plain letter of their
/// group, the sibilants on sa.
const Map<String, String> _nearestLetter = <String, String>{
  'घ': 'ग',
  'ङ': 'ग',
  'छ': 'च',
  'झ': 'ज',
  'ञ': 'ज',
  'ठ': 'ट',
  'ढ': 'ड',
  'ण': 'न',
  'थ': 'त',
  'ध': 'द',
  'फ': 'प',
  'श': 'स',
  'ष': 'स',
};

/// Places a Devanagari syllable (for instance "चू", "ला", "अ") on the chakra:
/// the consonant on its cell and the vowel it carries on a vowel cell. Returns
/// null when the text does not begin with a Devanagari letter.
SbcSyllable? sbcSyllableOf(String syllable) {
  if (syllable.isEmpty) return null;
  final List<String> chars = syllable.runes
      .map((int r) => String.fromCharCode(r))
      .toList();
  final String first = chars.first;
  final int code = first.runes.first;
  // Independent vowels, U+0905 to U+0914.
  if (code >= 0x0905 && code <= 0x0914) {
    String vowel = first;
    if (chars.length > 1 && chars[1] == 'ं') vowel = 'अं';
    return SbcSyllable(
      syllableHindi: syllable,
      consonant: null,
      vowel: vowel,
      exact: true,
      basisEnglish: 'a vowel, placed on its own cell',
      basisHindi: 'स्वर, जो अपने कोष्ठक में रखा गया',
    );
  }
  // Consonants, U+0915 to U+0939.
  if (code < 0x0915 || code > 0x0939) return null;
  String vowel = 'अ';
  for (final String ch in chars.skip(1)) {
    final String? v = _matraVowel[ch];
    if (v != null) {
      vowel = v;
      break;
    }
  }
  final bool onChakra = _consonantRoman.containsKey(first);
  final String? nearest = onChakra ? first : _nearestLetter[first];
  if (nearest == null) return null;
  return SbcSyllable(
    syllableHindi: syllable,
    consonant: nearest,
    vowel: vowel,
    exact: onChakra,
    basisEnglish: onChakra
        ? 'the consonant is on the chakra'
        : 'the chakra does not carry "$first"; the nearest letter it does carry, "$nearest", is used',
    basisHindi: onChakra
        ? 'यह व्यंजन चक्र में है'
        : 'चक्र में "$first" नहीं है; उसका निकटतम अक्षर "$nearest" लिया गया है',
  );
}

/// The syllable the native's name begins with. If the name was written in
/// Devanagari its first syllable is used; otherwise the traditional naming
/// syllable of the janma nakshatra pada (the app's own namkaran table), which
/// is the syllable a name is meant to begin with.
SbcSyllable? sbcSyllableForKundli(Kundli kundli) {
  final String name = kundli.birth.name.trim();
  if (name.isNotEmpty) {
    final int code = name.runes.first;
    if (code >= 0x0900 && code <= 0x097F) {
      // The first letter with any matra that follows it.
      final StringBuffer buf = StringBuffer(name.substring(0, 1));
      if (name.length > 1 && _matraVowel.containsKey(name.substring(1, 2))) {
        buf.write(name.substring(1, 2));
      }
      final SbcSyllable? s = sbcSyllableOf(buf.toString());
      if (s != null) return s;
    }
  }
  final NamkaranSuggestion n = namkaranFor(
    kundli.grahas[Graha.moon]!.siderealLongitude,
  );
  return sbcSyllableOf(n.syllableHindi);
}

// -----------------------------------------------------------------------------
// Transit and the reading.
// -----------------------------------------------------------------------------

enum SbcPointKind { nakshatra, akshara, swara, moonSign, lagnaSign }

class SbcNatalPoint {
  const SbcNatalPoint({
    required this.kind,
    required this.cell,
    required this.labelEnglish,
    required this.labelHindi,
  });

  final SbcPointKind kind;
  final SbcCell cell;
  final String labelEnglish;
  final String labelHindi;
}

/// How a strike is read.
enum SbcNature { supportive, pressing, mixed }

/// A graha's vedha: the line it casts, the cells it strikes, and which of the
/// native's own points lie on it.
class SbcVedha {
  const SbcVedha({
    required this.graha,
    required this.origin,
    required this.line,
    required this.basisEnglish,
    required this.basisHindi,
    required this.path,
    required this.struck,
    required this.nature,
    required this.isRetrograde,
  });

  final Graha graha;
  final SbcCell origin;
  final VedhaLine line;

  /// Why this line: the motion rule that chose it.
  final String basisEnglish;
  final String basisHindi;

  /// Every cell struck, from the cell after the origin to the rim cell where
  /// the line leaves the grid.
  final List<SbcCell> path;

  /// The native's points on that line. Empty when it touches none of them.
  final List<SbcNatalPoint> struck;
  final SbcNature nature;
  final bool isRetrograde;

  bool get touchesNative => struck.isNotEmpty;
}

class SarvatobhadraReading {
  const SarvatobhadraReading({
    required this.grid,
    required this.moment,
    required this.natalPoints,
    required this.syllable,
    required this.vedhas,
  });

  final SbcGrid grid;
  final DateTime moment;

  /// The native's own points on the grid.
  final List<SbcNatalPoint> natalPoints;
  final SbcSyllable? syllable;

  /// One vedha for each of the nine grahas, whether or not it touches the
  /// native.
  final List<SbcVedha> vedhas;

  /// The vedhas that strike at least one of the native's points.
  List<SbcVedha> get active =>
      vedhas.where((SbcVedha v) => v.touchesNative).toList(growable: false);
}

/// Mean daily motion in longitude, degrees, as seen from the Earth. The inner
/// planets average the Sun's motion; the outer ones their own orbital motion.
const Map<Graha, double> _meanDailyMotion = <Graha, double>{
  Graha.mars: 0.5240,
  Graha.mercury: 0.9856,
  Graha.jupiter: 0.0831,
  Graha.venus: 0.9856,
  Graha.saturn: 0.0335,
};

SbcNature _natureOf(Graha g) => switch (g) {
  Graha.jupiter || Graha.venus || Graha.mercury => SbcNature.supportive,
  Graha.moon => SbcNature.mixed,
  _ => SbcNature.pressing,
};

({VedhaLine line, String en, String hi}) _lineFor(Graha g, double speed) {
  if (g == Graha.rahu || g == Graha.ketu) {
    return (
      line: VedhaLine.right,
      en: 'a node, which always moves backward',
      hi: 'छाया ग्रह, जो सदा पीछे की ओर चलता है',
    );
  }
  if (g == Graha.sun || g == Graha.moon) {
    return (
      line: VedhaLine.left,
      en: 'a luminary, which casts the left line',
      hi: 'प्रकाशक ग्रह, जो वाम रेखा डालता है',
    );
  }
  if (speed < 0) {
    return (line: VedhaLine.right, en: 'retrograde', hi: 'वक्री');
  }
  final double mean = _meanDailyMotion[g]!;
  if (speed > mean) {
    return (
      line: VedhaLine.left,
      en: 'direct and swift (faster than its mean daily motion)',
      hi: 'मार्गी और शीघ्र (अपनी औसत दैनिक गति से तेज़)',
    );
  }
  return (
    line: VedhaLine.front,
    en: 'direct at ordinary pace',
    hi: 'मार्गी, सामान्य गति',
  );
}

/// Reads the Sarvatobhadra Chakra for a native at [moment] (now by default).
SarvatobhadraReading computeSarvatobhadra(Kundli kundli, {DateTime? moment}) {
  final DateTime when = moment ?? DateTime.now();
  final SbcGrid grid = sarvatobhadraGrid;
  final Instant instant = Instant.fromUtc(when.toUtc());

  // The native's own points.
  final PlacedGraha moon = kundli.grahas[Graha.moon]!;
  final List<SbcNatalPoint> natal = <SbcNatalPoint>[];
  final int natalNak = sbcNakshatraIndexOf(moon.siderealLongitude);
  natal.add(
    SbcNatalPoint(
      kind: SbcPointKind.nakshatra,
      cell: grid.nakshatraCell(natalNak),
      labelEnglish: 'your janma nakshatra, ${sbcNakshatraEnglish(natalNak)}',
      labelHindi: 'आपका जन्म नक्षत्र, ${sbcNakshatraHindi(natalNak)}',
    ),
  );
  final SbcSyllable? syllable = sbcSyllableForKundli(kundli);
  if (syllable != null) {
    if (syllable.consonant != null) {
      final SbcCell? c = grid.letterCell(syllable.consonant!);
      if (c != null) {
        natal.add(
          SbcNatalPoint(
            kind: SbcPointKind.akshara,
            cell: c,
            labelEnglish:
                'the consonant of your name syllable, ${c.hindi} (${c.english})',
            labelHindi: 'आपके नाम-अक्षर का व्यंजन, ${c.hindi} (${c.english})',
          ),
        );
      }
    }
    final SbcCell? v = grid.letterCell(syllable.vowel);
    if (v != null) {
      natal.add(
        SbcNatalPoint(
          kind: SbcPointKind.swara,
          cell: v,
          labelEnglish:
              'the vowel of your name syllable, ${v.hindi} (${v.english})',
          labelHindi: 'आपके नाम-अक्षर का स्वर, ${v.hindi} (${v.english})',
        ),
      );
    }
  }
  natal.add(
    SbcNatalPoint(
      kind: SbcPointKind.moonSign,
      cell: grid.rashiCell(moon.rashi.index),
      labelEnglish: 'your Moon sign, ${rashiInfo(moon.rashi).english}',
      labelHindi: 'आपकी चंद्र राशि, ${rashiInfo(moon.rashi).hindi}',
    ),
  );
  natal.add(
    SbcNatalPoint(
      kind: SbcPointKind.lagnaSign,
      cell: grid.rashiCell(kundli.lagnaRashi.index),
      labelEnglish: 'your lagna sign, ${rashiInfo(kundli.lagnaRashi).english}',
      labelHindi: 'आपका लग्न, ${rashiInfo(kundli.lagnaRashi).hindi}',
    ),
  );

  // The grahas as they stand now.
  final Map<Graha, BodyPosition> raw = allPositions(instant);
  final List<SbcVedha> vedhas = <SbcVedha>[];
  for (final Graha g in Graha.values) {
    final BodyPosition p = raw[g]!;
    final double sidereal = toSidereal(
      p.tropicalLongitude,
      kundli.ayanamsa,
      instant.centuriesTt,
    );
    final SbcCell origin = grid.nakshatraCell(sbcNakshatraIndexOf(sidereal));
    final ({VedhaLine line, String en, String hi}) choice = _lineFor(
      g,
      p.speed,
    );
    final List<SbcCell> path = vedhaPath(grid, origin, choice.line);
    final List<SbcNatalPoint> struck = natal
        .where(
          (SbcNatalPoint n) =>
              n.cell != origin &&
              path.any(
                (SbcCell c) => c.row == n.cell.row && c.col == n.cell.col,
              ),
        )
        .toList(growable: false);
    vedhas.add(
      SbcVedha(
        graha: g,
        origin: origin,
        line: choice.line,
        basisEnglish: choice.en,
        basisHindi: choice.hi,
        path: path,
        struck: struck,
        nature: _natureOf(g),
        isRetrograde: p.speed < 0 && g != Graha.rahu && g != Graha.ketu,
      ),
    );
  }

  return SarvatobhadraReading(
    grid: grid,
    moment: when,
    natalPoints: natal,
    syllable: syllable,
    vedhas: vedhas,
  );
}

/// A plain statement of one active vedha, in both languages. It names the
/// graha, its line, what it touches and how the tradition reads that; it never
/// says what will happen.
({String en, String hi}) describeVedha(SbcVedha v) {
  final GrahaInfo info = grahaInfo(v.graha);
  final String touchedEn = v.struck
      .map((SbcNatalPoint p) => p.labelEnglish)
      .join(', ');
  final String touchedHi = v.struck
      .map((SbcNatalPoint p) => p.labelHindi)
      .join(', ');
  final String how = switch (v.nature) {
    SbcNature.supportive =>
      'The chakra reads a strike by ${info.english} as supportive.',
    SbcNature.pressing =>
      'The chakra reads a strike by ${info.english} as a pressing influence, one that asks for patience; the tradition says a supportive vedha on the same point offsets it.',
    SbcNature.mixed =>
      'The chakra reads a strike by the Moon as mixed, and the Moon moves on within hours.',
  };
  final String howHi = switch (v.nature) {
    SbcNature.supportive => 'चक्र ${info.hindi} के वेध को सहायक पढ़ता है।',
    SbcNature.pressing =>
      'चक्र ${info.hindi} के वेध को दबाव डालने वाला प्रभाव पढ़ता है, जो धैर्य माँगता है; परंपरा कहती है कि उसी बिंदु पर शुभ ग्रह का वेध उसे संतुलित करता है।',
    SbcNature.mixed =>
      'चक्र चंद्र के वेध को मिश्रित पढ़ता है, और चंद्र कुछ ही घंटों में आगे बढ़ जाता है।',
  };
  return (
    en: '${info.english} stands in ${v.origin.english} and casts its ${v.line.english} line (${v.basisEnglish}). The line passes through $touchedEn. $how It is a passing influence and says nothing about what will happen.',
    hi: '${info.hindi} ${v.origin.hindi} में है और अपनी ${v.line.hindi} रेखा डालता है (${v.basisHindi})। रेखा $touchedHi से होकर गुज़रती है। $howHi यह एक गुज़रता प्रभाव है और आगे क्या होगा इसके बारे में कुछ नहीं कहता।',
  );
}
