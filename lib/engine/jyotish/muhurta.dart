import '../astro/ayanamsa.dart';
import '../astro/ephemeris.dart';
import '../astro/houses.dart';
import '../astro/time.dart';
import 'chart.dart';
import 'nakshatra.dart';
import 'panchang.dart';

/// Activities the muhurta finder knows the classical rules for.
enum Activity {
  grihaPravesh,
  vehicle,
  business,
  travel,
  marriage,
  naming,
  education,
  property,
  engagement,
  newWork,
}

class ActivityInfo {
  const ActivityInfo({
    required this.activity,
    required this.english,
    required this.hindi,
    required this.nakshatras,
    required this.weekdays,
    required this.note,
    required this.noteHindi,
  });

  final Activity activity;
  final String english;
  final String hindi;

  /// Nakshatra indices, zero-based from Ashwini, that the texts allow.
  final List<int> nakshatras;

  /// Weekdays, 0 = Sunday, that the texts prefer.
  final List<int> weekdays;
  final String note;
  final String noteHindi;
}

const List<ActivityInfo> activityTable = <ActivityInfo>[
  ActivityInfo(
    activity: Activity.grihaPravesh,
    english: 'Griha Pravesh',
    hindi: 'गृह प्रवेश',
    nakshatras: <int>[3, 4, 7, 11, 12, 13, 14, 16, 20, 21, 22, 23, 25, 26],
    weekdays: <int>[1, 3, 4, 5],
    note:
        'Entering a new home. The fixed nakshatras are preferred because the texts read them as settling rather than moving.',
    noteHindi: 'नए घर में प्रवेश। ध्रुव नक्षत्र स्थिरता देते हैं।',
  ),
  ActivityInfo(
    activity: Activity.vehicle,
    english: 'Buying a vehicle',
    hindi: 'वाहन खरीदना',
    nakshatras: <int>[0, 3, 4, 6, 7, 12, 13, 14, 16, 21, 22, 23, 26],
    weekdays: <int>[1, 3, 4, 5],
    note: 'The movable nakshatras suit anything that travels.',
    noteHindi: 'चर नक्षत्र यात्रा और वाहन के लिए उपयुक्त हैं।',
  ),
  ActivityInfo(
    activity: Activity.business,
    english: 'Starting a business',
    hindi: 'व्यापार आरंभ',
    nakshatras: <int>[0, 3, 4, 6, 7, 11, 12, 13, 14, 16, 20, 21, 22, 23, 26],
    weekdays: <int>[1, 3, 4, 5],
    note:
        'Mercury and Jupiter days carry trade; the swift nakshatras suit an opening.',
    noteHindi: 'बुध और गुरुवार व्यापार के लिए शुभ माने गए हैं।',
  ),
  ActivityInfo(
    activity: Activity.travel,
    english: 'Setting out on a journey',
    hindi: 'यात्रा आरंभ',
    nakshatras: <int>[0, 4, 6, 7, 12, 16, 21, 22, 26],
    weekdays: <int>[1, 3, 4, 5],
    note:
        'Avoid the direction the day forbids; the app flags the nakshatra and the kaal only.',
    noteHindi: 'दिशाशूल का ध्यान रखें।',
  ),
  ActivityInfo(
    activity: Activity.marriage,
    english: 'Marriage',
    hindi: 'विवाह',
    nakshatras: <int>[3, 4, 9, 11, 12, 14, 16, 18, 20, 25, 26],
    weekdays: <int>[1, 3, 4, 5],
    note:
        'A full marriage muhurta also weighs both charts; this screens the day only.',
    noteHindi: 'पूर्ण विवाह मुहूर्त दोनों कुंडलियों से देखा जाता है।',
  ),
  ActivityInfo(
    activity: Activity.naming,
    english: 'Namkaran',
    hindi: 'नामकरण',
    nakshatras: <int>[0, 3, 4, 6, 7, 11, 12, 13, 14, 16, 20, 21, 22, 23, 26],
    weekdays: <int>[1, 3, 4, 5],
    note: 'Traditionally the eleventh or twelfth day after birth.',
    noteHindi: 'परंपरा में जन्म के ग्यारहवें या बारहवें दिन।',
  ),
  ActivityInfo(
    activity: Activity.education,
    english: 'Starting study',
    hindi: 'विद्यारंभ',
    nakshatras: <int>[0, 6, 7, 12, 13, 14, 16, 11, 20, 21, 23, 25, 26],
    weekdays: <int>[3, 4, 5],
    note: 'Mercury and Jupiter days, with Saraswati invoked.',
    noteHindi: 'बुध और गुरुवार, सरस्वती वंदना के साथ।',
  ),
  ActivityInfo(
    activity: Activity.property,
    english: 'Buying land or property',
    hindi: 'भूमि या संपत्ति',
    nakshatras: <int>[3, 11, 12, 16, 20, 21, 25, 26],
    weekdays: <int>[1, 3, 4, 5],
    note: 'Fixed nakshatras for anything meant to stay.',
    noteHindi: 'स्थायी कार्य के लिए ध्रुव नक्षत्र।',
  ),
  ActivityInfo(
    activity: Activity.engagement,
    english: 'Engagement',
    hindi: 'सगाई',
    nakshatras: <int>[3, 4, 11, 12, 13, 16, 20, 21, 25, 26],
    weekdays: <int>[1, 3, 4, 5],
    note: 'Soft and fixed nakshatras, as for marriage.',
    noteHindi: 'मृदु और ध्रुव नक्षत्र।',
  ),
  ActivityInfo(
    activity: Activity.newWork,
    english: 'Any new undertaking',
    hindi: 'कोई भी नया कार्य',
    nakshatras: <int>[0, 3, 4, 6, 7, 11, 12, 13, 14, 16, 20, 21, 22, 23, 26],
    weekdays: <int>[1, 3, 4, 5],
    note: 'The general list, for work that has no rule of its own.',
    noteHindi: 'सामान्य सूची।',
  ),
];

