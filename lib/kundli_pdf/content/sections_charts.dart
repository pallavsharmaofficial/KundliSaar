import 'package:pdf/widgets.dart' as pw;

import '../../engine/astro/ephemeris.dart';
import '../../engine/astro/time.dart';
import '../../engine/jyotish/ashtakavarga.dart';
import '../../engine/jyotish/chart.dart';
import '../../engine/jyotish/nakshatra.dart';
import '../../engine/jyotish/panchang.dart';
import '../../engine/jyotish/panchang_calendar.dart';
import '../../engine/jyotish/shadbala.dart';
import '../../engine/jyotish/upagrahas.dart';
import '../../engine/jyotish/varga.dart';
import '../design/chart_paint.dart';
import '../design/kit.dart';
import '../design/palette.dart';
import 'data.dart';
import 'hindi.dart';

/// The boxes of a chart for the grahas in whichever signs they are given. With
/// no override this is the rasi chart, with the marks for a graha that turns
/// back and one that is burnt up.
List<HouseBox> houseBoxes(
  Kundli k, {
  Map<Graha, int>? signs,
  int? lagnaSign,
  bool marks = true,
  bool includeNodes = true,
}) {
  final int lagna = lagnaSign ?? k.lagnaRashi.index;
  return <HouseBox>[
    for (int h = 1; h <= 12; h++)
      HouseBox(
        house: h,
        sign: (lagna + h - 1) % 12,
        isLagna: h == 1,
        labels: <String>[
          for (final PlacedGraha g in k.grahas.values)
            if ((includeNodes ||
                    (g.graha != Graha.rahu && g.graha != Graha.ketu)) &&
                (signs != null ? signs[g.graha]! : g.rashi.index) ==
                    (lagna + h - 1) % 12)
              '${Hi.chartLabel(g.graha)}${marks && g.isRetrograde ? '(व)' : ''}${marks && g.isCombust ? '(अ)' : ''}',
        ],
      ),
  ];
}

const Map<Varga, String> _vargaReadsHindi = <Varga, String>{
  Varga.d1: 'शरीर और जीवन का समग्र रूप',
  Varga.d2: 'संसाधन और धन',
  Varga.d3: 'साहस और भाई-बहन',
  Varga.d4: 'घर, भूमि और भाग्य',
  Varga.d7: 'संतान और वंश',
  Varga.d9: 'विवाह, धर्म और भीतरी बल',
  Varga.d10: 'कार्य और प्रतिष्ठा',
  Varga.d12: 'माता-पिता और पूर्वज',
  Varga.d16: 'वाहन और सुख-साधन',
  Varga.d20: 'उपासना और साधना',
  Varga.d24: 'विद्या और शिक्षा',
  Varga.d27: 'बल और कमज़ोरी',
  Varga.d30: 'कठिनाइयाँ और उनके कारण',
  Varga.d40: 'मातृ पक्ष की विरासत',
  Varga.d45: 'पितृ पक्ष की विरासत और चरित्र',
  Varga.d60: 'पूर्व कर्मों का सार',
};

