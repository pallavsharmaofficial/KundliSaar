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

  @override
  String get featureStrengths => 'Strengths';

  @override
  String get featureTransits => 'Transits';

  @override
  String get featureMuhurta => 'Muhurta';

  @override
  String get featureVarshphal => 'Year chart';

  @override
  String get featureNumerology => 'Numbers';

  @override
  String get featurePrashna => 'Prashna';

  @override
  String get featureRashifal => 'Today';

  @override
  String get featureFestivals => 'Festivals';

  @override
  String get featureNamkaran => 'Baby name';

  @override
  String get featureRemedies => 'Remedies';

  @override
  String get featureHastrekha => 'Palm';

  @override
  String get shadbala => 'Shadbala';

  @override
  String get ashtakavarga => 'Ashtakavarga';

  @override
  String get sarvashtakavarga => 'Sarvashtakavarga';

  @override
  String get bindus => 'bindus';

  @override
  String get rupas => 'rupas';

  @override
  String get needs => 'needs';

  @override
  String get strong => 'Strong';

  @override
  String get weak => 'Below strength';

  @override
  String get sadeSati => 'Sade Sati';

  @override
  String runningPhase(String phase) {
    return 'Phase $phase of three';
  }

  @override
  String get aspectsOnNatal => 'Transits touching your chart';

  @override
  String get nextReturn => 'Returns to its natal sign';

  @override
  String get chooseActivity => 'What is the work?';

  @override
  String get searchDays => 'Days to search';

  @override
  String get bestWindows => 'Best windows found';

  @override
  String get whyThisWindow => 'Why';

  @override
  String get solarReturn => 'Solar return';

  @override
  String get muntha => 'Muntha';

  @override
  String get yearLord => 'Lord of the year';

  @override
  String get chooseYear => 'Year';

  @override
  String get mulank => 'Mulank, the birth number';

  @override
  String get bhagyank => 'Bhagyank, the destiny number';

  @override
  String get namank => 'Namank, the name number';

  @override
  String get loshuGrid => 'Lo Shu grid';

  @override
  String get missingNumbers => 'Missing';

  @override
  String get repeatedNumbers => 'Repeated';

  @override
  String get luckyColour => 'Colours';

  @override
  String get luckyNumber => 'Number';

  @override
  String get luckyDays => 'Days';

  @override
  String get askPrashna => 'Ask the moment';

  @override
  String get prashnaHint => 'Type the question you are holding';

  @override
  String get castNow => 'Cast the chart for now';

  @override
  String get theLeaning => 'What the chart leans to';

  @override
  String get whatItReads => 'What it read';

  @override
  String get dailyReading => 'Today for you';

  @override
  String get tara => 'Tara';

  @override
  String get upcoming => 'Coming up';

  @override
  String get wholeYear => 'Whole year';

  @override
  String get syllable => 'Syllable';

  @override
  String get suggestedNames => 'Names that fit';

  @override
  String get otherPadas => 'The other padas';

  @override
  String get japaCount => 'Japa count';

  @override
  String get daan => 'What to give';

  @override
  String get yantra => 'Yantra';

  @override
  String get simpleAct => 'Do this today';

  @override
  String get gemstoneWarning =>
      'Ask someone knowledgeable before wearing a stone. Mantra and giving are safe for anyone.';

  @override
  String get tracePalm => 'Trace your palm';

  @override
  String get handType => 'Hand type';

  @override
  String get palmLines => 'The lines';

  @override
  String get palmMounts => 'The mounts';

  @override
  String get markBreak => 'Break';

  @override
  String get markChain => 'Chained';

  @override
  String get markFork => 'Forked';

  @override
  String get notPresent => 'Not present';

  @override
  String get takePhoto => 'Use a photo of my palm';

  @override
  String get clearPhoto => 'Remove the photo';

  @override
  String get readMyPalm => 'Read my palm';

  @override
  String get dragToTrace => 'Drag the dots onto your own lines';

  @override
  String get prominence => 'How raised';

  @override
  String get listening => 'Listening';

  @override
  String get tapToSpeak => 'Tap to speak';

  @override
  String get speakAnswer => 'Read it aloud';

  @override
  String get stopSpeaking => 'Stop';

  @override
  String get voiceUnavailable => 'Voice is not available on this device';

  @override
  String get swamijiIdle => 'Ask me about your kundli.';

  @override
  String get swamijiThinking => 'Let me look at the chart.';

  @override
  String get moreFeatures => 'More';

  @override
  String get computing => 'Casting the chart';
}
