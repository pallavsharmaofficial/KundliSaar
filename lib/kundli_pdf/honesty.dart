/// The words the book must never print, in Hindi. The app does not forecast
/// death, illness, pregnancy, examinations, court matters or the returns on an
/// investment, and a hard period is described by what it asks of the person,
/// never as doom. The same lists guard the engine's own texts in its tests;
/// this is the union of them, used here to keep a piece of text out of the PDF
/// if it ever carried one, and by the PDF tests to prove none got in.
const List<String> refusedHindiStems = <String>[
  'मृत्यु',
  'मौत',
  'मरण',
  'बीमार',
  'रोग',
  'गर्भ',
  'प्रसव',
  'परीक्षा',
  'इम्तिहान',
  'मुकदमा',
  'अदालत',
  'क़ानून',
  'कानून',
  'जेल',
  'कारावास',
  'निवेश',
  'शेयर',
  'सट्टा',
  'लॉटरी',
  'जुआ',
  'अभिशाप',
  'विनाश',
  'तबाही',
  'दुर्भाग्य',
  'स्वास्थ्य',
  'मुनाफ़ा',
  'दुर्घटना',
  'अस्पताल',
  'कैंसर',
  'बीमारी',
];

/// Words the engine's classical-yoga tests also ban, in the yoga texts only:
/// they talk about longevity and poverty. Elsewhere "आयु" is simply age.
const List<String> yogaOnlyStems = <String>['आयु', 'ग़रीबी', 'गरीबी'];

/// "मरण" (death) is also the tail of "स्मरण" (remembrance), "संस्मरण" and
/// "विस्मरण", where a virama joins it to the letter before. A stem is a refused
/// word only when it is not the second half of such a conjunct.
final Map<String, RegExp> _patterns = <String, RegExp>{
  for (final String stem in <String>[...refusedHindiStems, ...yogaOnlyStems])
    stem: stem == 'मरण' ? RegExp('(?<!्)मरण') : RegExp(RegExp.escape(stem)),
};

/// True when [hindi] contains any of the refused words.
bool isRefusedHindi(String hindi, {bool yoga = false}) =>
    refusedWordIn(hindi, yoga: yoga) != null;

/// The first refused word in [hindi], or null.
String? refusedWordIn(String hindi, {bool yoga = false}) {
  for (final String stem in refusedHindiStems) {
    if (_patterns[stem]!.hasMatch(hindi)) return stem;
  }
  if (yoga) {
    for (final String stem in yogaOnlyStems) {
      if (_patterns[stem]!.hasMatch(hindi)) return stem;
    }
  }
  return null;
}
