import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../engine/astro/ephemeris.dart';
import '../../engine/jyotish/chart.dart';
import '../../engine/jyotish/dasha.dart';
import '../../engine/jyotish/nakshatra.dart';
import '../../engine/jyotish/phaladesh.dart';
import '../../engine/jyotish/rashi.dart';
import '../../engine/jyotish/shadbala.dart';
import '../../engine/jyotish/yogas.dart';
import '../design/kit.dart';
import '../design/ornament.dart';
import '../design/palette.dart';
import 'data.dart';
import 'hindi.dart';
import 'readings.dart';

/// One entry of the contents page.
class SectionEntry {
  const SectionEntry(this.id, this.number, this.title, this.subtitle);
  final String id;
  final String number;
  final String title;
  final String subtitle;
}

const List<SectionEntry> sectionEntries = <SectionEntry>[
  SectionEntry(
    'birth',
    '१',
    'जन्म विवरण',
    'जन्म का क्षण, स्थान और मुख्य बातें',
  ),
  SectionEntry(
    'charts',
    '२',
    'लग्न कुंडली और वर्ग कुंडलियाँ',
    'लग्न, चंद्र और सोलह वर्ग, बने हुए चित्र में',
  ),
  SectionEntry(
    'planets',
    '३',
    'ग्रह स्थिति',
    'हर ग्रह राशि, अंश, नक्षत्र और भाव में',
  ),
  SectionEntry('panchang', '४', 'पंचांग', 'जन्म का पंचांग और संवत्'),
  SectionEntry('shadbala', '५', 'षड्बल', 'ग्रहों के छह बल'),
  SectionEntry('ashtaka', '६', 'अष्टकवर्ग', 'हर राशि के बिंदु'),
  SectionEntry(
    'dasha',
    '७',
    'विंशोत्तरी दशा',
    'महादशा, अंतर्दशा और प्रत्यंतर्दशा, तिथियों सहित',
  ),
  SectionEntry(
    'timeline',
    '८',
    'जीवन फलादेश',
    'जन्म से नब्बे वर्ष तक, चरण-दर-चरण',
  ),
  SectionEntry(
    'dashaphala',
    '९',
    'दशा फल',
    'हर महादशा और अभी चल रही दशाओं का फल',
  ),
  SectionEntry('bhava', '१०', 'भाव फल', 'बारह भावों का फल'),
  SectionEntry('graha', '११', 'ग्रह फल', 'नौ ग्रहों का फल'),
  SectionEntry('yoga', '१२', 'योग और दोष', 'हर योग और दोष, उसके परिहार के साथ'),
  SectionEntry('matbhed', '१३', 'दो मत', 'जहाँ ग्रंथ एकमत नहीं हैं'),
  SectionEntry('gochar', '१४', 'गोचर', 'अभी के धीमे ग्रह, आपकी कुंडली के साथ'),
  SectionEntry(
    'varshphal',
    '१५',
    'वर्षफल',
    'इस वर्ष की कुंडली, ताजिक पद्धति से',
  ),
  SectionEntry('sudarshan', '१६', 'सुदर्शन चक्र', 'हर भाव तीन संदर्भों से'),
  SectionEntry(
    'other',
    '१७',
    'अन्य विधियाँ',
    'घात चक्र, उपग्रह, अंक और मिलान के आधार',
  ),
  SectionEntry('upaya', '१८', 'उपाय', 'परंपरा के सरल उपाय'),
];

