import '../astro/ephemeris.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'saham.dart';
import 'tajika_aspects.dart';
import 'tajika_bala.dart';
import 'tajika_common.dart';
import 'varshphal_dasha.dart';

/// A dated window of the year: one Mudda period, read through the Tajika
/// aspects the period's lord is in and the sahams it is lord of.
///
/// The windows are the Mudda periods and so tile the year exactly: the first
/// starts at the pravesh, each begins where the one before ended, and the last
/// ends at the next pravesh.
///
/// What goes into a window's reading is the app's own way of ordering the
/// year's material, not a classical rule: the Mudda dasha says which graha's
/// matters are in front, and the window then lists what the year chart says
/// about that graha (its placement, its houses, its Tajika aspects, the sahams
/// it is lord of) and the dated moments from the grahas' real motion that fall
/// inside the stretch.
class YearWindow {
  const YearWindow({
    required this.index,
    required this.startJd,
    required this.endJd,
    required this.startLocal,
    required this.endLocal,
    required this.lord,
    required this.title,
    required this.reading,
    required this.factors,
    required this.aspects,
    required this.events,
    required this.sahams,
    required this.subPeriods,
    required this.isBalance,
    required this.isCarryOver,
  });

  final int index;
  final double startJd;
  final double endJd;

  /// Wall-clock start and end in the birth place's offset.
  final DateTime startLocal;
  final DateTime endLocal;

  /// The Mudda dasha lord of the window.
  final Graha lord;
  final Bi title;
  final Bi reading;
  final List<Bi> factors;

  /// The Tajika aspects the lord is in, closest first.
  final List<TajikaAspect> aspects;

  /// Dated moments inside the window: an Ittasala becoming exact, a pair
  /// leaving its orb, an aspect ending on a sign change.
  final List<WindowEvent> events;

  /// The interpreted sahams the lord is lord of.
  final List<SahamId> sahams;
  final List<MuddaSub> subPeriods;
  final bool isBalance;
  final bool isCarryOver;

  double get days => endJd - startJd;
}

/// A dated moment inside a window.
class WindowEvent {
  const WindowEvent({
    required this.jd,
    required this.local,
    required this.kind,
    required this.aspect,
    required this.text,
  });

  final double jd;
  final DateTime local;
  final TajikaEventKind kind;
  final TajikaAspect aspect;
  final Bi text;
}

Bi _dignityWords(Dignity dignity) => switch (dignity) {
  Dignity.exalted => const Bi('exalted', 'उच्च का'),
  Dignity.moolatrikona => const Bi('in its moolatrikona', 'मूलत्रिकोण में'),
  Dignity.own => const Bi('in its own sign', 'स्वराशि में'),
  Dignity.friend => const Bi('in a friend’s sign', 'मित्र राशि में'),
  Dignity.neutral => const Bi('in a neutral sign', 'सम राशि में'),
  Dignity.enemy => const Bi('in an enemy’s sign', 'शत्रु राशि में'),
  Dignity.debilitated => const Bi('debilitated', 'नीच का'),
};

Bi _toneWord(SahamTone tone) => switch (tone) {
  SahamTone.supported => const Bi('supported', 'सहारा पाता'),
  SahamTone.mixed => const Bi('mixed', 'मिला-जुला'),
  SahamTone.strained => const Bi('strained', 'दबाव में'),
};

Bi _eventText(TajikaAspect a, TajikaEvent event, DateTime local) {
  final Bi when = dateBi(local);
  final Bi f = grahaBi(a.faster);
  final Bi s = grahaBi(a.slower);
  switch (event.kind) {
    case TajikaEventKind.perfects:
      return Bi(
        'Around ${when.en}, ${f.en} reaches ${s.en}’s degree: the '
            '${a.isApplying ? 'Ittasala becomes exact' : 'two meet again'}.',
        'लगभग ${when.hi}, ${f.hi} ${s.hi} के अंश तक पहुँचता है: '
            '${a.isApplying ? 'इत्थशाल पूर्ण (सटीक) होता है' : 'दोनों फिर मिलते हैं'}।',
      );
    case TajikaEventKind.leavesOrb:
      return Bi(
        'Around ${when.en}, ${f.en} and ${s.en} drift out of their shared '
            'orb: the ${a.isApplying ? 'Ittasala' : 'Ishrafa'} fades.',
        'लगभग ${when.hi}, ${f.hi} और ${s.hi} अपने साझा दीप्तांश से बाहर '
            'निकल जाते हैं: ${a.isApplying ? 'इत्थशाल' : 'ईसराफ'} मंद पड़ता है।',
      );
    case TajikaEventKind.signChange:
      return Bi(
        'Around ${when.en}, one of ${f.en} and ${s.en} changes sign, which '
            'ends their aspect before it completes.',
        'लगभग ${when.hi}, ${f.hi} और ${s.hi} में से एक राशि बदलता है, जिससे '
            'उनकी दृष्टि पूरी होने से पहले समाप्त हो जाती है।',
      );
  }
}