ActivityInfo activityInfo(Activity activity) =>
    activityTable.firstWhere((ActivityInfo a) => a.activity == activity);

/// How much each choghadiya moves a muhurta score. Public so the website's
/// panchang page marks the slots with the same judgement the finder applies.
const Map<String, int> choghadiyaScore = <String, int>{
  'Amrit': 20,
  'Shubh': 15,
  'Labh': 15,
  'Char': 5,
  'Udveg': -15,
  'Kaal': -20,
  'Rog': -20,
};

/// Yogas the texts call unfit for beginnings.
const List<int> inauspiciousYogas = <int>[0, 5, 8, 9, 12, 16, 18, 26];

/// Rikta tithis, read as empty for new work.
const List<int> riktaTithis = <int>[3, 8, 13, 18, 23, 28];

/// One scored window, with every reason that moved the score.
class MuhurtaWindow {
  const MuhurtaWindow({
    required this.startJdUt,
    required this.endJdUt,
    required this.score,
    required this.reasons,
    required this.reasonsHindi,
    required this.nakshatra,
    required this.tithiName,
    required this.weekday,
  });

  final double startJdUt;
  final double endJdUt;

  /// Zero to a hundred; a hundred means nothing in the rules objects.
  final int score;
  final List<String> reasons;
  final List<String> reasonsHindi;
  final String nakshatra;
  final String tithiName;
  final int weekday;

  bool get isGood => score >= 70;
}

