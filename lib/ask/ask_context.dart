import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/phaladesh.dart';
import '../engine/jyotish/transits.dart';
import 'ask_language.dart';

/// Phaladesh is worked out once per chart and kept for as long as the chart
/// object lives, so a second question costs nothing.
final Expando<Phaladesh> _phalaCache = Expando<Phaladesh>('phaladesh');

Phaladesh phaladeshFor(Kundli kundli) =>
    _phalaCache[kundli] ??= computePhaladesh(kundli);

/// Transits are worked out for a day, not for an instant: Saturn and Jupiter
/// do not move far in a day, and asking twice costs nothing.
final Expando<Map<String, GocharPhala>> _gocharCache =
    Expando<Map<String, GocharPhala>>('gochar');
final Expando<Map<String, TransitReport>> _transitCache =
    Expando<Map<String, TransitReport>>('transits');

String _dayKey(DateTime moment) {
  final DateTime d = moment.toUtc();
  return '${d.year}-${d.month}-${d.day}';
}

GocharPhala gocharFor(Kundli kundli, DateTime now) {
  final Map<String, GocharPhala> byDay = _gocharCache[kundli] ??=
      <String, GocharPhala>{};
  return byDay[_dayKey(now)] ??= phaladeshFor(kundli).gochar(now: now);
}

TransitReport transitsFor(Kundli kundli, DateTime now) {
  final Map<String, TransitReport> byDay = _transitCache[kundli] ??=
      <String, TransitReport>{};
  return byDay[_dayKey(now)] ??= computeTransits(kundli, now);
}

/// Everything a composer needs to write one answer: the chart, the readings
/// phaladesh has already worked out, the moment asked about, and the language.
///
/// Nothing here recomputes a reading. A dasha is read from [Phaladesh.dasha],
/// the dated windows come from [Phaladesh.timeline], how a graha stands comes
/// from the standings in [PhalaContext], and the transits come from
/// [Phaladesh.gochar].
class AskCtx {
  AskCtx(this.k, this.now, bool hindi)
    : l = AskLang(hindi),
      p = phaladeshFor(k);

  final Kundli k;
  final Phaladesh p;
  final DateTime now;
  final AskLang l;

  PhalaContext get pc => p.context;
  Duration get zone => k.birth.utcOffset;
  bool get hindi => l.hindi;

  /// The periods running at [now], outermost first.
  late final List<PeriodReading> chain = p.dasha.chainAt(now);

  PeriodReading? get maha => chain.isNotEmpty ? chain[0] : null;
  PeriodReading? get antar => chain.length > 1 ? chain[1] : null;
  PeriodReading? get praty => chain.length > 2 ? chain[2] : null;

  /// The antardasha window the timeline places [now] in.
  late final TimelineWindow? window = p.timeline.windowAt(now);

  late final GocharPhala gochar = gocharFor(k, now);

  late final TransitReport transits = transitsFor(k, now);

  GrahaStanding st(Graha g) => pc.of(g);

  String get lagna => l.sign(k.lagnaRashi);

  String date(DateTime utc) => l.date(utc, zone);
  String monthYear(DateTime utc) => l.monthYear(utc, zone);

  String name(Graha g) => l.graha(g);

  /// True when [maha] began within a day or two of the birth, which is the
  /// case for the first mahadasha only: it was already running.
  bool startedAtBirth(PeriodReading period) =>
      (period.startJdUt - k.instant.julianDayUt).abs() < 2;

  // -------------------------------------------------------------------------
  // How a graha stands in this chart
  // -------------------------------------------------------------------------

