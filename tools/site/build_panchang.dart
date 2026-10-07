/// Generates site/panchang/index.html: today's panchang for Delhi from the
/// app's own engine, the next seven days, and the festivals coming up.
///
///     dart run tools/site/build_panchang.dart            # today, in IST
///     dart run tools/site/build_panchang.dart --date=2026-10-07
///
/// This is the one generator that reads the clock, and it reads it once, to
/// pick the date. The date is the only thing that varies: the same date always
/// gives byte-identical output, and the page records only a date (never a
/// time) so a second run on the same day changes nothing and the daily
/// workflow has nothing to commit.
library;

import 'dart:io';

import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/astro/time.dart';
import 'package:kundlisaar/engine/jyotish/festivals.dart';
import 'package:kundlisaar/engine/jyotish/muhurta.dart';
import 'package:kundlisaar/engine/jyotish/panchang.dart';

import 'common.dart';
import 'glossary_hi.dart';

const String _path = 'panchang/index.html';

/// Delhi, the place the web page is computed for. India keeps one time zone
/// all year, so a fixed offset is exact.
const GeoPlace _delhi = GeoPlace(
  name: 'Delhi',
  latitude: 28.6139,
  longitude: 77.2090,
  timeZoneId: 'Asia/Kolkata',
);
const Duration _ist = Duration(hours: 5, minutes: 30);