/// The cover: nothing but the person and the headline facts, over the full
/// ornament.
pw.Widget coverPage(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final BirthData b = k.birth;
  final PlacedGraha moon = k.grahas[Graha.moon]!;
  final DateTime now = d.now.toUtc().add(b.utcOffset);

  pw.Widget line(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: <pw.Widget>[
        kit.text(
          '$label  ',
          style: kit.style(
            kit.fonts.regular,
            11,
            color: Pal.inkSoft,
            spacing: 1,
          ),
        ),
        // A long place name wraps instead of running off the page.
        pw.Flexible(
          child: kit.text(
            value,
            style: kit.style(kit.fonts.semi, 12, spacing: 1),
            align: pw.TextAlign.center,
          ),
        ),
      ],
    ),
  );

  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(96, 0, 96, 0),
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: <pw.Widget>[
        pw.SizedBox(height: 366),
        kit.text(
          '॥ वैदिक ज्योतिष · निरयण पद्धति ॥',
          style: kit.style(kit.fonts.serif, 11, color: Pal.gold, spacing: 1),
          align: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        kit.text(
          'जन्म पत्रिका',
          style: kit.style(
            kit.fonts.display,
            56,
            color: Pal.maroon,
            spacing: 1,
          ),
          align: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        pw.SizedBox(
          height: 14,
          width: 220,
          child: pw.CustomPaint(
            painter: (PdfGraphics g, PdfPoint s) =>
                Ornament.divider(g, 110, 7, 100),
          ),
        ),
        pw.SizedBox(height: 10),
        kit.text(
          b.name,
          style: kit.style(kit.fonts.serif, 30, color: Pal.ink, spacing: 1),
          align: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 16),
        line('जन्म तिथि', Hi.localDate(b.localDateTime)),
        line(
          'जन्म समय',
          '${Hi.clock(b.localDateTime)} बजे${b.timeIsApproximate ? ' (अनुमानित)' : ''}',
        ),
        line('जन्म स्थान', b.place.name),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: Pal.gold, width: 0.8),
            color: Pal.parchment,
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              _fact(kit, 'लग्न', Hi.sign(k.lagnaRashi)),
              pw.SizedBox(width: 22),
              _fact(kit, 'चंद्र राशि', Hi.sign(moon.rashi)),
              pw.SizedBox(width: 22),
              _fact(
                kit,
                'नक्षत्र',
                '${moon.nakshatra.hindi} · पाद ${moon.pada}',
              ),
            ],
          ),
        ),
        pw.Spacer(),
        kit.text(
          'कुंडलीसार द्वारा आपके उपकरण पर तैयार · ${Hi.localDate(now)}',
          style: kit.style(
            kit.fonts.regular,
            8.6,
            color: Pal.inkSoft,
            spacing: 1,
          ),
          align: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 112),
      ],
    ),
  );
}

pw.Widget _fact(Kit kit, String label, String value) => pw.Column(
  mainAxisSize: pw.MainAxisSize.min,
  children: <pw.Widget>[
    kit.text(
      label,
      style: kit.style(kit.fonts.regular, 8.6, color: Pal.gold, spacing: 1),
      align: pw.TextAlign.center,
    ),
    pw.SizedBox(height: 1),
    kit.text(
      value,
      style: kit.style(kit.fonts.semi, 12, color: Pal.maroon, spacing: 1),
      align: pw.TextAlign.center,
    ),
  ],
);

/// The contents, and how to read the book.
List<pw.Widget> contentsPage(Kit kit, KundliPdfData d) {
  final BirthData b = d.kundli.birth;
  return <pw.Widget>[
    kit.sectionTitle(
      id: 'contents',
      number: 'प्रारंभ',
      title: 'विषय-सूची',
      subtitle: 'हर शीर्षक पर दबाने से वहीं पहुँचा जा सकता है',
    ),
    for (final SectionEntry e in sectionEntries)
      kit.contentsLine(e.id, e.number, e.title),
    kit.gap(14),
    kit.h2('इस जन्म पत्रिका को कैसे पढ़ें'),
    kit.bullets(<String>[
      'यह पत्रिका आपकी जन्म तिथि, समय और स्थान से, आपके अपने उपकरण पर ही बनी है। कोई जानकारी कहीं भेजी नहीं गई।',
      'हर फल के साथ \'आधार\' दिया है, यानी कुंडली के वे कारक जिनसे वह बात कही गई है। कारकों को पढ़कर आप स्वयं देख सकते हैं कि बात कहाँ से आई।',
      'जहाँ कोई दोष या कठिनाई दिखी है, वहाँ उसके साथ उसका परिहार या उपाय भी लिखा है। उपाय मंत्र, व्रत, दान और सरल आचरण के हैं; इनके लिए कुछ भी मोल नहीं देना पड़ता।',
      'जहाँ ग्रंथ एकमत नहीं हैं, वहाँ दोनों मत और उनके तर्क \'दो मत\' में रखे गए हैं, और इस कुंडली पर दोनों की गणना भी।',
    ], style: kit.body),
    kit.gap(8),
    kit.h3('चिह्न'),
    pw.Wrap(
      spacing: 10,
      runSpacing: 6,
      children: <pw.Widget>[
        kit.chip('अनुकूल', tone: ToneLook.supportive),
        kit.chip('मिला-जुला', tone: ToneLook.mixed),
        kit.chip('परिश्रम माँगता है', tone: ToneLook.demanding),
      ],
    ),
    kit.gap(6),
    kit.note(
      'यह चिह्न किसी फ़ैसले का नहीं, उस समय के स्वभाव का है। \'परिश्रम माँगता है\' का अर्थ केवल इतना है कि वह समय मेहनत और धैर्य माँगता है।',
    ),
    kit.h3('संकेत की पट्टी'),
    kit.para(
      'हर फल के आगे \'प्रबल\', \'मध्यम\', \'हल्का\' या \'मिला-जुला\' संकेत लिखा है। यह केवल गिनती है कि कुंडली के कितने अलग-अलग कारक उस फल से सहमत हैं। यह इस ऐप की अपनी गिनती है; यह कोई शास्त्रीय माप नहीं है, और किसी बात के घटने का अनुमान भी नहीं। कारक आपस में थोड़े जुड़े हुए हैं, इसलिए प्रबल संकेत भी एक मज़बूत इशारा भर है, वादा नहीं।',
    ),
    kit.h3('यह पत्रिका क्या है'),
    kit.para(
      'यह परंपरागत पराशरी पद्धति पर आधारित जीवन के क्षेत्रों और समय के स्वभाव का वर्णन है। इसमें किसी घटना, तिथि-विशेष या परिणाम की भविष्यवाणी नहीं है। जो विषय इस ऐप में जानबूझकर नहीं पढ़े जाते, उन पर यहाँ कुछ नहीं कहा गया है।',
    ),
    if (b.timeIsApproximate)
      kit.para(
        'आपने जन्म का समय अनुमानित बताया है। चंद्र, नक्षत्र और दशा भरोसेमंद रहेंगे; लग्न और भाव बदल सकते हैं, और दशाओं की तिथियाँ कुछ महीने खिसक सकती हैं।',
      ),
  ];
}

