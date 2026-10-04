import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi = Localizations.localeOf(context).languageCode == 'hi';
    return Scaffold(
      appBar: AppBar(title: Text(l.about)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          ToranaHeader(title: l.appTitle, subtitle: l.tagline),
          Panel(
            title: hindi ? 'आपकी निजता' : 'Your privacy',
            child: Text(l.privacyNote),
          ),
          Panel(
            title: hindi ? 'गणना कैसे होती है' : 'How the numbers are made',
            child: Text(
              hindi
                  ? 'ग्रहों की स्थिति इसी ऐप के भीतर, अपने गणित से बनती है। यह गणित JPL DE440s के आँकड़ों पर बिठाया गया है और 1900 से 2070 तक लगभग एक विकला तक सटीक है। कोई सर्वर नहीं, कोई API नहीं।'
                  : 'Planetary positions are computed inside the app by our own series, fitted to the public-domain JPL DE440s ephemeris and holding to about an arc-second from 1900 to 2070. No server, no API.',
            ),
          ),
          Panel(
            title: hindi ? 'स्रोत और आभार' : 'Sources and credits',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const FactRow('Ephemeris', 'NASA JPL DE440s (public domain)'),
                const FactRow('Places', 'GeoNames cities15000 (CC BY 4.0)'),
                const FactRow('Time zones', 'IANA tz database'),
                const FactRow(
                  'Fonts',
                  'Mukta, Tiro Devanagari Hindi, Yatra One (OFL)',
                ),
                const FactRow(
                  'Classical rules',
                  'Brihat Parashara Hora Shastra, Phaladeepika',
                ),
              ],
            ),
          ),
          DisclaimerNote(l.disclaimer),
        ],
      ),
    );
  }
}
