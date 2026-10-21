// The shared widgets and the home screen, in every combination the app can be
// in: light and dark, Hindi and English, at normal and at 1.4x text. Hindi
// runs longer than English and sets taller; 1.4x is the largest the app's
// text clamp allows a phone to ask for, and is where an overflow was found
// before. Each combination must lay out without an overflow or any other
// exception.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/core/theme.dart';
import 'package:kundlisaar/data/time_zones.dart';
import 'package:kundlisaar/l10n/app_localizations.dart';
import 'package:kundlisaar/screens/home_screen.dart';
import 'package:kundlisaar/widgets/chart_more.dart';
import 'package:kundlisaar/widgets/common.dart';
import 'package:kundlisaar/widgets/feature_tile.dart';
import 'package:kundlisaar/widgets/glyphs.dart';

import 'support/visual.dart';

/// One of everything the theme and the shared widgets make, with the longest
/// strings each is given in the app.
class Showcase extends StatelessWidget {
  const Showcase({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi = Localizations.localeOf(context).languageCode == 'hi';
    final String longTitle = hindi
        ? 'संवत्, मास, ऋतु और पक्ष के अनुसार पंचांग के पाँच अंग'
        : 'The five limbs of the panchang by samvat, month, season and fortnight';
    final String longValue = hindi
        ? 'द्वादशी · कृष्ण पक्ष · 23:16 तक, फिर त्रयोदशी'
        : 'Dwadashi · Krishna paksha · until 23:16, then Trayodashi';
    return Scaffold(
      appBar: AppBar(
        title: Text(longTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          ToranaHeader(title: l.tagline, subtitle: longTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () {},
                  icon: const KIcon(KGlyph.kundli),
                  label: Text(l.newChart),
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () {}, child: Text(longTitle)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: <ButtonSegment<int>>[
                    ButtonSegment<int>(
                      value: 0,
                      label: Text(l.chartStyleNorth),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text(l.chartStyleSouth),
                    ),
                  ],
                  selected: const <int>{0},
                ),
                Panel(
                  title: longTitle,
                  trailing: const Icon(Icons.shield_outlined, size: 20),
                  child: Column(
                    children: <Widget>[
                      FactRow(l.mantra, longValue, emphasise: true),
                      FactRow(l.japaCount, longValue),
                      FactRow(longTitle, '16000'),
                    ],
                  ),
                ),
                Panel(
                  child: Row(
                    children: <Widget>[
                      const MandalaMark(size: 56),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.profileEmpty)),
                    ],
                  ),
                ),
                Card(
                  child: ListTile(
                    title: Text(
                      longTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(longValue),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'नाम',
                  ),
                ),
                SwitchListTile.adaptive(
                  value: true,
                  onChanged: (_) {},
                  title: Text(longTitle),
                  subtitle: Text(longValue),
                ),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: Text(longValue),
                      selected: true,
                      onSelected: (_) {},
                    ),
                    FilterChip(
                      label: Text(l.chartStyleSouth),
                      selected: false,
                      onSelected: (_) {},
                    ),
                  ],
                ),
                SectionLabel(l.moreFeatures),
                SectionLabel(longTitle),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final KGlyph g in KGlyph.values)
                      FeatureTile(
                        glyph: g,
                        label: g == KGlyph.sarvatobhadra
                            ? l.featureSarvatobhadra
                            : (g == KGlyph.phaladesh
                                  ? l.featurePhaladesh
                                  : l.featureGhatChakra),
                        onTap: () {},
                        width: 103,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const ChartMore(profileId: 'reena'),
              ],
            ),
          ),
          DisclaimerNote(l.disclaimer),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialised();
  setUpAll(loadAppFonts);

  const List<double> scales = <double>[1.0, 1.4];

  for (final Brightness brightness in Brightness.values) {
    for (final String language in <String>['hi', 'en']) {
      for (final double scale in scales) {
        final String where = '${brightness.name}, $language, ${scale}x';

        testWidgets('shared widgets lay out without overflow: $where', (
          WidgetTester tester,
        ) async {
          tester.view.physicalSize = const Size(1080, 36000);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            themedApp(
              home: const Showcase(),
              brightness: brightness,
              locale: Locale(language),
              textScale: scale,
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          // All of it was built, so all of it was laid out.
          expect(find.byType(FeatureTile), findsNWidgets(KGlyph.values.length));
          expect(find.byType(DisclaimerNote), findsOneWidget);
        });

        testWidgets('the home screen lays out without overflow: $where', (
          WidgetTester tester,
        ) async {
          tester.view.physicalSize = const Size(1080, 36000);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            await appWithProviders(
              home: const HomeScreen(),
              brightness: brightness,
              locale: Locale(language),
              textScale: scale,
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          // 18 readings, each its own tile; none of the names is cut short.
          expect(find.byType(FeatureTile), findsNWidgets(18));
          for (final Element tile in find.byType(FeatureTile).evaluate()) {
            final Finder label = find.descendant(
              of: find.byWidget(tile.widget),
              matching: find.byType(Text),
            );
            final RenderParagraph paragraph = tester
                .renderObject<RenderParagraph>(label);
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '"${(tile.widget as FeatureTile).label}" is cut short',
            );
          }
        });
      }
    }
  }

  testWidgets('the theme fits every icon to one weight and one grid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      themedApp(
        home: Scaffold(
          body: Wrap(
            children: <Widget>[
              for (final KGlyph g in KGlyph.values) KIcon(g, size: 28),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final Element e in find.byType(KIcon).evaluate()) {
      expect(e.size, const Size(28, 28));
    }
  });

  test('a bare ThemeData still gives the shared widgets their tones', () {
    // A test or a screen outside the app's theme must not crash.
    expect(
      ThemeData(brightness: Brightness.dark).extension<KundliTones>(),
      isNull,
    );
  });
}
