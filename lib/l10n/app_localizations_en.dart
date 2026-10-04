// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KundliSaar';

  @override
  String get tagline =>
      'Your kundli, computed on your phone, explained in your language';

  @override
  String get newChart => 'New kundli';

  @override
  String get savedCharts => 'Saved kundlis';

  @override
  String get openChart => 'Open';

  @override
  String get name => 'Name';

  @override
  String get birthDate => 'Date of birth';

  @override
  String get birthTime => 'Time of birth';

  @override
  String get birthPlace => 'Place of birth';

  @override
  String get timeNotSure => 'I am not sure of the time';

  @override
  String get timeNotSureHelp =>
      'We will still cast the chart. The Moon, the nakshatra and the dasha stay reliable; the lagna and the houses may shift.';

  @override
  String get computeChart => 'Show my kundli';

  @override
  String get searchPlace => 'Search for a town or city';

  @override
  String get noResults => 'Nothing found. Try another spelling.';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get today => 'Today';

  @override
  String get tabChart => 'Chart';

  @override
  String get tabDasha => 'Periods';

  @override
  String get tabPanchang => 'Panchang';

  @override
  String get tabMatch => 'Matching';

  @override
  String get tabAsk => 'Ask';

  @override
  String get tabLearn => 'Learn';

  @override
  String get lagna => 'Lagna';

  @override
  String get moonSign => 'Moon sign';

  @override
  String get sunSign => 'Sun sign';

  @override
  String get nakshatra => 'Nakshatra';

  @override
  String get pada => 'Pada';

  @override
  String get house => 'House';

  @override
  String get sign => 'Sign';

  @override
  String get degree => 'Degree';

  @override
  String get planet => 'Planet';

  @override
  String get planets => 'Grahas';

  @override
  String get retrograde => 'Retrograde';

  @override
  String get combust => 'Combust';

  @override
  String get dignityExalted => 'Exalted';

  @override
  String get dignityDebilitated => 'Debilitated';

  @override
  String get dignityOwn => 'Own sign';

  @override
  String get dignityMoolatrikona => 'Moolatrikona';

  @override
  String get dignityFriend => 'Friendly sign';

  @override
  String get dignityNeutral => 'Neutral sign';

  @override
  String get dignityEnemy => 'Enemy sign';

  @override
  String get chartStyleNorth => 'North Indian';

  @override
  String get chartStyleSouth => 'South Indian';

  @override
  String get chartStyleEast => 'East Indian';

  @override
  String get divisionalCharts => 'Divisional charts';

  @override
  String get showTheAstrology => 'Show the astrology';

  @override
  String get hideTheAstrology => 'Hide the detail';

  @override
  String get mahadasha => 'Mahadasha';

  @override
  String get antardasha => 'Antardasha';

  @override
  String get pratyantardasha => 'Pratyantardasha';

  @override
  String get runningNow => 'Running now';

  @override
  String get balanceAtBirth => 'Balance at birth';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get tithi => 'Tithi';

  @override
  String get paksha => 'Paksha';

  @override
  String get yoga => 'Yoga';

  @override
  String get karana => 'Karana';

  @override
  String get vara => 'Weekday';

  @override
  String get sunrise => 'Sunrise';

  @override
  String get sunset => 'Sunset';

  @override
  String get moonrise => 'Moonrise';

  @override
  String get moonset => 'Moonset';

  @override
  String get rahuKaal => 'Rahu Kaal';

  @override
  String get gulika => 'Gulika Kaal';

  @override
  String get yamaganda => 'Yamaganda';

  @override
  String get abhijit => 'Abhijit Muhurta';

  @override
  String get choghadiyaDay => 'Day Choghadiya';

  @override
  String get choghadiyaNight => 'Night Choghadiya';

  @override
  String get hora => 'Hora';

  @override
  String untilTime(String time) {
    return 'until $time';
  }

  @override
  String get yogasAndDoshas => 'Yogas and doshas';

  @override
  String get whyThis => 'Why the chart says this';

  @override
  String get whatItMeans => 'What the tradition says';

  @override
  String get cancelledBy => 'What weakens it';

  @override
  String get noYogasFound => 'No major yoga or dosha stands out in this chart.';

  @override
  String get remedies => 'Remedies';

  @override
  String get mantra => 'Mantra';

  @override
  String get gemstone => 'Gemstone';

  @override
  String get deity => 'Deity';

  @override
  String get charity => 'Daan';

  @override
  String get fastingDay => 'Fasting day';

  @override
  String get mythology => 'Story';

  @override
  String get matchTitle => 'Kundli Milan';

  @override
  String get bride => 'Bride';

  @override
  String get groom => 'Groom';

  @override
  String gunaScore(String score) {
    return '$score of 36 gunas';
  }

  @override
  String get mangalDosha => 'Mangal dosha';

  @override
  String get present => 'Present';

  @override
  String get absent => 'Not present';

  @override
  String get matchNote =>
      'The score is one traditional measure among several. It is not a decision about two people.';

  @override
  String get askTitle => 'Ask about this kundli';

  @override
  String get askPlaceholder => 'Ask anything, in Hindi or English';

  @override
  String get askAnswerSource => 'Read from';

  @override
  String get askNoAnswer =>
      'I cannot answer that from this chart yet. Try one of the questions below.';

  @override
  String get learnTitle => 'Learn';

  @override
  String get learnGrahas => 'The nine grahas';

  @override
  String get learnRashis => 'The twelve rashis';

  @override
  String get learnNakshatras => 'The 27 nakshatras';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get ayanamsa => 'Ayanamsa';

  @override
  String get chartStyle => 'Chart style';

  @override
  String get about => 'About';

  @override
  String get privacyNote =>
      'Your birth details never leave this device. There is no account and nothing is uploaded.';

  @override
  String get disclaimer =>
      'This is traditional Vedic guidance and cultural material, not medical, legal or financial advice.';

  @override
  String get accuracyNote =>
      'Positions are computed with our own ephemeris, accurate to about an arc-second against JPL DE440s.';

  @override
  String ayanamsaValue(String value) {
    return 'Ayanamsa $value';
  }

  @override
  String get profileEmpty => 'No kundli saved yet.';

  @override
  String get readAloud => 'Read aloud';

  @override
  String get stopReading => 'Stop';
}
