/// Namkaran: the syllable a child's name should begin with, by the pada of the
/// nakshatra the Moon stood in at birth. The table is fixed and old; the names
/// beside it are only examples that fit the sound.
library;

import 'nakshatra.dart';

/// Four syllables for each nakshatra, one per pada, from Ashwini onward.
const List<List<String>> padaSyllables = <List<String>>[
  <String>['Chu', 'Che', 'Cho', 'La'],
  <String>['Li', 'Lu', 'Le', 'Lo'],
  <String>['A', 'I', 'U', 'E'],
  <String>['O', 'Va', 'Vi', 'Vu'],
  <String>['Ve', 'Vo', 'Ka', 'Ki'],
  <String>['Ku', 'Gha', 'Nga', 'Chha'],
  <String>['Ke', 'Ko', 'Ha', 'Hi'],
  <String>['Hu', 'He', 'Ho', 'Da'],
  <String>['Di', 'Du', 'De', 'Do'],
  <String>['Ma', 'Mi', 'Mu', 'Me'],
  <String>['Mo', 'Ta', 'Ti', 'Tu'],
  <String>['Te', 'To', 'Pa', 'Pi'],
  <String>['Pu', 'Sha', 'Na', 'Tha'],
  <String>['Pe', 'Po', 'Ra', 'Ri'],
  <String>['Ru', 'Re', 'Ro', 'Ta'],
  <String>['Ti', 'Tu', 'Te', 'To'],
  <String>['Na', 'Ni', 'Nu', 'Ne'],
  <String>['No', 'Ya', 'Yi', 'Yu'],
  <String>['Ye', 'Yo', 'Bha', 'Bhi'],
  <String>['Bhu', 'Dha', 'Pha', 'Dha'],
  <String>['Bhe', 'Bho', 'Ja', 'Ji'],
  <String>['Ju', 'Je', 'Jo', 'Gha'],
  <String>['Ga', 'Gi', 'Gu', 'Ge'],
  <String>['Go', 'Sa', 'Si', 'Su'],
  <String>['Se', 'So', 'Da', 'Di'],
  <String>['Du', 'Tha', 'Jha', 'Tra'],
  <String>['De', 'Do', 'Cha', 'Chi'],
];

/// The same syllables in Devanagari.
const List<List<String>> padaSyllablesHindi = <List<String>>[
  <String>['चू', 'चे', 'चो', 'ला'],
  <String>['ली', 'लू', 'ले', 'लो'],
  <String>['अ', 'ई', 'उ', 'ए'],
  <String>['ओ', 'वा', 'वी', 'वू'],
  <String>['वे', 'वो', 'का', 'की'],
  <String>['कु', 'घ', 'ङ', 'छ'],
  <String>['के', 'को', 'हा', 'ही'],
  <String>['हु', 'हे', 'हो', 'डा'],
  <String>['डी', 'डू', 'डे', 'डो'],
  <String>['मा', 'मी', 'मू', 'मे'],
  <String>['मो', 'टा', 'टी', 'टू'],
  <String>['टे', 'टो', 'पा', 'पी'],
  <String>['पू', 'ष', 'ण', 'ठ'],
  <String>['पे', 'पो', 'रा', 'री'],
  <String>['रू', 'रे', 'रो', 'ता'],
  <String>['ती', 'तू', 'ते', 'तो'],
  <String>['ना', 'नी', 'नू', 'ने'],
  <String>['नो', 'या', 'यी', 'यू'],
  <String>['ये', 'यो', 'भा', 'भी'],
  <String>['भू', 'धा', 'फा', 'ढा'],
  <String>['भे', 'भो', 'जा', 'जी'],
  <String>['जू', 'जे', 'जो', 'घा'],
  <String>['गा', 'गी', 'गु', 'गे'],
  <String>['गो', 'सा', 'सी', 'सू'],
  <String>['से', 'सो', 'दा', 'दी'],
  <String>['दू', 'थ', 'झ', 'ञ'],
  <String>['दे', 'दो', 'चा', 'ची'],
];

class SuggestedName {
  const SuggestedName(this.name, this.hindi, this.meaning, this.meaningHindi);

  final String name;
  final String hindi;
  final String meaning;
  final String meaningHindi;
}

