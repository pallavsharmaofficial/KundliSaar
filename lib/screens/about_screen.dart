import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../widgets/common.dart';

/// Where the app says what it is, who made it, and what it does with your
/// details. The two policy links are the ones the stores ask for, and they
/// point at the same pages the website serves.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String site =
      'https://pallavsharmaofficial.github.io/KundliSaar';
  static const String repository =
      'https://github.com/pallavsharmaofficial/KundliSaar';

  Future<void> _open(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(hindi ? 'निजता नीति' : 'Privacy policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open('$site/privacy.html'),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(hindi ? 'उपयोग की शर्तें' : 'Terms of use'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open('$site/terms.html'),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: Text(
                    hindi ? 'इस काम को सहयोग दें' : 'Support the work',
                  ),
                  subtitle: Text(
                    hindi
                        ? 'ऐप मुफ़्त ही रहेगा'
                        : 'The app stays free either way',
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open('$site/support.html'),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(hindi ? 'स्रोत कोड' : 'Source code'),
                  subtitle: const Text('MIT'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open(repository),
                ),
              ],
            ),
          ),
          Panel(
            title: hindi ? 'स्रोत और आभार' : 'Sources and credits',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FactRow('Ephemeris', 'NASA JPL DE440s (public domain)'),
                FactRow('Places', 'GeoNames cities15000 (CC BY 4.0)'),
                FactRow('Time zones', 'IANA tz database'),
                FactRow(
                  'Fonts',
                  'Mukta, Tiro Devanagari Hindi, Yatra One (OFL)',
                ),
                FactRow(
                  'Rule tradition',
                  'Parashari, after Brihat Parashara Hora Shastra and '
                      'Phaladeepika. How strongly each rule weighs is this '
                      "app's own convention, not theirs.",
                ),
                FactRow('Version', '0.2.0'),
              ],
            ),
          ),
          DisclaimerNote(l.disclaimer),
        ],
      ),
    );
  }
}
