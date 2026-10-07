import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/jyotish/chart.dart';
import '../engine/jyotish/rashi.dart';
import '../engine/jyotish/sudarshan.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Sudarshana Chakra: each of the twelve houses read from the Lagna, the Moon
/// and the Sun at once. A house that stands well from all three is the
/// tradition's mark of a reliably good area of life.
class SudarshanScreen extends StatelessWidget {
  const SudarshanScreen({super.key, this.profileId});

  final String? profileId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    return ChartScaffold(
      title: hindi ? 'सुदर्शन चक्र' : 'Sudarshan Chakra',
      profileId: profileId,
      builder: (BuildContext context, Kundli kundli, _) =>
          DeferredBuilder<SudarshanChakra>(
            message: l.computing,
            work: () => computeSudarshan(kundli),
            builder: (BuildContext context, SudarshanChakra chakra) {
              final ThemeData theme = Theme.of(context);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  ToranaHeader(
                    title: hindi ? 'सुदर्शन चक्र' : 'Sudarshan Chakra',
                    subtitle: hindi
                        ? 'हर भाव लग्न, चंद्र और सूर्य, तीनों से एक साथ पढ़ा गया।'
                        : 'Every house read from the Lagna, the Moon and the Sun at once.',
                  ),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Center(
                          child: _Wheel(
                            chakra: chakra,
                            hindi: hindi,
                            size: 300,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Legend(hindi: hindi),
                        const SizedBox(height: 10),
                        Text(
                          hindi ? chakra.noteHindi : chakra.noteEnglish,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13.5,
                            height: 1.45,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Panel(
                    title: hindi
                        ? 'बारह भाव, तीन संदर्भ'
                        : 'Twelve houses, three references',
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Column(
                      children: <Widget>[
                        _HeaderRow(hindi: hindi),
                        for (final SudarshanHouse h in chakra.houses)
                          _SummaryRow(house: h, kundli: kundli, hindi: hindi),
                      ],
                    ),
                  ),
                  for (final SudarshanHouse h in chakra.houses)
                    _HouseCard(house: h, kundli: kundli, hindi: hindi),
                  DisclaimerNote(l.disclaimer),
                ],
              );
            },
          ),
    );
  }
}

Color _verdictColor(ThemeData theme, HouseVerdict v) => switch (v) {
  HouseVerdict.strong => theme.colorScheme.primary.withValues(alpha: 0.85),
  HouseVerdict.mixed => theme.colorScheme.tertiary.withValues(alpha: 0.45),
  HouseVerdict.weak => theme.colorScheme.error.withValues(alpha: 0.30),
};

String _verdictWord(HouseVerdict v, bool hindi) => switch (v) {
  HouseVerdict.strong => hindi ? 'सहायक' : 'supported',
  HouseVerdict.mixed => hindi ? 'मिश्र' : 'mixed',
  HouseVerdict.weak => hindi ? 'दबा' : 'pressed',
};

IconData _verdictIcon(HouseVerdict v) => switch (v) {
  HouseVerdict.strong => Icons.check_circle,
  HouseVerdict.mixed => Icons.remove_circle_outline,
  HouseVerdict.weak => Icons.circle_outlined,
};

String _agreementWord(SudarshanAgreement a, bool hindi) => switch (a) {
  SudarshanAgreement.all => hindi ? 'तीनों से' : 'all three',
  SudarshanAgreement.two => hindi ? 'दो से' : 'two of three',
  SudarshanAgreement.one => hindi ? 'एक से' : 'one only',
  SudarshanAgreement.none => hindi ? 'किसी से नहीं' : 'none',
};