/// जन्म विवरण.
List<pw.Widget> birthSection(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final BirthData b = k.birth;
  final PlacedGraha moon = k.grahas[Graha.moon]!;
  final PlacedGraha sun = k.grahas[Graha.sun]!;
  final NakshatraInfo nak = moon.nakshatra;
  final DashaPeriod first = k.vimshottari.first;
  final double balanceDays = first.endJdUt - first.startJdUt;
  final int y = (balanceDays / vimshottariYear).floor();
  final double restDays = balanceDays - y * vimshottariYear;
  final int m = (restDays / (vimshottariYear / 12)).floor();
  final int dd = (restDays - m * (vimshottariYear / 12)).round();

  String latLon() {
    final double la = b.place.latitude;
    final double lo = b.place.longitude;
    return '${la.abs().toStringAsFixed(2)}° ${la >= 0 ? 'उत्तर' : 'दक्षिण'}, '
        '${lo.abs().toStringAsFixed(2)}° ${lo >= 0 ? 'पूर्व' : 'पश्चिम'}';
  }

  String zone() {
    final int mins = b.utcOffset.inMinutes;
    final String sign = mins >= 0 ? '+' : '-';
    final int a = mins.abs();
    return 'यूटीसी $sign${a ~/ 60}:${(a % 60).toString().padLeft(2, '0')}';
  }

  return <pw.Widget>[
    kit.sectionTitle(
      id: 'birth',
      number: 'भाग १',
      title: 'जन्म विवरण',
      subtitle: 'जिस क्षण से यह कुंडली बनी',
    ),
    kit.h2('जन्म का क्षण'),
    kit.kv('नाम', b.name, strong: true),
    if (b.gender != null && b.gender!.trim().isNotEmpty)
      kit.kv('लिंग', switch (b.gender!.trim().toLowerCase()) {
        'male' || 'm' => 'पुरुष',
        'female' || 'f' => 'स्त्री',
        _ => b.gender!.trim(),
      }),
    kit.kv('जन्म तिथि', Hi.localDate(b.localDateTime)),
    kit.kv(
      'जन्म समय',
      '${Hi.clock(b.localDateTime)} बजे${b.timeIsApproximate ? ' (अनुमानित)' : ''}',
    ),
    kit.kv('जन्म स्थान', b.place.name),
    kit.kv('अक्षांश · देशांतर', latLon()),
    kit.kv('समय-क्षेत्र', zone()),
    kit.kv('अयनांश', '${Hi.ayanamsa(k.ayanamsa)} · ${Hi.dms(k.ayanamsaValue)}'),
    kit.gap(6),
    kit.h2('मुख्य बातें'),
    kit.kv(
      'लग्न',
      '${Hi.sign(k.lagnaRashi)} · ${Hi.dms(k.ascendant % 30)}',
      strong: true,
    ),
    kit.kv('लग्न स्वामी', Hi.graha(rashiInfo(k.lagnaRashi).lord)),
    kit.kv(
      'चंद्र राशि',
      '${Hi.sign(moon.rashi)} · ${Hi.dms(moon.degreesInSign)}',
      strong: true,
    ),
    kit.kv('जन्म नक्षत्र', '${nak.hindi} · पाद ${moon.pada}', strong: true),
    kit.kv('नक्षत्र स्वामी', Hi.graha(nak.lord)),
    kit.kv('नक्षत्र देवता', nak.deityHindi),
    kit.kv(
      'सूर्य राशि',
      '${Hi.sign(sun.rashi)} · ${Hi.dms(sun.degreesInSign)}',
    ),
    kit.kv(
      'जन्म के समय दशा',
      '${Hi.graha(first.lord)} महादशा, शेष $y वर्ष $m माह $dd दिन',
    ),
    kit.gap(6),
    ..._atAGlance(kit, d),
    if (b.timeIsApproximate)
      kit.note(
        'जन्म का समय अनुमानित है। चंद्र, नक्षत्र और दशा भरोसेमंद रहेंगे; लग्न और भाव बदल सकते हैं।',
      ),
    kit.note(
      'ग्रहों की स्थितियाँ इस ऐप के अपने गणित से बनी हैं, जो JPL DE440s की तुलना में लगभग एक विकला तक सटीक है। निरयण राशि चक्र ऊपर लिखे अयनांश से लिया गया है।',
    ),
  ];
}