/// Builds the windows of the year.
List<YearWindow> buildYearWindows({
  required Kundli chart,
  required MuddaDasha mudda,
  required TajikaReport tajika,
  required List<Saham> sahams,
  required Map<Graha, PanchaVargiyaBala> bala,
  required Graha yearLord,
  required Graha munthaLord,
  required int munthaHouse,
  required Duration utcOffset,
}) {
  final List<YearWindow> windows = <YearWindow>[];
  for (int i = 0; i < mudda.periods.length; i++) {
    final MuddaPeriod p = mudda.periods[i];
    final Graha lord = p.lord;
    final PlacedGraha placed = chart.grahas[lord]!;
    final bool isNode = lord == Graha.rahu || lord == Graha.ketu;
    final List<int> ruled = isNode ? const <int>[] : housesRuledBy(chart, lord);
    final List<TajikaAspect> aspects = isNode
        ? const <TajikaAspect>[]
        : tajika.aspectsOf(lord);
    final List<Saham> mine = sahams
        .where((Saham s) => s.lord == lord && s.isInterpreted)
        .toList(growable: false);
    final DateTime startLocal = utcFromJulianDay(p.startJd).add(utcOffset);
    final DateTime endLocal = utcFromJulianDay(p.endJd).add(utcOffset);

    // Dated moments inside the window, for the lord and for the lord of the
    // year.
    final List<WindowEvent> events = <WindowEvent>[];
    for (final TajikaAspect a in tajika.aspects) {
      final TajikaEvent? e = a.event;
      if (e == null) continue;
      if (!(a.involves(lord) || a.involves(yearLord))) continue;
      if (e.jd < p.startJd || e.jd >= p.endJd) continue;
      final DateTime local = utcFromJulianDay(e.jd).add(utcOffset);
      events.add(
        WindowEvent(
          jd: e.jd,
          local: local,
          kind: e.kind,
          aspect: a,
          text: _eventText(a, e, local),
        ),
      );
    }
    events.sort((WindowEvent a, WindowEvent b) => a.jd.compareTo(b.jd));

    final Bi lordName = grahaBi(lord);
    final List<Bi> parts = <Bi>[];

    // 1. Whose period it is.
    parts.add(
      p.isBalance
          ? Bi(
              'The year opens in what remains of ${lordName.en}’s Mudda dasha.',
              'वर्ष ${lordName.hi} की मुद्दा दशा के शेष भाग में खुलता है।',
            )
          : p.isCarryOver
          ? Bi(
              '${lordName.en}’s Mudda dasha comes round again to close the '
                  'year.',
              '${lordName.hi} की मुद्दा दशा वर्ष को पूरा करने फिर आती है।',
            )
          : Bi(
              'This is ${lordName.en}’s Mudda dasha.',
              'यह ${lordName.hi} की मुद्दा दशा है।',
            ),
    );

    // 2. Where the lord stands and what it rules.
    if (isNode) {
      parts.add(
        Bi(
          '${lordName.en} stands in ${rashiBi(placed.rashi.index).en}, '
              '${houseBi(placed.house).en}, so the stretch stirs '
              '${houseTheme(placed.house).en}. Tajika keeps the nodes out of '
              'its aspects, so the reading rests on that house alone.',
          '${lordName.hi} ${rashiBi(placed.rashi.index).hi} में, '
              '${houseBi(placed.house).hi} में है, इसलिए यह खंड '
              '${houseTheme(placed.house).hi} को जगाता है। ताजिक राहु-केतु को '
              'अपनी दृष्टियों से बाहर रखता है, इसलिए पठन उसी भाव पर टिका है।',
        ),
      );
    } else {
      final String ruledEn = ruled.map((int h) => houseTheme(h).en).join('; ');
      final String ruledHi = ruled.map((int h) => houseTheme(h).hi).join('; ');
      parts.add(
        Bi(
          '${lordName.en} stands in ${rashiBi(placed.rashi.index).en}, '
              '${houseBi(placed.house).en}, ${_dignityWords(placed.dignity).en}, '
              'and rules ${housesBi(ruled).en}. So the stretch draws on '
              '$ruledEn, coloured by ${houseTheme(placed.house).en}.',
          '${lordName.hi} ${rashiBi(placed.rashi.index).hi} में, '
              '${houseBi(placed.house).hi} में, ${_dignityWords(placed.dignity).hi} '
              'है और ${housesBi(ruled).hi} का स्वामी है। इसलिए यह खंड $ruledHi '
              'पर टिका है, जिस पर ${houseTheme(placed.house).hi} का रंग है।',
        ),
      );
    }

    // 3. Its roles in the year.
    if (lord == yearLord) {
      parts.add(
        Bi(
          '${lordName.en} is also the lord of the year, so this stretch is '
              'where the year’s own theme is strongest.',
          '${lordName.hi} वर्ष का स्वामी भी है, इसलिए इस खंड में वर्ष का अपना '
              'विषय सबसे प्रबल है।',
        ),
      );
    }
    if (lord == munthaLord) {
      parts.add(
        Bi(
          '${lordName.en} rules the Muntha sign, which sits in '
              '${houseBi(munthaHouse).en}.',
          '${lordName.hi} मुन्था की राशि का स्वामी है, जो '
              '${houseBi(munthaHouse).hi} में है।',
        ),
      );
    }

    // 4. Its Tajika aspects, the closest two.
    for (final TajikaAspect a in aspects.take(2)) {
      final Graha other = a.faster == lord ? a.slower : a.faster;
      final Bi otherName = grahaBi(other);
      parts.add(
        a.isApplying
            ? Bi(
                'With ${otherName.en} it is in Ittasala (${a.gap.toStringAsFixed(1)}° '
                    'apart): the tradition reads their matters as moving toward '
                    'completion.',
                '${otherName.hi} से इसका इत्थशाल है (${a.gap.toStringAsFixed(1)}° '
                    'का अंतर): परंपरा उनके विषयों को पूर्णता की ओर बढ़ता पढ़ती है।',
              )
            : Bi(
                'With ${otherName.en} it is in Ishrafa (${a.gap.toStringAsFixed(1)}° '
                    'past): the tradition reads their matters as slipping away.',
                '${otherName.hi} से इसका ईसराफ है (${a.gap.toStringAsFixed(1)}° '
                    'आगे): परंपरा उनके विषयों को हाथ से निकलता पढ़ती है।',
              ),
      );
    }
    // 5. Dated moments.
    for (final WindowEvent e in events) {
      parts.add(e.text);
    }

    // 6. Sahams.
    if (mine.isNotEmpty) {
      parts.add(
        Bi(
          'Sahams in ${lordName.en}’s charge: '
              '${mine.map((Saham s) => '${s.name.en} (${_toneWord(s.tone!).en})').join(', ')}.',
          '${lordName.hi} के अधीन सहम: '
              '${mine.map((Saham s) => '${s.name.hi} (${_toneWord(s.tone!).hi})').join(', ')}।',
        ),
      );
    }

    parts.add(
      const Bi(
        'Read it as emphasis for these weeks, not as a forecast of events.',
        'इसे इन सप्ताहों का ज़ोर समझें, घटनाओं की भविष्यवाणी नहीं।',
      ),
    );

    final List<Bi> factors = <Bi>[
      Bi(
        'Mudda dasha of ${lordName.en}, ${dateBi(startLocal).en} to '
            '${dateBi(endLocal).en}',
        '${lordName.hi} की मुद्दा दशा, ${dateBi(startLocal).hi} से '
            '${dateBi(endLocal).hi}',
      ),
      ...mudda.factors.take(2),
      Bi(
        '${lordName.en} in ${rashiBi(placed.rashi.index).en}, '
            '${houseBi(placed.house).en}, ${_dignityWords(placed.dignity).en}',
        '${lordName.hi} ${rashiBi(placed.rashi.index).hi} में, '
            '${houseBi(placed.house).hi} में, ${_dignityWords(placed.dignity).hi}',
      ),
      if (!isNode) ...<Bi>[
        Bi(
          'Rules ${housesBi(ruled).en} of the year chart',
          'वर्ष कुंडली के ${housesBi(ruled).hi} का स्वामी',
        ),
        Bi(
          'Five-fold strength ${compactNumber(bala[lord]!.vishwa)} vishwa '
              '(${pvBandBi(bala[lord]!.band).en})',
          'पंचवर्गीय बल ${compactNumber(bala[lord]!.vishwa)} विश्वा '
              '(${pvBandBi(bala[lord]!.band).hi})',
        ),
      ],
      for (final TajikaAspect a in aspects.take(2)) ...a.factors.take(2),
      for (final Saham s in mine)
        Bi(
          '${s.name.en} falls in ${houseBi(s.house).en}; its lord is '
              '${lordName.en}',
          '${s.name.hi} ${houseBi(s.house).hi} में पड़ता है; इसका स्वामी '
              '${lordName.hi} है',
        ),
    ];

    windows.add(
      YearWindow(
        index: i,
        startJd: p.startJd,
        endJd: p.endJd,
        startLocal: startLocal,
        endLocal: endLocal,
        lord: lord,
        title: Bi('${lordName.en} Mudda dasha', '${lordName.hi} की मुद्दा दशा'),
        reading: joinBi(parts),
        factors: factors,
        aspects: aspects,
        events: events,
        sahams: mine.map((Saham s) => s.id).toList(growable: false),
        subPeriods: p.subPeriods,
        isBalance: p.isBalance,
        isCarryOver: p.isCarryOver,
      ),
    );
  }
  return windows;
}

/// Local wall-clock time of a UT Julian day at [utcOffset].
DateTime localOf(double jdUt, Duration utcOffset) =>
    utcFromJulianDay(jdUt).add(utcOffset);