/// Example names by starting syllable. Not a complete list, and not a ruling:
/// the syllable is the tradition, the name is the family's choice.
const Map<String, List<SuggestedName>>
namesBySyllable = <String, List<SuggestedName>>{
  'Chu': <SuggestedName>[
    SuggestedName('Chaitanya', 'चैतन्य', 'Consciousness', 'चेतना'),
    SuggestedName('Churni', 'चूर्णी', 'A river name', 'नदी का नाम'),
  ],
  'Che': <SuggestedName>[
    SuggestedName('Chetan', 'चेतन', 'Awake, alive', 'जागृत'),
    SuggestedName('Chetana', 'चेतना', 'Awareness', 'चेतना'),
  ],
  'Cho': <SuggestedName>[
    SuggestedName('Chodan', 'चोदन', 'One who urges on', 'प्रेरक'),
  ],
  'La': <SuggestedName>[
    SuggestedName('Lakshya', 'लक्ष्य', 'The aim', 'उद्देश्य'),
    SuggestedName('Lavanya', 'लावण्य', 'Grace', 'सौंदर्य'),
  ],
  'A': <SuggestedName>[
    SuggestedName('Aarav', 'आरव', 'Peaceful sound', 'शांत ध्वनि'),
    SuggestedName('Ananya', 'अनन्य', 'Without another like her', 'अद्वितीय'),
    SuggestedName('Arjun', 'अर्जुन', 'Bright, white', 'उज्ज्वल'),
  ],
  'I': <SuggestedName>[
    SuggestedName(
      'Ishaan',
      'ईशान',
      'The north-east, a name of Shiva',
      'शिव का नाम',
    ),
    SuggestedName('Ira', 'इरा', 'The earth, Saraswati', 'पृथ्वी'),
  ],
  'U': <SuggestedName>[
    SuggestedName('Utkarsh', 'उत्कर्ष', 'Rising', 'उन्नति'),
    SuggestedName('Uma', 'उमा', 'Parvati', 'पार्वती'),
  ],
  'E': <SuggestedName>[
    SuggestedName('Ekansh', 'एकांश', 'A whole part', 'एक अंश'),
  ],
  'O': <SuggestedName>[
    SuggestedName('Om', 'ओम', 'The first sound', 'प्रणव'),
    SuggestedName('Ojas', 'ओजस', 'Vital strength', 'तेज'),
  ],
  'Va': <SuggestedName>[
    SuggestedName('Vaani', 'वाणी', 'Speech, Saraswati', 'सरस्वती'),
    SuggestedName('Varun', 'वरुण', 'Lord of the waters', 'जल के देव'),
  ],
  'Vi': <SuggestedName>[
    SuggestedName('Vihaan', 'विहान', 'First light', 'प्रभात'),
    SuggestedName('Vidhi', 'विधि', 'Rule, destiny', 'विधान'),
  ],
  'Ka': <SuggestedName>[
    SuggestedName('Kabir', 'कबीर', 'Great', 'महान'),
    SuggestedName('Kavya', 'काव्य', 'Poetry', 'कविता'),
  ],
  'Ki': <SuggestedName>[
    SuggestedName('Kiaan', 'कियान', 'Grace of God', 'ईश्वर की कृपा'),
  ],
  'Ke': <SuggestedName>[SuggestedName('Keshav', 'केशव', 'Krishna', 'कृष्ण')],
  'Ko': <SuggestedName>[SuggestedName('Komal', 'कोमल', 'Soft', 'कोमल')],
  'Ha': <SuggestedName>[
    SuggestedName('Harsh', 'हर्ष', 'Joy', 'आनंद'),
    SuggestedName('Hansika', 'हंसिका', 'Swan', 'हंस'),
  ],
  'Hi': <SuggestedName>[
    SuggestedName('Hitesh', 'हितेश', 'One who wishes good', 'हित करने वाला'),
  ],
  'Ma': <SuggestedName>[
    SuggestedName('Manan', 'मनन', 'Reflection', 'चिंतन'),
    SuggestedName('Maitri', 'मैत्री', 'Friendship', 'मित्रता'),
  ],
  'Mi': <SuggestedName>[SuggestedName('Mihir', 'मिहिर', 'The Sun', 'सूर्य')],
  'Mu': <SuggestedName>[SuggestedName('Mukul', 'मुकुल', 'A bud', 'कली')],
  'Me': <SuggestedName>[SuggestedName('Megha', 'मेघा', 'Cloud', 'बादल')],
  'Na': <SuggestedName>[
    SuggestedName('Naman', 'नमन', 'Bowing', 'प्रणाम'),
    SuggestedName('Navya', 'नव्य', 'New', 'नया'),
  ],
  'Ni': <SuggestedName>[SuggestedName('Nitya', 'नित्य', 'Constant', 'शाश्वत')],
  'Pa': <SuggestedName>[
    SuggestedName('Parth', 'पार्थ', 'Arjuna', 'अर्जुन'),
    SuggestedName('Pavani', 'पावनी', 'Purifying', 'पवित्र'),
  ],
  'Pi': <SuggestedName>[SuggestedName('Piyush', 'पीयूष', 'Nectar', 'अमृत')],
  'Ra': <SuggestedName>[
    SuggestedName('Raghav', 'राघव', 'Of Raghu’s line, Rama', 'राम'),
    SuggestedName('Radhika', 'राधिका', 'Radha', 'राधा'),
  ],
  'Ri': <SuggestedName>[SuggestedName('Riya', 'रिया', 'Singer', 'गायिका')],
  'Sa': <SuggestedName>[
    SuggestedName('Sanvi', 'सान्वी', 'Lakshmi', 'लक्ष्मी'),
    SuggestedName('Samarth', 'समर्थ', 'Capable', 'सक्षम'),
  ],
  'Si': <SuggestedName>[
    SuggestedName(
      'Siddharth',
      'सिद्धार्थ',
      'One whose aim is accomplished',
      'सिद्ध अर्थ वाला',
    ),
  ],
  'Su': <SuggestedName>[SuggestedName('Suhani', 'सुहानी', 'Pleasant', 'प्रिय')],
  'De': <SuggestedName>[
    SuggestedName('Dev', 'देव', 'God', 'देवता'),
    SuggestedName('Devika', 'देविका', 'Little goddess', 'लघु देवी'),
  ],
  'Do': <SuggestedName>[SuggestedName('Dolan', 'डोलन', 'Swinging', 'झूलना')],
  'Cha': <SuggestedName>[
    SuggestedName('Chandni', 'चाँदनी', 'Moonlight', 'चाँदनी'),
  ],
  'Chi': <SuggestedName>[SuggestedName('Chirag', 'चिराग', 'Lamp', 'दीपक')],
  'Ga': <SuggestedName>[
    SuggestedName('Gaurav', 'गौरव', 'Pride, honour', 'सम्मान'),
  ],
  'Ja': <SuggestedName>[
    SuggestedName('Jay', 'जय', 'Victory', 'विजय'),
    SuggestedName('Janvi', 'जाह्नवी', 'The Ganga', 'गंगा'),
  ],
  'Ya': <SuggestedName>[SuggestedName('Yash', 'यश', 'Fame', 'कीर्ति')],
  'Ta': <SuggestedName>[
    SuggestedName('Tanvi', 'तन्वी', 'Slender, Parvati', 'पार्वती'),
  ],
  'Te': <SuggestedName>[SuggestedName('Tejas', 'तेजस', 'Radiance', 'तेज')],
  'Bha': <SuggestedName>[SuggestedName('Bhavya', 'भव्य', 'Grand', 'भव्य')],
};

class NamkaranSuggestion {
  const NamkaranSuggestion({
    required this.nakshatra,
    required this.pada,
    required this.syllable,
    required this.syllableHindi,
    required this.names,
    required this.alternates,
  });

  final NakshatraInfo nakshatra;
  final int pada;
  final String syllable;
  final String syllableHindi;
  final List<SuggestedName> names;

  /// The other three padas of the same nakshatra, which many families accept.
  final List<String> alternates;
}

NamkaranSuggestion namkaranFor(double moonSiderealLongitude) {
  final NakshatraInfo nakshatra = nakshatraOf(moonSiderealLongitude);
  final int pada = padaOf(moonSiderealLongitude);
  final String syllable = padaSyllables[nakshatra.index][pada - 1];
  return NamkaranSuggestion(
    nakshatra: nakshatra,
    pada: pada,
    syllable: syllable,
    syllableHindi: padaSyllablesHindi[nakshatra.index][pada - 1],
    names: namesBySyllable[syllable] ?? const <SuggestedName>[],
    alternates: padaSyllables[nakshatra.index],
  );
}
