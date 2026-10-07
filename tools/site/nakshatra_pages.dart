/// The 27 nakshatra pages.
///
/// Every number, name and list on these pages is read from the engine; the
/// sentences are templates that choose their wording from that data (a
/// nakshatra that straddles two signs is described differently from one that
/// sits in a single sign, one with no yoni partner says so, and so on). What
/// the templates may not do is state anything the engine could not back, so
/// the prose is explanation of method and classification, not character
/// reading or story.
library;

import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/jyotish/dasha.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/matching.dart' show ganaScores;
import 'package:kundlisaar/engine/jyotish/muhurta.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/namkaran.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';
import 'package:kundlisaar/engine/jyotish/varga.dart';

import 'common.dart';
import 'glossary_hi.dart';

/// Arc-minutes in a nakshatra and in a pada. Whole numbers, so no degree is
/// ever printed with a floating-point tail.
const int _nakshatraArc = 800;
const int _padaArc = 200;
const int _signArc = 1800;

/// Other spellings people search for. These are romanisations and spelling
/// variants of the same name, not other traditions' names.
const Map<String, List<String>> _spellingsEnglish = <String, List<String>>{
  'Ashwini': <String>['Ashvini', 'Aswini'],
  'Bharani': <String>['Apabharani'],
  'Krittika': <String>['Kritika', 'Karthika'],
  'Mrigashira': <String>['Mrigasira', 'Mrigshira', 'Mrigashirsha'],
  'Ardra': <String>['Aridra', 'Arudra'],
  'Pushya': <String>['Pushyami', 'Tishya'],
  'Ashlesha': <String>['Aslesha', 'Ashlesa'],
  'Magha': <String>['Makha'],
  'Purva Phalguni': <String>['Purvaphalguni', 'Pubba'],
  'Uttara Phalguni': <String>['Uttaraphalguni'],
  'Hasta': <String>['Hastha'],
  'Chitra': <String>['Chitta'],
  'Swati': <String>['Svati', 'Swathi'],
  'Vishakha': <String>['Visakha', 'Vaisakha'],
  'Jyeshtha': <String>['Jyestha', 'Jyeshta', 'Jeshtha'],
  'Mula': <String>['Moola', 'Mool'],
  'Purva Ashadha': <String>['Purvashadha', 'Poorvashada'],
  'Uttara Ashadha': <String>['Uttarashadha'],
  'Shravana': <String>['Sravana', 'Shravan'],
  'Dhanishta': <String>['Dhanista', 'Shravishtha'],
  'Shatabhisha': <String>['Satabhisha', 'Shatataraka'],
  'Purva Bhadrapada': <String>[
    'Purvabhadra',
    'Purvabhadrapada',
    'Poorvabhadra',
  ],
  'Uttara Bhadrapada': <String>['Uttarabhadra', 'Uttarabhadrapada'],
  'Revati': <String>['Revathi'],
};

const Map<String, List<String>> _spellingsHindi = <String, List<String>>{
  'Ashwini': <String>['अश्वनी'],
  'Krittika': <String>['कृतिका'],
  'Mrigashira': <String>['मृगशीर्ष'],
  'Ardra': <String>['आद्रा'],
  'Ashlesha': <String>['अश्लेषा'],
  'Purva Phalguni': <String>['पूर्वाफाल्गुनी'],
  'Uttara Phalguni': <String>['उत्तराफाल्गुनी'],
  'Swati': <String>['स्वाति'],
  'Jyeshtha': <String>['जेष्ठा'],
  'Mula': <String>['मूला'],
  'Purva Ashadha': <String>['पूर्वाषाढा', 'पूर्वाषाढ़'],
  'Uttara Ashadha': <String>['उत्तराषाढा'],
  'Dhanishta': <String>['श्रविष्ठा'],
  'Shatabhisha': <String>['शतभिषक्', 'शतभिषज'],
  'Purva Bhadrapada': <String>['पूर्वाभाद्रपद'],
  'Uttara Bhadrapada': <String>['उत्तराभाद्रपद'],
};

class _Pada {
  const _Pada({
    required this.number,
    required this.startArc,
    required this.rashi,
    required this.navamsa,
    required this.syllable,
    required this.syllableHindi,
    required this.balanceStart,
    required this.balanceEnd,
  });

  final int number;
  final int startArc;
  final Rashi rashi;
  final Rashi navamsa;
  final String syllable;
  final String syllableHindi;

  /// Months of the lord's mahadasha left if the Moon is at the start and at
  /// the end of this pada.
  final int balanceStart;
  final int balanceEnd;

  int get endArc => startArc + _padaArc;
  int get startInSign => startArc % _signArc;
  int get endInSign => startInSign + _padaArc;
}

