import '../astro/ephemeris.dart';

class GrahaInfo {
  const GrahaInfo({
    required this.graha,
    required this.english,
    required this.hindi,
    required this.sanskrit,
    required this.exaltationDegree,
    required this.ownSigns,
    required this.moolatrikona,
    required this.karaka,
    required this.deityEnglish,
    required this.deityHindi,
    required this.gemstone,
    required this.gemstoneHindi,
    required this.metal,
    required this.mantra,
    required this.weekday,
    required this.combustionOrb,
  });

  final Graha graha;
  final String english;
  final String hindi;
  final String sanskrit;

  /// Degree of deepest exaltation on the 360 degree sidereal circle.
  final double? exaltationDegree;
  final List<int> ownSigns;

  /// Sign and degree range of moolatrikona, or null.
  final List<double>? moolatrikona;
  final String karaka;
  final String deityEnglish;
  final String deityHindi;
  final String gemstone;
  final String gemstoneHindi;
  final String metal;
  final String mantra;

  /// 0 = Sunday.
  final int weekday;
  final double combustionOrb;
}

const List<GrahaInfo> grahaTable = <GrahaInfo>[
  GrahaInfo(
    graha: Graha.sun,
    english: 'Sun',
    hindi: 'सूर्य',
    sanskrit: 'Surya',
    exaltationDegree: 10,
    ownSigns: <int>[4],
    moolatrikona: <double>[4, 0, 20],
    karaka: 'Soul, father, authority',
    deityEnglish: 'Surya',
    deityHindi: 'सूर्य देव',
    gemstone: 'Ruby',
    gemstoneHindi: 'माणिक्य',
    metal: 'Gold or copper',
    mantra: 'Om Hraam Hreem Hraum Sah Suryaya Namah',
    weekday: 0,
    combustionOrb: 0,
  ),
  GrahaInfo(
    graha: Graha.moon,
    english: 'Moon',
    hindi: 'चंद्र',
    sanskrit: 'Chandra',
    exaltationDegree: 33,
    ownSigns: <int>[3],
    moolatrikona: <double>[1, 4, 30],
    karaka: 'Mind, mother, feeling',
    deityEnglish: 'Chandra',
    deityHindi: 'चंद्र देव',
    gemstone: 'Pearl',
    gemstoneHindi: 'मोती',
    metal: 'Silver',
    mantra: 'Om Shraam Shreem Shraum Sah Chandraya Namah',
    weekday: 1,
    combustionOrb: 12,
  ),
  GrahaInfo(
    graha: Graha.mars,
    english: 'Mars',
    hindi: 'मंगल',
    sanskrit: 'Mangala',
    exaltationDegree: 298,
    ownSigns: <int>[0, 7],
    moolatrikona: <double>[0, 0, 12],
    karaka: 'Courage, brothers, land',
    deityEnglish: 'Kartikeya',
    deityHindi: 'कार्तिकेय',
    gemstone: 'Red coral',
    gemstoneHindi: 'मूंगा',
    metal: 'Copper',
    mantra: 'Om Kraam Kreem Kraum Sah Bhaumaya Namah',
    weekday: 2,
    combustionOrb: 17,
  ),
  GrahaInfo(
    graha: Graha.mercury,
    english: 'Mercury',
    hindi: 'बुध',
    sanskrit: 'Budha',
    exaltationDegree: 165,
    ownSigns: <int>[2, 5],
    moolatrikona: <double>[5, 16, 20],
    karaka: 'Speech, intellect, trade',
    deityEnglish: 'Vishnu',
    deityHindi: 'विष्णु',
    gemstone: 'Emerald',
    gemstoneHindi: 'पन्ना',
    metal: 'Bronze',
    mantra: 'Om Braam Breem Braum Sah Budhaya Namah',
    weekday: 3,
    combustionOrb: 14,
  ),
  GrahaInfo(
    graha: Graha.jupiter,
    english: 'Jupiter',
    hindi: 'गुरु',
    sanskrit: 'Brihaspati',
    exaltationDegree: 95,
    ownSigns: <int>[8, 11],
    moolatrikona: <double>[8, 0, 10],
    karaka: 'Wisdom, children, teachers',
    deityEnglish: 'Brihaspati',
    deityHindi: 'बृहस्पति',
    gemstone: 'Yellow sapphire',
    gemstoneHindi: 'पुखराज',
    metal: 'Gold',
    mantra: 'Om Graam Greem Graum Sah Gurave Namah',
    weekday: 4,
    combustionOrb: 11,
  ),
  GrahaInfo(
    graha: Graha.venus,
    english: 'Venus',
    hindi: 'शुक्र',
    sanskrit: 'Shukra',
    exaltationDegree: 357,
    ownSigns: <int>[1, 6],
    moolatrikona: <double>[6, 0, 15],
    karaka: 'Love, marriage, art',
    deityEnglish: 'Shukracharya',
    deityHindi: 'शुक्राचार्य',
    gemstone: 'Diamond',
    gemstoneHindi: 'हीरा',
    metal: 'Silver',
    mantra: 'Om Draam Dreem Draum Sah Shukraya Namah',
    weekday: 5,
    combustionOrb: 10,
  ),
  GrahaInfo(
    graha: Graha.saturn,
    english: 'Saturn',
    hindi: 'शनि',
    sanskrit: 'Shani',
    exaltationDegree: 200,
    ownSigns: <int>[9, 10],
    moolatrikona: <double>[10, 0, 20],
    karaka: 'Work, discipline, longevity',
    deityEnglish: 'Shani',
    deityHindi: 'शनि देव',
    gemstone: 'Blue sapphire',
    gemstoneHindi: 'नीलम',
    metal: 'Iron',
    mantra: 'Om Praam Preem Praum Sah Shanaischaraya Namah',
    weekday: 6,
    combustionOrb: 15,
  ),
  GrahaInfo(
    graha: Graha.rahu,
    english: 'Rahu',
    hindi: 'राहु',
    sanskrit: 'Rahu',
    exaltationDegree: 50,
    ownSigns: <int>[],
    moolatrikona: null,
    karaka: 'Desire, foreign things',
    deityEnglish: 'Durga',
    deityHindi: 'दुर्गा',
    gemstone: 'Hessonite',
    gemstoneHindi: 'गोमेद',
    metal: 'Lead',
    mantra: 'Om Bhraam Bhreem Bhraum Sah Rahave Namah',
    weekday: 6,
    combustionOrb: 0,
  ),
  GrahaInfo(
    graha: Graha.ketu,
    english: 'Ketu',
    hindi: 'केतु',
    sanskrit: 'Ketu',
    exaltationDegree: 230,
    ownSigns: <int>[],
    moolatrikona: null,
    karaka: 'Detachment, liberation',
    deityEnglish: 'Ganesha',
    deityHindi: 'गणेश',
    gemstone: "Cat's eye",
    gemstoneHindi: 'लहसुनिया',
    metal: 'Mixed metal',
    mantra: 'Om Sraam Sreem Sraum Sah Ketave Namah',
    weekday: 2,
    combustionOrb: 0,
  ),
];