/// लग्न कुंडली और वर्ग कुंडलियाँ: drawn, all of them.
List<pw.Widget> chartsSection(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final PlacedGraha moon = k.grahas[Graha.moon]!;
  final PlacedGraha sun = k.grahas[Graha.sun]!;
  final List<HouseBox> rasi = houseBoxes(k);

  pw.Widget card(
    String title,
    String sub,
    pw.Widget chart, {
    double width = 150,
  }) => pw.Container(
    width: width,
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: <pw.Widget>[
        chart,
        pw.SizedBox(height: 3),
        kit.text(
          title,
          style: kit.style(kit.fonts.semi, 9.4, color: Pal.maroon, spacing: 1),
          align: pw.TextAlign.center,
        ),
        if (sub.isNotEmpty)
          kit.text(
            sub,
            style: kit.style(
              kit.fonts.regular,
              7.8,
              color: Pal.inkSoft,
              spacing: 1,
            ),
            align: pw.TextAlign.center,
          ),
      ],
    ),
  );

  final List<pw.Widget> out = <pw.Widget>[
    kit.sectionTitle(
      id: 'charts',
      number: 'भाग २',
      title: 'लग्न कुंडली और वर्ग कुंडलियाँ',
      subtitle: 'हर कुंडली में अंक राशि का क्रमांक है (मेष = 1)',
    ),
    kit.h2('लग्न कुंडली'),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Column(
          children: <pw.Widget>[
            kit.northChart(262, rasi, labelSize: 11.2),
            pw.SizedBox(height: 4),
            kit.text('उत्तर भारतीय शैली', style: kit.small),
          ],
        ),
        pw.Column(
          children: <pw.Widget>[
            pw.SizedBox(height: 28),
            kit.southChart(
              208,
              rasi,
              labelSize: 9.6,
              centre: <String>['लग्न', Hi.sign(k.lagnaRashi)],
            ),
            pw.SizedBox(height: 4),
            kit.text('दक्षिण भारतीय शैली', style: kit.small),
          ],
        ),
      ],
    ),
    kit.gap(6),
    kit.note(
      'सू सूर्य · चं चंद्र · मं मंगल · बु बुध · गु गुरु · शु शुक्र · श शनि · रा राहु · के केतु · ल लग्न · (व) वक्री · (अ) अस्त',
    ),
    kit.gap(4),
    kit.h2('चंद्र और सूर्य कुंडली'),
    kit.para(
      'चंद्र कुंडली में चंद्र की राशि को लग्न मानकर और सूर्य कुंडली में सूर्य की राशि को लग्न मानकर, उन्हीं ग्रहों को भावों में रखा गया है।',
    ),
    pw.Wrap(
      spacing: 10,
      runSpacing: 6,
      children: <pw.Widget>[
        card(
          'चंद्र कुंडली',
          '${Hi.sign(moon.rashi)} लग्न मानकर',
          kit.northChart(
            140,
            houseBoxes(k, lagnaSign: moon.rashi.index),
            labelSize: 7.6,
          ),
        ),
        card(
          'सूर्य कुंडली',
          '${Hi.sign(sun.rashi)} लग्न मानकर',
          kit.northChart(
            140,
            houseBoxes(k, lagnaSign: sun.rashi.index),
            labelSize: 7.6,
          ),
        ),
        card(
          'नवांश (D9)',
          _vargaReadsHindi[Varga.d9]!,
          kit.northChart(
            140,
            houseBoxes(
              k,
              signs: k.vargaPlacements(Varga.d9),
              lagnaSign: k.vargaLagna(Varga.d9),
              marks: false,
            ),
            labelSize: 7.6,
          ),
        ),
      ],
    ),
    kit.gap(6),
    kit.h2('सोलह वर्ग कुंडलियाँ'),
    kit.para(
      'हर वर्ग कुंडली जीवन का एक अलग पहलू पढ़ने के लिए लग्न कुंडली के ग्रहों को उस वर्ग के नियम से नई राशियों में रखती है। नीचे का वाक्य बताता है कि परंपरा उस वर्ग से क्या पढ़ती है।',
    ),
    pw.Wrap(
      spacing: 10,
      runSpacing: 8,
      children: <pw.Widget>[
        for (final VargaInfo v in vargaTable)
          card(
            'D${v.divisions} · ${v.hindi}',
            _vargaReadsHindi[v.varga]!,
            kit.northChart(
              140,
              houseBoxes(
                k,
                signs: k.vargaPlacements(v.varga),
                lagnaSign: k.vargaLagna(v.varga),
                marks: false,
              ),
              labelSize: 7.6,
            ),
          ),
      ],
    ),
  ];
  return out;
}