/// A run of consecutive padas that share a sign.
class _Run {
  _Run(this.rashi);
  final Rashi rashi;
  final List<_Pada> padas = <_Pada>[];
}

List<_Pada> _padasOf(NakshatraInfo info) {
  final int months = (vimshottariYears[info.lord]! * 12).round();
  check(
    months % 4 == 0,
    '${info.english}: the lord’s dasha does not divide into four padas',
  );
  return <_Pada>[
    for (int p = 0; p < 4; p++)
      _Pada(
        number: p + 1,
        startArc: info.index * _nakshatraArc + p * _padaArc,
        rashi: Rashi.values[(info.index * _nakshatraArc + p * _padaArc) ~/
            _signArc],
        navamsa: Rashi.values[vargaSign(
          Varga.d9,
          (info.index * _nakshatraArc + p * _padaArc + _padaArc / 2) / 60.0,
        )],
        syllable: padaSyllables[info.index][p],
        syllableHindi: padaSyllablesHindi[info.index][p],
        balanceStart: months * (4 - p) ~/ 4,
        balanceEnd: months * (3 - p) ~/ 4,
      ),
  ];
}

List<_Run> _runsOf(List<_Pada> padas) {
  final List<_Run> runs = <_Run>[];
  for (final _Pada pada in padas) {
    if (runs.isEmpty || runs.last.rashi != pada.rashi) {
      runs.add(_Run(pada.rashi));
    }
    runs.last.padas.add(pada);
  }
  return runs;
}

String _padaRangeEnglish(List<_Pada> padas) => padas.length == 1
    ? 'pada ${padas.first.number}'
    : 'padas ${padas.first.number} to ${padas.last.number}';

String _padaRangeHindi(List<_Pada> padas) => padas.length == 1
    ? 'चरण ${padas.first.number}'
    : 'चरण ${padas.first.number} से ${padas.last.number}';

/// "10 वर्ष" for a whole-year dasha.
String _yearsHindi(double years) => '${years.round()} वर्ष';

Graha _nextLord(Graha lord) =>
    vimshottariOrder[(vimshottariOrder.indexOf(lord) + 1) % 9];

/// The lowest and highest gana score between two classes, either way round,
/// read from the matcher's own table.
(int, int) _ganaRange(Gana a, Gana b) {
  final int one = ganaScores[a.name]![b.index];
  final int two = ganaScores[b.name]![a.index];
  return one <= two ? (one, two) : (two, one);
}

String _rangeText((int, int) range, {required bool hindi}) =>
    range.$1 == range.$2
    ? '${range.$1}'
    : (hindi ? '${range.$1} या ${range.$2}' : '${range.$1} or ${range.$2}');

String _ganaSentenceEnglish(Gana gana) {
  final List<Gana> others = Gana.values
      .where((Gana g) => g != gana)
      .toList(growable: false);
  final String own = '${ganaScores[gana.name]![gana.index]}';
  final String first = _rangeText(_ganaRange(gana, others[0]), hindi: false);
  final String second = _rangeText(_ganaRange(gana, others[1]), hindi: false);
  final String base =
      '${ganaEnglish(gana)} gana scores $own of 6 with its own kind, '
      '$first with ${ganaEnglish(others[0])} and $second with ${ganaEnglish(others[1])}.';
  return gana == Gana.rakshasa
      ? '$base The name labels a temperament, not a moral failing, and how much a mismatch matters is disputed.'
      : base;
}

String _ganaSentenceHindi(Gana gana) {
  final List<Gana> others = Gana.values
      .where((Gana g) => g != gana)
      .toList(growable: false);
  final String own = '${ganaScores[gana.name]![gana.index]}';
  final String first = _rangeText(_ganaRange(gana, others[0]), hindi: true);
  final String second = _rangeText(_ganaRange(gana, others[1]), hindi: true);
  final String base =
      '${ganaHindi(gana)} गण को अपने गण से 6 में से $own अंक मिलते हैं, '
      '${ganaHindi(others[0])} से $first और ${ganaHindi(others[1])} से $second।';
  return gana == Gana.rakshasa
      ? '$base यह नाम स्वभाव का वर्ग है, चरित्र का फ़ैसला नहीं, और बेमेल का महत्व विवादित है।'
      : base;
}