/// Scans [days] from [from] and returns the best windows for [activity].
///
/// Each day is cut into the eight choghadiya parts, which is how muhurta is
/// actually handed out in practice, and every part is scored against the
/// panchang of that moment plus the chandra bala of the person, when a chart
/// is given.
List<MuhurtaWindow> findMuhurta({
  required Activity activity,
  required DateTime from,
  required int days,
  required Duration utcOffset,
  required GeoPlace place,
  Kundli? forPerson,
  Ayanamsa ayanamsa = Ayanamsa.lahiri,
  int limit = 12,
}) {
  final ActivityInfo info = activityInfo(activity);
  final List<MuhurtaWindow> windows = <MuhurtaWindow>[];

  for (int day = 0; day < days; day++) {
    final DateTime date = DateTime(
      from.year,
      from.month,
      from.day,
    ).add(Duration(days: day));
    final Panchang panchang = computePanchang(
      localDate: date,
      utcOffset: utcOffset,
      place: place,
      ayanamsa: ayanamsa,
    );
    if (panchang.sunrise == null || panchang.sunset == null) continue;

    for (final TimeSpan slot in panchang.dayChoghadiya) {
      int score = 50;
      final List<String> reasons = <String>[];
      final List<String> hindi = <String>[];

      // Choghadiya quality.
      score += choghadiyaScore[slot.name] ?? 0;
      reasons.add('${slot.name} choghadiya');
      hindi.add('${slot.name} चौघड़िया');

      // Nakshatra of the moment.
      final Instant middle = Instant.fromJulianDayUt(
        (slot.startJdUt + slot.endJdUt) / 2,
      );
      final double moon = toSidereal(
        positionOf(Graha.moon, middle).tropicalLongitude,
        ayanamsa,
        middle.centuriesTt,
      );
      final int nakshatra = nakshatraIndexOf(moon);
      if (info.nakshatras.contains(nakshatra)) {
        score += 20;
        reasons.add(
          '${nakshatraTable[nakshatra].english} is allowed for this work',
        );
        hindi.add('${nakshatraTable[nakshatra].hindi} इस कार्य के लिए शुभ है');
      } else {
        score -= 15;
        reasons.add(
          '${nakshatraTable[nakshatra].english} is not in the list for this work',
        );
        hindi.add(
          '${nakshatraTable[nakshatra].hindi} इस कार्य की सूची में नहीं है',
        );
      }

      // Weekday.
      if (info.weekdays.contains(panchang.weekday)) {
        score += 10;
        reasons.add('${weekdayNames[panchang.weekday]} suits it');
        hindi.add('${weekdayNamesHindi[panchang.weekday]} उपयुक्त है');
      }

      // Tithi, yoga and karana.
      if (riktaTithis.contains(panchang.tithi.index)) {
        score -= 15;
        reasons.add('${panchang.tithi.name} is a rikta tithi');
        hindi.add('${panchang.tithi.nameHindi} रिक्ता तिथि है');
      }
      if (panchang.tithi.index == 29) {
        score -= 20;
        reasons.add('Amavasya is avoided for new work');
        hindi.add('अमावस्या में नया कार्य नहीं');
      }
      if (inauspiciousYogas.contains(panchang.yoga.index)) {
        score -= 10;
        reasons.add('${panchang.yoga.name} yoga is unfit for beginnings');
        hindi.add('${panchang.yoga.name} योग आरंभ के लिए अशुभ है');
      }
      if (panchang.karana.name == 'Vishti') {
        score -= 20;
        reasons.add('Vishti (Bhadra) karana is running');
        hindi.add('विष्टि (भद्रा) करण चल रहा है');
      }

      // Inauspicious periods.
      bool overlaps(TimeSpan? span) =>
          span != null &&
          slot.startJdUt < span.endJdUt &&
          slot.endJdUt > span.startJdUt;
      if (overlaps(panchang.rahuKaal)) {
        score -= 25;
        reasons.add('Overlaps Rahu Kaal');
        hindi.add('राहु काल में पड़ता है');
      }
      if (overlaps(panchang.yamaganda)) {
        score -= 10;
        reasons.add('Overlaps Yamaganda');
        hindi.add('यमगंड में पड़ता है');
      }
      if (overlaps(panchang.abhijit)) {
        score += 10;
        reasons.add('Touches Abhijit muhurta');
        hindi.add('अभिजित मुहूर्त में आता है');
      }

      // Chandra bala, when we know the person.
      if (forPerson != null) {
        final int fromMoon =
            (((moon / 30).floor() - forPerson.moonRashi.index + 12) % 12) + 1;
        if (<int>[4, 8, 12].contains(fromMoon)) {
          score -= 15;
          reasons.add('The Moon is in house $fromMoon from your natal Moon');
          hindi.add('चंद्र आपके जन्म चंद्र से $fromMoonवें भाव में है');
        } else if (<int>[1, 3, 6, 7, 10, 11].contains(fromMoon)) {
          score += 10;
          reasons.add('Chandra bala is good, house $fromMoon from your Moon');
          hindi.add('चंद्र बल अच्छा है ($fromMoonवाँ भाव)');
        }
      }

      windows.add(
        MuhurtaWindow(
          startJdUt: slot.startJdUt,
          endJdUt: slot.endJdUt,
          score: score.clamp(0, 100),
          reasons: reasons,
          reasonsHindi: hindi,
          nakshatra: nakshatraTable[nakshatra].english,
          tithiName: panchang.tithi.name,
          weekday: panchang.weekday,
        ),
      );
    }
  }

  windows.sort((MuhurtaWindow a, MuhurtaWindow b) {
    final int byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.startJdUt.compareTo(b.startJdUt);
  });
  return windows.take(limit).toList(growable: false);
}
