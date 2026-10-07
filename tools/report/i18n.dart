/// Language handling for the report: one text, two renderings, and the rule
/// for how a page shows them when the buyer asked for both.
library;

import 'dart:convert';

import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';

enum ReportLang { hi, en, both }

/// An English and a Hindi rendering of the same thing. Strings may carry
/// inline markup (<b>, <span>); anything that came from the buyer must be
/// passed through [esc] before it goes in.
typedef Bi = ({String en, String hi});

Bi bi(String en, String hi) => (en: en, hi: hi);

String esc(String text) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(text);

/// How the same content is laid out in each of the three modes.
///
/// Prose is stacked, Hindi first, because a side-by-side translation halves
/// the measure of both columns and a Devanagari line under 40 characters
/// breaks badly. Short labels are paired or stacked so that tables keep
/// their columns.
class Loc {
  const Loc(this.lang);

  final ReportLang lang;

  bool get hi => lang == ReportLang.hi;
  bool get en => lang == ReportLang.en;
  bool get both => lang == ReportLang.both;

  /// The language a number-heavy sentence is written in when only one can be
  /// shown inline.
  String one(Bi b) => lang == ReportLang.en ? b.en : b.hi;

  /// Inline: "hi · en" when both, otherwise the one language.
  String pair(Bi b, {String sep = ' · '}) => switch (lang) {
    ReportLang.hi => b.hi,
    ReportLang.en => b.en,
    ReportLang.both =>
      '<span lang="hi">${b.hi}</span>$sep<span lang="en" class="sub">${b.en}</span>',
  };

  /// A table cell: Hindi over English when both.
  String stack(Bi b) => switch (lang) {
    ReportLang.hi => b.hi,
    ReportLang.en => b.en,
    ReportLang.both =>
      '<span lang="hi">${b.hi}</span><span lang="en" class="sub2">${b.en}</span>',
  };

  /// One paragraph per language shown.
  String para(Bi b, {String cls = ''}) {
    final String c = cls.isEmpty ? '' : ' $cls';
    return switch (lang) {
      ReportLang.hi => '<p lang="hi" class="hi$c">${b.hi}</p>',
      ReportLang.en => '<p lang="en" class="en$c">${b.en}</p>',
      ReportLang.both =>
        '<p lang="hi" class="hi$c">${b.hi}</p><p lang="en" class="en$c">${b.en}</p>',
    };
  }

  /// A heading's inner HTML: both languages in one heading, Hindi large and
  /// the English as its subtitle line.
  String head(Bi b) => switch (lang) {
    ReportLang.hi => b.hi,
    ReportLang.en => b.en,
    ReportLang.both =>
      '<span lang="hi">${b.hi}</span><span lang="en" class="h-en">${b.en}</span>',
  };

  /// Plain text for places HTML cannot go (the PDF header, document title).
  String plain(Bi b) => switch (lang) {
    ReportLang.hi => b.hi,
    ReportLang.en => b.en,
    ReportLang.both => '${b.hi} · ${b.en}',
  };
}

// --- Names ---------------------------------------------------------------

Bi gName(Graha g) => bi(grahaInfo(g).english, grahaInfo(g).hindi);

const List<String> _western = <String>[
  'Aries',
  'Taurus',
  'Gemini',
  'Cancer',
  'Leo',
  'Virgo',
  'Libra',
  'Scorpio',
  'Sagittarius',
  'Capricorn',
  'Aquarius',
  'Pisces',
];

String westernName(int signIndex) => _western[signIndex % 12];

/// The sign as the engine names it, with the Western name beside it in
/// English so a reader who knows only "Cancer" is not stranded.
Bi rName(int signIndex, {bool western = true}) {
  final RashiInfo info = rashiInfo(Rashi.values[signIndex % 12]);
  return bi(
    western ? '${info.english} (${westernName(signIndex)})' : info.english,
    info.hindi,
  );
}

/// Three letters, for tables with a column per divisional chart.
Bi rShort(int signIndex) => bi(
  _western[signIndex % 12].substring(0, 3),
  rashiInfo(Rashi.values[signIndex % 12]).hindi,
);

Bi nName(NakshatraInfo n) => bi(n.english, n.hindi);

// --- Ordinals ------------------------------------------------------------