/// Nakshatras whose first or last pada sits on a water-to-fire sign boundary.
/// Returns the sentence pair, or null when the nakshatra is not one of them.
///
/// Water-to-fire junctions fall exactly on nakshatra boundaries at 0, 120 and
/// 240 degrees, so they are found from the data rather than listed by name.
Bi? _gandanta(NakshatraInfo info, List<_Pada> padas, List<PageRef> refs) {
  final String path = refs[info.index].path;
  final int startArc = info.index * _nakshatraArc;
  final int endArc = startArc + _nakshatraArc;
  if (startArc % _signArc == 0) {
    final NakshatraInfo before = nakshatraTable[(info.index + 26) % 27];
    final Rashi thisSign = padas.first.rashi;
    final Rashi previousSign = Rashi.values[(thisSign.index + 11) % 12];
    if (rashiInfo(previousSign).element == Element.water &&
        rashiInfo(thisSign).element == Element.fire) {
      final String beforeLink = link(
        path,
        refs[before.index].path,
        esc(before.english),
      );
      final String beforeLinkHi = link(
        path,
        refs[before.index].path,
        esc(before.hindi),
        lang: 'hi',
      );
      return (
        en:
            'Its first pada opens the fire sign ${rashiInfo(thisSign).english} just after $beforeLink ends the water sign ${rashiInfo(previousSign).english}, a junction the tradition calls gandanta and reads with care; authorities differ on its width.',
        hi:
            'इसका पहला चरण अग्नि राशि ${rashiInfo(thisSign).hindi} खोलता है, ठीक उसके बाद जब $beforeLinkHi जल राशि ${rashiInfo(previousSign).hindi} को समाप्त करता है; इस संधि को परंपरा गंडांत कहकर सावधानी से पढ़ती है, विस्तार पर ग्रंथकार एकमत नहीं।',
      );
    }
  }
  if (endArc % _signArc == 0) {
    final NakshatraInfo after = nakshatraTable[(info.index + 1) % 27];
    final Rashi lastSign = padas.last.rashi;
    final Rashi nextSign = Rashi.values[(lastSign.index + 1) % 12];
    if (rashiInfo(lastSign).element == Element.water &&
        rashiInfo(nextSign).element == Element.fire) {
      final String afterLink = link(
        path,
        refs[after.index].path,
        esc(after.english),
      );
      final String afterLinkHi = link(
        path,
        refs[after.index].path,
        esc(after.hindi),
        lang: 'hi',
      );
      return (
        en:
            'Its last pada ends the water sign ${rashiInfo(lastSign).english}, and $afterLink opens the fire sign ${rashiInfo(nextSign).english}, a junction the tradition calls gandanta and reads with care; authorities differ on its width.',
        hi:
            'इसका अंतिम चरण जल राशि ${rashiInfo(lastSign).hindi} को समाप्त करता है और $afterLinkHi अग्नि राशि ${rashiInfo(nextSign).hindi} खोलता है; इस संधि को परंपरा गंडांत कहकर सावधानी से पढ़ती है, विस्तार पर ग्रंथकार एकमत नहीं।',
      );
    }
  }
  return null;
}

/// The activities whose nakshatra list includes this one.
List<ActivityInfo> allowedActivities(NakshatraInfo info) => activityTable
    .where((ActivityInfo a) => a.nakshatras.contains(info.index))
    .toList(growable: false);

/// Links to a set of nakshatras, in English or Hindi.
String _nakshatraLinks(
  String from,
  List<PageRef> refs,
  List<NakshatraInfo> list, {
  required bool hindi,
}) => (hindi ? joinHindi : joinEnglish)(<String>[
  for (final NakshatraInfo n in list)
    link(
      from,
      refs[n.index].path,
      esc(hindi ? n.hindi : n.english),
      lang: hindi ? 'hi' : null,
    ),
]);

List<NakshatraInfo> _sharing(
  NakshatraInfo info,
  bool Function(NakshatraInfo) same,
) => nakshatraTable
    .where((NakshatraInfo n) => n.index != info.index && same(n))
    .toList(growable: false);

/// The first and last read better as such than as "1st" and "27th".
String _placeEnglish(NakshatraInfo info) => info.index == 26
    ? 'last'
    : info.index == 0
    ? 'first'
    : ordinalEnglish(info.index + 1);

String _placeHindi(NakshatraInfo info) =>
    info.index == 26 ? 'अंतिम' : ordinalsHindi[info.index];

class _Prose {
  const _Prose(this.english, this.hindi);
  final List<String> english;
  final List<String> hindi;
}