/// ग्रह स्थिति.
List<pw.Widget> planetsSection(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final List<List<String>> rows = <List<String>>[
    <String>[
      'लग्न',
      Hi.sign(k.lagnaRashi),
      Hi.dms(k.ascendant % 30),
      '—',
      '1',
      '—',
    ],
    for (final Graha g in Graha.values)
      (() {
        final PlacedGraha p = k.grahas[g]!;
        final List<String> flags = <String>[
          Hi.dignity(p.dignity),
          if (p.isRetrograde) 'वक्री',
          if (p.isCombust) 'अस्त',
        ];
        return <String>[
          Hi.graha(g),
          Hi.sign(p.rashi),
          Hi.dms(p.degreesInSign),
          '${p.nakshatra.hindi} · ${p.pada}',
          '${p.house}',
          flags.join(' · '),
        ];
      })(),
  ];

  final List<PlacedUpagraha> ups = <PlacedUpagraha>[
    for (final PlacedUpagraha u in d.upagrahas.placed)
      if (!kit.isRefused(u.info.hindi)) u,
  ];

  return <pw.Widget>[
    kit.sectionTitle(
      id: 'planets',
      number: 'भाग ३',
      title: 'ग्रह स्थिति',
      subtitle: 'हर ग्रह किस राशि, अंश, नक्षत्र और भाव में है',
    ),
    kit.table(
      headers: <String>[
        'ग्रह',
        'राशि',
        'अंश',
        'नक्षत्र · पाद',
        'भाव',
        'स्थिति',
      ],
      rows: rows,
      widths: <double>[1.25, 1.35, 1.55, 2.3, 0.7, 2.4],
      align: <pw.TextAlign>[
        pw.TextAlign.left,
        pw.TextAlign.left,
        pw.TextAlign.left,
        pw.TextAlign.left,
        pw.TextAlign.center,
        pw.TextAlign.left,
      ],
      highlightRows: <int>{0},
    ),
    kit.gap(6),
    kit.note(
      'भाव पूरे-राशि पद्धति से गिने गए हैं: लग्न की राशि पहला भाव है। स्थिति में ग्रह की राशि का स्वरूप (उच्च, नीच, स्वराशि, मित्र, सम या शत्रु राशि) और वक्री या अस्त होना लिखा है।',
    ),
    kit.gap(6),
    kit.h2('नक्षत्र और उनके स्वामी'),
    kit.table(
      headers: <String>[
        'ग्रह',
        'नक्षत्र',
        'नक्षत्र स्वामी',
        'देवता',
        'गण',
        'नाड़ी',
      ],
      rows: <List<String>>[
        for (final Graha g in Graha.values)
          (() {
            final NakshatraInfo n = k.grahas[g]!.nakshatra;
            return <String>[
              Hi.graha(g),
              n.hindi,
              Hi.graha(n.lord),
              n.deityHindi,
              Hi.gana(n.gana),
              Hi.nadi(n.nadi),
            ];
          })(),
      ],
      widths: <double>[1.2, 1.9, 1.5, 2.2, 1.0, 1.0],
    ),
    kit.gap(8),
    kit.h2('उपग्रह'),
    kit.para(
      'उपग्रह ग्रहों के साथ गिने जाने वाले सूक्ष्म बिंदु हैं। इन्हें यहाँ केवल इस बात के लिए रखा गया है कि हर एक किस राशि और किस भाव में है; इनसे कोई अलग फल नहीं कहा गया है।',
    ),
    kit.table(
      headers: <String>['उपग्रह', 'राशि', 'अंश', 'नक्षत्र', 'भाव'],
      rows: <List<String>>[
        for (final PlacedUpagraha u in ups)
          <String>[
            u.info.hindi,
            Hi.sign(u.rashi),
            Hi.dms(u.degreesInSign),
            u.nakshatra.hindi,
            '${u.house}',
          ],
      ],
      widths: <double>[1.8, 1.4, 1.5, 2.0, 0.8],
      align: <pw.TextAlign>[
        pw.TextAlign.left,
        pw.TextAlign.left,
        pw.TextAlign.left,
        pw.TextAlign.left,
        pw.TextAlign.center,
      ],
    ),
  ];
}