  String num1(double v) {
    final String s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  /// "For a Virgo lagna Mars is ...", in the graha's functional character.
  String natureLine(Graha g) {
    final GrahaStanding s = st(g);
    final bool node = g == Graha.rahu || g == Graha.ketu;
    final Graha who = node ? s.reader : g;
    final String me = name(who);
    final String base = switch (s.nature) {
      FunctionalNature.yogakaraka => l.t(
        'For a $lagna lagna $me is a yogakaraka: it rules both a kendra and a trikona, which makes it one of the most helpful grahas in your chart.',
        '$lagna लग्न के लिए $me योगकारक है। यह केंद्र और त्रिकोण, दोनों का स्वामी है, यानी आपकी कुंडली के सबसे मददगार ग्रहों में से एक।',
      ),
      FunctionalNature.benefic => l.t(
        'For a $lagna lagna $me counts as a graha that gives good results.',
        '$lagna लग्न के लिए $me शुभ फल देने वाला ग्रह माना जाता है।',
      ),
      FunctionalNature.mixed => l.t(
        'For a $lagna lagna the results of $me come mixed.',
        '$lagna लग्न के लिए $me का फल मिला-जुला रहता है।',
      ),
      FunctionalNature.malefic => l.t(
        'For a $lagna lagna $me rules difficult houses, so its results come through effort rather than ease.',
        '$lagna लग्न के लिए $me कठिन भावों का स्वामी है, इसलिए इसका फल आसानी से नहीं, मेहनत से मिलता है।',
      ),
    };
    if (!node) return base;
    final String self = name(g);
    return l.t(
      '$base $self gives its results in that same spirit.',
      '$base $self उसी के अनुरूप फल देता है।',
    );
  }

  /// "Its shadbala is 7.5 rupas against the 5 it needs, so ...". With [named]
  /// the graha is named instead of "its", for a sentence that stands alone.
  String strengthLine(Graha g, {bool named = false}) {
    final b = st(g).bala;
    if (b == null) return '';
    final String r = num1(b.totalRupas);
    final String need = num1(b.requiredRupas);
    final double ratio = b.ratio;
    final String me = name(g);
    final String subject = named
        ? l.t('$me’s shadbala', '$me का षड्बल')
        : l.t('Its shadbala', 'इसका षड्बल');
    if (ratio >= 1.25) {
      return l.t(
        '$subject is $r rupas against the $need it needs, so it is well supplied with strength.',
        '$subject $r रूप है, जबकि इसे $need चाहिए, यानी यह काफ़ी बलवान है।',
      );
    }
    if (ratio >= 1.0) {
      return l.t(
        '$subject is $r rupas against the $need it needs, so it has the strength it requires.',
        '$subject $r रूप है, जबकि इसे $need चाहिए, यानी ज़रूरी बल पूरा है।',
      );
    }
    if (ratio >= 0.8) {
      return l.t(
        '$subject is $r rupas against the $need it needs, a little short of what it requires.',
        '$subject $r रूप है, जबकि इसे $need चाहिए, यानी बल थोड़ा कम है।',
      );
    }
    return l.t(
      '$subject is $r rupas against the $need it needs, so it is short of strength and does better with support.',
      '$subject $r रूप है, जबकि इसे $need चाहिए, यानी बल कम है और इसे सहारे की ज़रूरत है।',
    );
  }

  /// The sentences that say what a graha rules, where it stands and in what
  /// condition. [depth] 0 is the placement alone, 1 adds its character for
  /// this lagna, 2 adds its strength, and 3 the finer conditions.
  String standing(Graha g, {int depth = 3}) {
    final GrahaStanding s = st(g);
    final PlacedGraha pl = s.placed;
    final bool node = g == Graha.rahu || g == Graha.ketu;
    final String me = name(g);
    final String sign = l.sign(pl.rashi);
    final List<String> out = <String>[];

    final bool showDignity =
        !node ||
        pl.dignity == Dignity.exalted ||
        pl.dignity == Dignity.debilitated;
    final String dignity = showDignity
        ? l.t(
            ' — ${l.dignityIn(pl.dignity)}, ${l.dignityGloss(pl.dignity, bhanga: s.neechaBhanga != null)}',
            ' — ${l.dignityIn(pl.dignity)}, ${l.dignityGloss(pl.dignity, bhanga: s.neechaBhanga != null)}',
          )
        : '';

    if (!node) {
      out.add(
        l.t(
          '$me rules ${l.houses(s.ruled)} of your $lagna-lagna chart, and stands in ${l.house(pl.house)}, in $sign$dignity.',
          '$me आपकी $lagna लग्न की कुंडली में ${l.houses(s.ruled)} का स्वामी है, और $sign राशि में, ${l.house(pl.house)} में बैठा है$dignity।',
        ),
      );
    } else {
      final String reader = name(s.reader);
      out.add(
        l.t(
          '$me owns no house of its own; it gives results as $reader does, the lord of the sign it stands in.',
          '$me का अपना कोई भाव नहीं होता; वह जिस राशि में बैठा है, उसके स्वामी $reader की तरह फल देता है।',
        ),
      );
      out.add(
        l.t(
          '$me stands in ${l.house(pl.house)}, in $sign$dignity.',
          '$me $sign राशि में, ${l.house(pl.house)} में बैठा है$dignity।',
        ),
      );
    }
    if (depth >= 1) out.add(natureLine(g));
    final String strength = strengthLine(g);
    if (depth >= 2 && strength.isNotEmpty) out.add(strength);
    if (depth >= 3) {
      if (pl.isCombust) {
        out.add(
          l.t(
            'It is combust, too close to the Sun, which dims its strength a little.',
            'यह सूर्य के बहुत पास होने से अस्त है, जिससे इसकी शक्ति कुछ दबी रहती है।',
          ),
        );
      }
      if (pl.isRetrograde) {
        out.add(
          l.t(
            'It is retrograde, turned inward, which the tradition often reads as added strength.',
            'यह वक्री है, यानी भीतर की ओर मुड़ा हुआ; परंपरा इसे अक्सर और बलवान मानती है।',
          ),
        );
      }
    }
    return out.join(' ');
  }

  /// True when [g] is a lord of one of [houses], or stands in one of them.
  bool concerns(Graha g, Set<int> houses) {
    final GrahaStanding s = st(g);
    return s.houses(pc).any(houses.contains) || houses.contains(s.placed.house);
  }

  /// Why a house is in focus for a graha: it rules it, stands in it, or both.
  /// A node owns no house, so it is said to give results as the lord of its
  /// sign does.
  String whyHouse(Graha g, int house) {
    final GrahaStanding s = st(g);
    final bool node = g == Graha.rahu || g == Graha.ketu;
    final bool rules = s.houses(pc).contains(house);
    final bool sits = s.placed.house == house;
    final String me = name(g);
    final String reader = name(s.reader);
    if (node && rules) {
      return sits
          ? l.t(
              'because $me gives results as $reader does, and $reader rules that house, and $me stands there too',
              'क्योंकि $me $reader की तरह फल देता है, $reader उस भाव का स्वामी है, और $me वहीं बैठा भी है',
            )
          : l.t(
              'because $me gives results as $reader does, and $reader rules that house',
              'क्योंकि $me $reader की तरह फल देता है, और $reader उस भाव का स्वामी है',
            );
    }
    if (rules && sits) {
      return l.t(
        'because $me both rules it and stands in it',
        'क्योंकि $me इस भाव का स्वामी भी है और वहीं बैठा भी है',
      );
    }
    if (sits) {
      return l.t('because $me stands there', 'क्योंकि $me वहाँ बैठा है');
    }
    return l.t(
      'because $me is the lord of that house',
      'क्योंकि $me उस भाव का स्वामी है',
    );
  }

  /// The first sentence of a reading's "what tends to come up", which names
  /// the matters of the house in the words of everyday life.
  String firstSentenceOf(String text) {
    final int at = text.indexOf(RegExp(r'[.।]'));
    return at < 0 ? text : text.substring(0, at + 1);
  }

  /// Where the sub-lord stands counted from the lord of the period around it,
  /// and how the two get on.
  String modifierLine(PeriodReading sub) {
    final Graha? parent = sub.parentLord;
    final int? place = sub.placeFromParent;
    if (parent == null) return '';
    if (parent == sub.lord || place == null) {
      return l.t(
        'Here the sub-period belongs to the very same graha, so the larger period’s own nature comes forward in its plainest form.',
        'यहाँ अंतर्दशा भी उसी ग्रह की है, इसलिए बड़ी दशा का अपना स्वभाव सबसे सीधे रूप में सामने रहता है।',
      );
    }
    final String up = name(parent);
    final String me = name(sub.lord);
    final String band;
    if (const <int>[1, 4, 5, 7, 9, 10].contains(place)) {
      band = l.t(
        'the tradition counts this as an easy position: the sub-period helps bring out what the larger period points to',
        'शास्त्र में इसे सहज स्थिति माना जाता है, यानी अंतर्दशा बड़ी दशा के विषय को उभारने में मदद करती है',
      );
    } else if (place == 2 || place == 11) {
      band = l.t(
        'this is a place of gain, so the sub-period backs the main theme with resources',
        'यह लाभ का स्थान है, यानी अंतर्दशा मुख्य विषय को साधनों का सहारा देती है',
      );
    } else if (place == 3) {
      band = l.t(
        'this is a place of effort, so the fruit comes through trying rather than ease',
        'यह मेहनत का स्थान है, यानी फल सहजता से नहीं, कोशिश से मिलता है',
      );
    } else {
      band = l.t(
        'the tradition counts this as a difficult position, which asks for a little adjustment between the two',
        'शास्त्र इसे कठिन स्थिति मानता है, यानी दोनों के बीच थोड़ा तालमेल बिठाना पड़ता है',
      );
    }
    final String relation = switch (sub.relation) {
      Relation.friend => l.t(
        'The two are natural friends, so they work together.',
        'दोनों नैसर्गिक मित्र हैं, इसलिए साथ चलते हैं।',
      ),
      Relation.enemy => l.t(
        'The two are natural enemies, so there is some pull between them to be managed.',
        'दोनों नैसर्गिक शत्रु हैं, इसलिए आपस में खिंचाव रहता है, जिसे सँभालना पड़ता है।',
      ),
      _ => l.t(
        'The two are neutral to each other, so each goes its own way.',
        'दोनों आपस में सम हैं, यानी अपनी-अपनी राह चलते हैं।',
      ),
    };
    return l.t(
      'Counted from $up, $me stands in the ${l.ordinal(place)} place; $band. $relation',
      '$up से गिनें तो $me ${l.ordinal(place)} स्थान पर है; $band। $relation',
    );
  }

  /// The two areas of life a period concentrates on, as one phrase.
  String focusPhrase(PeriodReading period) {
    final List<LifeArea> a = period.areas;
    if (a.isEmpty) return '';
    final String first = l.area(a.first.house);
    if (a.length == 1) return first;
    final String second = l.area(a[1].house);
    return l.t('$first, with $second alongside', '$first, और साथ में $second');
  }
}