/// The four explanatory paragraphs of a page, in both languages.
///
/// The budget is 150 to 250 words in each language and Hindi runs about a
/// fifth longer than English, so the lists that would eat the budget (the
/// other nakshatras of the same nadi, the activities a nakshatra is allowed
/// for) sit in the facts table and the prose says what they mean.
_Prose _proseFor(NakshatraInfo info, List<_Pada> padas, List<PageRef> refs) {
  final GrahaInfo lord = grahaInfo(info.lord);
  final GrahaInfo next = grahaInfo(_nextLord(info.lord));
  final double years = vimshottariYears[info.lord]!;
  final List<_Run> runs = _runsOf(padas);
  final int startArc = info.index * _nakshatraArc;
  final int endArc = startArc + _nakshatraArc;
  final int quarterMonths = padas[0].balanceEnd;

  // 1. Where it sits.
  final String whereEn;
  final String whereHi;
  if (runs.length == 1) {
    final RashiInfo sign = rashiInfo(runs.first.rashi);
    final bool differs = padas.first.startInSign != startArc;
    final String range =
        '${arcText(padas.first.startInSign)} to ${arcText(padas.last.endInSign)}';
    final String rangeHi =
        '${arcText(padas.first.startInSign)} से ${arcText(padas.last.endInSign)}';
    whereEn =
        'lies wholly in ${sign.english}${differs ? ' ($range of the sign)' : ''}';
    whereHi =
        'पूरी तरह ${sign.hindi} राशि${differs ? ' ($rangeHi)' : ''} में पड़ता है';
  } else {
    final List<String> en = <String>[];
    final List<String> hi = <String>[];
    for (final _Run run in runs) {
      final RashiInfo sign = rashiInfo(run.rashi);
      en.add(
        '${_padaRangeEnglish(run.padas)} in ${sign.english} (${arcText(run.padas.first.startInSign)} to ${arcText(run.padas.last.endInSign)})',
      );
      hi.add(
        '${_padaRangeHindi(run.padas)} ${sign.hindi} राशि (${arcText(run.padas.first.startInSign)} से ${arcText(run.padas.last.endInSign)}) में ${run.padas.length == 1 ? 'आता है' : 'आते हैं'}',
      );
    }
    whereEn = 'straddles two signs, with ${en.join(' and ')}';
    whereHi = 'दो राशियों में बँटा है: ${hi.join(' और ')}';
  }
  final bool yoniSymbol = info.symbolEnglish == 'Yoni';
  final String placeEn = _placeEnglish(info);
  final String placeHi = _placeHindi(info);
  final String p1En =
      '${esc(info.english)} is the $placeEn of the 27 nakshatras. '
      'On the sidereal zodiac it runs from ${arcText(startArc % 21600)} to ${arcText(endArc)} and $whereEn. '
      'Its symbol is ${symbolForSentence(info.symbolEnglish)}${yoniSymbol ? ' (not the yoni animal below)' : ''} and its deity is ${esc(deityForSentence(info.deityEnglish))}.';
  final String p1Hi =
      '${esc(info.hindi)} 27 नक्षत्रों में $placeHi नक्षत्र है। '
      'निरयन राशिचक्र पर यह ${arcText(startArc % 21600)} से ${arcText(endArc)} तक फैला है और $whereHi। '
      'इसका प्रतीक ${symbolHindi(info.symbolEnglish)}${yoniSymbol ? ' (नीचे की पशु-योनि नहीं)' : ''} है और देवता ${esc(info.deityHindi)} हैं।';

  // 2. The lord and the dasha.
  final String p2En =
      '${esc(sentenceCase(grahaForSentence(lord.english)))} rules it, so with the Moon in ${esc(info.english)} at birth the Vimshottari cycle opens with the ${esc(lord.english)} mahadasha, ${years.round()} of the 120 years. '
      'Only the unspent part remains at birth: ${monthsEnglish(quarterMonths)} if the Moon had crossed a quarter of the nakshatra, nothing at its end, when ${esc(grahaForSentence(next.english))} begins at once.';
  final String p2Hi =
      'इसके स्वामी ${esc(lord.hindi)} हैं, इसलिए जन्म पर चंद्रमा ${esc(info.hindi)} में हो तो विंशोत्तरी चक्र ${esc(lord.hindi)} की महादशा से खुलता है, जो 120 में से ${years.round()} वर्ष की है। '
      'जन्म पर केवल बचा भाग मिलता है: नक्षत्र का चौथाई पार हुआ हो तो ${monthsHindi(quarterMonths)}, अंत पर हो तो कुछ नहीं, तब ${esc(next.hindi)} की दशा तुरंत शुरू होती है।';

  // 3. Gana, yoni and nadi. The classes' other members are in the facts.
  final bool hasPartner = _sharing(
    info,
    (NakshatraInfo n) => n.yoni == info.yoni,
  ).isNotEmpty;
  final String yoniEn = hasPartner ? ' A shared yoni scores 4 of 4.' : '';
  final String yoniHi = hasPartner
      ? ' एक ही योनि होने पर 4 में से 4 अंक मिलते हैं।'
      : '';
  final String p3En =
      'For marriage matching, ${esc(info.english)} is ${ganaEnglish(info.gana)} gana, ${esc(info.yoni)} yoni and ${nadiEnglish(info.nadi)} nadi. '
      'Nadi weighs most, 8 of the 36 points, and scores nothing when both partners share it. '
      '${_ganaSentenceEnglish(info.gana)}$yoniEn';
  final String p3Hi =
      'विवाह-मिलान में ${esc(info.hindi)} ${ganaHindi(info.gana)} गण, ${esc(yoniHindi(info.yoni))} योनि और ${nadiHindi(info.nadi)} नाड़ी का नक्षत्र है। '
      'अष्टकूट के 36 अंकों में नाड़ी का भार सबसे अधिक, 8 अंक, है और दोनों की नाड़ी एक हो तो उसमें शून्य मिलता है। '
      '${_ganaSentenceHindi(info.gana)}$yoniHi';

  // 4. What the muhurta rules and the junctions say.
  final List<ActivityInfo> allowed = allowedActivities(info);
  final String muhurtaEn = allowed.isEmpty
      ? 'The app’s muhurta finder lists ${esc(info.english)} for none of its ${activityTable.length} activities; that is about picking a day to begin something, not about people born under it.'
      : 'The app’s muhurta finder allows ${esc(info.english)} for ${allowed.length == activityTable.length ? 'all' : '${allowed.length} of'} its ${activityTable.length} activities, listed above.';
  final String muhurtaHi = allowed.isEmpty
      ? 'ऐप का मुहूर्त खोजक अपने ${activityTable.length} कार्यों में से किसी के लिए ${esc(info.hindi)} को नहीं गिनता; यह कार्य शुरू करने के दिन की बात है, इस नक्षत्र में जन्मे लोगों की नहीं।'
      : 'ऐप का मुहूर्त खोजक ${esc(info.hindi)} को ${allowed.length == activityTable.length ? 'अपने सभी ${activityTable.length}' : 'अपने ${activityTable.length} में से ${allowed.length}'} कार्यों के लिए मान्य गिनता है, जो ऊपर दिए हैं।';
  final Bi? junction = _gandanta(info, padas, refs);
  // A paragraph of one short sentence reads like a stub, so when there is no
  // junction to explain the muhurta sentence joins the paragraph before it.
  final bool fold = junction == null && allowed.isNotEmpty;
  final List<String> english = <String>[
    p1En,
    p2En,
    fold ? '$p3En $muhurtaEn' : p3En,
    if (!fold) junction == null ? muhurtaEn : '$muhurtaEn ${junction.en}',
  ];
  final List<String> hindi = <String>[
    p1Hi,
    p2Hi,
    fold ? '$p3Hi $muhurtaHi' : p3Hi,
    if (!fold) junction == null ? muhurtaHi : '$muhurtaHi ${junction.hi}',
  ];
  return _Prose(english, hindi);
}