GrahaInfo grahaInfo(Graha graha) =>
    grahaTable.firstWhere((GrahaInfo info) => info.graha == graha);

/// Natural friendship between grahas, after Parashara.
enum Relation { friend, neutral, enemy }

const Map<Graha, Map<Graha, Relation>> naturalRelations =
    <Graha, Map<Graha, Relation>>{
      Graha.sun: <Graha, Relation>{
        Graha.moon: Relation.friend,
        Graha.mars: Relation.friend,
        Graha.jupiter: Relation.friend,
        Graha.mercury: Relation.neutral,
        Graha.venus: Relation.enemy,
        Graha.saturn: Relation.enemy,
      },
      Graha.moon: <Graha, Relation>{
        Graha.sun: Relation.friend,
        Graha.mercury: Relation.friend,
        Graha.mars: Relation.neutral,
        Graha.jupiter: Relation.neutral,
        Graha.venus: Relation.neutral,
        Graha.saturn: Relation.neutral,
      },
      Graha.mars: <Graha, Relation>{
        Graha.sun: Relation.friend,
        Graha.moon: Relation.friend,
        Graha.jupiter: Relation.friend,
        Graha.venus: Relation.neutral,
        Graha.saturn: Relation.neutral,
        Graha.mercury: Relation.enemy,
      },
      Graha.mercury: <Graha, Relation>{
        Graha.sun: Relation.friend,
        Graha.venus: Relation.friend,
        Graha.mars: Relation.neutral,
        Graha.jupiter: Relation.neutral,
        Graha.saturn: Relation.neutral,
        Graha.moon: Relation.enemy,
      },
      Graha.jupiter: <Graha, Relation>{
        Graha.sun: Relation.friend,
        Graha.moon: Relation.friend,
        Graha.mars: Relation.friend,
        Graha.saturn: Relation.neutral,
        Graha.mercury: Relation.enemy,
        Graha.venus: Relation.enemy,
      },
      Graha.venus: <Graha, Relation>{
        Graha.mercury: Relation.friend,
        Graha.saturn: Relation.friend,
        Graha.mars: Relation.neutral,
        Graha.jupiter: Relation.neutral,
        Graha.sun: Relation.enemy,
        Graha.moon: Relation.enemy,
      },
      Graha.saturn: <Graha, Relation>{
        Graha.mercury: Relation.friend,
        Graha.venus: Relation.friend,
        Graha.jupiter: Relation.neutral,
        Graha.sun: Relation.enemy,
        Graha.moon: Relation.enemy,
        Graha.mars: Relation.enemy,
      },
    };

Relation relationBetween(Graha of, Graha towards) =>
    naturalRelations[of]?[towards] ?? Relation.neutral;