/// पंचांग.
List<pw.Widget> panchangSection(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final Duration off = k.birth.utcOffset;
  final Panchang p = d.panchang;
  final PanchangCalendar c = d.calendar;

  // The five limbs at the moment of birth, cut from the same elongation and
  // longitudes the engine's panchang uses.
  final double elong = lunarElongationAt(k.instant);
  final int tithiIdx = (elong / 12).floor() % 30;
  final String tithi = tithiIdx == 29
      ? 'अमावस्या'
      : tithiNamesHindi[tithiIdx % 15];
  final String paksha = tithiIdx < 15 ? 'शुक्ल पक्ष' : 'कृष्ण पक्ष';
  final int karanaIdx = (elong / 6).floor() % 60;
  final double sum =
      (k.grahas[Graha.sun]!.siderealLongitude +
          k.grahas[Graha.moon]!.siderealLongitude) %
      360;
  final int yogaIdx = (sum / nakshatraSpan).floor() % 27;
  final NakshatraInfo nak = k.janmaNakshatra;

  String karana() {
    if (karanaIdx == 0) return 'किंस्तुघ्न';
    if (karanaIdx >= 57) {
      return const <String>['शकुनि', 'चतुष्पद', 'नाग'][karanaIdx - 57];
    }
    return movableKaranasHindi[(karanaIdx - 1) % 7];
  }

  final DateTime birthDay = DateTime(
    k.birth.localDateTime.year,
    k.birth.localDateTime.month,
    k.birth.localDateTime.day,
  );
  String t(double? jd) {
    if (jd == null) return '—';
    final DateTime local = Instant.fromJulianDayUt(jd).utc.add(off);
    final int days = DateTime(
      local.year,
      local.month,
      local.day,
    ).difference(birthDay).inDays;
    final String when = days == 0
        ? ''
        : (days > 0 ? ' (अगले दिन)' : ' (पिछले दिन)');
    return '${Hi.clock(local)}$when';
  }

  return <pw.Widget>[
    kit.sectionTitle(
      id: 'panchang',
      number: 'भाग ४',
      title: 'पंचांग',
      subtitle: 'जन्म के क्षण का पंचांग, और उस दिन का',
    ),
    kit.h2('जन्म के क्षण पर पंचांग के पाँच अंग'),
    kit.kv('वार', Hi.weekdays[d.upagrahas.weekday], strong: true),
    kit.kv('तिथि', '$paksha · $tithi', strong: true),
    kit.kv(
      'नक्षत्र',
      '${nak.hindi} · पाद ${k.grahas[Graha.moon]!.pada}',
      strong: true,
    ),
    kit.kv('योग', yogaNamesHindi[yogaIdx]),
    kit.kv('करण', karana()),
    kit.gap(4),
    kit.note(
      'वार सूर्योदय से सूर्योदय तक गिना जाता है, इसलिए सूर्योदय से पहले जन्म हो तो पिछला वार माना गया है। तिथि, योग और करण जन्म के ठीक क्षण की चंद्र-सूर्य की स्थिति से हैं।',
    ),
    kit.gap(6),
    kit.h2('जन्म के दिन का पंचांग'),
    kit.para(
      'नीचे उस दिन का पंचांग है जब आपका जन्म हुआ, सूर्योदय के अनुसार, हर अंग के समाप्त होने के समय के साथ।',
    ),
    kit.table(
      headers: <String>['अंग', 'सूर्योदय पर', 'समाप्ति'],
      rows: <List<String>>[
        <String>[
          'तिथि',
          '${p.paksha == 'Shukla' ? 'शुक्ल' : 'कृष्ण'} ${p.tithi.nameHindi}',
          t(p.tithi.endsAtJdUt),
        ],
        <String>['नक्षत्र', p.nakshatra.nameHindi, t(p.nakshatra.endsAtJdUt)],
        <String>['योग', p.yoga.nameHindi, t(p.yoga.endsAtJdUt)],
        <String>['करण', p.karana.nameHindi, t(p.karana.endsAtJdUt)],
        <String>['वार', Hi.weekdays[p.weekday], '—'],
      ],
      widths: <double>[1.2, 3, 1.6],
    ),
    kit.gap(6),
    kit.table(
      headers: <String>['सूर्योदय', 'सूर्यास्त', 'चंद्रोदय', 'चंद्रास्त'],
      rows: <List<String>>[
        <String>[t(p.sunrise), t(p.sunset), t(p.moonrise), t(p.moonset)],
      ],
      widths: <double>[1, 1, 1, 1],
      boldColumns: const <int>{},
    ),
    kit.gap(8),
    kit.h2('संवत् और मास'),
    kit.kv('विक्रम संवत्', '${c.vikramSamvat}'),
    kit.kv('शक संवत्', '${c.shakaSamvat}'),
    kit.kv('कलि संवत्', '${c.kaliSamvat}'),
    kit.kv('संवत्सर (शक वर्ष का नाम)', c.samvatsara.nameHindi),
    kit.kv('चांद्र मास (अमांत)', c.amanta.nameHindi),
    kit.kv('चांद्र मास (पूर्णिमांत)', c.purnimanta.nameHindi),
    kit.kv('पक्ष', c.paksha.nameHindi),
    kit.kv(
      'ऋतु',
      '${c.vedicRitu.nameHindi} (वैदिक) · ${c.drikRitu.nameHindi} (दृक्)',
    ),
    kit.kv(
      'अयन',
      '${c.vedicAyana.nameHindi} (वैदिक) · ${c.drikAyana.nameHindi} (दृक्)',
    ),
    kit.kv(
      'सूर्य (निरयण)',
      '${c.nirayanaSun.nameHindi} · ${Hi.deg(c.nirayanaSun.degrees)}',
    ),
    kit.kv(
      'सूर्य (सायन)',
      '${c.sayanaSun.nameHindi} · ${Hi.deg(c.sayanaSun.degrees)}',
    ),
    kit.gap(4),
    kit.note(
      'संवत्सर और मास के नामों पर पंचांग-परंपराओं में मतभेद है; ऐसे मतभेद \'दो मत\' भाग में रखे गए हैं।',
    ),
  ];
}

