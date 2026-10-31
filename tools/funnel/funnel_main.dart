// The "आपका अच्छा समय" landing page's engine: the app's own Dart, compiled to
// JavaScript with dart2js, so the page computes the kundli and makes the PDF
// in the visitor's browser without loading the whole Flutter app.
//
// It exposes two functions on `globalThis`:
//
//   ksCompute(birthJson) -> JSON string with the chart summary and the plain
//     answer to "when is my good time".
//   ksPdf(birthJson, password, regular, semiBold, tiro, yatra) -> Promise of
//     the encrypted PDF bytes. The four arguments after the password are the
//     font files as Uint8Arrays.
//
// birthJson: {"name","date":"YYYY-MM-DD","time":"HH:MM","timeApprox":bool,
//             "place":{"name","lat","lon","tz"}}
//
// Build: dart compile js -O2 tools/funnel/funnel_main.dart -o funnel.js

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:kundlisaar/ask/ask_context.dart';
import 'package:kundlisaar/ask/ask_story.dart';
import 'package:kundlisaar/data/time_zones.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/astro/ephemeris.dart';
import 'package:kundlisaar/engine/astro/houses.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/engine/jyotish/dasha.dart';
import 'package:kundlisaar/engine/jyotish/graha_data.dart';
import 'package:kundlisaar/engine/jyotish/rashi.dart';
import 'package:kundlisaar/kundli_pdf/kundli_pdf.dart';

@JS('ksCompute')
external set _ksCompute(JSFunction f);

@JS('ksPdf')
external set _ksPdf(JSFunction f);

void main() {
  _ksCompute = _compute.toJS;
  _ksPdf = _pdf.toJS;
}

BirthData _birth(String json) {
  final Map<String, dynamic> m = jsonDecode(json) as Map<String, dynamic>;
  final List<int> d = (m['date'] as String).split('-').map(int.parse).toList();
  final List<int> t = (m['time'] as String).split(':').map(int.parse).toList();
  final Map<String, dynamic> p = m['place'] as Map<String, dynamic>;
  final DateTime local = DateTime(d[0], d[1], d[2], t[0], t[1]);
  final String zone = (p['tz'] as String?) ?? 'Asia/Kolkata';
  return BirthData(
    name: (m['name'] as String?)?.trim() ?? '',
    localDateTime: local,
    utcOffset: TimeZones.offsetFor(zone, local),
    place: GeoPlace(
      name: p['name'] as String,
      latitude: (p['lat'] as num).toDouble(),
      longitude: (p['lon'] as num).toDouble(),
      timeZoneId: zone,
    ),
    timeIsApproximate: m['timeApprox'] == true,
  );
}

String _isoDate(DateTime utc, Duration zone) {
  final DateTime l = utc.add(zone);
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

String _compute(String birthJson) {
  final BirthData birth = _birth(birthJson);
  final Kundli k = computeKundli(birth);
  final DateTime now = DateTime.now();
  final PlacedGraha moon = k.grahas[Graha.moon]!;
  final PlacedGraha sun = k.grahas[Graha.sun]!;
  final List<DashaPeriod> chain = k.dashaChainAt(now);
  final Duration zone = birth.utcOffset;

  final AskCtx c = AskCtx(k, now, true);
  final List<String> answer =
      composeStory(c, titleEn: '', titleHi: '').short?.paragraphs ??
      const <String>[];

  Map<String, String>? period(int i) => chain.length > i
      ? <String, String>{
          'lord': grahaInfo(chain[i].lord).hindi,
          'end': _isoDate(chain[i].end, zone),
        }
      : null;

  return jsonEncode(<String, Object?>{
    'lagna': rashiInfo(k.lagnaRashi).hindi,
    'rashi': rashiInfo(moon.rashi).hindi,
    'sunSign': rashiInfo(sun.rashi).hindi,
    'nakshatra': moon.nakshatra.hindi,
    'pada': moon.pada,
    'nakshatraLord': grahaInfo(moon.nakshatra.lord).hindi,
    'mahadasha': period(0),
    'antardasha': period(1),
    'answer': answer,
    'utcOffsetMinutes': zone.inMinutes,
    'ayanamsa': k.ayanamsaValue,
    'grahas': <Map<String, Object>>[
      for (final Graha g in Graha.values)
        <String, Object>{
          'graha': grahaInfo(g).hindi,
          'sign': rashiInfo(k.grahas[g]!.rashi).hindi,
          'degree': double.parse(
            k.grahas[g]!.degreesInSign.toStringAsFixed(2),
          ),
          'house': k.grahas[g]!.house,
          'retro': k.grahas[g]!.isRetrograde,
        },
    ],
  });
}

JSPromise<JSUint8Array> _pdf(
  String birthJson,
  String password,
  JSUint8Array regular,
  JSUint8Array semiBold,
  JSUint8Array tiro,
  JSUint8Array yatra,
) {
  Future<JSUint8Array> run() async {
    final KundliPdfResult r = await buildKundliPdf(
      KundliPdfRequest(
        birth: _birth(birthJson),
        ayanamsa: Ayanamsa.lahiri,
        now: DateTime.now(),
        fonts: KundliPdfFontBytes(
          regular: regular.toDart,
          semiBold: semiBold.toDart,
          tiro: tiro.toDart,
          yatra: yatra.toDart,
        ),
        password: password,
      ),
      // Let the page breathe between sections so its spinner keeps turning.
      yieldToUi: () => Future<void>.delayed(Duration.zero),
    );
    return Uint8List.fromList(r.bytes).toJS;
  }

  return run().toJS;
}