String _enOrd(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

const List<String> _hiOrd = <String>[
  '',
  'पहला',
  'दूसरा',
  'तीसरा',
  'चौथा',
  'पाँचवाँ',
  'छठा',
  'सातवाँ',
  'आठवाँ',
  'नौवाँ',
  'दसवाँ',
  'ग्यारहवाँ',
  'बारहवाँ',
];

/// The form that sits before "में", "का" and "से": पहले, दूसरे, ...
const List<String> _hiOrdOblique = <String>[
  '',
  'पहले',
  'दूसरे',
  'तीसरे',
  'चौथे',
  'पाँचवें',
  'छठे',
  'सातवें',
  'आठवें',
  'नौवें',
  'दसवें',
  'ग्यारहवें',
  'बारहवें',
];

/// "7th house" / "सातवाँ भाव".
Bi houseDirect(int house) => bi('${_enOrd(house)} house', '${_hiOrd[house]} भाव');

/// "in the 7th house" / "सातवें भाव में".
Bi inHouse(int house) =>
    bi('in the ${_enOrd(house)} house', '${_hiOrdOblique[house]} भाव में');

/// "of the 7th house" / "सातवें भाव का".
Bi ofHouse(int house) =>
    bi('of the ${_enOrd(house)} house', '${_hiOrdOblique[house]} भाव का');

String enOrdinal(int n) => _enOrd(n);
String hiOrdinalOblique(int n) => _hiOrdOblique[n];
String hiOrdinal(int n) => _hiOrd[n];

// --- Dates and times -----------------------------------------------------

const List<String> _enMonths = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _hiMonths = <String>[
  'जनवरी',
  'फ़रवरी',
  'मार्च',
  'अप्रैल',
  'मई',
  'जून',
  'जुलाई',
  'अगस्त',
  'सितंबर',
  'अक्टूबर',
  'नवंबर',
  'दिसंबर',
];

const List<String> enWeekdays = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const List<String> hiWeekdays = <String>[
  'रविवार',
  'सोमवार',
  'मंगलवार',
  'बुधवार',
  'गुरुवार',
  'शुक्रवार',
  'शनिवार',
];

Bi weekdayName(int sundayZero) =>
    bi(enWeekdays[sundayZero % 7], hiWeekdays[sundayZero % 7]);

/// "15 August 1990" / "15 अगस्त 1990".
Bi dateBi(DateTime d, {bool short = false}) => bi(
  short
      ? '${d.day} ${_enMonths[d.month - 1].substring(0, 3)} ${d.year}'
      : '${d.day} ${_enMonths[d.month - 1]} ${d.year}',
  '${d.day} ${_hiMonths[d.month - 1]} ${d.year}',
);

/// Dates inside tables: the Hindi month name is up to eight letters wide, so
/// a bilingual table shows the English short form and nothing else.
String dateCell(Loc loc, DateTime d) {
  if (loc.hi) return dateBi(d).hi;
  return dateBi(d, short: true).en;
}

String _hiPeriodOfDay(int hour) {
  if (hour >= 4 && hour < 12) return 'सुबह';
  if (hour >= 12 && hour < 16) return 'दोपहर';
  if (hour >= 16 && hour < 20) return 'शाम';
  return 'रात';
}

Bi timeBi(DateTime t) {
  final int h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final String mm = t.minute.toString().padLeft(2, '0');
  final String suffix = t.hour < 12 ? 'AM' : 'PM';
  return bi('$h12:$mm $suffix', '${_hiPeriodOfDay(t.hour)} $h12:$mm');
}

String clock24(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// A span of days as years, months and days: "4 years 3 months 12 days".
Bi spanBi(double days) {
  int d = days.round();
  final int years = d ~/ 365;
  d -= years * 365;
  final int months = d ~/ 30;
  d -= months * 30;
  final List<String> en = <String>[];
  final List<String> hi = <String>[];
  if (years > 0) {
    en.add('$years ${years == 1 ? 'year' : 'years'}');
    hi.add('$years वर्ष');
  }
  if (months > 0) {
    en.add('$months ${months == 1 ? 'month' : 'months'}');
    hi.add('$months माह');
  }
  if (d > 0 || en.isEmpty) {
    en.add('$d ${d == 1 ? 'day' : 'days'}');
    hi.add('$d दिन');
  }
  return bi(en.join(' '), hi.join(' '));
}

/// A longitude as degrees, minutes and seconds inside its sign.
String dms(double degrees, {bool seconds = true}) {
  final double abs = degrees.abs();
  int d = abs.floor();
  double rest = (abs - d) * 60.0;
  int m = rest.floor();
  int s = ((rest - m) * 60.0).round();
  if (s >= 60) {
    s = 0;
    m += 1;
  }
  if (m >= 60) {
    m = 0;
    d += 1;
  }
  final String mm = m.toString().padLeft(2, '0');
  final String ss = s.toString().padLeft(2, '0');
  return seconds ? "$d°$mm'$ss\"" : "$d°$mm'";
}

/// Joins items as "a, b and c" / "a, b और c".
Bi joinBi(List<Bi> items) {
  if (items.isEmpty) return bi('', '');
  if (items.length == 1) return items.first;
  final List<Bi> head = items.sublist(0, items.length - 1);
  final Bi last = items.last;
  return bi(
    '${head.map((Bi b) => b.en).join(', ')} and ${last.en}',
    '${head.map((Bi b) => b.hi).join(', ')} और ${last.hi}',
  );
}
