import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/kundli_ground.dart';

/// The palette comes from folk and temple painting rather than the cosmic
/// purple every astrology app wears: kumkum and wine on a warm parchment,
/// marigold used as the one bright accent, and a lapis indigo for the quiet
/// work of icons and information.
///
/// It is built in roles rather than as a list of favourites, so each colour
/// has one job and the screen has a hierarchy:
///
///  * **ink** is for reading; **ink soft** is for what supports it.
///  * **maroon** (the primary) is for what you can press, and nothing else.
///  * **marigold** (the accent) is ornament and emphasis: never text.
///  * **indigo** (the secondary) is the colour of icons and the small print
///    of data.
///  * **parchment** is the ground; **ivory** is what is raised off it.
///
/// Every text colour here is checked against the surface it is set on in
/// `test/theme_contrast_test.dart`.
class Palette {
  // Day.
  static const Color parchment = Color(0xFFF6EEE2);
  static const Color parchmentDeep = Color(0xFFEADFCD);
  static const Color parchmentGlow = Color(0xFFFCF6EA);
  static const Color ivory = Color(0xFFFFFCF6);
  static const Color ivoryWash = Color(0xFFFAF2E3);
  static const Color ink = Color(0xFF1A1210);
  static const Color inkSoft = Color(0xFF5A4A42);
  static const Color maroon = Color(0xFF7B1E32);
  static const Color indigo = Color(0xFF2B3878);
  static const Color indigoWash = Color(0xFFE6E9F7);
  static const Color haldi = Color(0xFFE8A010);
  static const Color haldiWash = Color(0xFFFBE9C6);

  /// Marigold dark enough to be read as text: it is the accent's text colour.
  static const Color gold = Color(0xFF8A5600);
  static const Color sindoor = Color(0xFFB8281F);
  static const Color tulsi = Color(0xFF2F6B4F);
  static const Color outline = Color(0xFF8A7A66);
  static const Color outlineSoft = Color(0xFFE2D4BC);

  // Night.
  static const Color nightGround = Color(0xFF0F1330);
  static const Color nightGlow = Color(0xFF1B2166);
  static const Color nightSurface = Color(0xFF181D47);
  static const Color nightWash = Color(0xFF1F2552);
  static const Color nightRaised = Color(0xFF262D62);
  static const Color nightParchment = Color(0xFFF4ECDA);
  static const Color nightInkSoft = Color(0xFFB9B8D2);
  static const Color nightGold = Color(0xFFF2B544);
  static const Color nightPeriwinkle = Color(0xFFB4C2FF);
  static const Color nightCoral = Color(0xFFFF9E80);
  static const Color nightOutline = Color(0xFF6E78B8);
  static const Color nightOutlineSoft = Color(0xFF2E3672);
}

/// The colours the app's own widgets need that a [ColorScheme] has no slot
/// for. Read it with [KundliTones.of].
@immutable
class KundliTones extends ThemeExtension<KundliTones> {
  const KundliTones({
    required this.ground,
    required this.glow,
    required this.motif,
    required this.motifAlpha,
    required this.card,
    required this.cardBorder,
    required this.wash,
    required this.accent,
    required this.accentWash,
    required this.accentText,
    required this.glyph,
    required this.glyphAccent,
    required this.plate,
    required this.softInk,
    required this.shadow,
  });

  /// The page.
  final Color ground;

  /// What the top of the page glows towards.
  final Color glow;

  /// The colour of the kundli drawn across the ground, and its opacity on
  /// the home screen (reading screens use a fixed fraction of it).
  final Color motif;
  final double motifAlpha;

  /// A raised surface, its edge, and a quieter inset one.
  final Color card;
  final Color cardBorder;
  final Color wash;

  /// The accent: a fill or an ornament, never text.
  final Color accent;

  /// A tint of the accent, to sit behind an icon or mark a selection.
  final Color accentWash;

  /// The accent dark enough to be read as text on a card or the ground.
  final Color accentText;

