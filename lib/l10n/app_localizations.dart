import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'KundliSaar'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your kundli, computed on your phone, explained in your language'**
  String get tagline;

  /// No description provided for @newChart.
  ///
  /// In en, this message translates to:
  /// **'New kundli'**
  String get newChart;

  /// No description provided for @savedCharts.
  ///
  /// In en, this message translates to:
  /// **'Saved kundlis'**
  String get savedCharts;

  /// No description provided for @openChart.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openChart;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get birthDate;

  /// No description provided for @birthTime.
  ///
  /// In en, this message translates to:
  /// **'Time of birth'**
  String get birthTime;

  /// No description provided for @birthPlace.
  ///
  /// In en, this message translates to:
  /// **'Place of birth'**
  String get birthPlace;

  /// No description provided for @timeNotSure.
  ///
  /// In en, this message translates to:
  /// **'I am not sure of the time'**
  String get timeNotSure;

  /// No description provided for @timeNotSureHelp.
  ///
  /// In en, this message translates to:
  /// **'We will still cast the chart. The Moon, the nakshatra and the dasha stay reliable; the lagna and the houses may shift.'**
  String get timeNotSureHelp;

  /// No description provided for @computeChart.
  ///
  /// In en, this message translates to:
  /// **'Show my kundli'**
  String get computeChart;

  /// No description provided for @searchPlace.
  ///
  /// In en, this message translates to:
  /// **'Search for a town or city'**
  String get searchPlace;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found. Try another spelling.'**
  String get noResults;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tabChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get tabChart;

  /// No description provided for @tabDasha.
  ///
  /// In en, this message translates to:
  /// **'Periods'**
  String get tabDasha;

  /// No description provided for @tabPanchang.
  ///
  /// In en, this message translates to:
  /// **'Panchang'**
  String get tabPanchang;

  /// No description provided for @tabMatch.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get tabMatch;

  /// No description provided for @tabAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get tabAsk;

  /// No description provided for @tabLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get tabLearn;

  /// No description provided for @lagna.
  ///
  /// In en, this message translates to:
  /// **'Lagna'**
  String get lagna;

  /// No description provided for @moonSign.
  ///
  /// In en, this message translates to:
  /// **'Moon sign'**
  String get moonSign;

  /// No description provided for @sunSign.
  ///
  /// In en, this message translates to:
  /// **'Sun sign'**
  String get sunSign;

  /// No description provided for @nakshatra.
  ///
  /// In en, this message translates to:
  /// **'Nakshatra'**
  String get nakshatra;

  /// No description provided for @pada.
  ///
  /// In en, this message translates to:
  /// **'Pada'**
  String get pada;

  /// No description provided for @house.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get house;

  /// No description provided for @sign.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get sign;

  /// No description provided for @degree.
  ///
  /// In en, this message translates to:
  /// **'Degree'**
  String get degree;

  /// No description provided for @planet.
  ///
  /// In en, this message translates to:
  /// **'Planet'**
  String get planet;

  /// No description provided for @planets.
  ///
  /// In en, this message translates to:
  /// **'Grahas'**
  String get planets;

  /// No description provided for @retrograde.
  ///
  /// In en, this message translates to:
  /// **'Retrograde'**
  String get retrograde;

  /// No description provided for @combust.
  ///
  /// In en, this message translates to:
  /// **'Combust'**
  String get combust;

  /// No description provided for @dignityExalted.
  ///
  /// In en, this message translates to:
  /// **'Exalted'**
  String get dignityExalted;

  /// No description provided for @dignityDebilitated.
  ///
  /// In en, this message translates to:
  /// **'Debilitated'**
  String get dignityDebilitated;

  /// No description provided for @dignityOwn.
  ///
  /// In en, this message translates to:
  /// **'Own sign'**
  String get dignityOwn;

  /// No description provided for @dignityMoolatrikona.
  ///
  /// In en, this message translates to:
  /// **'Moolatrikona'**
  String get dignityMoolatrikona;

  /// No description provided for @dignityFriend.
  ///
  /// In en, this message translates to:
  /// **'Friendly sign'**
  String get dignityFriend;

  /// No description provided for @dignityNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral sign'**
  String get dignityNeutral;

  /// No description provided for @dignityEnemy.
  ///
  /// In en, this message translates to:
  /// **'Enemy sign'**
  String get dignityEnemy;

  /// No description provided for @chartStyleNorth.
  ///
  /// In en, this message translates to:
  /// **'North Indian'**
  String get chartStyleNorth;

  /// No description provided for @chartStyleSouth.
  ///
  /// In en, this message translates to:
  /// **'South Indian'**
  String get chartStyleSouth;

  /// No description provided for @chartStyleEast.
  ///
  /// In en, this message translates to:
  /// **'East Indian'**
  String get chartStyleEast;

  /// No description provided for @divisionalCharts.
  ///
  /// In en, this message translates to:
  /// **'Divisional charts'**
  String get divisionalCharts;

  /// No description provided for @showTheAstrology.
  ///
  /// In en, this message translates to:
  /// **'Show the astrology'**
  String get showTheAstrology;

  /// No description provided for @hideTheAstrology.
  ///
  /// In en, this message translates to:
  /// **'Hide the detail'**
  String get hideTheAstrology;

  /// No description provided for @mahadasha.
  ///
  /// In en, this message translates to:
  /// **'Mahadasha'**
  String get mahadasha;

  /// No description provided for @antardasha.
  ///
  /// In en, this message translates to:
  /// **'Antardasha'**
  String get antardasha;

  /// No description provided for @pratyantardasha.
  ///
  /// In en, this message translates to:
  /// **'Pratyantardasha'**
  String get pratyantardasha;

  /// No description provided for @runningNow.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get runningNow;

  /// No description provided for @balanceAtBirth.
  ///
  /// In en, this message translates to:
  /// **'Balance at birth'**
  String get balanceAtBirth;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @tithi.
  ///
  /// In en, this message translates to:
  /// **'Tithi'**
  String get tithi;

  /// No description provided for @paksha.
  ///
  /// In en, this message translates to:
  /// **'Paksha'**
  String get paksha;

  /// No description provided for @yoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get yoga;

  /// No description provided for @karana.
  ///
  /// In en, this message translates to:
  /// **'Karana'**
  String get karana;

  /// No description provided for @vara.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get vara;

  /// No description provided for @sunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get sunrise;

  /// No description provided for @sunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get sunset;

  /// No description provided for @moonrise.
  ///
  /// In en, this message translates to:
  /// **'Moonrise'**
  String get moonrise;

  /// No description provided for @moonset.
  ///
  /// In en, this message translates to:
  /// **'Moonset'**
  String get moonset;

  /// No description provided for @rahuKaal.
  ///
  /// In en, this message translates to:
  /// **'Rahu Kaal'**
  String get rahuKaal;

  /// No description provided for @gulika.
  ///
  /// In en, this message translates to:
  /// **'Gulika Kaal'**
  String get gulika;

  /// No description provided for @yamaganda.
  ///
  /// In en, this message translates to:
  /// **'Yamaganda'**
  String get yamaganda;

  /// No description provided for @abhijit.
  ///
  /// In en, this message translates to:
  /// **'Abhijit Muhurta'**
  String get abhijit;

  /// No description provided for @choghadiyaDay.
  ///
  /// In en, this message translates to:
  /// **'Day Choghadiya'**
  String get choghadiyaDay;

  /// No description provided for @choghadiyaNight.
  ///
  /// In en, this message translates to:
  /// **'Night Choghadiya'**
  String get choghadiyaNight;

  /// No description provided for @hora.
  ///
  /// In en, this message translates to:
  /// **'Hora'**
  String get hora;

  /// No description provided for @untilTime.
  ///
  /// In en, this message translates to:
  /// **'until {time}'**
  String untilTime(String time);

  /// No description provided for @yogasAndDoshas.
  ///
  /// In en, this message translates to:
  /// **'Yogas and doshas'**
  String get yogasAndDoshas;

  /// No description provided for @whyThis.
  ///
  /// In en, this message translates to:
  /// **'Why the chart says this'**
  String get whyThis;

  /// No description provided for @whatItMeans.
  ///
  /// In en, this message translates to:
  /// **'What the tradition says'**
  String get whatItMeans;

  /// No description provided for @cancelledBy.
  ///
  /// In en, this message translates to:
  /// **'What weakens it'**
  String get cancelledBy;

  /// No description provided for @noYogasFound.
  ///
  /// In en, this message translates to:
  /// **'No major yoga or dosha stands out in this chart.'**
  String get noYogasFound;

  /// No description provided for @remedies.
  ///
  /// In en, this message translates to:
  /// **'Remedies'**
  String get remedies;

  /// No description provided for @mantra.
  ///
  /// In en, this message translates to:
  /// **'Mantra'**
  String get mantra;

  /// No description provided for @gemstone.
  ///
  /// In en, this message translates to:
  /// **'Gemstone'**
  String get gemstone;

  /// No description provided for @deity.
  ///
  /// In en, this message translates to:
  /// **'Deity'**
  String get deity;

  /// No description provided for @charity.
  ///
  /// In en, this message translates to:
  /// **'Daan'**
  String get charity;

  /// No description provided for @fastingDay.
  ///
  /// In en, this message translates to:
  /// **'Fasting day'**
  String get fastingDay;

  /// No description provided for @mythology.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get mythology;

  /// No description provided for @matchTitle.
  ///
  /// In en, this message translates to:
  /// **'Kundli Milan'**
  String get matchTitle;

  /// No description provided for @bride.
  ///
  /// In en, this message translates to:
  /// **'Bride'**
  String get bride;

  /// No description provided for @groom.
  ///
  /// In en, this message translates to:
  /// **'Groom'**
  String get groom;

  /// No description provided for @gunaScore.
  ///
  /// In en, this message translates to:
  /// **'{score} of 36 gunas'**
  String gunaScore(String score);

  /// No description provided for @mangalDosha.
  ///
  /// In en, this message translates to:
  /// **'Mangal dosha'**
  String get mangalDosha;

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// No description provided for @absent.
  ///
  /// In en, this message translates to:
  /// **'Not present'**
  String get absent;

  /// No description provided for @matchNote.
  ///
  /// In en, this message translates to:
  /// **'The score is one traditional measure among several. It is not a decision about two people.'**
  String get matchNote;

  /// No description provided for @askTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask about this kundli'**
  String get askTitle;

  /// No description provided for @askPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask anything, in Hindi or English'**
  String get askPlaceholder;

  /// No description provided for @askAnswerSource.
  ///
  /// In en, this message translates to:
  /// **'Read from'**
  String get askAnswerSource;

  /// No description provided for @askNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'I cannot answer that from this chart yet. Try one of the questions below.'**
  String get askNoAnswer;

  /// No description provided for @learnTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learnTitle;

  /// No description provided for @learnGrahas.
  ///
  /// In en, this message translates to:
  /// **'The nine grahas'**
  String get learnGrahas;

  /// No description provided for @learnRashis.
  ///
  /// In en, this message translates to:
  /// **'The twelve rashis'**
  String get learnRashis;

  /// No description provided for @learnNakshatras.
  ///
  /// In en, this message translates to:
  /// **'The 27 nakshatras'**
  String get learnNakshatras;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @ayanamsa.
  ///
  /// In en, this message translates to:
  /// **'Ayanamsa'**
  String get ayanamsa;

  /// No description provided for @chartStyle.
  ///
  /// In en, this message translates to:
  /// **'Chart style'**
  String get chartStyle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your birth details never leave this device. There is no account and nothing is uploaded.'**
  String get privacyNote;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'This is traditional Vedic guidance and cultural material, not medical, legal or financial advice.'**
  String get disclaimer;

  /// No description provided for @accuracyNote.
  ///
  /// In en, this message translates to:
  /// **'Positions are computed with our own ephemeris, accurate to about an arc-second against JPL DE440s.'**
  String get accuracyNote;

  /// No description provided for @ayanamsaValue.
  ///
  /// In en, this message translates to:
  /// **'Ayanamsa {value}'**
  String ayanamsaValue(String value);

  /// No description provided for @profileEmpty.
  ///
  /// In en, this message translates to:
  /// **'No kundli saved yet.'**
  String get profileEmpty;

  /// No description provided for @readAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get readAloud;

  /// No description provided for @stopReading.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopReading;

  /// No description provided for @featureStrengths.
  ///
  /// In en, this message translates to:
  /// **'Strengths'**
  String get featureStrengths;

  /// No description provided for @featureTransits.
  ///
  /// In en, this message translates to:
  /// **'Transits'**
  String get featureTransits;

  /// No description provided for @featureMuhurta.
  ///
  /// In en, this message translates to:
  /// **'Muhurta'**
  String get featureMuhurta;

  /// No description provided for @featureVarshphal.
  ///
  /// In en, this message translates to:
  /// **'Year chart'**
  String get featureVarshphal;

  /// No description provided for @featureNumerology.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get featureNumerology;

  /// No description provided for @featurePrashna.
  ///
  /// In en, this message translates to:
  /// **'Prashna'**
  String get featurePrashna;

  /// No description provided for @featureRashifal.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get featureRashifal;

  /// No description provided for @featureFestivals.
  ///
  /// In en, this message translates to:
  /// **'Festivals'**
  String get featureFestivals;

  /// No description provided for @featureNamkaran.
  ///
  /// In en, this message translates to:
  /// **'Baby name'**
  String get featureNamkaran;

  /// No description provided for @featureRemedies.
  ///
  /// In en, this message translates to:
  /// **'Remedies'**
  String get featureRemedies;

  /// No description provided for @featureHastrekha.
  ///
  /// In en, this message translates to:
  /// **'Palm'**
  String get featureHastrekha;

  /// No description provided for @shadbala.
  ///
  /// In en, this message translates to:
  /// **'Shadbala'**
  String get shadbala;

  /// No description provided for @ashtakavarga.
  ///
  /// In en, this message translates to:
  /// **'Ashtakavarga'**
  String get ashtakavarga;

  /// No description provided for @sarvashtakavarga.
  ///
  /// In en, this message translates to:
  /// **'Sarvashtakavarga'**
  String get sarvashtakavarga;

  /// No description provided for @bindus.
  ///
  /// In en, this message translates to:
  /// **'bindus'**
  String get bindus;

  /// No description provided for @rupas.
  ///
  /// In en, this message translates to:
  /// **'rupas'**
  String get rupas;

  /// No description provided for @needs.
  ///
  /// In en, this message translates to:
  /// **'needs'**
  String get needs;

  /// No description provided for @strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strong;

  /// No description provided for @weak.
  ///
  /// In en, this message translates to:
  /// **'Below strength'**
  String get weak;

  /// No description provided for @sadeSati.
  ///
  /// In en, this message translates to:
  /// **'Sade Sati'**
  String get sadeSati;

  /// No description provided for @runningPhase.
  ///
  /// In en, this message translates to:
  /// **'Phase {phase} of three'**
  String runningPhase(String phase);

  /// No description provided for @aspectsOnNatal.
  ///
  /// In en, this message translates to:
  /// **'Transits touching your chart'**
  String get aspectsOnNatal;

  /// No description provided for @nextReturn.
  ///
  /// In en, this message translates to:
  /// **'Returns to its natal sign'**
  String get nextReturn;

  /// No description provided for @chooseActivity.
  ///
  /// In en, this message translates to:
  /// **'What is the work?'**
  String get chooseActivity;

  /// No description provided for @searchDays.
  ///
  /// In en, this message translates to:
  /// **'Days to search'**
  String get searchDays;

  /// No description provided for @bestWindows.
  ///
  /// In en, this message translates to:
  /// **'Best windows found'**
  String get bestWindows;

  /// No description provided for @whyThisWindow.
  ///
  /// In en, this message translates to:
  /// **'Why'**
  String get whyThisWindow;

  /// No description provided for @solarReturn.
  ///
  /// In en, this message translates to:
  /// **'Solar return'**
  String get solarReturn;

  /// No description provided for @muntha.
  ///
  /// In en, this message translates to:
  /// **'Muntha'**
  String get muntha;

  /// No description provided for @yearLord.
  ///
  /// In en, this message translates to:
  /// **'Lord of the year'**
  String get yearLord;

  /// No description provided for @chooseYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get chooseYear;

  /// No description provided for @mulank.
  ///
  /// In en, this message translates to:
  /// **'Mulank, the birth number'**
  String get mulank;

  /// No description provided for @bhagyank.
  ///
  /// In en, this message translates to:
  /// **'Bhagyank, the destiny number'**
  String get bhagyank;

  /// No description provided for @namank.
  ///
  /// In en, this message translates to:
  /// **'Namank, the name number'**
  String get namank;

  /// No description provided for @loshuGrid.
  ///
  /// In en, this message translates to:
  /// **'Lo Shu grid'**
  String get loshuGrid;

  /// No description provided for @missingNumbers.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missingNumbers;

  /// No description provided for @repeatedNumbers.
  ///
  /// In en, this message translates to:
  /// **'Repeated'**
  String get repeatedNumbers;

  /// No description provided for @luckyColour.
  ///
  /// In en, this message translates to:
  /// **'Colours'**
  String get luckyColour;

  /// No description provided for @luckyNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get luckyNumber;

  /// No description provided for @luckyDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get luckyDays;

  /// No description provided for @askPrashna.
  ///
  /// In en, this message translates to:
  /// **'Ask the moment'**
  String get askPrashna;

  /// No description provided for @prashnaHint.
  ///
  /// In en, this message translates to:
  /// **'Type the question you are holding'**
  String get prashnaHint;

  /// No description provided for @castNow.
  ///
  /// In en, this message translates to:
  /// **'Cast the chart for now'**
  String get castNow;

  /// No description provided for @theLeaning.
  ///
  /// In en, this message translates to:
  /// **'What the chart leans to'**
  String get theLeaning;

  /// No description provided for @whatItReads.
  ///
  /// In en, this message translates to:
  /// **'What it read'**
  String get whatItReads;

  /// No description provided for @dailyReading.
  ///
  /// In en, this message translates to:
  /// **'Today for you'**
  String get dailyReading;

  /// No description provided for @tara.
  ///
  /// In en, this message translates to:
  /// **'Tara'**
  String get tara;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get upcoming;

  /// No description provided for @wholeYear.
  ///
  /// In en, this message translates to:
  /// **'Whole year'**
  String get wholeYear;

  /// No description provided for @syllable.
  ///
  /// In en, this message translates to:
  /// **'Syllable'**
  String get syllable;

  /// No description provided for @suggestedNames.
  ///
  /// In en, this message translates to:
  /// **'Names that fit'**
  String get suggestedNames;

  /// No description provided for @otherPadas.
  ///
  /// In en, this message translates to:
  /// **'The other padas'**
  String get otherPadas;

  /// No description provided for @japaCount.
  ///
  /// In en, this message translates to:
  /// **'Japa count'**
  String get japaCount;

  /// No description provided for @daan.
  ///
  /// In en, this message translates to:
  /// **'What to give'**
  String get daan;

  /// No description provided for @yantra.
  ///
  /// In en, this message translates to:
  /// **'Yantra'**
  String get yantra;

  /// No description provided for @simpleAct.
  ///
  /// In en, this message translates to:
  /// **'Do this today'**
  String get simpleAct;

  /// No description provided for @gemstoneWarning.
  ///
  /// In en, this message translates to:
  /// **'Ask someone knowledgeable before wearing a stone. Mantra and giving are safe for anyone.'**
  String get gemstoneWarning;

  /// No description provided for @tracePalm.
  ///
  /// In en, this message translates to:
  /// **'Trace your palm'**
  String get tracePalm;

  /// No description provided for @handType.
  ///
  /// In en, this message translates to:
  /// **'Hand type'**
  String get handType;

  /// No description provided for @palmLines.
  ///
  /// In en, this message translates to:
  /// **'The lines'**
  String get palmLines;

  /// No description provided for @palmMounts.
  ///
  /// In en, this message translates to:
  /// **'The mounts'**
  String get palmMounts;

  /// No description provided for @markBreak.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get markBreak;

  /// No description provided for @markChain.
  ///
  /// In en, this message translates to:
  /// **'Chained'**
  String get markChain;

  /// No description provided for @markFork.
  ///
  /// In en, this message translates to:
  /// **'Forked'**
  String get markFork;

  /// No description provided for @notPresent.
  ///
  /// In en, this message translates to:
  /// **'Not present'**
  String get notPresent;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use a photo of my palm'**
  String get takePhoto;

  /// No description provided for @clearPhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove the photo'**
  String get clearPhoto;

  /// No description provided for @readMyPalm.
  ///
  /// In en, this message translates to:
  /// **'Read my palm'**
  String get readMyPalm;

  /// No description provided for @dragToTrace.
  ///
  /// In en, this message translates to:
  /// **'Drag the dots onto your own lines'**
  String get dragToTrace;

  /// No description provided for @prominence.
  ///
  /// In en, this message translates to:
  /// **'How raised'**
  String get prominence;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get listening;

  /// No description provided for @tapToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap to speak'**
  String get tapToSpeak;

  /// No description provided for @speakAnswer.
  ///
  /// In en, this message translates to:
  /// **'Read it aloud'**
  String get speakAnswer;

  /// No description provided for @stopSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopSpeaking;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice is not available on this device'**
  String get voiceUnavailable;

  /// No description provided for @swamijiIdle.
  ///
  /// In en, this message translates to:
  /// **'Ask me about your kundli.'**
  String get swamijiIdle;

  /// No description provided for @swamijiThinking.
  ///
  /// In en, this message translates to:
  /// **'Let me look at the chart.'**
  String get swamijiThinking;

  /// No description provided for @moreFeatures.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreFeatures;

  /// No description provided for @computing.
  ///
  /// In en, this message translates to:
  /// **'Casting the chart'**
  String get computing;

  /// No description provided for @featurePhaladesh.
  ///
  /// In en, this message translates to:
  /// **'Life timeline'**
  String get featurePhaladesh;

  /// No description provided for @phTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get phTimeline;

  /// No description provided for @phHouses.
  ///
  /// In en, this message translates to:
  /// **'Houses'**
  String get phHouses;

  /// No description provided for @phPeriods.
  ///
  /// In en, this message translates to:
  /// **'Periods'**
  String get phPeriods;

  /// No description provided for @phGrahas.
  ///
  /// In en, this message translates to:
  /// **'Grahas'**
  String get phGrahas;

  /// No description provided for @phGochar.
  ///
  /// In en, this message translates to:
  /// **'Transits'**
  String get phGochar;

  /// No description provided for @phTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Your life, window by window'**
  String get phTimelineTitle;

  /// No description provided for @phTimelineSub.
  ///
  /// In en, this message translates to:
  /// **'Dated windows from birth to about ninety, each read from your own chart.'**
  String get phTimelineSub;

  /// No description provided for @phHousesTitle.
  ///
  /// In en, this message translates to:
  /// **'The twelve houses'**
  String get phHousesTitle;

  /// No description provided for @phHousesSub.
  ///
  /// In en, this message translates to:
  /// **'Each house read from its sign, its lord, who sits in it and who looks at it.'**
  String get phHousesSub;

  /// No description provided for @phPeriodsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dasha by dasha'**
  String get phPeriodsTitle;

  /// No description provided for @phPeriodsSub.
  ///
  /// In en, this message translates to:
  /// **'Every mahadasha, antardasha and pratyantardasha with its dates, read against the periods before it, after it and around it.'**
  String get phPeriodsSub;

  /// No description provided for @phGrahasTitle.
  ///
  /// In en, this message translates to:
  /// **'The nine grahas'**
  String get phGrahasTitle;

  /// No description provided for @phGrahasSub.
  ///
  /// In en, this message translates to:
  /// **'Each graha in its sign and house, with its dignity and the company it keeps.'**
  String get phGrahasSub;

  /// No description provided for @phGocharTitle.
  ///
  /// In en, this message translates to:
  /// **'Transits now'**
  String get phGocharTitle;

  /// No description provided for @phGocharSub.
  ///
  /// In en, this message translates to:
  /// **'The slow grahas read against your chart, with the dates they enter and leave each sign.'**
  String get phGocharSub;

  /// No description provided for @phNow.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get phNow;

  /// No description provided for @phAge.
  ///
  /// In en, this message translates to:
  /// **'Age {from} to {to}'**
  String phAge(String from, String to);

  /// No description provided for @phAsks.
  ///
  /// In en, this message translates to:
  /// **'What it asks of you'**
  String get phAsks;

  /// No description provided for @phRelief.
  ///
  /// In en, this message translates to:
  /// **'Relief'**
  String get phRelief;

  /// No description provided for @phLord.
  ///
  /// In en, this message translates to:
  /// **'Lord'**
  String get phLord;

  /// No description provided for @phLordStands.
  ///
  /// In en, this message translates to:
  /// **'Lord stands in'**
  String get phLordStands;

  /// No description provided for @phOccupants.
  ///
  /// In en, this message translates to:
  /// **'Occupants'**
  String get phOccupants;

  /// No description provided for @phAspects.
  ///
  /// In en, this message translates to:
  /// **'Aspected by'**
  String get phAspects;

  /// No description provided for @phNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get phNone;

  /// No description provided for @phEntered.
  ///
  /// In en, this message translates to:
  /// **'Entered the sign'**
  String get phEntered;

  /// No description provided for @phLeaves.
  ///
  /// In en, this message translates to:
  /// **'Leaves the sign'**
  String get phLeaves;

  /// No description provided for @phFromMoon.
  ///
  /// In en, this message translates to:
  /// **'From the Moon'**
  String get phFromMoon;

  /// No description provided for @phFromLagna.
  ///
  /// In en, this message translates to:
  /// **'From the lagna'**
  String get phFromLagna;

  /// No description provided for @phFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get phFocus;

  /// No description provided for @phToneSupportive.
  ///
  /// In en, this message translates to:
  /// **'Supportive'**
  String get phToneSupportive;

  /// No description provided for @phToneMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get phToneMixed;

  /// No description provided for @phToneDemanding.
  ///
  /// In en, this message translates to:
  /// **'Asks for effort'**
  String get phToneDemanding;

  /// No description provided for @phYogas.
  ///
  /// In en, this message translates to:
  /// **'Yogas it takes part in'**
  String get phYogas;

  /// No description provided for @phApproxTime.
  ///
  /// In en, this message translates to:
  /// **'You marked the birth time as approximate. Dasha dates rest on the Moon’s exact position, so every date here can move by months. Trust the order of the periods more than the dates.'**
  String get phApproxTime;

  /// No description provided for @phScope.
  ///
  /// In en, this message translates to:
  /// **'These readings describe areas of life and the character of a time. They do not speak to death, illness, pregnancy, examinations, legal matters or investments, and nothing here forecasts an event.'**
  String get phScope;

  /// No description provided for @phPromise.
  ///
  /// In en, this message translates to:
  /// **'What this lord promises'**
  String get phPromise;

  /// No description provided for @phModifier.
  ///
  /// In en, this message translates to:
  /// **'Counted from the lord of the period above'**
  String get phModifier;

  /// No description provided for @phContext.
  ///
  /// In en, this message translates to:
  /// **'The periods before and after'**
  String get phContext;

  /// No description provided for @phUntil.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String phUntil(String date);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