String _factsEnglish(
  NakshatraInfo info,
  List<_Pada> padas,
  List<PageRef> refs,
  List<PageRef> grahas,
) {
  final String path = refs[info.index].path;
  final GrahaInfo lord = grahaInfo(info.lord);
  final List<_Run> runs = _runsOf(padas);
  final List<String> alsoWritten =
      _spellingsEnglish[info.english] ?? const <String>[];
  final List<String> alsoWrittenHi =
      _spellingsHindi[info.english] ?? const <String>[];
  final String signs = joinEnglish(<String>[
    for (final _Run run in runs)
      '${link(path, _rashiPath(run.rashi), esc(rashiInfo(run.rashi).english))}${runs.length > 1 ? ' (${_padaRangeEnglish(run.padas)})' : ''}',
  ]);
  final List<NakshatraInfo> sameNadi = _sharing(
    info,
    (NakshatraInfo n) => n.nadi == info.nadi,
  );
  final List<NakshatraInfo> sameYoni = _sharing(
    info,
    (NakshatraInfo n) => n.yoni == info.yoni,
  );
  return factsHtml(<(String, String)>[
    ('Position', '${info.index + 1} of 27'),
    (
      'Name',
      '${esc(info.english)} · <span lang="hi">${esc(info.hindi)}</span>${alsoWritten.isEmpty && alsoWrittenHi.isEmpty ? '' : '<br><small>Also written: ${joinEnglish(<String>[...alsoWritten.map(esc), ...alsoWrittenHi.map((String s) => '<span lang="hi">${esc(s)}</span>')])}</small>'}',
    ),
    (
      'Lord (dasha)',
      '${link(path, grahas[grahaIndexOf(info.lord)].path, esc(lord.english))} · ${vimshottariYears[info.lord]!.round()} of the 120 years<br><small>${esc(lord.english)} signifies ${esc(lord.karaka.toLowerCase())}</small>',
    ),
    ('Deity', esc(info.deityEnglish)),
    ('Symbol', esc(info.symbolEnglish)),
    ('Gana', ganaEnglish(info.gana)),
    ('Yoni', esc(sentenceCase(info.yoni))),
    ('Nadi', nadiEnglish(info.nadi)),
    (
      'Sidereal span',
      '${arcText(info.index * _nakshatraArc)} to ${arcText((info.index + 1) * _nakshatraArc)}',
    ),
    ('Sign (rashi)', signs),
    ('Naming syllables', esc(padas.map((_Pada p) => p.syllable).join(', '))),
    (
      'Same nadi (${nadiEnglish(info.nadi)})',
      _nakshatraLinks(path, refs, sameNadi, hindi: false),
    ),
    (
      'Same yoni',
      sameYoni.isEmpty
          ? 'No other nakshatra'
          : _nakshatraLinks(path, refs, sameYoni, hindi: false),
    ),
    (
      'Allowed in the app’s muhurta lists',
      allowedActivities(info).isEmpty
          ? 'None of the ${activityTable.length} activities'
          : joinEnglish(<String>[
              for (final ActivityInfo a in allowedActivities(info))
                esc(a.english),
            ]),
    ),
  ]);
}