class _Legend extends StatelessWidget {
  const _Legend({required this.hindi});

  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Widget item(HouseVerdict v) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: _verdictColor(theme, v),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(_verdictWord(v, hindi), style: theme.textTheme.bodySmall),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: <Widget>[
        item(HouseVerdict.strong),
        item(HouseVerdict.mixed),
        item(HouseVerdict.weak),
        Text(
          hindi
              ? 'भीतर से बाहर: लग्न, चंद्र, सूर्य'
              : 'Inside to outside: Lagna, Moon, Sun',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.hindi});

  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12.5,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: 30, child: Text(hindi ? 'भाव' : 'No.', style: style)),
          Expanded(child: Text(hindi ? 'क्षेत्र' : 'Area', style: style)),
          SizedBox(
            width: 28,
            child: Text(
              hindi ? 'ल' : 'L',
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              hindi ? 'च' : 'M',
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              hindi ? 'स' : 'S',
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

String _shortArea(String area) {
  final int colon = area.indexOf(':');
  final String head = colon >= 0 ? area.substring(0, colon) : area;
  return head;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.house,
    required this.kundli,
    required this.hindi,
  });

  final SudarshanHouse house;
  final Kundli kundli;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool signature = house.agreement == SudarshanAgreement.all;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            child: Text(
              '${house.house}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: signature ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _shortArea(hindi ? house.areaHindi : house.areaEnglish),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: signature ? FontWeight.w600 : null,
              ),
            ),
          ),
          for (final HouseStanding s in house.standings)
            SizedBox(
              width: 28,
              child: Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _verdictColor(theme, s.verdict),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HouseCard extends StatelessWidget {
  const _HouseCard({
    required this.house,
    required this.kundli,
    required this.hindi,
  });

  final SudarshanHouse house;
  final Kundli kundli;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        initiallyExpanded: false,
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                hindi ? '${house.house}वाँ भाव' : 'House ${house.house}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              _agreementWord(house.agreement, hindi),
              style: theme.textTheme.titleSmall?.copyWith(
                color: house.agreement == SudarshanAgreement.all
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _shortArea(hindi ? house.areaHindi : house.areaEnglish),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
          ),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hindi ? house.readingHindi : house.readingEnglish,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final HouseStanding s in house.standings)
                  _StandingBlock(standing: s, hindi: hindi),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingBlock extends StatelessWidget {
  const _StandingBlock({required this.standing, required this.hindi});

  final HouseStanding standing;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RashiInfo sign = rashiInfo(standing.rashi);
    final List<String> factors = hindi
        ? standing.factorsHindi
        : standing.factorsEnglish;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _verdictIcon(standing.verdict),
                size: 18,
                color: _verdictColor(theme, standing.verdict),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hindi
                      ? '${standing.reference.hindi} से · ${hindi ? sign.hindi : sign.english} · ${_verdictWord(standing.verdict, true)}'
                      : 'From the ${standing.reference.english} · ${sign.english} · ${_verdictWord(standing.verdict, false)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            hindi
                ? '(${standing.reference.standsForHindi})'
                : '(${standing.reference.standsForEnglish})',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          if (factors.isEmpty)
            Text(
              hindi ? 'कोई कारक नहीं।' : 'No factors.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final String f in factors)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 7, right: 8),
                      child: Icon(Icons.circle, size: 5),
                    ),
                    Expanded(
                      child: Text(
                        f,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Three concentric rings of twelve segments: the Lagna inside, the Moon in the
/// middle and the Sun outside, house 1 at the top running clockwise.
class _Wheel extends StatelessWidget {
  const _Wheel({required this.chakra, required this.hindi, required this.size});

  final SudarshanChakra chakra;
  final bool hindi;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WheelPainter(
          chakra: chakra,
          theme: theme,
          textColor: theme.colorScheme.onSurface,
          lineColor: theme.colorScheme.surface,
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.chakra,
    required this.theme,
    required this.textColor,
    required this.lineColor,
  });

  final SudarshanChakra chakra;
  final ThemeData theme;
  final Color textColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double outer = size.width / 2 - 14;
    final double ring = outer * 0.24;
    // Inner ring first: the Lagna, then the Moon, then the Sun.
    final List<double> inners = <double>[
      outer * 0.28,
      outer * 0.28 + ring,
      outer * 0.28 + 2 * ring,
    ];
    final List<double> outers = <double>[
      inners[0] + ring,
      inners[1] + ring,
      inners[2] + ring,
    ];
    final double sweep = 2 * math.pi / 12;
    for (int r = 0; r < 3; r++) {
      for (int i = 0; i < 12; i++) {
        final SudarshanHouse h = chakra.houses[i];
        final HouseVerdict v = h.standings[r].verdict;
        final double start = -math.pi / 2 + i * sweep;
        final Path path = Path()
          ..arcTo(
            Rect.fromCircle(center: c, radius: outers[r]),
            start,
            sweep,
            false,
          )
          ..arcTo(
            Rect.fromCircle(center: c, radius: inners[r]),
            start + sweep,
            -sweep,
            false,
          )
          ..close();
        canvas.drawPath(path, Paint()..color = _verdictColor(theme, v));
        canvas.drawPath(
          path,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
    // The house numbers just outside the wheel.
    for (int i = 0; i < 12; i++) {
      final double mid = -math.pi / 2 + (i + 0.5) * sweep;
      final Offset p =
          c + Offset(math.cos(mid), math.sin(mid)) * (outers[2] + 10);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: chakra.houses[i].agreement == SudarshanAgreement.all
                ? FontWeight.w800
                : FontWeight.w500,
            color: textColor.withValues(alpha: 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.chakra != chakra || old.theme != theme;
}
