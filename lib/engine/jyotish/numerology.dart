/// Ank Jyotish, the Indian reading of numbers, which people ask for alongside
/// a kundli as often as they ask for the kundli itself.
library;

/// Chaldean letter values, the set used in Indian numerology.
const Map<String, int> chaldean = <String, int>{
  'a': 1,
  'b': 2,
  'c': 3,
  'd': 4,
  'e': 5,
  'f': 8,
  'g': 3,
  'h': 5,
  'i': 1,
  'j': 1,
  'k': 2,
  'l': 3,
  'm': 4,
  'n': 5,
  'o': 7,
  'p': 8,
  'q': 1,
  'r': 2,
  's': 3,
  't': 4,
  'u': 6,
  'v': 6,
  'w': 6,
  'x': 5,
  'y': 1,
  'z': 7,
};

class NumberInfo {
  const NumberInfo({
    required this.number,
    required this.planet,
    required this.planetHindi,
    required this.traits,
    required this.traitsHindi,
    required this.luckyDays,
    required this.luckyColours,
    required this.luckyColoursHindi,
    required this.gemstone,
    required this.friendly,
  });

  final int number;
  final String planet;
  final String planetHindi;
  final String traits;
  final String traitsHindi;
  final List<String> luckyDays;
  final List<String> luckyColours;
  final List<String> luckyColoursHindi;
  final String gemstone;
  final List<int> friendly;
}

const List<NumberInfo> numberTable = <NumberInfo>[
  NumberInfo(
    number: 1,
    planet: 'Sun',
    planetHindi: 'सूर्य',
    traits:
        'Leads, decides, dislikes being managed. Works best when the responsibility is clearly its own.',
    traitsHindi: 'नेतृत्व, निर्णय और आत्मविश्वास।',
    luckyDays: <String>['Sunday', 'Monday'],
    luckyColours: <String>['Gold', 'Orange', 'Copper'],
    luckyColoursHindi: <String>['सुनहरा', 'नारंगी', 'ताँबा'],
    gemstone: 'Ruby',
    friendly: <int>[1, 2, 4, 9],
  ),
  NumberInfo(
    number: 2,
    planet: 'Moon',
    planetHindi: 'चंद्र',
    traits:
        'Reads a room before speaking. Gentle, changeable, strong in partnership.',
    traitsHindi: 'संवेदनशीलता, कल्पना और सहयोग।',
    luckyDays: <String>['Monday', 'Friday'],
    luckyColours: <String>['White', 'Cream', 'Silver'],
    luckyColoursHindi: <String>['सफ़ेद', 'क्रीम', 'चाँदी'],
    gemstone: 'Pearl',
    friendly: <int>[1, 2, 7],
  ),
  NumberInfo(
    number: 3,
    planet: 'Jupiter',
    planetHindi: 'गुरु',
    traits:
        'Teaches, advises, keeps faith. Grows through knowledge and through people older than itself.',
    traitsHindi: 'ज्ञान, उपदेश और श्रद्धा।',
    luckyDays: <String>['Thursday', 'Tuesday'],
    luckyColours: <String>['Yellow', 'Saffron'],
    luckyColoursHindi: <String>['पीला', 'केसरिया'],
    gemstone: 'Yellow sapphire',
    friendly: <int>[3, 6, 9],
  ),
  NumberInfo(
    number: 4,
    planet: 'Rahu',
    planetHindi: 'राहु',
    traits:
        'Unconventional, restless, good with machines and with anything foreign.',
    traitsHindi: 'अलग सोच, बेचैनी और तकनीक।',
    luckyDays: <String>['Saturday', 'Sunday'],
    luckyColours: <String>['Grey', 'Blue'],
    luckyColoursHindi: <String>['स्लेटी', 'नीला'],
    gemstone: 'Hessonite',
    friendly: <int>[1, 4, 8],
  ),
  NumberInfo(
    number: 5,
    planet: 'Mercury',
    planetHindi: 'बुध',
    traits: 'Quick, verbal, commercial. Bores easily and recovers fast.',
    traitsHindi: 'तीव्र बुद्धि, वाणी और व्यापार।',
    luckyDays: <String>['Wednesday', 'Friday'],
    luckyColours: <String>['Green', 'Light blue'],
    luckyColoursHindi: <String>['हरा', 'आसमानी'],
    gemstone: 'Emerald',
    friendly: <int>[5, 6, 9],
  ),
  NumberInfo(
    number: 6,
    planet: 'Venus',
    planetHindi: 'शुक्र',
    traits:
        'Drawn to beauty, comfort and company. Good taste, and a weakness for it.',
    traitsHindi: 'सौंदर्य, कला और सुख।',
    luckyDays: <String>['Friday', 'Wednesday'],
    luckyColours: <String>['White', 'Pink', 'Pastel'],
    luckyColoursHindi: <String>['सफ़ेद', 'गुलाबी'],
    gemstone: 'Diamond or white sapphire',
    friendly: <int>[3, 5, 6],
  ),
  NumberInfo(
    number: 7,
    planet: 'Ketu',
    planetHindi: 'केतु',
    traits:
        'Private, searching, uneasy with small talk. Often drawn to research or to practice.',
    traitsHindi: 'एकांत, खोज और साधना।',
    luckyDays: <String>['Monday', 'Sunday'],
    luckyColours: <String>['Smoky grey', 'White'],
    luckyColoursHindi: <String>['धूम्र', 'सफ़ेद'],
    gemstone: "Cat's eye",
    friendly: <int>[2, 7],
  ),
  NumberInfo(
    number: 8,
    planet: 'Saturn',
    planetHindi: 'शनि',
    traits:
        'Slow, durable, undervalued early and respected late. Builds what lasts.',
    traitsHindi: 'धैर्य, परिश्रम और स्थायित्व।',
    luckyDays: <String>['Saturday', 'Friday'],
    luckyColours: <String>['Dark blue', 'Black'],
    luckyColoursHindi: <String>['गहरा नीला', 'काला'],
    gemstone: 'Blue sapphire',
    friendly: <int>[4, 8],
  ),
  NumberInfo(
    number: 9,
    planet: 'Mars',
    planetHindi: 'मंगल',
    traits: 'Direct, courageous, impatient. Needs something to push against.',
    traitsHindi: 'साहस, ऊर्जा और स्पष्टता।',
    luckyDays: <String>['Tuesday', 'Sunday'],
    luckyColours: <String>['Red', 'Maroon'],
    luckyColoursHindi: <String>['लाल', 'मरून'],
    gemstone: 'Red coral',
    friendly: <int>[1, 3, 9],
  ),
];