/// षड्बल.
List<pw.Widget> shadbalaSection(Kit kit, KundliPdfData d) {
  final Map<Graha, BalaBreakdown> bala = d.phala.context.bala;
  return <pw.Widget>[
    kit.sectionTitle(
      id: 'shadbala',
      number: 'भाग ५',
      title: 'षड्बल',
      subtitle: 'छह बलों का योग, रूप में। हर ग्रह के लिए आवश्यक बल अलग है।',
    ),
    kit.para(
      'षड्बल में स्थान, दिग्, काल, चेष्टा, नैसर्गिक और दृक् बल जोड़े जाते हैं। साठ विरुपा का एक रूप होता है। ग्रह तब अपना फल देने में सक्षम माना जाता है जब उसका कुल बल परंपरा के बताए न्यूनतम रूप को पार कर ले। नीचे की पट्टी में गहरी रेखा वही न्यूनतम है।',
    ),
    kit.table(
      headers: <String>[
        'ग्रह',
        'स्थान',
        'दिग्',
        'काल',
        'चेष्टा',
        'नैसर्गिक',
        'दृक्',
        'कुल रूप',
        'चाहिए',
        'स्थिति',
      ],
      rows: <List<String>>[
        for (final Graha g in shadbalaGrahas)
          (() {
            final BalaBreakdown b = bala[g]!;
            return <String>[
              Hi.graha(g),
              b.sthana.toStringAsFixed(1),
              b.dig.toStringAsFixed(1),
              b.kala.toStringAsFixed(1),
              b.chesta.toStringAsFixed(1),
              b.naisargika.toStringAsFixed(1),
              b.drik.toStringAsFixed(1),
              b.totalRupas.toStringAsFixed(2),
              '${b.requiredRupas}',
              b.isStrong ? 'बलवान' : 'बल से कम',
            ];
          })(),
      ],
      widths: <double>[1.1, 1, 0.9, 0.9, 1, 1.15, 0.9, 1.15, 0.95, 1.3],
      align: <pw.TextAlign>[
        pw.TextAlign.left,
        ...List<pw.TextAlign>.filled(8, pw.TextAlign.right),
        pw.TextAlign.left,
      ],
      size: 8.8,
    ),
    kit.note(
      'स्थान, दिग्, काल, चेष्टा, नैसर्गिक और दृक् के मान विरुपा में हैं; कुल और चाहिए रूप में।',
    ),
    kit.gap(8),
    kit.h2('कुल बल, आवश्यक बल के सामने'),
    for (final Graha g in shadbalaGrahas)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: <pw.Widget>[
            pw.SizedBox(
              width: 62,
              child: kit.text(Hi.graha(g), style: kit.bodyStrong),
            ),
            kit.barWidget(
              270,
              9,
              bala[g]!.totalRupas,
              bala[g]!.requiredRupas * 1.7,
              mark: bala[g]!.requiredRupas,
            ),
            pw.SizedBox(width: 10),
            kit.text(
              '${bala[g]!.totalRupas.toStringAsFixed(2)} रूप · ${bala[g]!.isStrong ? 'बलवान' : 'बल से कम'}',
              style: kit.small,
            ),
          ],
        ),
      ),
    kit.gap(6),
    kit.note(
      'राहु और केतु के लिए षड्बल परिभाषित नहीं है, इसलिए वे यहाँ नहीं हैं।',
    ),
  ];
}