  /// The stroke and accent of the app's own icons.
  final Color glyph;
  final Color glyphAccent;

  /// What an icon sits on.
  final Color plate;

  /// Secondary text as a solid colour (the tint screens use is ink at 60%).
  final Color softInk;

  /// The colour a raised surface casts.
  final Color shadow;

  static const KundliTones day = KundliTones(
    ground: Palette.parchment,
    glow: Palette.parchmentGlow,
    motif: Palette.maroon,
    motifAlpha: 0.10,
    card: Palette.ivory,
    cardBorder: Color(0xFFE6D8BF),
    wash: Palette.ivoryWash,
    accent: Palette.haldi,
    accentWash: Palette.haldiWash,
    accentText: Palette.gold,
    glyph: Palette.indigo,
    glyphAccent: Color(0xFFE59A0A),
    plate: Palette.haldiWash,
    softInk: Palette.inkSoft,
    shadow: Color(0xFF5B3A14),
  );

  static const KundliTones night = KundliTones(
    ground: Palette.nightGround,
    glow: Palette.nightGlow,
    motif: Palette.nightGold,
    motifAlpha: 0.07,
    card: Palette.nightSurface,
    cardBorder: Palette.nightOutlineSoft,
    wash: Palette.nightWash,
    accent: Palette.nightGold,
    accentWash: Color(0xFF3A3358),
    accentText: Palette.nightGold,
    glyph: Palette.nightPeriwinkle,
    glyphAccent: Palette.nightGold,
    plate: Color(0xFF262D63),
    softInk: Palette.nightInkSoft,
    shadow: Color(0xFF000000),
  );

  /// The tones of [theme], or the ones for its brightness when the theme did
  /// not come from [buildTheme] (a bare `ThemeData` in a test).
  static KundliTones of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.extension<KundliTones>() ??
        (theme.brightness == Brightness.dark ? night : day);
  }

  @override
  KundliTones copyWith({
    Color? ground,
    Color? glow,
    Color? motif,
    double? motifAlpha,
    Color? card,
    Color? cardBorder,
    Color? wash,
    Color? accent,
    Color? accentWash,
    Color? accentText,
    Color? glyph,
    Color? glyphAccent,
    Color? plate,
    Color? softInk,
    Color? shadow,
  }) => KundliTones(
    ground: ground ?? this.ground,
    glow: glow ?? this.glow,
    motif: motif ?? this.motif,
    motifAlpha: motifAlpha ?? this.motifAlpha,
    card: card ?? this.card,
    cardBorder: cardBorder ?? this.cardBorder,
    wash: wash ?? this.wash,
    accent: accent ?? this.accent,
    accentWash: accentWash ?? this.accentWash,
    accentText: accentText ?? this.accentText,
    glyph: glyph ?? this.glyph,
    glyphAccent: glyphAccent ?? this.glyphAccent,
    plate: plate ?? this.plate,
    softInk: softInk ?? this.softInk,
    shadow: shadow ?? this.shadow,
  );

  @override
  KundliTones lerp(ThemeExtension<KundliTones>? other, double t) {
    if (other is! KundliTones) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return KundliTones(
      ground: mix(ground, other.ground),
      glow: mix(glow, other.glow),
      motif: mix(motif, other.motif),
      motifAlpha: motifAlpha + (other.motifAlpha - motifAlpha) * t,
      card: mix(card, other.card),
      cardBorder: mix(cardBorder, other.cardBorder),
      wash: mix(wash, other.wash),
      accent: mix(accent, other.accent),
      accentWash: mix(accentWash, other.accentWash),
      accentText: mix(accentText, other.accentText),
      glyph: mix(glyph, other.glyph),
      glyphAccent: mix(glyphAccent, other.glyphAccent),
      plate: mix(plate, other.plate),
      softInk: mix(softInk, other.softInk),
      shadow: mix(shadow, other.shadow),
    );
  }
}