NumberInfo numberInfo(int number) => numberTable[(number - 1) % 9];

int digitSum(int value) {
  int sum = value.abs();
  while (sum > 9) {
    sum = sum
        .toString()
        .split('')
        .fold(0, (int a, String d) => a + int.parse(d));
  }
  return sum == 0 ? 9 : sum;
}

class NumerologyReading {
  const NumerologyReading({
    required this.mulank,
    required this.bhagyank,
    required this.namank,
    required this.loshu,
    required this.missingNumbers,
    required this.repeatedNumbers,
  });

  /// Birth number, from the day of the month.
  final int mulank;

  /// Destiny number, from the whole date.
  final int bhagyank;

  /// Name number, by the Chaldean values; zero when no name was given.
  final int namank;

  /// The Lo Shu grid: how many times each digit 1..9 appears in the date.
  final Map<int, int> loshu;
  final List<int> missingNumbers;
  final List<int> repeatedNumbers;

  bool get mulankAndBhagyankAgree =>
      numberInfo(mulank).friendly.contains(bhagyank);
}

NumerologyReading computeNumerology({
  required DateTime birthDate,
  String name = '',
}) {
  final int mulank = digitSum(birthDate.day);
  final String digits = '${birthDate.day}${birthDate.month}${birthDate.year}'
      .replaceAll('0', '');
  final int bhagyank = digitSum(
    digits.split('').fold(0, (int a, String d) => a + int.parse(d)),
  );
  final int namank = name.trim().isEmpty
      ? 0
      : digitSum(
          name
              .toLowerCase()
              .split('')
              .where(chaldean.containsKey)
              .fold(0, (int a, String c) => a + chaldean[c]!),
        );

  final Map<int, int> loshu = <int, int>{for (int i = 1; i <= 9; i++) i: 0};
  for (final String digit in digits.split('')) {
    loshu[int.parse(digit)] = loshu[int.parse(digit)]! + 1;
  }
  loshu[mulank] = loshu[mulank]! + 1;
  loshu[bhagyank] = loshu[bhagyank]! + 1;

  return NumerologyReading(
    mulank: mulank,
    bhagyank: bhagyank,
    namank: namank,
    loshu: loshu,
    missingNumbers: <int>[
      for (int i = 1; i <= 9; i++)
        if (loshu[i] == 0) i,
    ],
    repeatedNumbers: <int>[
      for (int i = 1; i <= 9; i++)
        if (loshu[i]! >= 3) i,
    ],
  );
}
