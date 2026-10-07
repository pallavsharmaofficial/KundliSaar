import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/engine/astro/angles.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/astro/time.dart';
import 'package:kundlisaar/engine/jyotish/nakshatra.dart';
import 'package:kundlisaar/engine/jyotish/panchang.dart';
import 'package:kundlisaar/engine/jyotish/panchang_calendar.dart';
import 'package:kundlisaar/engine/jyotish/panchang_details.dart';
import 'package:kundlisaar/engine/jyotish/panchang_tables.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';

const GeoPlace delhi = GeoPlace(
  name: 'New Delhi',
  latitude: 28.6139,
  longitude: 77.2090,
  timeZoneId: 'Asia/Kolkata',
);

const GeoPlace singapore = GeoPlace(
  name: 'Singapore',
  latitude: 1.3521,
  longitude: 103.8198,
  timeZoneId: 'Asia/Singapore',
);

const Duration ist = Duration(hours: 5, minutes: 30);

final Map<String, PanchangDetails> _cache = <String, PanchangDetails>{};

PanchangDetails detailsFor(
  int year,
  int month,
  int day, {
  GeoPlace place = delhi,
  Duration offset = ist,
}) => _cache.putIfAbsent(
  '$year-$month-$day-${place.name}',
  () => computePanchangDetails(
    computePanchang(
      localDate: DateTime(year, month, day),
      utcOffset: offset,
      place: place,
    ),
  ),
);

/// A wall-clock time in India as a Julian day.
double ist_(int y, int mo, int d, int h, int mi) =>
    Instant.fromLocal(DateTime(y, mo, d, h, mi), ist).julianDayUt;

double minutes(double a, double b) => (a - b).abs() * 1440;

final RegExp devanagari = RegExp(r'[ऀ-ॿ]');

double moonAt(double jdUt, {Ayanamsa ay = Ayanamsa.lahiri}) =>
    siderealLongitudeAt(Graha.moon, Instant.fromJulianDayUt(jdUt), ay);

void expectBothLanguages(String english, String hindi, String what) {
  expect(english.trim(), isNotEmpty, reason: '$what: English is empty');
  expect(hindi.trim(), isNotEmpty, reason: '$what: Hindi is empty');
  expect(
    devanagari.hasMatch(hindi),
    isTrue,
    reason: '$what: "$hindi" holds no Devanagari',
  );
}

