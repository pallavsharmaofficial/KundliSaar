// The palette's contrast, pinned.
//
// Every pair below is a text colour on the surface the app actually sets it
// on, or (for icons, borders and the accent) a non-text colour on its ground.
// WCAG 2.x AA asks 4.5:1 for body text, 3:1 for large text and for the
// parts of a control a person needs to see. Each row carries its own floor,
// which is the figure the report quotes: if a colour is ever changed so that
// a pair drops below it, this fails and says which.
//
// The 60 to 70 percent "tints" are here because the screens do not use a
// grey for secondary text: they use the ink at a fraction of its opacity
// (`onSurface.withValues(alpha: 0.6)`), which no theme colour can fix after
// the fact. The ink is therefore chosen dark enough that those tints still
// pass.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/core/theme.dart';

/// WCAG 2.x contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [fg] at [alpha] over [bg], as the eye sees it.
Color tint(Color fg, Color bg, double alpha) =>
    Color.alphaBlend(fg.withValues(alpha: alpha), bg);

class Pair {
  const Pair(this.name, this.fg, this.bg);

  final String name;
  final Color fg;
  final Color bg;

  double get ratio => contrast(fg, bg);

  /// Icons and the edges of controls need 3:1; every piece of text, 4.5:1.
  bool get nonText =>
      name.startsWith('icon') || name.startsWith('input border');
}

/// The ratios the report quotes: what each pair achieves, rounded down to one
/// place. A colour change that lowers any of them fails the test below and
/// names the pair.
const Map<String, double> lightClaims = <String, double>{
  'ink on ground': 16.0,
  'ink on card': 18.0,
  'ink on inset wash': 16.5,
  'ink on accent wash (selected chip)': 15.4,
  'ink on sheet (dialog, picker)': 15.3,
  'ink soft on ground': 7.3,
  'ink soft on card': 8.2,
  'ink soft on inset wash': 7.5,
  'ink soft on accent wash': 7.0,
  'ink 60% on ground': 4.6,
  'ink 60% on card': 4.7,
  'ink 65% on card': 5.6,
  'ink 70% on card': 6.7,
  'primary on ground (links, tab label)': 8.7,
  'primary on card': 9.8,
  'primary on accent wash (selected segment)': 8.4,
  'on-primary on primary (button label)': 9.8,
  'secondary on ground': 9.4,
  'secondary on card': 10.5,
  'accent text on ground (section labels)': 5.3,
  'accent text on card': 6.0,
  'error on card (inauspicious, demanding)': 6.0,
  'on-error on error': 6.0,
  'on-secondary on secondary': 10.5,
  'on-tertiary on tertiary': 8.3,
  'snackbar text on snackbar': 14.1,
  'icon stroke on icon plate': 9.0,
  'icon stroke on card': 10.5,
  'input border on card': 4.0,
  'input border on ground': 3.6,
};

const Map<String, double> darkClaims = <String, double>{
  'ink on ground': 15.4,
  'ink on card': 13.6,
  'ink on inset wash': 12.3,
  'ink on accent wash (selected chip)': 9.9,
  'ink on sheet (dialog, picker)': 10.9,
  'ink soft on ground': 9.3,
  'ink soft on card': 8.3,
  'ink soft on inset wash': 7.5,
  'ink soft on accent wash': 6.0,
  'ink 60% on ground': 6.1,
  'ink 60% on card': 5.7,
  'ink 65% on card': 6.4,
  'ink 70% on card': 7.3,
  'primary on ground (links, tab label)': 9.9,
  'primary on card': 8.7,
  'primary on accent wash (selected segment)': 6.3,
  'on-primary on primary (button label)': 9.6,
  'secondary on ground': 10.4,
  'secondary on card': 9.2,
  'accent text on ground (section labels)': 9.9,
  'accent text on card': 8.7,
  'error on card (inauspicious, demanding)': 8.0,
  'on-error on error': 8.2,
  'on-secondary on secondary': 9.4,
  'on-tertiary on tertiary': 7.2,
  'snackbar text on snackbar': 15.6,
  'icon stroke on icon plate': 7.3,
  'icon stroke on card': 9.2,
  'input border on card': 3.8,
  'input border on ground': 4.3,
};

