import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/astro/ephemeris.dart';
import '../engine/jyotish/chart.dart';
import '../engine/jyotish/ghat_chakra.dart';
import '../engine/jyotish/graha_data.dart';
import '../engine/jyotish/sarvatobhadra.dart';
import '../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';
import '../widgets/common.dart';
import 'profile_scope.dart';

/// Sarvatobhadra Chakra: the 81-cell grid, with the line each graha casts from
/// the nakshatra it stands in, and which of the native's own points those lines
/// pass through. It is a timing aid for transit and muhurta; every reading is a
/// passing influence and none of them says what will happen.
class SarvatobhadraScreen extends StatefulWidget {
  const SarvatobhadraScreen({super.key, this.profileId});

  final String? profileId;

  @override
  State<SarvatobhadraScreen> createState() => _SarvatobhadraScreenState();
}

class _SarvatobhadraScreenState extends State<SarvatobhadraScreen> {
  DateTime _moment = DateTime.now();
  Graha? _selected;
  SbcCell? _cell;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _moment,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _moment = DateTime(picked.year, picked.month, picked.day, 12);
      _selected = null;
      _cell = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context)!;
    final bool hindi =
        context.watch<SettingsCubit>().state.languageCode == 'hi';
    return ChartScaffold(
      title: hindi ? 'सर्वतोभद्र चक्र' : 'Sarvatobhadra Chakra',
      profileId: widget.profileId,
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.event_outlined),
          tooltip: hindi ? 'तिथि चुनें' : 'Choose a date',
          onPressed: _pickDate,
        ),
        IconButton(
          icon: const Icon(Icons.today_outlined),
          tooltip: hindi ? 'आज' : 'Today',
          onPressed: () => setState(() {
            _moment = DateTime.now();
            _selected = null;
            _cell = null;
          }),
        ),
      ],
      builder: (BuildContext context, Kundli kundli, _) => DeferredBuilder<SarvatobhadraReading>(
        key: ValueKey<String>(
          '${kundli.instant.julianDayUt}-${_moment.millisecondsSinceEpoch ~/ 60000}',
        ),
        message: l.computing,
        work: () => computeSarvatobhadra(kundli, moment: _moment),
        builder: (BuildContext context, SarvatobhadraReading reading) {
          final ThemeData theme = Theme.of(context);
          final Graha shown =
              _selected ??
              (reading.active.isNotEmpty
                  ? reading.active.first.graha
                  : Graha.moon);
          final SbcVedha vedha = reading.vedhas.firstWhere(
            (SbcVedha v) => v.graha == shown,
          );
          final List<SbcVedha> active = reading.active;
          String date(DateTime d) => '${d.day}/${d.month}/${d.year}';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              ToranaHeader(
                title: hindi ? 'सर्वतोभद्र चक्र' : 'Sarvatobhadra Chakra',
                subtitle: hindi
                    ? '${date(_moment)} के गोचर की रेखाएँ, आपके नक्षत्र और नाम-अक्षर के विरुद्ध।'
                    : 'The lines of the transits on ${date(_moment)}, against your nakshatra and name syllable.',
              ),
              Panel(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _GridView(
                      reading: reading,
                      vedha: vedha,
                      hindi: hindi,
                      selectedCell: _cell,
                      onTap: (SbcCell c) => setState(() => _cell = c),
                    ),
                    const SizedBox(height: 10),
                    _Legend(hindi: hindi),
                  ],
                ),
              ),
              if (_cell != null)
                Panel(
                  title: hindi ? 'चुना हुआ कोष्ठक' : 'The cell you chose',
                  child: _CellDetail(cell: _cell!, hindi: hindi),
                ),
              Panel(
                title: hindi ? 'ग्रह की रेखा देखें' : 'See a graha’s line',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        for (final SbcVedha v in reading.vedhas)
                          ChoiceChip(
                            label: Text(
                              hindi
                                  ? grahaInfo(v.graha).hindi
                                  : grahaInfo(v.graha).english,
                            ),
                            avatar: v.touchesNative
                                ? const Icon(Icons.adjust, size: 16)
                                : null,
                            selected: v.graha == shown,
                            onSelected: (_) =>
                                setState(() => _selected = v.graha),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hindi
                          ? '${grahaInfo(vedha.graha).hindi} ${vedha.origin.hindi} में है और ${vedha.line.hindi} रेखा डालता है: ${vedha.basisHindi}।'
                          : '${grahaInfo(vedha.graha).english} stands in ${vedha.origin.english} and casts its ${vedha.line.english} line: ${vedha.basisEnglish}.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      vedha.touchesNative
                          ? (hindi
                                ? 'यह रेखा आपके बिंदुओं में से इनसे गुज़रती है: ${vedha.struck.map((SbcNatalPoint p) => p.labelHindi).join(', ')}।'
                                : 'This line passes through: ${vedha.struck.map((SbcNatalPoint p) => p.labelEnglish).join(', ')}.')
                          : (hindi
                                ? 'यह रेखा आपके किसी बिंदु से नहीं गुज़रती।'
                                : 'This line touches none of your points.'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Panel(
                title: hindi
                    ? 'आज आपके बिंदुओं पर वेध'
                    : 'Vedha on your points',
                child: active.isEmpty
                    ? Text(
                        hindi
                            ? 'इस समय किसी ग्रह की सक्रिय रेखा आपके नक्षत्र, नाम-अक्षर, चंद्र राशि या लग्न से होकर नहीं गुज़रती।'
                            : 'No graha’s active line passes through your nakshatra, name syllable, Moon sign or lagna at this moment.',
                        style: theme.textTheme.bodyMedium,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final SbcVedha v in active)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                hindi
                                    ? describeVedha(v).hi
                                    : describeVedha(v).en,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                        ],
                      ),
              ),
              Panel(
                title: hindi ? 'आपके अपने बिंदु' : 'Your own points',
                child: Column(
                  children: <Widget>[
                    for (final SbcNatalPoint p in reading.natalPoints)
                      FactRow(switch (p.kind) {
                        SbcPointKind.nakshatra =>
                          hindi ? 'जन्म नक्षत्र' : 'Janma nakshatra',
                        SbcPointKind.akshara =>
                          hindi ? 'नाम का व्यंजन' : 'Name consonant',
                        SbcPointKind.swara =>
                          hindi ? 'नाम का स्वर' : 'Name vowel',
                        SbcPointKind.moonSign =>
                          hindi ? 'चंद्र राशि' : 'Moon sign',
                        SbcPointKind.lagnaSign => hindi ? 'लग्न' : 'Lagna',
                      }, hindi ? p.cell.hindi : p.cell.english),
                    if (reading.syllable != null) ...<Widget>[
                      const Divider(),
                      Text(
                        hindi
                            ? 'नाम-अक्षर: ${reading.syllable!.syllableHindi}। ${reading.syllable!.basisHindi}। जन्म-नक्षत्र का पारंपरिक नामाक्षर लिया गया है, जब तक नाम देवनागरी में न लिखा हो।'
                            : 'Name syllable: ${reading.syllable!.syllableHindi}. ${reading.syllable!.basisEnglish}. The traditional naming syllable of the janma nakshatra is used unless the name was written in Devanagari.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13.5,
                          height: 1.45,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Panel(
                title: hindi ? 'वेध कैसे काम करता है' : 'How vedha works',
                child: Text(
                  hindi
                      ? 'ग्रह जिस नक्षत्र में हो, उसके कोष्ठक से तीन रेखाएँ निकल सकती हैं: सीधी (सम्मुख), और दो तिरछी, एक राशिचक्र की दिशा में (वाम) और एक उसके विरुद्ध (दक्षिण)। रेखा के रास्ते में पड़ने वाले सब कोष्ठक विद्ध माने जाते हैं। कौन-सी रेखा सक्रिय है यह गति से तय होता है: वक्री ग्रह दक्षिण, राहु-केतु दक्षिण, सूर्य-चंद्र वाम, और अन्य मार्गी ग्रह औसत दैनिक गति से तेज़ हों तो वाम, नहीं तो सम्मुख। "तेज़" की कोई संख्या ग्रंथ नहीं देते; औसत गति की सीमा यहाँ की अपनी पद्धति है। गुरु, शुक्र और बुध का वेध सहायक, सूर्य, मंगल, शनि, राहु और केतु का दबाव डालने वाला, और चंद्र का मिश्रित पढ़ा जाता है। हर वेध एक गुज़रता प्रभाव है, भविष्यवाणी नहीं।'
                      : 'From the nakshatra a graha stands in, up to three lines run through the grid: straight across (front) and two diagonals, one in the direction of the zodiac (left) and one against it (right). Every cell on the way is struck. Which line is active depends on motion: a retrograde graha casts the right line, Rahu and Ketu the right, the Sun and Moon the left, and any other direct graha the left if it is faster than its mean daily motion and the front otherwise. The texts give no number for "swift"; the mean-motion divide is this app’s own convention. A strike by Jupiter, Venus or Mercury is read as supportive, by the Sun, Mars, Saturn, Rahu or Ketu as pressing, and by the Moon as mixed. Every vedha is a passing influence, not a prediction.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              DisclaimerNote(l.disclaimer),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// The grid.
// -----------------------------------------------------------------------------

const List<String> _nakShortEn = <String>[
  'Ash',
  'Bha',
  'Kri',
  'Roh',
  'Mri',
  'Ard',
  'Pun',
  'Pus',
  'Asl',
  'Mag',
  'PPh',
  'UPh',
  'Has',
  'Chi',
  'Swa',
  'Vis',
  'Anu',
  'Jye',
  'Mul',
  'PAs',
  'UAs',
  'Abh',
  'Shr',
  'Dha',
  'Sat',
  'PBh',
  'UBh',
  'Rev',
];

const List<String> _nakShortHi = <String>[
  'अश्वि',
  'भरणी',
  'कृत्ति',
  'रोहिणी',
  'मृग',
  'आर्द्रा',
  'पुनर्व',
  'पुष्य',
  'आश्ले',
  'मघा',
  'पू.फा',
  'उ.फा',
  'हस्त',
  'चित्रा',
  'स्वाती',
  'विशा',
  'अनु',
  'ज्येष्ठा',
  'मूल',
  'पू.षा',
  'उ.षा',
  'अभिजित्',
  'श्रवण',
  'धनि',
  'शतभि',
  'पू.भा',
  'उ.भा',
  'रेवती',
];

const List<String> _dayShortEn = <String>[
  'Su',
  'Mo',
  'Tu',
  'We',
  'Th',
  'Fr',
  'Sa',
];
const List<String> _dayShortHi = <String>[
  'र',
  'सो',
  'मं',
  'बु',
  'गु',
  'शु',
  'श',
];

String _cellText(SbcCell c, bool hindi) {
  switch (c.kind) {
    case SbcCellKind.nakshatra:
      return hindi ? _nakShortHi[c.nakshatra28!] : _nakShortEn[c.nakshatra28!];
    case SbcCellKind.vowel:
    case SbcCellKind.consonant:
      return c.hindi;
    case SbcCellKind.rashi:
      return hindi ? c.hindi : c.english.substring(0, 3);
    case SbcCellKind.tithi:
      final String days = c.weekdays
          .map((int d) => hindi ? _dayShortHi[d] : _dayShortEn[d])
          .join('/');
      final String name = hindi
          ? c.tithiGroup!.hindi
          : c.tithiGroup!.english.substring(0, 3);
      return '$name\n$days';
  }
}

class _GridView extends StatelessWidget {
  const _GridView({
    required this.reading,
    required this.vedha,
    required this.hindi,
    required this.selectedCell,
    required this.onTap,
  });

  final SarvatobhadraReading reading;
  final SbcVedha vedha;
  final bool hindi;
  final SbcCell? selectedCell;
  final void Function(SbcCell) onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double side = box.maxWidth;
        final double cell = side / 9;
        final Set<(int, int)> path = <(int, int)>{
          for (final SbcCell c in vedha.path) (c.row, c.col),
        };
        final Set<(int, int)> natal = <(int, int)>{
          for (final SbcNatalPoint p in reading.natalPoints)
            (p.cell.row, p.cell.col),
        };
        Color base(SbcCell c) => switch (c.kind) {
          SbcCellKind.nakshatra => cs.primary.withValues(alpha: 0.16),
          SbcCellKind.vowel => cs.onSurface.withValues(alpha: 0.09),
          SbcCellKind.consonant => cs.surface,
          SbcCellKind.rashi => cs.tertiary.withValues(alpha: 0.16),
          SbcCellKind.tithi => cs.secondary.withValues(alpha: 0.18),
        };
        return SizedBox(
          width: side,
          height: side,
          child: Column(
            children: <Widget>[
              for (int r = 0; r < 9; r++)
                Row(
                  children: <Widget>[
                    for (int c = 0; c < 9; c++)
                      Builder(
                        builder: (BuildContext context) {
                          final SbcCell sc = reading.grid.at(r, c);
                          final bool onPath = path.contains((r, c));
                          final bool isOrigin =
                              r == vedha.origin.row && c == vedha.origin.col;
                          final bool isNatal = natal.contains((r, c));
                          final bool isSelected =
                              selectedCell != null &&
                              selectedCell!.row == r &&
                              selectedCell!.col == c;
                          return GestureDetector(
                            onTap: () => onTap(sc),
                            child: Container(
                              width: cell,
                              height: cell,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: isOrigin
                                    ? cs.primary
                                    : (onPath
                                          ? cs.primary.withValues(alpha: 0.42)
                                          : base(sc)),
                                border: Border.all(
                                  color: isSelected
                                      ? cs.onSurface
                                      : (isNatal
                                            ? cs.error.withValues(alpha: 0.85)
                                            : cs.outline.withValues(
                                                alpha: 0.35,
                                              )),
                                  width: isSelected || isNatal ? 2 : 0.6,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _cellText(sc, hindi),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.05,
                                    fontWeight: isOrigin
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isOrigin
                                        ? cs.onPrimary
                                        : cs.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.hindi});

  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    Widget key(Color color, String label, {Color? border}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: border ?? cs.outline.withValues(alpha: 0.4),
              width: border != null ? 2 : 0.6,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        key(cs.primary, hindi ? 'ग्रह का नक्षत्र' : 'Graha’s nakshatra'),
        key(
          cs.primary.withValues(alpha: 0.42),
          hindi ? 'रेखा का मार्ग' : 'Line’s path',
        ),
        key(
          Colors.transparent,
          hindi ? 'आपका बिंदु' : 'Your point',
          border: cs.error.withValues(alpha: 0.85),
        ),
        key(
          cs.primary.withValues(alpha: 0.16),
          hindi ? 'नक्षत्र' : 'Nakshatra',
        ),
        key(cs.onSurface.withValues(alpha: 0.09), hindi ? 'स्वर' : 'Vowel'),
        key(cs.tertiary.withValues(alpha: 0.16), hindi ? 'राशि' : 'Rashi'),
        key(
          cs.secondary.withValues(alpha: 0.18),
          hindi ? 'तिथि-वार' : 'Tithi and weekday',
        ),
      ],
    );
  }
}

class _CellDetail extends StatelessWidget {
  const _CellDetail({required this.cell, required this.hindi});

  final SbcCell cell;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String kind = switch (cell.kind) {
      SbcCellKind.nakshatra => hindi ? 'नक्षत्र' : 'Nakshatra',
      SbcCellKind.vowel => hindi ? 'स्वर' : 'Vowel',
      SbcCellKind.consonant => hindi ? 'व्यंजन' : 'Consonant',
      SbcCellKind.rashi => hindi ? 'राशि' : 'Rashi',
      SbcCellKind.tithi => hindi ? 'तिथि और वार' : 'Tithi and weekday',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FactRow(kind, hindi ? cell.hindi : cell.english, emphasise: true),
        FactRow(
          hindi ? 'स्थान' : 'Position',
          hindi
              ? 'पंक्ति ${cell.row + 1}, स्तंभ ${cell.col + 1}'
              : 'Row ${cell.row + 1}, column ${cell.col + 1}',
        ),
        if (cell.inferred)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hindi
                  ? 'यह कोष्ठक छपे चक्र से अनुमानित है, सीधे छपा हुआ नहीं।'
                  : 'This cell is inferred from the printed layout, not printed itself.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
            ),
          ),
      ],
    );
  }
}