/// "एक नज़र में": where the person stands today, and what stands out in the
/// chart. Every line is something the later parts say in full.
List<pw.Widget> _atAGlance(Kit kit, KundliPdfData d) {
  final Kundli k = d.kundli;
  final Duration zone = d.zone;
  final List<DashaPeriod> chain = k.dashaChainAt(d.now);
  final TimelineWindow? window = d.phala.timeline.windowAt(d.now);
  const List<String> levels = <String>['महादशा', 'अंतर्दशा', 'प्रत्यंतर्दशा'];
  final Map<Graha, BalaBreakdown> bala = d.phala.context.bala;
  final List<Graha> byStrength = <Graha>[...shadbalaGrahas]
    ..sort((Graha a, Graha b) => bala[b]!.ratio.compareTo(bala[a]!.ratio));
  final List<String> yogas = <String>[
    for (final YogaFinding f in d.yogas)
      if (!f.isDosha && !kit.isRefused(f.nameHindi, yoga: true)) f.nameHindi,
  ];
  final List<String> doshas = <String>[
    for (final YogaFinding f in d.yogas)
      if (f.isDosha && !kit.isRefused(f.nameHindi, yoga: true)) f.nameHindi,
  ];
  final String? headline = window == null ? null : clean(kit, window.headline);

  return <pw.Widget>[
    kit.h2('एक नज़र में'),
    if (chain.isNotEmpty) ...<pw.Widget>[
      kit.text(
        '${Hi.localDate(d.now.toUtc().add(zone))} के अनुसार अभी की दशाएँ',
        style: kit.small,
      ),
      kit.gap(3),
      for (int i = 0; i < chain.length; i++)
        kit.kv(
          levels[i],
          '${Hi.graha(chain[i].lord)} · ${Hi.date(chain[i].end, zone)} तक',
          strong: i == 0,
        ),
    ],
    if (window != null && headline != null) ...<pw.Widget>[
      kit.gap(3),
      toneChips(kit, window.tone, window.indication),
      kit.gap(3),
      kit.para(headline, style: kit.bodyStrong),
    ],
    kit.kv(
      'साढ़ेसाती',
      d.sadeSati.isRunning
          ? 'चल रही है, ${const <String>['', 'पहला', 'दूसरा', 'तीसरा'][d.sadeSati.phase.clamp(0, 3)]} चरण'
          : 'अभी नहीं चल रही',
    ),
    kit.gap(4),
    kit.bullets(<String>[
      if (yogas.isNotEmpty) 'योग: ${yogas.join(', ')}',
      if (doshas.isNotEmpty)
        'दोष: ${doshas.join(', ')} (हर एक का परिहार या उपाय \'योग और दोष\' भाग में है)',
      'षड्बल में सबसे आगे: ${Hi.graha(byStrength.first)} (${bala[byStrength.first]!.totalRupas.toStringAsFixed(1)} रूप)',
      'षड्बल में सबसे पीछे: ${Hi.graha(byStrength.last)} (${bala[byStrength.last]!.totalRupas.toStringAsFixed(1)} रूप, चाहिए ${bala[byStrength.last]!.requiredRupas})',
    ], style: kit.body),
    kit.gap(6),
  ];
}