List<Pair> pairsFor(Brightness brightness) {
  final ThemeData theme = buildTheme(brightness: brightness);
  final ColorScheme s = theme.colorScheme;
  final KundliTones t = theme.extension<KundliTones>()!;
  final Color ink = s.onSurface;

  return <Pair>[
    // Body text.
    Pair('ink on ground', ink, t.ground),
    Pair('ink on card', ink, t.card),
    Pair('ink on inset wash', ink, t.wash),
    Pair('ink on accent wash (selected chip)', ink, t.accentWash),
    Pair('ink on sheet (dialog, picker)', ink, s.surfaceContainerHigh),
    // Secondary text, as a solid colour and as the tint the screens use.
    Pair('ink soft on ground', t.softInk, t.ground),
    Pair('ink soft on card', t.softInk, t.card),
    Pair('ink soft on inset wash', t.softInk, t.wash),
    Pair('ink soft on accent wash', t.softInk, t.accentWash),
    Pair('ink 60% on ground', tint(ink, t.ground, 0.6), t.ground),
    Pair('ink 60% on card', tint(ink, t.card, 0.6), t.card),
    Pair('ink 65% on card', tint(ink, t.card, 0.65), t.card),
    Pair('ink 70% on card', tint(ink, t.card, 0.7), t.card),
    // Colour used as text or as a control.
    Pair('primary on ground (links, tab label)', s.primary, t.ground),
    Pair('primary on card', s.primary, t.card),
    Pair('primary on accent wash (selected segment)', s.primary, t.accentWash),
    Pair('on-primary on primary (button label)', s.onPrimary, s.primary),
    Pair('secondary on ground', s.secondary, t.ground),
    Pair('secondary on card', s.secondary, t.card),
    Pair('accent text on ground (section labels)', t.accentText, t.ground),
    Pair('accent text on card', t.accentText, t.card),
    Pair('error on card (inauspicious, demanding)', s.error, t.card),
    Pair('on-error on error', s.onError, s.error),
    Pair('on-secondary on secondary', s.onSecondary, s.secondary),
    Pair('on-tertiary on tertiary', s.onTertiary, s.tertiary),
    Pair('snackbar text on snackbar', s.onInverseSurface, s.inverseSurface),
    // Non-text: icons and the edges of controls.
    Pair('icon stroke on icon plate', t.glyph, t.plate),
    Pair('icon stroke on card', t.glyph, t.card),
    Pair('input border on card', s.outline, t.card),
    Pair('input border on ground', s.outline, t.ground),
  ];
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    final Map<String, double> claims = brightness == Brightness.dark
        ? darkClaims
        : lightClaims;
    group('contrast, ${brightness.name}', () {
      final List<Pair> pairs = pairsFor(brightness);

      test('every pair has a claim, and every claim a pair', () {
        expect(pairs.map((Pair p) => p.name).toSet(), claims.keys.toSet());
      });

      for (final Pair p in pairs) {
        test('${p.name}: at least ${claims[p.name]}:1', () {
          expect(
            p.ratio,
            greaterThanOrEqualTo(p.nonText ? 3.0 : 4.5),
            reason: 'below WCAG AA: ${p.ratio.toStringAsFixed(2)}:1',
          );
          expect(
            p.ratio,
            greaterThanOrEqualTo(claims[p.name]!),
            reason:
                '${p.name} was pinned at ${claims[p.name]}:1 and is now '
                '${p.ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });
  }

  test('the two themes use one set of roles', () {
    // The same colour must never do two jobs in one theme: primary (what you
    // press) and the accent (ornament) are different colours in both.
    for (final Brightness b in Brightness.values) {
      final ThemeData theme = buildTheme(brightness: b);
      final KundliTones t = theme.extension<KundliTones>()!;
      expect(theme.colorScheme.primary, isNot(t.accentWash));
      expect(
        contrast(theme.colorScheme.primary, t.ground),
        greaterThan(7),
        reason: 'the primary has to stand clear of the ground',
      );
    }
    expect(
      buildTheme(brightness: Brightness.light).colorScheme.primary,
      isNot(KundliTones.day.accent),
    );
  });
}