/// अष्टकवर्ग.
List<pw.Widget> ashtakaSection(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final AshtakavargaResult av = d.phala.context.ashtakavarga;
  final int lagna = k.lagnaRashi.index;

  List<HouseBox> boxes(List<int> bindus) => <HouseBox>[
    for (int h = 1; h <= 12; h++)
      HouseBox(
        house: h,
        sign: (lagna + h - 1) % 12,
        isLagna: h == 1,
        labels: <String>['${bindus[(lagna + h - 1) % 12]}'],
      ),
  ];

  pw.Widget mini(String title, String sub, List<int> bindus) => pw.Container(
    width: 150,
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Column(
      children: <pw.Widget>[
        kit.northChart(140, boxes(bindus), labelSize: 11, perRow: 1),
        pw.SizedBox(height: 3),
        kit.text(
          title,
          style: kit.style(kit.fonts.semi, 9.4, color: Pal.maroon, spacing: 1),
        ),
        kit.text(
          sub,
          style: kit.style(
            kit.fonts.regular,
            7.8,
            color: Pal.inkSoft,
            spacing: 1,
          ),
        ),
      ],
    ),
  );

  return <pw.Widget>[
    kit.sectionTitle(
      id: 'ashtaka',
      number: 'भाग ६',
      title: 'अष्टकवर्ग',
      subtitle: 'हर राशि में बिंदु। 30 से ऊपर बलवान, 25 से नीचे कमज़ोर।',
    ),
    kit.para(
      'हर ग्रह के पास कुछ निश्चित भाव होते हैं जो आठ संदर्भों (सात ग्रह और लग्न) से गिनने पर शुभ माने जाते हैं। इन्हें गिनकर हर राशि के बिंदु बनते हैं। सातों के बिंदु जोड़ने पर सर्वाष्टकवर्ग बनता है, जिसका कुल योग हमेशा 337 होता है।',
    ),
    kit.h2('सर्वाष्टकवर्ग'),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        kit.northChart(236, boxes(av.sarva), labelSize: 14, perRow: 1),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              for (int s = 0; s < 12; s++)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2.6),
                  child: pw.Row(
                    children: <pw.Widget>[
                      pw.SizedBox(
                        width: 52,
                        child: kit.text(
                          Hi.signAt(s),
                          style: kit.style(
                            s == lagna ? kit.fonts.semi : kit.fonts.regular,
                            9.2,
                            spacing: 1,
                          ),
                        ),
                      ),
                      pw.SizedBox(
                        width: 26,
                        child: kit.text(
                          '${av.sarva[s]}',
                          style: kit.style(kit.fonts.semi, 9.2, spacing: 1),
                        ),
                      ),
                      kit.text(
                        sarvaVerdict(av.sarva[s], hindi: true),
                        style: kit.style(
                          kit.fonts.regular,
                          8.4,
                          color: Pal.inkSoft,
                          spacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              pw.SizedBox(height: 3),
              kit.text(
                'कुल योग ${av.sarvaTotal} बिंदु',
                style: kit.style(
                  kit.fonts.semi,
                  9.4,
                  color: Pal.maroon,
                  spacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    kit.gap(10),
    kit.h2('हर ग्रह का भिन्नाष्टकवर्ग'),
    pw.Wrap(
      spacing: 10,
      runSpacing: 6,
      children: <pw.Widget>[
        for (final Graha g in ashtakavargaGrahas)
          mini(
            Hi.graha(g),
            'कुल ${av.charts[g]!.total} बिंदु',
            av.charts[g]!.bindus,
          ),
      ],
    ),
    kit.gap(6),
    kit.h2('सारणी: राशि के अनुसार बिंदु'),
    kit.table(
      headers: <String>[
        'ग्रह',
        for (int s = 0; s < 12; s++) Hi.signAt(s),
        'योग',
      ],
      rows: <List<String>>[
        for (final Graha g in ashtakavargaGrahas)
          <String>[
            Hi.graha(g),
            for (int s = 0; s < 12; s++) '${av.charts[g]!.bindus[s]}',
            '${av.charts[g]!.total}',
          ],
        <String>[
          'सर्व',
          for (int s = 0; s < 12; s++) '${av.sarva[s]}',
          '${av.sarvaTotal}',
        ],
      ],
      widths: <double>[1.5, ...List<double>.filled(12, 1.0), 1.1],
      align: <pw.TextAlign>[
        pw.TextAlign.left,
        ...List<pw.TextAlign>.filled(13, pw.TextAlign.center),
      ],
      size: 7.8,
      highlightRows: <int>{7},
    ),
    kit.gap(4),
    kit.note(
      'कुंडली में लग्न की राशि ${Hi.sign(k.lagnaRashi)} है; ऊपर की कुंडलियों में पहला भाव वही है।',
    ),
  ];
}