String _factsHindi(
  NakshatraInfo info,
  List<_Pada> padas,
  List<PageRef> refs,
  List<PageRef> grahas,
) {
  final String path = refs[info.index].path;
  final GrahaInfo lord = grahaInfo(info.lord);
  final List<_Run> runs = _runsOf(padas);
  final List<String> alsoWritten =
      _spellingsHindi[info.english] ?? const <String>[];
  final String signs = joinHindi(<String>[
    for (final _Run run in runs)
      '${link(path, _rashiPath(run.rashi), esc(rashiInfo(run.rashi).hindi), lang: 'hi')}${runs.length > 1 ? ' (${_padaRangeHindi(run.padas)})' : ''}',
  ]);
  final List<NakshatraInfo> sameNadi = _sharing(
    info,
    (NakshatraInfo n) => n.nadi == info.nadi,
  );
  final List<NakshatraInfo> sameYoni = _sharing(
    info,
    (NakshatraInfo n) => n.yoni == info.yoni,
  );
  return factsHtml(<(String, String)>[
    ('क्रम', '27 में से ${info.index + 1}'),
    (
      'नाम',
      '${esc(info.hindi)}${alsoWritten.isEmpty ? '' : '<br><small>अन्य रूप: ${alsoWritten.map(esc).join(', ')}</small>'}',
    ),
    (
      'स्वामी (दशा)',
      '${link(path, grahas[grahaIndexOf(info.lord)].path, esc(lord.hindi), lang: 'hi')} · 120 में से ${_yearsHindi(vimshottariYears[info.lord]!)}<br><small>${esc(lord.hindi)} ${esc(karakaHindi(lord.karaka))} के कारक हैं</small>',
    ),
    ('देवता', esc(info.deityHindi)),
    ('प्रतीक', esc(symbolHindi(info.symbolEnglish))),
    ('गण', ganaHindi(info.gana)),
    ('योनि', esc(yoniHindi(info.yoni))),
    ('नाड़ी', nadiHindi(info.nadi)),
    (
      'निरयन विस्तार',
      '${arcText(info.index * _nakshatraArc)} से ${arcText((info.index + 1) * _nakshatraArc)}',
    ),
    ('राशि', signs),
    ('नामाक्षर', esc(padas.map((_Pada p) => p.syllableHindi).join(', '))),
    (
      'समान नाड़ी (${nadiHindi(info.nadi)})',
      _nakshatraLinks(path, refs, sameNadi, hindi: true),
    ),
    (
      'समान योनि',
      sameYoni.isEmpty
          ? 'कोई अन्य नक्षत्र नहीं'
          : _nakshatraLinks(path, refs, sameYoni, hindi: true),
    ),
    (
      'ऐप की मुहूर्त सूची में मान्य',
      allowedActivities(info).isEmpty
          ? '${activityTable.length} में से किसी कार्य के लिए नहीं'
          : joinHindi(<String>[
              for (final ActivityInfo a in allowedActivities(info))
                esc(a.hindi),
            ]),
    ),
  ]);
}

String _rashiPath(Rashi rashi) => rashiRefsCache[rashi.index].path;

final List<PageRef> rashiRefsCache = rashiRefs();

String _padaTableEnglish(NakshatraInfo info, List<_Pada> padas) {
  final GrahaInfo lord = grahaInfo(info.lord);
  return tableHtml(
    headers: <String>[
      'Pada',
      'Sidereal degrees',
      'Sign',
      'Navamsa',
      'Name begins with',
      '${esc(lord.english)} dasha left at birth',
    ],
    rows: <List<String>>[
      for (final _Pada p in padas)
        <String>[
          '${p.number}',
          '${arcText(p.startArc % 21600)} to ${arcText(p.endArc)}',
          '${esc(rashiInfo(p.rashi).english)} ${arcText(p.startInSign)} to ${arcText(p.endInSign)}',
          esc(rashiInfo(p.navamsa).english),
          '<strong>${esc(p.syllable)}</strong>',
          '${monthsEnglish(p.balanceStart)} → ${monthsEnglish(p.balanceEnd)}',
        ],
    ],
  );
}