void main() {
  group('the frame the panchang reads', () {
    test('the Sun stands at 180 degrees at the 2026 September equinox', () {
      // 23 September 2026, 00:05 UT, from DE440s through skyfield. positionOf
      // once stood 0.37 degrees east of this; the panchang must never.
      final Instant equinox = Instant.fromUtc(DateTime.utc(2026, 9, 23, 0, 5));
      expect(
        angleDiff(longitudeOfDate(Graha.sun, equinox), 180.0).abs(),
        lessThan(0.01),
      );
    });

    test('the weekday follows the civil date east of Greenwich too', () {
      // Sunrise in Singapore falls on the previous UT date.
      final Panchang p = computePanchang(
        localDate: DateTime(2026, 10, 7),
        utcOffset: const Duration(hours: 8),
        place: singapore,
      );
      expect(p.weekday, 3, reason: '7 October 2026 is a Wednesday');
    });
  });

  group('Delhi, 7 October 2026, against Drik Panchang', () {
    final PanchangDetails d = detailsFor(2026, 10, 7);

    test('the limbs and the Moon boundaries', () {
      expect(d.panchang.tithi.name, 'Dwadashi');
      expect(
        minutes(d.panchang.tithi.endsAtJdUt, ist_(2026, 10, 7, 23, 16)),
        lessThan(3),
      );
      expect(d.panchang.nakshatra.name, 'Magha');
      // Drik: Magha until 21:40. The boundary is the Moon's own, so it has no
      // sunrise in it and has to be right to the minute.
      expect(
        minutes(d.panchang.nakshatra.endsAtJdUt, ist_(2026, 10, 7, 21, 40)),
        lessThan(2),
      );
      expect(d.panchang.yoga.name, 'Shubha');
      expect(
        minutes(d.panchang.yoga.endsAtJdUt, ist_(2026, 10, 8, 2, 52)),
        lessThan(3),
      );
    });

    test('Gand Mool, Vidaal and the Anandadi change at the same moment', () {
      final double magha = ist_(2026, 10, 7, 21, 40);
      final PanchangWindow gandMool = d.gandMool.single;
      expect(gandMool.label, 'Magha');
      expect(minutes(gandMool.endJdUt, magha), lessThan(2));
      // The window opens when Ashlesha ends, the evening before.
      expect(gandMool.startJdUt, lessThan(d.dayStartJdUt));
      expect(d.vidaal.single.note.key, 'vidaal');
      expect(minutes(d.vidaal.single.startJdUt, magha), lessThan(2));
      expect(d.aadal, isEmpty);
      expect(d.anandadi.map((AnandadiSpan a) => a.info.name), <String>[
        'Chara',
        'Sthira',
      ]);
      expect(minutes(d.anandadi.first.endJdUt, magha), lessThan(2));
      expect(d.panchak, isNull);
      expect(d.bhadra, isEmpty);
      expect(d.vinchhudo, isNull);
    });

    test('the Moon is in Simha all day, and the Chandrabalam list matches', () {
      expect(d.moonSegments.every((MoonSegment s) => s.rashi == 4), isTrue);
      final List<String> good = chandraBalaFavourableRashis(
        4,
      ).map((int r) => rashiTable[r].english).toList();
      expect(
        good,
        unorderedEquals(<String>[
          'Mithuna',
          'Simha',
          'Tula',
          'Vrischika',
          'Kumbha',
          'Meena',
        ]),
      );
    });

    test('calendar context', () {
      final PanchangCalendar c = d.calendar;
      expect(c.vikramSamvat, 2083);
      expect(c.shakaSamvat, 1948);
      expect(c.kaliSamvat, 5127);
      expect(c.kaliAhargana, 1872855);
      expect(c.samvatsara.name, 'Parabhava');
      expect(c.amanta.name, 'Bhadrapada');
      expect(c.purnimanta.name, 'Ashwin');
      expect(c.vedicRitu.nameHindi, 'वर्षा');
      expect(c.drikRitu.nameHindi, 'शरद');
      expect(c.vedicAyana.nameHindi, 'दक्षिणायन');
      expect(c.drikAyana.nameHindi, 'दक्षिणायन');
      expect(c.nirayanaSun.name, 'Kanya');
      expect(c.sayanaSun.name, 'Tula');
      expect(d.dishaShool.direction, 'North');
    });
  });

  group('Sarvartha Siddhi, October 2026, against the Drik windows', () {
    // Drik Panchang, New Delhi. A window ends at the next sunrise when the
    // nakshatra runs on, because the vara changes there.
    final Map<int, List<double>> drik = <int, List<double>>{
      4: <double>[ist_(2026, 10, 5, 0, 13), ist_(2026, 10, 5, 6, 16)],
      5: <double>[ist_(2026, 10, 5, 6, 16), ist_(2026, 10, 5, 23, 9)],
      6: <double>[ist_(2026, 10, 6, 6, 17), ist_(2026, 10, 6, 22, 17)],
      14: <double>[ist_(2026, 10, 14, 6, 21), ist_(2026, 10, 15, 4, 3)],
      18: <double>[ist_(2026, 10, 18, 12, 49), ist_(2026, 10, 19, 6, 24)],
      19: <double>[ist_(2026, 10, 19, 15, 38), ist_(2026, 10, 20, 6, 25)],
      25: <double>[ist_(2026, 10, 25, 19, 22), ist_(2026, 10, 26, 6, 29)],
      27: <double>[ist_(2026, 10, 27, 15, 39), ist_(2026, 10, 28, 6, 30)],
      28: <double>[ist_(2026, 10, 28, 6, 30), ist_(2026, 10, 29, 6, 31)],
    };

    test('the same days, and the same hours to the minute or two', () {
      final Set<int> found = <int>{};
      for (int day = 1; day <= 31; day++) {
        final PanchangDetails d = detailsFor(2026, 10, day);
        final List<PanchangWindow> windows = d.auspicious
            .where((PanchangWindow w) => w.key == 'sarvartha_siddhi')
            .toList();
        if (windows.isEmpty) continue;
        found.add(day);
        expect(windows.length, 1, reason: '1 October + $day');
        final List<double>? expected = drik[day];
        if (expected == null) continue;
        // Ends at a sunrise are given four minutes: the sunrise itself comes
        // from rise_set.dart, which moves with the astro layer.
        expect(
          minutes(windows.single.startJdUt, expected[0]),
          lessThan(4),
          reason: 'start on 2026-10-$day',
        );
        expect(
          minutes(windows.single.endJdUt, expected[1]),
          lessThan(4),
          reason: 'end on 2026-10-$day',
        );
      }
      expect(found, drik.keys.toSet());
    });
  });

  group('Panchak', () {
    test('fires on exactly the five nakshatras', () {
      expect(panchakNakshatras, <int>[22, 23, 24, 25, 26]);
      expect(
        panchakNakshatras.map((int n) => nakshatraTable[n].english),
        <String>[
          'Dhanishta',
          'Shatabhisha',
          'Purva Bhadrapada',
          'Uttara Bhadrapada',
          'Revati',
        ],
      );
      // Walk the whole zodiac: the Moon is in Panchak for 300 to 360 degrees
      // and for no other longitude, which is the second half of Dhanishta
      // through Revati.
      for (double lon = 0; lon < 360; lon += 0.25) {
        final bool inPanchak = lon >= panchakStartDegree;
        if (inPanchak) {
          expect(
            panchakNakshatras.contains(nakshatraIndexOf(lon)),
            isTrue,
            reason: 'longitude $lon',
          );
        }
        if (!panchakNakshatras.contains(nakshatraIndexOf(lon))) {
          expect(inPanchak, isFalse, reason: 'longitude $lon');
        }
      }
      // The first half of Dhanishta is in Makara and not Panchak.
      expect(nakshatraIndexOf(295), 22);
      expect(295 >= panchakStartDegree, isFalse);
    });

    test('a day has a Panchak exactly when the Moon is in those stars', () {
      int withPanchak = 0;
      for (int day = 0; day < 60; day++) {
        final DateTime date = DateTime(2026, 9, 1).add(Duration(days: day));
        final PanchangDetails d = detailsFor(date.year, date.month, date.day);
        final double atStart = moonAt(d.dayStartJdUt);
        final double atEnd = moonAt(d.dayEndJdUt);
        final PanchangWindow? w = d.panchak;
        if (w == null) {
          expect(atStart >= 300, isFalse, reason: 'sunrise on $date');
          expect(atEnd >= 300, isFalse, reason: 'next sunrise on $date');
          continue;
        }
        withPanchak++;
        expect(w.startJdUt, lessThan(w.endJdUt));
        // It begins at the Moon's entry into Kumbha and ends at the exit
        // from Meena.
        expect(angleDiff(moonAt(w.startJdUt), 300).abs(), lessThan(0.001));
        expect(angleDiff(moonAt(w.endJdUt), 0).abs(), lessThan(0.001));
        // Inside, the Moon is only ever in the five nakshatras...
        for (final double f in <double>[0.0, 0.25, 0.5, 0.75, 1.0]) {
          final double jd =
              w.startJdUt + 0.0007 + f * (w.endJdUt - w.startJdUt - 0.0014);
          expect(
            panchakNakshatras.contains(nakshatraIndexOf(moonAt(jd))),
            isTrue,
            reason: 'inside the window on $date',
          );
        }
        // ...and a few minutes either side of it, never in Panchak.
        expect(moonAt(w.startJdUt - 0.003) >= 300, isFalse);
        expect(moonAt(w.endJdUt + 0.003) >= 300, isFalse);
      }
      // Some days of September and October 2026 carry one.
      expect(withPanchak, greaterThan(5));
      expect(withPanchak, lessThan(20));
    });

    test(
      'begins and ends where the printed lists say, and is typed by day',
      () {
        // (date to ask for, start, end, kind) from Drik-grade New Delhi lists.
        final List<(DateTime, double, double, String)> printed =
            <(DateTime, double, double, String)>[
              (
                DateTime(2026, 2, 17),
                ist_(2026, 2, 17, 9, 5),
                ist_(2026, 2, 21, 19, 7),
                'agni',
              ),
              (
                DateTime(2026, 3, 17),
                ist_(2026, 3, 16, 18, 14),
                ist_(2026, 3, 21, 2, 27),
                'raja',
              ),
              (
                DateTime(2026, 5, 11),
                ist_(2026, 5, 10, 12, 12),
                ist_(2026, 5, 14, 22, 34),
                'roga',
              ),
              (
                DateTime(2026, 6, 7),
                ist_(2026, 6, 6, 19, 3),
                ist_(2026, 6, 11, 8, 16),
                'mrityu',
              ),
              (
                DateTime(2026, 7, 4),
                ist_(2026, 7, 4, 0, 48),
                ist_(2026, 7, 8, 16, 0),
                'mrityu',
              ),
              (
                DateTime(2026, 7, 31),
                ist_(2026, 7, 31, 6, 38),
                ist_(2026, 8, 4, 21, 54),
                'chora',
              ),
              (
                DateTime(2026, 9, 24),
                ist_(2026, 9, 23, 21, 56),
                ist_(2026, 9, 28, 10, 15),
                'madhyam',
              ),
              (
                DateTime(2026, 11, 18),
                ist_(2026, 11, 17, 15, 30),
                ist_(2026, 11, 22, 5, 54),
                'agni',
              ),
            ];
        for (final (DateTime date, double start, double end, String kind)
            in printed) {
          final PanchangWindow? w = detailsFor(
            date.year,
            date.month,
            date.day,
          ).panchak;
          expect(w, isNotNull, reason: '$date');
          expect(
            minutes(w!.startJdUt, start),
            lessThan(3),
            reason: 'start $date',
          );
          expect(minutes(w.endJdUt, end), lessThan(3), reason: 'end $date');
          expect(
            w.label,
            panchakKinds.firstWhere((PanchakKind k) => k.key == kind).name,
          );
        }
      },
    );

    test('the kind follows the weekday it begins on', () {
      expect(panchakKinds.map((PanchakKind k) => k.key), <String>[
        'roga',
        'raja',
        'agni',
        'madhyam',
        'madhyam',
        'chora',
        'mrityu',
      ]);
    });
  });

  group('Bhadra', () {
    test(
      'is the Vishti karana: six degrees of elongation, 8 times a month',
      () {
        expect(
          <int>[
            for (int k = 0; k < 60; k++)
              if (isVishtiKarana(k)) k,
          ],
          <int>[7, 14, 21, 28, 35, 42, 49, 56],
        );
        int seen = 0;
        for (int day = 0; day < 40; day++) {
          final DateTime date = DateTime(2026, 10, 1).add(Duration(days: day));
          final PanchangDetails d = detailsFor(date.year, date.month, date.day);
          for (final PanchangWindow w in d.bhadra) {
            seen++;
            final double e0 = lunarElongationAt(
              Instant.fromJulianDayUt(w.startJdUt + 1e-5),
            );
            final double e1 = lunarElongationAt(
              Instant.fromJulianDayUt(w.endJdUt - 1e-5),
            );
            expect(
              <double>[
                42,
                84,
                126,
                168,
                210,
                252,
                294,
                336,
              ].any((double s) => (e0 - s).abs() < 0.01),
              isTrue,
              reason: 'starts at $e0',
            );
            expect((norm360(e1 - e0) - 6).abs(), lessThan(0.01));
            expect(w.parts, isNotEmpty);
          }
        }
        expect(seen, greaterThanOrEqualTo(10));
      },
    );

    test(
      'dwells on earth when the Moon is in Karka, Simha, Kumbha or Meena',
      () {
        for (int rashi = 0; rashi < 12; rashi++) {
          final bool earth = <int>[3, 4, 10, 11].contains(rashi);
          expect(bhadraLokaBySign[rashi] == BhadraLoka.prithvi, earth);
        }
      },
    );
  });

  group('Gand Mool', () {
    test('is the six junction nakshatras and only those', () {
      expect(
        gandMoolNakshatras.map((int n) => nakshatraTable[n].english),
        <String>['Ashwini', 'Ashlesha', 'Magha', 'Jyeshtha', 'Mula', 'Revati'],
      );
      // They are the stars that begin or end at the junction of a water sign
      // and a fire sign: 0, 120 and 240 degrees.
      bool atJunction(int n) {
        final double start = n * nakshatraSpan;
        final double end = (n + 1) * nakshatraSpan;
        bool onJunction(double x) {
          final double m = x % 120.0;
          return m < 1e-9 || (120.0 - m) < 1e-9;
        }

        return onJunction(start) || onJunction(end);
      }

      expect(<int>[
        for (int n = 0; n < 27; n++)
          if (atJunction(n)) n,
      ], gandMoolNakshatras);
    });

    test('every window holds one of them and carries the remedy', () {
      int seen = 0;
      for (int day = 0; day < 40; day++) {
        final DateTime date = DateTime(2026, 10, 1).add(Duration(days: day));
        for (final PanchangWindow w in detailsFor(
          date.year,
          date.month,
          date.day,
        ).gandMool) {
          seen++;
          final int nak = nakshatraIndexOf(
            moonAt((w.startJdUt + w.endJdUt) / 2),
          );
          expect(gandMoolNakshatras, contains(nak));
          expect(w.label, nakshatraTable[nak].english);
          expect(w.meaning, contains('Mool Shanti'));
          expect(w.meaningHindi, contains('मूल शांति'));
        }
      }
      expect(seen, greaterThanOrEqualTo(6));
    });
  });

  group('Vinchhudo', () {
    test('runs while the Moon is in Vrishchika, as Drik prints it', () {
      final PanchangWindow jan = detailsFor(2026, 1, 14).vinchhudo!;
      expect(minutes(jan.startJdUt, ist_(2026, 1, 13, 17, 21)), lessThan(3));
      expect(minutes(jan.endJdUt, ist_(2026, 1, 16, 5, 47)), lessThan(3));
      final PanchangWindow oct = detailsFor(2026, 10, 15).vinchhudo!;
      expect(minutes(oct.startJdUt, ist_(2026, 10, 13, 19, 12)), lessThan(3));
      expect(minutes(oct.endJdUt, ist_(2026, 10, 16, 6, 47)), lessThan(3));
      expect(angleDiff(moonAt(jan.startJdUt), 210).abs(), lessThan(0.001));
      expect(angleDiff(moonAt(jan.endJdUt), 240).abs(), lessThan(0.001));
      expect(detailsFor(2026, 10, 7).vinchhudo, isNull);
    });
  });

  group('the yoga tables', () {
    test('Amrit Siddhi is always one of that weekday\'s Sarvartha Siddhi', () {
      for (int wd = 0; wd < 7; wd++) {
        expect(
          sarvarthaSiddhiNakshatras[wd],
          contains(amritSiddhiNakshatra[wd]),
          reason: weekdayNames[wd],
        );
      }
      expect(sarvarthaSiddhiNakshatras.map((List<int> l) => l.length), <int>[
        7,
        5,
        4,
        5,
        5,
        5,
        3,
      ]);
    });

    test(
      'Dwipushkar and Tripushkar stars are the two-two and three-one splits',
      () {
        // A nakshatra that straddles a sign puts its four padas in two signs.
        // Two and two is dwipada, three and one is tripada; the names come from
        // that, and it fixes the lists independently of any printed table.
        final List<int> two = <int>[];
        final List<int> three = <int>[];
        for (int n = 0; n < 27; n++) {
          final Map<int, int> padas = <int, int>{};
          for (int p = 1; p <= 4; p++) {
            padas.update(
              rashiOfNakshatraPada(n, p),
              (int c) => c + 1,
              ifAbsent: () => 1,
            );
          }
          final List<int> sizes = padas.values.toList()..sort();
          if (sizes.length == 2 && sizes[0] == 2) two.add(n);
          if (sizes.length == 2 && sizes[0] == 1) three.add(n);
        }
        expect(dwipushkarNakshatras, two);
        expect(tripushkarNakshatras, three);
        expect(pushkarTithis, <int>[2, 7, 12]);
        expect(pushkarWeekdays, <int>[0, 2, 6]);
      },
    );

    test('Tripushkar falls where the published lists say', () {
      // Prokerala's 2026 list: Punarvasu on Sunday 4 January, Krittika on
      // Tuesday 24 February, Uttara Phalguni on Tuesday 28 April.
      for (final (int m, int d, String nak) in <(int, int, String)>[
        (1, 4, 'Punarvasu'),
        (2, 24, 'Krittika'),
        (4, 28, 'Uttara Phalguni'),
      ]) {
        final List<PanchangWindow> w = detailsFor(2026, m, d).auspicious
            .where((PanchangWindow w) => w.key == 'tripushkar')
            .toList();
        expect(w, isNotEmpty, reason: '2026-$m-$d');
        expect(w.single.label, contains(nak));
      }
    });

    test('Ravi Pushya and Guru Pushya need Pushya on Sunday and Thursday', () {
      // Pushya at sunrise on these days (from the panchang itself): Sundays
      // 4 January, 1 February, 1 March, 1 November 2026; Thursdays 21 May and
      // 18 June 2026.
      PanchangWindow? pushya(int y, int m, int d, String key) {
        final PanchangDetails det = detailsFor(y, m, d);
        final Iterable<PanchangWindow> found = det.auspicious.where(
          (PanchangWindow w) => w.key == key,
        );
        return found.isEmpty ? null : found.single;
      }

      for (final (int m, int d) in <(int, int)>[
        (1, 4),
        (2, 1),
        (3, 1),
        (11, 1),
      ]) {
        final PanchangWindow? w = pushya(2026, m, d, 'ravi_pushya');
        expect(w, isNotNull, reason: '2026-$m-$d');
        expect(
          nakshatraIndexOf(moonAt((w!.startJdUt + w.endJdUt) / 2)),
          pushyaNakshatra,
        );
        expect(pushya(2026, m, d, 'guru_pushya'), isNull);
      }
      for (final (int m, int d) in <(int, int)>[(5, 21), (6, 18)]) {
        expect(
          pushya(2026, m, d, 'guru_pushya'),
          isNotNull,
          reason: '2026-$m-$d',
        );
        expect(pushya(2026, m, d, 'ravi_pushya'), isNull);
      }
      // Monday 5 October: Pushya, but not on a Sunday or a Thursday.
      expect(pushya(2026, 10, 5, 'ravi_pushya'), isNull);
      expect(pushya(2026, 10, 5, 'guru_pushya'), isNull);
      expect(pushya(2026, 10, 5, 'sarvartha_siddhi'), isNotNull);
    });

    test('Jwalamukhi pairs the five tithis with their nakshatras', () {
      expect(
        jwalamukhiPairs.map(
          (int t, int n) => MapEntry<String, String>(
            tithiNames[t - 1],
            nakshatraTable[n].english,
          ),
        ),
        <String, String>{
          'Pratipada': 'Mula',
          'Panchami': 'Bharani',
          'Ashtami': 'Krittika',
          'Navami': 'Rohini',
          'Dashami': 'Ashlesha',
        },
      );
      // 24 February 2026 had Ashtami with Krittika until 15:06.
      final PanchangWindow w = detailsFor(2026, 2, 24).jwalamukhi.first;
      expect(w.label, 'Ashtami with Krittika');
      expect(minutes(w.endJdUt, ist_(2026, 2, 24, 15, 6)), lessThan(3));
    });

    test('Ravi, Aadal and Vidaal are counted from the Sun\'s nakshatra', () {
      expect(raviYogaCounts, <int>[4, 6, 9, 10, 13, 20]);
      expect(aadalCounts, <int>[2, 7, 9, 14, 16, 21, 23, 28]);
      expect(vidaalCounts, <int>[3, 6, 10, 13, 17, 20, 24, 27]);
      // Abhijit is the 22nd of the 28.
      expect(nakshatraPosition28(20), 21);
      expect(nakshatraPosition28(21), 23);
      expect(nakshatraPosition28(26), 28);
    });
  });

  group('Anandadi', () {
    test('each weekday starts at its own nakshatra and the cycle is 28', () {
      expect(anandadiTable.length, 28);
      expect(anandadiStartPosition, <int>[1, 5, 9, 13, 17, 21, 25]);
      // Ashwini, Mrigashira, Ashlesha, Hasta, Anuradha, Uttara Ashadha,
      // Shatabhisha begin Ananda on Sun to Sat.
      final List<int> starts = <int>[0, 4, 8, 12, 16, 20, 23];
      for (int wd = 0; wd < 7; wd++) {
        expect(
          (nakshatraPosition28(starts[wd]) - anandadiStartPosition[wd]) % 28,
          0,
          reason: weekdayNames[wd],
        );
      }
      // Counting Abhijit, Shravana is two after Uttara Ashadha on Friday.
      expect(anandadiTable[(nakshatraPosition28(21) - 21) % 28].name, 'Dhumra');
      // Wednesday's count is at Chara on Magha, as Drik printed on 7 October.
      expect(anandadiTable[(nakshatraPosition28(9) - 13) % 28].name, 'Chara');
    });
  });

  group('Chandra bala and Tara bala', () {
    test('Chandra bala is good in the 1st, 3rd, 6th, 7th, 10th and 11th', () {
      for (int natal = 0; natal < 12; natal++) {
        final ChandraBala b = chandraBala(
          natalMoonRashi: natal,
          transitMoonRashi: (natal + 2) % 12,
        );
        expect(b.house, 3);
        expect(b.tone, PanchangTone.auspicious);
      }
      final ChandraBala eighth = chandraBala(
        natalMoonRashi: 5,
        transitMoonRashi: 0,
      );
      expect(eighth.house, 8);
      expect(eighth.isChandrashtama, isTrue);
      expect(eighth.tone, PanchangTone.inauspicious);
      expect(
        chandraBala(natalMoonRashi: 0, transitMoonRashi: 1).tone,
        PanchangTone.neutral,
      );
      // Mrigashira's first two padas are Vrishabha, the last two Mithuna.
      expect(rashiOfNakshatraPada(4, 2), 1);
      expect(rashiOfNakshatraPada(4, 3), 2);
      expect(
        chandraBalaForNakshatra(
          natalNakshatra: 4,
          natalPada: 3,
          transitMoonRashi: 4,
        ).house,
        3,
      );
    });

    test('Tara bala counts in nines from the birth star', () {
      TaraBala at(int offset) =>
          taraBala(natalNakshatra: 10, transitNakshatra: (10 + offset) % 27);
      expect(at(0).tara.name, 'Janma');
      expect(at(1).tara.name, 'Sampat');
      expect(at(2).tara.name, 'Vipat');
      expect(at(8).tara.name, 'Ati Mitra');
      expect(at(9).tara.name, 'Janma');
      expect(at(26).tara.name, 'Ati Mitra');
      expect(at(26).count, 27);
      for (int natal = 0; natal < 27; natal++) {
        expect(taraBalaFavourableNakshatras(natal).length, 15);
      }
    });

    test('a chart-less reader and a chart read the day the same way', () {
      final PanchangDetails d = detailsFor(2026, 10, 7);
      // Natal Moon in Meena: the Moon in Simha is its 6th, favourable all day.
      final List<BalaSegment<ChandraBala>> segs = chandraBalaForDay(
        d,
        natalMoonRashi: 11,
      );
      expect(segs.single.value.house, 6);
      expect(segs.single.value.tone, PanchangTone.auspicious);
      // Two nakshatras in the day give two tara segments.
      expect(taraBalaForDay(d, natalNakshatra: 0).length, 2);
      expect(
        natalMoonAt(
          localDateTime: DateTime(1988, 8, 14, 9, 35),
          utcOffset: ist,
        ).nakshatra,
        inInclusiveRange(0, 26),
      );
    });
  });

  group('calendar', () {
    test('the samvat numbers turn at Chaitra, not at the new year', () {
      void expectYears(DateTime d, int vikram, int shaka, int kali) {
        final PanchangCalendar c = detailsFor(d.year, d.month, d.day).calendar;
        expect(c.vikramSamvat, vikram, reason: '$d Vikram');
        expect(c.shakaSamvat, shaka, reason: '$d Shaka');
        expect(c.kaliSamvat, kali, reason: '$d Kali');
      }

      expectYears(DateTime(2026, 10, 7), 2083, 1948, 5127);
      expectYears(DateTime(2026, 4, 10), 2083, 1948, 5127);
      expectYears(DateTime(2026, 3, 10), 2082, 1947, 5126);
      expectYears(DateTime(2026, 1, 15), 2082, 1947, 5126);
      expectYears(DateTime(2025, 12, 31), 2082, 1947, 5126);
      expectYears(DateTime(2027, 1, 2), 2083, 1948, 5127);
      expectYears(DateTime(2000, 1, 1), 2056, 1921, 5100);
    });

    test('the Shaka samvatsara follows the sixty-year cycle', () {
      expect(detailsFor(2025, 6, 1).calendar.samvatsara.name, 'Vishvavasu');
      expect(detailsFor(2026, 6, 1).calendar.samvatsara.name, 'Parabhava');
      expect(detailsFor(2027, 6, 1).calendar.samvatsara.name, 'Plavanga');
      expect(samvatsaraNames.length, 60);
      expect(samvatsaraNamesHindi.length, 60);
    });

    test(
      'amanta and purnimanta agree in the bright half and differ in the dark',
      () {
        int bright = 0;
        int dark = 0;
        for (int day = 0; day < 65; day++) {
          final DateTime date = DateTime(2026, 8, 1).add(Duration(days: day));
          final PanchangDetails d = detailsFor(date.year, date.month, date.day);
          final PanchangCalendar c = d.calendar;
          if (d.panchang.paksha == 'Shukla') {
            bright++;
            expect(c.amanta.index, c.purnimanta.index, reason: '$date');
            expect(c.amanta.isAdhika, c.purnimanta.isAdhika);
            expect(c.monthsDiffer, isFalse);
          } else {
            dark++;
            expect(
              c.purnimanta.index,
              (c.amanta.index + 1) % 12,
              reason: '$date',
            );
            expect(c.monthsDiffer, isTrue);
          }
        }
        expect(bright, greaterThan(20));
        expect(dark, greaterThan(20));
        // Pitru Paksha: Bhadrapada Krishna by the amanta count, Ashwin Krishna
        // by the purnimanta, on the same day.
        final PanchangCalendar pitru = detailsFor(2026, 9, 30).calendar;
        expect(pitru.amanta.name, 'Bhadrapada');
        expect(pitru.purnimanta.name, 'Ashwin');
        // Navratri: Ashwin Shukla by both.
        final PanchangCalendar navratri = detailsFor(2026, 10, 12).calendar;
        expect(navratri.amanta.name, 'Ashwin');
        expect(navratri.purnimanta.name, 'Ashwin');
      },
    );

    test('the extra month is found, and named for the month after it', () {
      // Adhika Jyeshtha 2026 ran 17 May to 15 June (amanta).
      final PanchangCalendar adhika = detailsFor(2026, 6, 1).calendar;
      expect(adhika.amanta.isAdhika, isTrue);
      expect(adhika.amanta.name, 'Adhika Jyeshtha');
      final PanchangCalendar nija = detailsFor(2026, 6, 25).calendar;
      expect(nija.amanta.isAdhika, isFalse);
      expect(nija.amanta.name, 'Jyeshtha');
      // The dark half of Vaishakha is already the adhika month by the
      // purnimanta count.
      final PanchangCalendar before = detailsFor(2026, 5, 10).calendar;
      expect(before.amanta.name, 'Vaishakha');
      expect(before.purnimanta.name, 'Adhika Jyeshtha');
      // Adhika Shravana 2023 and Adhika Ashwin 2020.
      expect(detailsFor(2023, 8, 1).calendar.amanta.name, 'Adhika Shravana');
      expect(detailsFor(2020, 10, 1).calendar.amanta.name, 'Adhika Ashwin');
      // A year never turns inside an adhika Chaitra, and Vikram years are
      // whole across the thirteen-month year.
      expect(detailsFor(2026, 9, 1).calendar.vikramSamvat, 2083);
    });

    test('the seasons and the ayana follow the Sun', () {
      final PanchangCalendar winter = detailsFor(2026, 1, 5).calendar;
      expect(winter.drikAyana.name, 'Uttarayana');
      // Before Makara Sankranti the Vedic ayana is still Dakshinayana.
      expect(winter.vedicAyana.name, 'Dakshinayana');
      expect(winter.drikRitu.name, startsWith('Shishira'));
      expect(winter.vedicRitu.name, startsWith('Hemanta'));
      final PanchangCalendar spring = detailsFor(2026, 4, 1).calendar;
      expect(spring.drikRitu.name, startsWith('Vasanta'));
      expect(spring.vedicAyana.name, 'Uttarayana');
    });
  });

  group('every window holds together', () {
    void check(PanchangDetails d, String where) {
      for (final PanchangWindow w in d.allWindows) {
        expect(w.startJdUt, lessThan(w.endJdUt), reason: '$where ${w.key}');
        expect(
          w.overlaps(d.dayStartJdUt, d.dayEndJdUt),
          isTrue,
          reason: '$where ${w.key} lies outside its day',
        );
        for (final WindowPart part in w.parts) {
          expect(
            part.startJdUt,
            lessThan(part.endJdUt),
            reason: '$where ${w.key} part',
          );
          expect(part.startJdUt, greaterThanOrEqualTo(w.startJdUt - 1e-9));
          expect(part.endJdUt, lessThanOrEqualTo(w.endJdUt + 1e-9));
        }
        // The weekday-bound yogas are cut to the Vedic day.
        if (<String>{
          'sarvartha_siddhi',
          'amrit_siddhi',
          'ravi_pushya',
          'guru_pushya',
          'dwipushkar',
          'tripushkar',
        }.contains(w.key)) {
          expect(w.startJdUt, greaterThanOrEqualTo(d.dayStartJdUt - 1e-9));
          expect(w.endJdUt, lessThanOrEqualTo(d.dayEndJdUt + 1e-9));
        }
      }
      for (final AnandadiSpan a in d.anandadi) {
        expect(a.startJdUt, lessThan(a.endJdUt), reason: '$where anandadi');
      }
      // The Anandadi spans and the Moon segments tile the Vedic day.
      expect(d.anandadi.first.startJdUt, closeTo(d.dayStartJdUt, 1e-9));
      expect(d.anandadi.last.endJdUt, closeTo(d.dayEndJdUt, 1e-9));
      for (int i = 1; i < d.anandadi.length; i++) {
        expect(
          d.anandadi[i].startJdUt,
          closeTo(d.anandadi[i - 1].endJdUt, 1e-9),
        );
      }
      for (final MoonSegment s in d.moonSegments) {
        expect(s.startJdUt, lessThan(s.endJdUt), reason: '$where moon');
      }
      expect(d.moonSegments.first.startJdUt, closeTo(d.dayStartJdUt, 1e-9));
      expect(d.moonSegments.last.endJdUt, closeTo(d.dayEndJdUt, 1e-9));
      expect(d.dayEndJdUt - d.dayStartJdUt, closeTo(1.0, 0.01));
    }

    test('forty-five days from 1 October 2026 in Delhi', () {
      for (int day = 0; day < 45; day++) {
        final DateTime date = DateTime(2026, 10, 1).add(Duration(days: day));
        check(detailsFor(date.year, date.month, date.day), '$date');
      }
    });

    test('other places and other years', () {
      for (int day = 0; day < 12; day++) {
        final DateTime date = DateTime(2026, 7, 1).add(Duration(days: day));
        check(
          detailsFor(
            date.year,
            date.month,
            date.day,
            place: singapore,
            offset: const Duration(hours: 8),
          ),
          'Singapore $date',
        );
      }
      for (final int year in <int>[1950, 1988, 2034]) {
        for (int day = 0; day < 6; day++) {
          final DateTime date = DateTime(year, 3, 10).add(Duration(days: day));
          check(detailsFor(date.year, date.month, date.day), '$date');
        }
      }
    });
  });

  group('both languages, everywhere', () {
    test('the rule notes', () {
      for (final RuleNote n in <RuleNote>[
        panchakNote,
        bhadraNote,
        gandMoolNote,
        dishaShoolNote,
        chandraBalaNote,
        taraBalaNote,
        sarvarthaSiddhiNote,
        amritSiddhiNote,
        raviPushyaNote,
        guruPushyaNote,
        raviYogaNote,
        dwipushkarNote,
        tripushkarNote,
        jwalamukhiNote,
        vinchhudoNote,
        aadalNote,
        vidaalNote,
        anandadiNote,
        vikramSamvatNote,
        shakaSamvatNote,
        kaliSamvatNote,
        lunarMonthNote,
        pakshaNote,
        rituNote,
        ayanaNote,
        solarMonthNote,
      ]) {
        expectBothLanguages(n.name, n.nameHindi, '${n.key} name');
        expectBothLanguages(n.meaning, n.meaningHindi, '${n.key} meaning');
      }
    });

    test('the tables', () {
      for (final PanchakKind k in panchakKinds) {
        expectBothLanguages(k.name, k.nameHindi, 'panchak ${k.key} name');
        expectBothLanguages(k.meaning, k.meaningHindi, 'panchak ${k.key}');
      }
      for (final DishaShool d in dishaShoolTable) {
        expectBothLanguages(
          d.direction,
          d.directionHindi,
          'disha ${d.weekday}',
        );
        expectBothLanguages(d.parihar, d.pariharHindi, 'parihar ${d.weekday}');
      }
      for (int i = 0; i < 3; i++) {
        expectBothLanguages(
          bhadraLokaName[i],
          bhadraLokaNameHindi[i],
          'loka $i',
        );
        expectBothLanguages(
          bhadraLokaMeaning[i],
          bhadraLokaMeaningHindi[i],
          'loka $i',
        );
      }
      for (final TaraInfo t in taraTable) {
        expectBothLanguages(t.name, t.nameHindi, 'tara ${t.number}');
        expectBothLanguages(t.meaning, t.meaningHindi, 'tara ${t.number}');
      }
      for (final AnandadiInfo a in anandadiTable) {
        expectBothLanguages(a.name, a.nameHindi, 'anandadi ${a.name}');
        expectBothLanguages(a.meaning, a.meaningHindi, 'anandadi ${a.name}');
      }
      for (int i = 0; i < 60; i++) {
        expectBothLanguages(
          samvatsaraNames[i],
          samvatsaraNamesHindi[i],
          'samvatsara $i',
        );
      }
      for (int i = 0; i < 6; i++) {
        expectBothLanguages(rituNames[i], rituNamesHindi[i], 'ritu $i');
      }
      for (int i = 0; i < 2; i++) {
        expectBothLanguages(ayanaNames[i], ayanaNamesHindi[i], 'ayana $i');
      }
      for (int i = 0; i < 27; i++) {
        expectBothLanguages(yogaNames[i], yogaNamesHindi[i], 'yoga $i');
      }
      for (int i = 0; i < 7; i++) {
        expectBothLanguages(
          choghadiyaCycle[i],
          choghadiyaCycleHindi[i],
          'choghadiya $i',
        );
        expectBothLanguages(
          choghadiyaMeaning[i],
          choghadiyaMeaningHindi[i],
          'choghadiya $i',
        );
        expectBothLanguages(horaMeaning[i], horaMeaningHindi[i], 'hora $i');
        expect(horaNamesHindi[i], isNotEmpty);
      }
      expect(anandadiTable.length, 28);
    });

    test('the karanas, the chandra and tara balas', () {
      final PanchangDetails d = detailsFor(2026, 10, 7);
      expect(d.panchang.karana.nameHindi, isNot(d.panchang.karana.name));
      for (int h = 0; h < 12; h++) {
        final ChandraBala b = chandraBala(
          natalMoonRashi: 0,
          transitMoonRashi: h,
        );
        expectBothLanguages(b.name, b.nameHindi, 'chandra $h');
        expectBothLanguages(b.meaning, b.meaningHindi, 'chandra $h');
      }
    });

    test('every window, label and part a run of days produces', () {
      for (int day = 0; day < 45; day++) {
        final DateTime date = DateTime(2026, 10, 1).add(Duration(days: day));
        final PanchangDetails d = detailsFor(date.year, date.month, date.day);
        final Panchang p = d.panchang;
        expectBothLanguages(p.yoga.name, p.yoga.nameHindi, 'yoga $date');
        expectBothLanguages(p.karana.name, p.karana.nameHindi, 'karana $date');
        expectBothLanguages(p.tithi.name, p.tithi.nameHindi, 'tithi $date');
        for (final TimeSpan h in p.horas) {
          expect(h.title, isNotEmpty);
          expectBothLanguages(h.meaning, h.meaningHindi, 'hora ${h.name}');
          expect(devanagari.hasMatch(h.titleHindi), isTrue);
        }
        for (final TimeSpan c in <TimeSpan>[
          ...p.dayChoghadiya,
          ...p.nightChoghadiya,
        ]) {
          expectBothLanguages(c.name, c.nameHindi, 'choghadiya ${c.name}');
        }
        for (final PanchangWindow w in d.allWindows) {
          expectBothLanguages(w.name, w.nameHindi, 'window ${w.key}');
          expectBothLanguages(w.meaning, w.meaningHindi, 'window ${w.key}');
          expect(
            w.label.isEmpty,
            w.labelHindi.isEmpty,
            reason: '${w.key} label',
          );
          expect(
            w.detail.isEmpty,
            w.detailHindi.isEmpty,
            reason: '${w.key} detail',
          );
          if (w.label.isNotEmpty) {
            expectBothLanguages(w.label, w.labelHindi, '${w.key} label');
          }
          for (final WindowPart part in w.parts) {
            expectBothLanguages(part.detail, part.detailHindi, '${w.key} part');
          }
        }
        for (final AnandadiSpan a in d.anandadi) {
          expectBothLanguages(a.info.name, a.info.nameHindi, 'anandadi');
        }
        expectBothLanguages(
          d.calendar.samvatsara.name,
          d.calendar.samvatsara.nameHindi,
          'samvatsara',
        );
        expectBothLanguages(
          d.calendar.amanta.name,
          d.calendar.amanta.nameHindi,
          'amanta',
        );
        expectBothLanguages(
          d.calendar.purnimanta.name,
          d.calendar.purnimanta.nameHindi,
          'purnimanta',
        );
        expectBothLanguages(
          d.calendar.paksha.name,
          d.calendar.paksha.nameHindi,
          'paksha',
        );
        expectBothLanguages(
          d.calendar.vedicRitu.name,
          d.calendar.vedicRitu.nameHindi,
          'ritu',
        );
        expectBothLanguages(
          d.calendar.drikAyana.name,
          d.calendar.drikAyana.nameHindi,
          'ayana',
        );
        expectBothLanguages(
          d.calendar.nirayanaSun.name,
          d.calendar.nirayanaSun.nameHindi,
          'sun',
        );
        expectBothLanguages(
          d.dishaShool.direction,
          d.dishaShool.directionHindi,
          'disha',
        );
      }
    });
  });

  group('disha shool', () {
    test('the direction by weekday', () {
      final List<String> expected = <String>[
        'West', // Sunday
        'East', // Monday
        'North', // Tuesday
        'North', // Wednesday
        'South', // Thursday
        'West', // Friday
        'East', // Saturday
      ];
      expect(dishaShoolTable.map((DishaShool d) => d.direction), expected);
      for (int wd = 0; wd < 7; wd++) {
        expect(dishaShoolTable[wd].weekday, wd);
      }
    });
  });
}