/// The type scale.
///
/// Mukta carries the interface and the body; Tiro Devanagari Hindi, the
/// printed-book face, carries the voice: the wordmark, headlines and screen
/// titles. Both cover Devanagari and Latin, so Hindi and English sit at the
/// same size and the same colour with no fallback face in between.
///
/// Devanagari needs more room than Latin. Mukta's own line is 1.66 em tall
/// (its ascent is 1.13 em, to clear the stacked vowel signs above the
/// headline bar) so body text is set at 1.6 and titles at no less than 1.45:
/// tighter than that and the signs of one line touch the descenders of the
/// one above. Tiro's Devanagari reaches 1.09 em above its baseline against
/// the 0.76 em it reports, so its headlines get 1.45 as well.
TextTheme _textTheme(Color ink) {
  const String body = 'Mukta';
  const String voice = 'Tiro';
  const List<String> mukta = <String>[body];

  return TextTheme(
    displayLarge: const TextStyle(
      fontFamily: voice,
      fontFamilyFallback: mukta,
      fontSize: 40,
      height: 1.3,
    ),
    displayMedium: const TextStyle(
      fontFamily: voice,
      fontFamilyFallback: mukta,
      fontSize: 34,
      height: 1.3,
    ),
    // The wordmark in the home app bar.
    displaySmall: const TextStyle(
      fontFamily: voice,
      fontFamilyFallback: mukta,
      fontSize: 28,
      height: 1.3,
    ),
    headlineLarge: const TextStyle(
      fontFamily: voice,
      fontFamilyFallback: mukta,
      fontSize: 26,
      height: 1.45,
    ),
    // The headline of a reading (ToranaHeader).
    headlineMedium: const TextStyle(
      fontFamily: voice,
      fontFamilyFallback: mukta,
      fontSize: 22,
      height: 1.45,
    ),
    headlineSmall: const TextStyle(
      fontFamily: voice,
      fontFamilyFallback: mukta,
      fontSize: 20,
      height: 1.45,
    ),
    // Screen titles in the app bar.
    titleLarge: const TextStyle(
      fontFamily: voice,
      fontFamilyFallback: mukta,
      fontSize: 22,
      height: 1.4,
    ),
    // Panel titles, names in a list.
    titleMedium: const TextStyle(
      fontFamily: body,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.45,
    ),
    // Section labels.
    titleSmall: const TextStyle(
      fontFamily: body,
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      height: 1.45,
      letterSpacing: 0.1,
    ),
    bodyLarge: const TextStyle(fontFamily: body, fontSize: 18, height: 1.6),
    bodyMedium: const TextStyle(fontFamily: body, fontSize: 17, height: 1.6),
    bodySmall: const TextStyle(fontFamily: body, fontSize: 14.5, height: 1.55),
    labelLarge: const TextStyle(
      fontFamily: body,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    labelMedium: const TextStyle(
      fontFamily: body,
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      height: 1.45,
      letterSpacing: 0.1,
    ),
    labelSmall: const TextStyle(
      fontFamily: body,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.45,
      letterSpacing: 0.2,
    ),
  ).apply(bodyColor: ink, displayColor: ink);
}

ThemeData buildTheme({required Brightness brightness}) {
  final bool dark = brightness == Brightness.dark;
  final KundliTones tones = dark ? KundliTones.night : KundliTones.day;

  final Color ink = dark ? Palette.nightParchment : Palette.ink;
  final Color primary = dark ? Palette.nightGold : Palette.maroon;
  final Color onPrimary = dark ? const Color(0xFF1B1330) : Palette.ivory;
  final Color secondary = dark ? Palette.nightPeriwinkle : Palette.indigo;
  final Color outline = dark ? Palette.nightOutline : Palette.outline;
  final Color outlineSoft = dark
      ? Palette.nightOutlineSoft
      : Palette.outlineSoft;

  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: dark ? const Color(0xFF4A3B1E) : const Color(0xFFF5DCD9),
    onPrimaryContainer: dark
        ? const Color(0xFFFFE2A6)
        : const Color(0xFF4A0E1C),
    secondary: secondary,
    onSecondary: dark ? const Color(0xFF111A4D) : Palette.ivory,
    secondaryContainer: dark ? const Color(0xFF2A3272) : Palette.indigoWash,
    onSecondaryContainer: dark
        ? const Color(0xFFDDE3FF)
        : const Color(0xFF141C4A),
    tertiary: dark ? const Color(0xFF8FA4F0) : Palette.haldi,
    onTertiary: dark ? const Color(0xFF0E1540) : Palette.ink,
    tertiaryContainer: tones.accentWash,
    onTertiaryContainer: dark
        ? const Color(0xFFFFE2A6)
        : const Color(0xFF4A2E00),
    error: dark ? Palette.nightCoral : Palette.sindoor,
    onError: dark ? const Color(0xFF3A1200) : Palette.ivory,
    errorContainer: dark ? const Color(0xFF5A2A22) : const Color(0xFFFBE0DB),
    onErrorContainer: dark ? const Color(0xFFFFDAD1) : const Color(0xFF5C0F0A),
    surface: tones.ground,
    onSurface: ink,
    onSurfaceVariant: tones.softInk,
    surfaceDim: dark ? const Color(0xFF0B0E26) : Palette.parchmentDeep,
    surfaceBright: dark ? Palette.nightRaised : Palette.ivory,
    surfaceContainerLowest: dark ? const Color(0xFF0B0E26) : Colors.white,
    surfaceContainerLow: tones.card,
    surfaceContainer: tones.wash,
    surfaceContainerHigh: dark ? Palette.nightRaised : const Color(0xFFF3E9D8),
    surfaceContainerHighest: dark
        ? const Color(0xFF2E3669)
        : const Color(0xFFEDE1CC),
    outline: outline,
    outlineVariant: outlineSoft,
    shadow: tones.shadow,
    scrim: const Color(0xFF000000),
    inverseSurface: dark ? Palette.nightParchment : const Color(0xFF2A1D19),
    onInverseSurface: dark ? Palette.ink : Palette.parchment,
    inversePrimary: dark ? Palette.maroon : Palette.nightGold,
    surfaceTint: Colors.transparent,
  );

  final TextTheme text = _textTheme(ink);
  final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
    side: BorderSide(color: tones.cardBorder),
  );
  final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  final SystemUiOverlayStyle overlay = dark
      ? SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Palette.nightGround,
        )
      : SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Palette.parchment,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[tones],
    textTheme: text,
    // Every screen's ground is painted by KundliGround, behind the page, and
    // arrives with the page transition (see _GroundTransitionsBuilder). The
    // scaffold on top of it must therefore be clear.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: tones.card,
    pageTransitionsTheme: _groundTransitions(tones),
    iconTheme: IconThemeData(color: secondary),
    dividerColor: outlineSoft,
    splashColor: primary.withValues(alpha: 0.08),
    highlightColor: primary.withValues(alpha: 0.05),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: secondary),
      actionsIconTheme: IconThemeData(color: secondary),
      systemOverlayStyle: overlay,
    ),
    cardTheme: CardThemeData(
      elevation: dark ? 0 : 1.5,
      color: tones.card,
      shadowColor: tones.shadow.withValues(alpha: dark ? 0 : 0.55),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: cardShape,
      margin: const EdgeInsets.symmetric(vertical: 7),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        textStyle: text.labelLarge,
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: dark ? 0 : 2,
        shadowColor: dark ? Colors.transparent : primary.withValues(alpha: 0.5),
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        textStyle: text.labelLarge,
        foregroundColor: dark ? primary : Palette.maroon,
        side: BorderSide(
          color: dark ? primary.withValues(alpha: 0.7) : Palette.maroon,
          width: 1.2,
        ),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 46),
        textStyle: text.labelLarge,
        foregroundColor: dark ? primary : Palette.maroon,
        shape: buttonShape,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll<TextStyle?>(
          text.labelLarge?.copyWith(fontSize: 15.5),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 10),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: outline.withValues(alpha: 0.8)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? tones.accentWash
              : tones.card,
        ),
        foregroundColor: WidgetStatePropertyAll<Color>(ink),
        iconColor: WidgetStatePropertyAll<Color>(
          dark ? primary : Palette.maroon,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: text.bodyMedium?.copyWith(fontSize: 15.5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      backgroundColor: tones.card,
      selectedColor: tones.accentWash,
      disabledColor: tones.wash,
      checkmarkColor: dark ? primary : Palette.maroon,
      side: BorderSide(color: outline.withValues(alpha: 0.6)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: true,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: tones.card,
      labelStyle: text.bodyLarge?.copyWith(color: tones.softInk),
      floatingLabelStyle: text.bodyLarge?.copyWith(
        color: dark ? primary : Palette.maroon,
      ),
      hintStyle: text.bodyLarge?.copyWith(color: tones.softInk),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: secondary,
      textColor: ink,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: tones.softInk),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: secondary,
      collapsedIconColor: secondary,
      textColor: ink,
      collapsedTextColor: ink,
      shape: const Border(),
      collapsedShape: const Border(),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: dark ? primary : Palette.maroon,
      unselectedLabelColor: tones.softInk,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge,
      indicatorColor: tones.accent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: outlineSoft,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? onPrimary : outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? primary : tones.wash,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? primary : outline,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? primary : outline,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: outlineSoft,
      thumbColor: primary,
      overlayColor: primary.withValues(alpha: 0.12),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: tones.accentWash,
      circularTrackColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tones.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: tones.shadow,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: tones.cardBorder),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tones.card,
      modalBackgroundColor: tones.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: tones.shadow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tones.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: tones.shadow,
      elevation: 4,
      textStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tones.cardBorder),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: text.bodyLarge,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(tones.card),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: dark ? Palette.maroon : Palette.nightGold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: dark ? 0 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: tones.card,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: primary,
      headerForegroundColor: onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: tones.card,
      hourMinuteColor: tones.accentWash,
      dialBackgroundColor: tones.accentWash,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),
    dividerTheme: DividerThemeData(color: outlineSoft, space: 24, thickness: 1),
  );
}