/// "2026-10-07" parsed, or today in IST.
DateTime _pickDate(List<String> args) {
  for (final String arg in args) {
    if (arg.startsWith('--date=')) {
      final DateTime parsed = DateTime.parse(arg.substring('--date='.length));
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  final DateTime now = DateTime.now().toUtc().add(_ist);
  return DateTime(now.year, now.month, now.day);
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _dateEnglish(DateTime d, {bool year = true}) =>
    '${d.day} ${monthEnglish[d.month - 1]}${year ? ' ${d.year}' : ''}';

String _dateHindi(DateTime d, {bool year = true}) =>
    '${d.day} ${monthHindi[d.month - 1]}${year ? ' ${d.year}' : ''}';

/// Dart numbers Monday as 1 and Sunday as 7; the engine counts Sunday as 0.
int _weekdayIndex(DateTime d) => d.weekday % 7;

String _shortMonthEnglish(DateTime d) => monthEnglish[d.month - 1].substring(0, 3);

/// A clock time on [date], to the nearest minute, as "6:18 AM". A time that
/// falls on another calendar day carries that day, because a tithi that ends
/// at 2 AM is the next night's, not today's.
String _clock(double? jdUt, DateTime date, {required bool hindi}) {
  if (jdUt == null) return '—';
  final DateTime local = utcFromJulianDay(
    jdUt,
  ).add(_ist).add(const Duration(seconds: 30));
  final int hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final String text =
      '$hour12:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
  if (local.year == date.year &&
      local.month == date.month &&
      local.day == date.day) {
    return text;
  }
  return hindi
      ? '$text, ${local.day} ${monthHindi[local.month - 1]}'
      : '$text, ${local.day} ${_shortMonthEnglish(local)}';
}

String _range(TimeSpan? span, DateTime date, {required bool hindi}) => span ==
        null
    ? '—'
    : '${_clock(span.startJdUt, date, hindi: hindi)} – ${_clock(span.endJdUt, date, hindi: hindi)}';

/// Both scripts in one cell: English, then Hindi in its own language tag.
String _both(String english, String hindi) =>
    '${esc(english)} · <span lang="hi">${esc(hindi)}</span>';

String _stacked(String english, String hindi) =>
    '${esc(english)}<br><small lang="hi">${esc(hindi)}</small>';

String _tithiName(Panchang p, {required bool hindi}) => hindi
    ? '${p.tithi.nameHindi}, ${pakshaHindi(p.paksha)}'
    : '${p.tithi.name}, ${pakshaEnglish(p.paksha)}';

String _minutes(TimeSpan span) =>
    ((span.endJdUt - span.startJdUt) * 1440).round().toString();

String _quality(String slot, {required bool hindi}) {
  final int score = choghadiyaScore[slot] ?? 0;
  if (score >= 15) {
    return '<span class="pill good">${hindi ? 'शुभ' : 'Auspicious'}</span>';
  }
  if (score < 0) {
    return '<span class="pill bad">${hindi ? 'अशुभ' : 'Inauspicious'}</span>';
  }
  return '<span class="pill">${hindi ? 'सामान्य' : 'Moderate'}</span>';
}

String _choghadiyaTable(
  List<TimeSpan> slots,
  DateTime date, {
  required String captionEn,
  required String captionHi,
}) => tableHtml(
  caption: '$captionEn · $captionHi',
  headers: <String>[
    'Slot · चौघड़िया',
    'Time · समय',
    'Quality · गुण',
  ],
  rows: <List<String>>[
    for (final TimeSpan slot in slots)
      <String>[
        _both(slot.name, choghadiyaHindi(slot.name)),
        _range(slot, date, hindi: false),
        '${_quality(slot.name, hindi: false)} <span lang="hi">${_quality(slot.name, hindi: true)}</span>',
      ],
  ],
);

void main(List<String> args) {
  final DateTime date = _pickDate(args);
  final Directory site = siteDir();
  final List<PageRef> naks = nakshatraRefs();

  final Panchang today = computePanchang(
    localDate: date,
    utcOffset: _ist,
    place: _delhi,
  );
  check(today.sunrise != null && today.sunset != null, 'no sunrise or sunset');
  check(
    today.rahuKaal != null && today.abhijit != null,
    'no Rahu Kaal or Abhijit',
  );
  final List<Panchang> week = <Panchang>[
    for (int i = 1; i <= 7; i++)
      computePanchang(
        localDate: date.add(Duration(days: i)),
        utcOffset: _ist,
        place: _delhi,
      ),
  ];

  // Festivals: this year and next, so a page built in December still looks
  // ahead into January.
  final List<Festival> all = <Festival>[
    ...festivalsForYear(year: date.year, place: _delhi, utcOffset: _ist),
    ...festivalsForYear(year: date.year + 1, place: _delhi, utcOffset: _ist),
  ];
  final List<Festival> upcoming = all
      .where((Festival f) => !f.date.isBefore(date))
      .toList(growable: false);
  final List<Festival> majors = upcoming
      .where((Festival f) => f.isMajor)
      .take(10)
      .toList(growable: false);
  final DateTime horizon = date.add(const Duration(days: 30));
  final List<Festival> vrat = upcoming
      .where((Festival f) => !f.isMajor && !f.date.isAfter(horizon))
      .toList(growable: false);
  check(majors.isNotEmpty, 'no upcoming festivals found');

  // The lunar month the day sits in comes from the festival calendar's own
  // day table.
  final LunarDay lunarToday = lunarYear(
    year: date.year,
    place: _delhi,
    utcOffset: _ist,
  ).firstWhere(
    (LunarDay d) =>
        d.date.year == date.year &&
        d.date.month == date.month &&
        d.date.day == date.day,
  );

  final int weekday = today.weekday;
  final String weekdayEn = weekdayEnglish[weekday];
  final String weekdayHi = weekdayNamesHindi[weekday];
  final PageRef nakRef = naks[today.nakshatra.index];
  final String nakLinkEn = link(_path, nakRef.path, esc(today.nakshatra.name));
  final String nakLinkHi = link(
    _path,
    nakRef.path,
    esc(today.nakshatra.nameHindi),
    lang: 'hi',
  );

  // ---- Today's five limbs ----------------------------------------------
  final String limbs = tableHtml(
    headers: <String>[
      'Limb · अंग',
      'Name · नाम',
      'Ends · समाप्त',
    ],
    rows: <List<String>>[
      <String>[
        'Tithi · तिथि',
        _both(_tithiName(today, hindi: false), _tithiName(today, hindi: true)),
        _clock(today.tithi.endsAtJdUt, date, hindi: false),
      ],
      <String>[
        'Nakshatra · नक्षत्र',
        '$nakLinkEn · $nakLinkHi',
        _clock(today.nakshatra.endsAtJdUt, date, hindi: false),
      ],
      <String>[
        'Yoga · योग',
        _both(today.yoga.name, yogaHindi(today.yoga.name)),
        _clock(today.yoga.endsAtJdUt, date, hindi: false),
      ],
      <String>[
        'Karana · करण',
        _both(today.karana.name, karanaHindi(today.karana.name)),
        _clock(today.karana.endsAtJdUt, date, hindi: false),
      ],
      <String>[
        'Vara (weekday) · वार',
        _both('$weekdayEn (${weekdayNames[weekday]})', weekdayHi),
        '—',
      ],
      <String>[
        'Lunar month · चांद्र मास',
        _both(
          '${lunarToday.month} (amanta)',
          '${lunarMonthsHindi[lunarToday.monthIndex]} (अमांत)',
        ),
        '—',
      ],
    ],
  );

  // ---- Sun and Moon -----------------------------------------------------
  final int dayMinutes =
      ((today.sunset! - today.sunrise!) * 1440).round();
  final String sunMoon = tableHtml(
    headers: <String>['Event · घटना', 'Time · समय'],
    rows: <List<String>>[
      <String>[
        'Sunrise · सूर्योदय',
        _clock(today.sunrise, date, hindi: false),
      ],
      <String>[
        'Sunset · सूर्यास्त',
        _clock(today.sunset, date, hindi: false),
      ],
      <String>[
        'Length of the day · दिनमान',
        '${dayMinutes ~/ 60} h ${dayMinutes % 60} min · <span lang="hi">${dayMinutes ~/ 60} घंटे ${dayMinutes % 60} मिनट</span>',
      ],
      <String>[
        'Moonrise · चंद्रोदय',
        _clock(today.moonrise, date, hindi: false),
      ],
      <String>[
        'Moonset · चंद्रास्त',
        _clock(today.moonset, date, hindi: false),
      ],
    ],
  );

  // ---- Periods ------------------------------------------------------------
  String part(int n, {required bool hindi}) => hindi
      ? 'दिन के आठ बराबर भागों में ${ordinalsHindi[n - 1]}'
      : 'The ${ordinalEnglish(n)} of the eight equal parts of daylight';
  final String periods = tableHtml(
    headers: <String>['Period · काल', 'Time · समय', 'How it is found · कैसे निकलता है'],
    rows: <List<String>>[
      <String>[
        _both('Abhijit Muhurta', periodHindi('Abhijit')),
        _range(today.abhijit, date, hindi: false),
        'The middle muhurta of the day, ${_minutes(today.abhijit!)} minutes around solar noon · <span lang="hi">दिन का मध्य मुहूर्त, सौर मध्याह्न के आसपास ${_minutes(today.abhijit!)} मिनट</span>',
      ],
      <String>[
        _both('Rahu Kaal', periodHindi('Rahu Kaal')),
        _range(today.rahuKaal, date, hindi: false),
        '${part(rahuKaalPart[weekday], hindi: false)} on a $weekdayEn · <span lang="hi">$weekdayHi को ${part(rahuKaalPart[weekday], hindi: true)}</span>',
      ],
      <String>[
        _both('Yamaganda', periodHindi('Yamaganda')),
        _range(today.yamaganda, date, hindi: false),
        '${part(yamagandaPart[weekday], hindi: false)} on a $weekdayEn · <span lang="hi">$weekdayHi को ${part(yamagandaPart[weekday], hindi: true)}</span>',
      ],
      <String>[
        _both('Gulika Kaal', periodHindi('Gulika')),
        _range(today.gulika, date, hindi: false),
        '${part(gulikaPart[weekday], hindi: false)} on a $weekdayEn · <span lang="hi">$weekdayHi को ${part(gulikaPart[weekday], hindi: true)}</span>',
      ],
    ],
  );

  // ---- Next seven days ------------------------------------------------------
  final String weekTable = tableHtml(
    cssClass: 'tight',
    caption: 'The next seven days in Delhi · दिल्ली के अगले सात दिन',
    headers: <String>[
      'Date · दिनांक',
      'Vara · वार',
      'Tithi · तिथि',
      'Nakshatra · नक्षत्र',
      'Yoga · योग',
      'Karana · करण',
      'Sunrise · सूर्योदय',
      'Sunset · सूर्यास्त',
      'Rahu Kaal · राहु काल',
    ],
    rows: <List<String>>[
      for (final Panchang p in week)
        <String>[
          _stacked(_dateEnglish(p.date, year: false), _dateHindi(p.date, year: false)),
          _stacked(weekdayEnglish[p.weekday], weekdayNamesHindi[p.weekday]),
          _stacked('${p.tithi.name} (${p.paksha})', p.tithi.nameHindi),
          '${link(_path, naks[p.nakshatra.index].path, esc(p.nakshatra.name))}<br><small lang="hi">${esc(p.nakshatra.nameHindi)}</small>',
          _stacked(p.yoga.name, yogaHindi(p.yoga.name)),
          _stacked(p.karana.name, karanaHindi(p.karana.name)),
          _clock(p.sunrise, p.date, hindi: false),
          _clock(p.sunset, p.date, hindi: false),
          _range(p.rahuKaal, p.date, hindi: false),
        ],
    ],
  );

  // ---- Festivals --------------------------------------------------------------
  List<String> festivalRow(Festival f) => <String>[
    _stacked(
      '${_dateEnglish(f.date, year: f.date.year != date.year)}, ${weekdayEnglish[_weekdayIndex(f.date)]}',
      '${_dateHindi(f.date, year: f.date.year != date.year)}, ${weekdayNamesHindi[_weekdayIndex(f.date)]}',
    ),
    '<strong>${esc(f.english)}</strong><br><small lang="hi">${esc(f.hindi)}</small>',
    '${esc(f.detail)}<br><small lang="hi">${esc(f.detailHindi)}</small>',
  ];
  final List<String> festivalHeaders = <String>[
    'Date · दिनांक',
    'Festival · पर्व',
    'Tithi and month · तिथि और मास',
  ];
  final String majorTable = tableHtml(
    caption: 'Festivals ahead · आगामी पर्व',
    headers: festivalHeaders,
    rows: <List<String>>[for (final Festival f in majors) festivalRow(f)],
  );
  final String vratTable = vrat.isEmpty
      ? ''
      : tableHtml(
          caption: 'Vrat and moon days in the next 30 days · अगले 30 दिनों के व्रत और चंद्र-दिवस',
          headers: festivalHeaders,
          rows: <List<String>>[for (final Festival f in vrat) festivalRow(f)],
        );

  // ---- Prose --------------------------------------------------------------------
  final String dateEn = _dateEnglish(date);
  final String dateHi = _dateHindi(date);
  const String howEn = '''
    <p class="prose">A panchang has five limbs. The <strong>tithi</strong> is the Moon’s phase, counted in thirty steps of 12° between the Moon and the Sun. The <strong>nakshatra</strong> is the lunar mansion the Moon is crossing. The <strong>yoga</strong> counts the combined longitude of Sun and Moon in steps of 13°20′. The <strong>karana</strong> is half a tithi, 6° of the Moon’s lead over the Sun, and the <strong>vara</strong> is the weekday. The names shown are the ones running at sunrise, which is how a panchang names a day, and each is followed by the time it ends, after which the next begins. Tithis vary in length, so one can begin and end inside a single day.</p>
    <p class="prose">Times are for Delhi in Indian Standard Time, with sunrise and sunset taken when the upper edge of the Sun meets a horizon corrected for refraction. For another town every time shifts by minutes, and the KundliSaar app computes the panchang for any date and any place. Festival dates follow the tithi at the moment each rule asks for, whether sunrise, midday, dusk or midnight. Where authorities pick the day differently a printed panchang can differ by a day, so check it for an observance that matters to you.</p>
''';
  const String howHi = '''
    <p class="prose">पंचांग के पाँच अंग हैं। <strong>तिथि</strong> चंद्रमा की कला है, जो चंद्र और सूर्य के बीच 12° के तीस चरणों में गिनी जाती है। <strong>नक्षत्र</strong> वह चंद्र-भवन है जिसे चंद्रमा पार कर रहा है। <strong>योग</strong> सूर्य और चंद्र के जोड़े गए देशांतर को 13°20′ के चरणों में गिनता है। <strong>करण</strong> आधी तिथि है, यानी सूर्य से चंद्रमा की 6° की बढ़त, और <strong>वार</strong> सप्ताह का दिन है। यहाँ वे नाम दिए हैं जो सूर्योदय पर चल रहे होते हैं, क्योंकि पंचांग इसी तरह दिन का नाम तय करता है, और हर नाम के आगे वह समय है जब वह समाप्त होता है और अगला शुरू होता है। तिथियों की अवधि घटती-बढ़ती है, इसलिए एक तिथि एक ही दिन के भीतर शुरू और समाप्त हो सकती है।</p>
    <p class="prose">समय दिल्ली के हैं, भारतीय मानक समय में; सूर्योदय और सूर्यास्त तब लिए गए हैं जब सूर्य का ऊपरी किनारा वायुमंडलीय अपवर्तन से सुधारे गए क्षितिज को छूता है। किसी दूसरे शहर में हर समय कुछ मिनट खिसक जाता है; कुंडलीसार ऐप किसी भी तारीख़ और किसी भी स्थान का पंचांग निकालता है। पर्वों की तिथि उस क्षण की तिथि से तय होती है जो हर नियम माँगता है, चाहे वह सूर्योदय हो, मध्याह्न, संध्या या मध्यरात्रि। जहाँ विद्वान दिन अलग चुनते हैं, वहाँ छपा पंचांग एक दिन भिन्न हो सकता है, इसलिए जो पर्व आपके लिए महत्त्व रखता हो, उसे अपने पंचांग से मिला लें।</p>
''';

  final String body =
      '''
  <section id="today">
    <h2>Today’s five limbs · आज के पंचांग के पाँच अंग</h2>
$limbs  </section>

  <section id="sun-moon">
    <h2>Sun and Moon · सूर्य और चंद्र</h2>
$sunMoon  </section>

  <section id="periods">
    <h2>Auspicious and inauspicious periods · शुभ और अशुभ काल</h2>
$periods  </section>

  <section id="choghadiya">
    <h2>Choghadiya · चौघड़िया</h2>
    <p class="note">The day from sunrise to sunset and the night from sunset to the next sunrise are each cut into eight equal slots. The quality is the one the app’s muhurta finder scores them by. · दिन (सूर्योदय से सूर्यास्त) और रात (सूर्यास्त से अगले सूर्योदय) को आठ-आठ बराबर खंडों में बाँटा गया है। गुण वही है जिससे ऐप का मुहूर्त खोजक इन्हें आँकता है।</p>
${_choghadiyaTable(today.dayChoghadiya, date, captionEn: 'Day choghadiya', captionHi: 'दिन की चौघड़िया')}${_choghadiyaTable(today.nightChoghadiya, date, captionEn: 'Night choghadiya', captionHi: 'रात की चौघड़िया')}  </section>

  <section id="week">
    <h2>The next seven days · अगले सात दिन</h2>
$weekTable  </section>

  <section id="festivals">
    <h2>Festivals and vrat ahead · आगामी पर्व और व्रत</h2>
$majorTable$vratTable    <p class="note">Computed from the tithi at the moment each observance’s rule asks for; a printed panchang may choose a different day. · हर पर्व के नियम द्वारा माँगे गए क्षण की तिथि से गणना; छपा पंचांग भिन्न दिन चुन सकता है।</p>
  </section>

  <section id="english" lang="en">
    <h2>How to read this panchang</h2>
$howEn${ctaBlock(from: _path, heading: (en: 'A panchang for your own town', hi: ''), body: (en: 'Pick any date and any place in KundliSaar and get the same panchang, with choghadiya and horas. It runs on your device, is free, and needs no account.', hi: ''), button: (en: 'Open the app', hi: ''), hindi: false)}  </section>

  <section id="hindi" lang="hi">
    <h2>इस पंचांग को कैसे पढ़ें</h2>
$howHi${ctaBlock(from: _path, heading: (en: '', hi: 'अपने शहर का पंचांग'), body: (en: '', hi: 'कुंडलीसार में कोई भी तारीख़ और कोई भी स्थान चुनें और वही पंचांग पाएँ, चौघड़िया और होरा के साथ। यह आपके फ़ोन पर चलता है, मुफ़्त है और खाता नहीं माँगता।'), button: (en: '', hi: 'ऐप खोलें'), hindi: true)}  </section>
''';
  checkText(_path, body);

  // ---- Page ----------------------------------------------------------------------
  final String title =
      'Panchang for $dateEn, Delhi: Tithi, Nakshatra, Rahu Kaal, Choghadiya (आज का पंचांग)';
  final String description =
      'Panchang for Delhi, $weekdayEn $dateEn: ${today.tithi.name} (${today.paksha} paksha) tithi until ${_clock(today.tithi.endsAtJdUt, date, hindi: false)}, ${today.nakshatra.name} nakshatra, ${today.yoga.name} yoga, Rahu Kaal ${_range(today.rahuKaal, date, hindi: false)}. आज का पंचांग, $dateHi: ${today.tithi.nameHindi} तिथि, ${today.nakshatra.nameHindi} नक्षत्र, राहु काल।';
  final List<Crumb> crumbs = <Crumb>[
    const Crumb('KundliSaar', ''),
    const Crumb('Panchang', 'panchang/'),
  ];
  final String iso = _isoDate(date);
  final String html = renderPage(
    PageSpec(
      path: _path,
      title: title,
      description: description,
      ogType: 'website',
      heading:
          'Today’s Panchang, Delhi <span class="h1-hi" lang="hi">· दिल्ली का आज का पंचांग</span>',
      lede:
          '$weekdayEn, $dateEn · <span lang="hi">$weekdayHi, $dateHi</span><br><span class="stamp">Generated for $dateEn (IST) from the KundliSaar engine · <span lang="hi">$dateHi (भारतीय समय) के लिए बनाया गया</span></span>',
      body: body,
      crumbs: crumbs,
      extraHead: '<meta name="kundlisaar:generated" content="$iso">',
      jsonLd: <Map<String, Object?>>[
        <String, Object?>{
          '@type': 'WebPage',
          'name': 'Panchang for Delhi, $dateEn',
          'description': description,
          'url': '$siteBase$_path',
          'inLanguage': <String>['en', 'hi'],
          'datePublished': referenceUpdated,
          'dateModified': iso,
          'publisher': publisherLd,
          'about': 'Hindu panchang: tithi, nakshatra, yoga, karana and vara',
          'spatialCoverage': <String, Object?>{
            '@type': 'Place',
            'name': 'Delhi, India',
            'geo': <String, Object?>{
              '@type': 'GeoCoordinates',
              'latitude': _delhi.latitude,
              'longitude': _delhi.longitude,
            },
          },
          'mainEntity': <String, Object?>{
            '@type': 'ItemList',
            'name': 'Upcoming festivals',
            'itemListElement': <Object?>[
              for (int i = 0; i < majors.length; i++)
                <String, Object?>{
                  '@type': 'ListItem',
                  'position': i + 1,
                  'name':
                      '${majors[i].english} (${majors[i].hindi}): ${_dateEnglish(majors[i].date)}',
                },
            ],
          },
        },
        breadcrumbLd(crumbs, '$siteBase$_path'),
      ],
    ),
  );
  checkText(_path, html);
  finishOrFail();

  final bool wrote = writeIfChanged(File('${site.path}/$_path'), html);
  // The sitemap carries this page's date as its lastmod, so it moves with it.
  final bool sitemap = writeSitemap(site, panchangDate: iso);
  stdout.writeln(
    'Panchang for $iso (Delhi): page ${wrote ? 'written' : 'unchanged'}, '
    'sitemap ${sitemap ? 'updated' : 'unchanged'}, '
    '${wordCount(plainText(html.substring(html.indexOf('<body>'))))} visible words, '
    '${majors.length} festivals and ${vrat.length} vrat days listed.',
  );
}