String _padaTableHindi(NakshatraInfo info, List<_Pada> padas) {
  final GrahaInfo lord = grahaInfo(info.lord);
  return tableHtml(
    headers: <String>[
      'चरण',
      'निरयन अंश',
      'राशि',
      'नवांश',
      'नाम का अक्षर',
      'जन्म पर शेष ${esc(lord.hindi)} दशा',
    ],
    rows: <List<String>>[
      for (final _Pada p in padas)
        <String>[
          '${p.number}',
          '${arcText(p.startArc % 21600)} से ${arcText(p.endArc)}',
          '${esc(rashiInfo(p.rashi).hindi)} ${arcText(p.startInSign)} से ${arcText(p.endInSign)}',
          esc(rashiInfo(p.navamsa).hindi),
          '<strong>${esc(p.syllableHindi)}</strong>',
          '${monthsHindi(p.balanceStart)} → ${monthsHindi(p.balanceEnd)}',
        ],
    ],
  );
}

/// Word counts of the prose, kept for the build report.
final Map<String, (int, int)> nakshatraProseWords = <String, (int, int)>{};

/// Builds all 27 pages, keyed by site path.
Map<String, String> buildNakshatraPages() {
  final List<PageRef> refs = nakshatraRefs();
  final List<PageRef> grahas = grahaRefs();
  final Map<String, String> pages = <String, String>{};

  // The generator refuses to publish if the engine's classification stops
  // being the classical three-by-nine split.
  for (final Gana gana in Gana.values) {
    check(
      nakshatraTable.where((NakshatraInfo n) => n.gana == gana).length == 9,
      'gana ${gana.name} no longer holds nine nakshatras',
    );
  }
  for (final Nadi nadi in Nadi.values) {
    check(
      nakshatraTable.where((NakshatraInfo n) => n.nadi == nadi).length == 9,
      'nadi ${nadi.name} no longer holds nine nakshatras',
    );
  }
  check(
    vimshottariYears.values.fold<double>(0, (double a, double b) => a + b) ==
        120,
    'Vimshottari years no longer total 120',
  );
  check(nakshatraTable.length == 27, 'the engine no longer has 27 nakshatras');

  for (final NakshatraInfo info in nakshatraTable) {
    final PageRef ref = refs[info.index];
    final List<_Pada> padas = _padasOf(info);
    final _Prose prose = _proseFor(info, padas, refs);
    final GrahaInfo lord = grahaInfo(info.lord);
    final List<_Run> runs = _runsOf(padas);

    final String signEn = joinEnglish(<String>[
      for (final _Run r in runs) rashiInfo(r.rashi).english,
    ]);
    final String signHi = joinHindi(<String>[
      for (final _Run r in runs) rashiInfo(r.rashi).hindi,
    ]);
    final String title =
        '${info.english} Nakshatra (${info.hindi} नक्षत्र): Lord, Deity, Padas and Name Letters';
    final String description =
        '${info.english} (${info.hindi}) nakshatra: lord ${lord.english}, deity ${info.deityEnglish}, ${ganaEnglish(info.gana)} gana, ${nadiEnglish(info.nadi)} nadi, in $signEn, with its four padas and naming syllables. ${info.hindi} नक्षत्र: स्वामी ${lord.hindi}, देवता ${info.deityHindi}, राशि $signHi, चरण और नामाक्षर।';

    final PageRef before = refs[(info.index + 26) % 27];
    final PageRef after = refs[(info.index + 1) % 27];
    final String body =
        '''
  <section id="english" lang="en">
    <h2>${esc(info.english)} nakshatra at a glance</h2>
${_factsEnglish(info, padas, refs, grahas)}
    <h2>Understanding ${esc(info.english)}</h2>
${prose.english.map((String p) => '    <p class="prose">$p</p>').join('\n')}
    <h2>The four padas of ${esc(info.english)}</h2>
    <p class="note">A nakshatra is 13°20′, a twenty-seventh of the zodiac, and the Moon crosses one in about a day. A pada is a quarter of it, 3°20′, exactly one navamsa, and the Moon takes about six hours to cross one, so a birth time that is a few hours out can change the pada and its naming syllable. The last column is how much of the ${esc(lord.english)} period would remain for someone born with the Moon at the start and at the end of that pada.</p>
${_padaTableEnglish(info, padas)}
${ctaBlock(from: ref.path, heading: (en: 'Find your own nakshatra', hi: ''), body: (en: 'Enter your birth date, time and place and KundliSaar shows the nakshatra and pada your Moon stood in, with the dasha that follows. It runs on your device, is free, and needs no account.', hi: ''), button: (en: 'Open the app', hi: ''), hindi: false)}
    <p class="note">Degrees are sidereal, on the Lahiri ayanamsa. Facts come from the same engine the app uses; the classical rules are explained in plain words and, where authorities differ, that is said. This is traditional reference material, not a prediction.</p>
    <p class="langjump"><a href="#hindi" lang="hi">हिन्दी में पढ़ें ↓</a></p>
  </section>

  <section id="hindi" lang="hi">
    <h2>${esc(info.hindi)} नक्षत्र एक नज़र में</h2>
${_factsHindi(info, padas, refs, grahas)}
    <h2>${esc(info.hindi)} को समझें</h2>
${prose.hindi.map((String p) => '    <p class="prose">$p</p>').join('\n')}
    <h2>${esc(info.hindi)} के चार चरण</h2>
    <p class="note">नक्षत्र 13°20′ का होता है, राशिचक्र का सत्ताईसवाँ भाग, और चंद्रमा उसे लगभग एक दिन में पार करता है। चरण उसका चौथाई, 3°20′, यानी ठीक एक नवांश है, और चंद्रमा उसे लगभग छह घंटे में पार करता है, इसलिए जन्म-समय कुछ घंटे इधर-उधर हो तो चरण और उसका नामाक्षर बदल सकता है। अंतिम स्तंभ बताता है कि चंद्रमा उस चरण के आरंभ और अंत पर हो तो ${esc(lord.hindi)} की दशा कितनी बची रहेगी।</p>
${_padaTableHindi(info, padas)}
${ctaBlock(from: ref.path, heading: (en: '', hi: 'अपना नक्षत्र जानें'), body: (en: '', hi: 'जन्म की तारीख़, समय और स्थान भरें; कुंडलीसार बताएगा कि आपका चंद्रमा किस नक्षत्र और चरण में था और उसके बाद कौन-सी दशा चलती है। यह आपके फ़ोन पर चलता है, मुफ़्त है और खाता नहीं माँगता।'), button: (en: '', hi: 'ऐप खोलें'), hindi: true)}
    <p class="note">अंश निरयन हैं, लाहिरी अयनांश पर। तथ्य उसी इंजन से आते हैं जिसे ऐप चलाता है; शास्त्रीय नियम सरल शब्दों में समझाए गए हैं और जहाँ विद्वान भिन्न मत रखते हैं, वहाँ यह कहा गया है। यह पारंपरिक जानकारी है, भविष्यवाणी नहीं।</p>
    <p class="langjump"><a href="#english" lang="en">Read in English ↑</a></p>
  </section>
''';

    final (int, int) words = (
      wordCount(plainText(prose.english.join(' '))),
      wordCount(plainText(prose.hindi.join(' '))),
    );
    nakshatraProseWords[ref.path] = words;
    check(
      words.$1 >= 150 && words.$1 <= 250,
      '${info.english}: English prose is ${words.$1} words, outside 150-250',
    );
    check(
      words.$2 >= 150 && words.$2 <= 250,
      '${info.english}: Hindi prose is ${words.$2} words, outside 150-250',
    );

    final List<Crumb> crumbs = <Crumb>[
      const Crumb('KundliSaar', ''),
      const Crumb('Learn', 'learn/'),
      const Crumb('Nakshatras', 'learn/#nakshatras'),
      Crumb('${info.english} · ${info.hindi}', ref.path),
    ];
    final String html = renderPage(
      PageSpec(
        path: ref.path,
        title: title,
        description: description,
        heading:
            '${esc(info.english)} nakshatra <span class="h1-hi" lang="hi">· ${esc(info.hindi)} नक्षत्र</span>',
        lede:
            'The ${_placeEnglish(info)} of the 27 lunar mansions: lord ${esc(lord.english)}, deity ${esc(info.deityEnglish)}, in $signEn.<br><span lang="hi">27 नक्षत्रों में ${_placeHindi(info)}: स्वामी ${esc(lord.hindi)}, देवता ${esc(info.deityHindi)}, राशि $signHi।</span>',
        body: body,
        crumbs: crumbs,
        jumpLinks: true,
        previous: SiblingLink(
          path: before.path,
          title:
              '${esc(before.english)} · <span lang="hi">${esc(before.hindi)}</span>',
        ),
        next: SiblingLink(
          path: after.path,
          title:
              '${esc(after.english)} · <span lang="hi">${esc(after.hindi)}</span>',
        ),
        jsonLd: <Map<String, Object?>>[
          articleLd(
            path: ref.path,
            headline: '${info.english} nakshatra (${info.hindi} नक्षत्र)',
            description: description,
            dateModified: referenceUpdated,
          ),
          breadcrumbLd(crumbs, '$siteBase${ref.path}'),
        ],
      ),
    );
    checkText(ref.path, html);
    pages[ref.path] = html;
  }
  return pages;
}