/// Gives every screen its ground.
///
/// The scaffold of every screen is clear, so the page behind it has to be
/// there from the moment the route appears and has to travel with the page
/// while it slides or fades in, or the screen underneath would show through
/// a transition. The one place that sees every route is its transition, so
/// the ground is added there: the platform's own transition is built as it
/// always was, around a page that is now ground plus screen.
PageTransitionsTheme _groundTransitions(KundliTones tones) {
  const PageTransitionsTheme platformDefaults = PageTransitionsTheme();
  final Map<TargetPlatform, PageTransitionsBuilder> builders =
      <TargetPlatform, PageTransitionsBuilder>{
        for (final TargetPlatform platform in TargetPlatform.values)
          platform: _GroundTransitionsBuilder(
            platformDefaults.builders[platform] ??
                const ZoomPageTransitionsBuilder(),
            tones,
          ),
      };
  return PageTransitionsTheme(builders: builders);
}

class _GroundTransitionsBuilder extends PageTransitionsBuilder {
  const _GroundTransitionsBuilder(this._inner, this._tones);

  final PageTransitionsBuilder _inner;
  final KundliTones _tones;

  @override
  Duration get transitionDuration => _inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _inner.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The home screen is the route named '/': go_router names each page by
    // its path, and a bare MaterialApp calls its `home` the same. A screen
    // opened from a link, or pushed without a name, is a reading screen.
    final bool home = route.settings.name == '/';
    return _inner.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      KundliGround(
        ground: _tones.ground,
        glow: _tones.glow,
        line: _tones.motif,
        lineAlpha: _tones.motifAlpha,
        weight: home ? GroundWeight.hero : GroundWeight.reading,
        child: child,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _GroundTransitionsBuilder &&
      other._inner == _inner &&
      other._tones == _tones;

  @override
  int get hashCode => Object.hash(_inner, _tones);
}
