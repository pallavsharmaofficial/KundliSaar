# The engine

Everything under `lib/engine/` is pure Dart: no Flutter imports, no platform
channels, no network. That is what lets the same code serve a phone, an iPhone
and a browser tab, and what lets CI hold it to an arc-second.

## Where the numbers come from

`tools/ephemeris/fit_ephemeris.py` samples geometric heliocentric positions
from NASA JPL's public-domain **DE440s** kernel (through skyfield, MIT) and fits
each body a VSOP-style Poisson series

```latex
f(T) = P(T) + \sum_k \left[ S_k(T)\sin(\mathrm{arg}_k) + C_k(T)\cos(\mathrm{arg}_k) \right]
```

where `arg_k` is an integer combination of linear mean longitudes and both
`S_k` and `C_k` are quadratics in `T`. The quadratic factors are what let a few
dozen terms track a drifting perihelion across two centuries; without them the
fit stalls at tenths of a degree.

Term selection is matching pursuit with periodic full refits. The one thing
that matters more than the algorithm is the sampling grid: a body must be
sampled finely enough for its own highest harmonic, or those harmonics alias
and the fit silently stalls. Mercury's tenth harmonic has a nine-day period, so
Mercury is fitted on a two-day grid while Jupiter and Saturn are happy on eight.

Fit quality, root mean square over 1900–2070:

| Body | Longitude | Latitude | Terms (L, B, R) |
|---|---|---|---|
| Mercury | 0.25″ | 0.24″ | 76, 19, 60 |
| Venus | 0.23″ | 0.23″ | 41, 11, 60 |
| Earth–Moon barycentre | 0.24″ | 0.22″ | 40, 0, 60 |
| Mars | 0.24″ | 0.24″ | 60, 16, 60 |
| Jupiter | 0.23″ | 0.22″ | 23, 15, 50 |
| Saturn | 0.22″ | 0.10″ | 20, 10, 53 |
| Moon | 1.10″ | 1.00″ | 130, 63, 30 |

## The frame

The series are fitted to the **true ecliptic and equinox of date**, which is the
frame astrology works in. Precession and nutation are already inside the
coefficients and must never be applied a second time — an easy and expensive
mistake, worth a whole degree at 1900.

## Assembling a geocentric position

1. Heliocentric position of the body and of the Earth–Moon barycentre.
2. The Earth's own centre: the barycentre less the Moon's geocentric vector
   times 0.012150584. The Earth swings about the barycentre by some 4,700 km a
   month, which is six arc-seconds of apparent solar longitude.
3. Light time, by two iterations.
4. Annual aberration from the Earth's velocity — except for the Moon, which
   travels with the Earth, so its light-time displacement and the aberration
   cancel to first order.
5. Rahu and Ketu are the mean lunar node and its opposite point.

Daily motion, and therefore retrogression, comes from a central difference over
half a day.

## Ayanamsa

Sidereal longitudes are the apparent tropical ones less the ayanamsa. Lahiri
(Chitrapaksha) is anchored at 23°51′11″ at J2000 and carried by the general
precession in longitude; that lands within half an arc-minute of the Calendar
Reform Committee's 23°15′ on 21 March 1956. Raman, Krishnamurti, True Chitra
and Pushya-paksha are offered as alternatives.

## Houses

Whole-sign houses by default. The ascendant is the closed-form rising point of
the ecliptic, and the test suite checks it against a brute-force horizon search
at four latitudes and eight times of day: the rising degree must sit on the
horizon, the degree after it must still be below, and the degree before it must
already be up.

## Panchang

`panchang.dart` cuts the five limbs from the Sun and Moon: tithi and karana
from the elongation, nakshatra from the sidereal Moon, yoga from the sum.
Everything past the five limbs lives in `computePanchangDetails`, a second pass
that the muhurta finder does not pay for:

- `panchang_tables.dart`: the rule tables and every name and one-line meaning
  in both languages. Where traditions differ the North Indian reading that
  Drik Panchang prints is used and the variant is named beside the table.
- `panchang_calendar.dart`: Vikram, Shaka and Kali years, the amanta and
  purnimanta month (with the adhika month found from the Sun's sign at the two
  new moons), ritu, ayana and the solar month, nirayana and sayana.
- `panchang_details.dart`: the day is cut at every tithi, karana, nakshatra,
  sign and Sun-nakshatra boundary, each rule is a test over those stretches,
  and adjacent stretches are merged into windows with exact ends. Panchak and
  Vinchhudo, which last days, are found directly from the Moon's entry into and
  exit from a stretch of the zodiac. Yogas that read the weekday are cut to the
  Vedic day, sunrise to sunrise, because the vara turns at sunrise; the rest run
  their full length.

The panchang reads `apparentOfDate` directly. It is the series the JPL fixtures
and the equinox test pin down, already in the true ecliptic of date, and the
cheaper call: a boundary search probes it dozens of times and has no use for the
speed `positionOf` also works out. (`positionOf` once precessed and nutated it a
second time, which put nakshatra boundaries forty minutes early in 2026 and left
tithi and karana alone, being differences.) The panchang's times were checked
against Drik Panchang for New Delhi and against an independent run of DE440s
through skyfield; see `test/engine/panchang_test.dart`.

## What is tested

- Every body against JPL fixtures at 240 random instants, 1900–2070.
- The Sun at six March equinox instants: zero degrees, within 0.4″.
- Houses against brute-force geometry.
- Divisional charts: every degree of the zodiac maps into a real sign in all
  sixteen vargas, with the hora, drekkana and trimsamsa boundaries checked by
  hand.
- Vimshottari: the first lord is the janma nakshatra lord, antardashas tile
  their mahadasha exactly, and the running chain contains the moment asked for.
  The first mahadasha began before birth, so its antardashas and pratyantardashas
  sit on the grid of the whole span and birth cuts into it, as every
  Vimshottari table does; they are not squeezed into the balance.
- `positionOf` is `apparentOfDate` with nothing added. The fitted series are
  already in the true ecliptic of date, so precession and nutation are not
  applied again; doing so once moved every planet by the precession since J2000
  (0.36 degrees in 2026) and put Makar Sankranti 2025 eight hours early.
- Shadbala: the Moon's paksha bala runs from nothing at the new moon to its
  greatest at the full moon (it once ran backwards inside 72 degrees of the
  Sun), and the Moon counts as a natural benefic only while bright, 72 to 288
  degrees from the Sun.
- Gochar: Saturn into Meena on 29 March 2025, Rahu into Kumbha on 18 May 2025
  and Jupiter into Mithuna and Karka on 14 May 2025 and 2 June 2026, each within
  a day of the dates published panchangs give.
- Panchang: at JPL's new and full moon instants the elongation is zero and
  180° to within an arc-minute.
- Panchang details: Magha ending at 21:40 and the Vidaal, Anandadi and Gand
  Mool windows for New Delhi on 7 October 2026; every Sarvartha Siddhi window of
  October 2026; the 2026 Panchak dates and kinds; Vinchhudo against Drik's
  times; Tripushkar and Dwipushkar dates against the published lists; adhika
  months in 2020, 2023 and 2026; both languages non-empty everywhere.

## Phaladesh: reading the chart for a time of life

`lib/engine/jyotish/phaladesh.dart` is the interpretive layer. It follows the
tradition's order: the dasha promises and the transit delivers, and no period
is read alone. Nothing in it is a table of finished prose. Each reading is put
together from rule results, and every reading carries the list of chart factors
it came from (`basis`), in both languages, so the screen can always say "why".

| Reading | What it is built from |
|---|---|
| `bhavaPhala` | The sign on the house, its lord, where the lord stands (house, sign, dignity, combustion, retrogression), occupants, full aspects, the sign's sarvashtakavarga count |
| `grahaPhala` | The graha's sign, house and dignity, combustion, retrogression, company, aspects, shadbala, its own bindus, the yogas it takes part in |
| `dashaPhala` | Every mahadasha, antardasha and pratyantardasha. Houses the lord rules from this lagna, where it stands and in what dignity, shadbala and bindus, functional nature for this lagna, the lord counted from the lord of the period around it, friend/neutral/enemy, the period before and after |
| `lifeTimeline` | One window per antardasha from birth to the antardasha running at ninety, with the dates, both lords, a headline, what to expect and the area of life |
| `gocharPhala` | Saturn, Jupiter, Rahu and Ketu: house from the Moon and from the lagna, the tradition's favourable houses, ashtakavarga, the dates they enter and leave the sign (`signStayAt` in `transits.dart`), Sade Sati and dhaiya, and whether the transit falls on an area the running periods already concern |

What is the tradition's: lordship, kendra and trikona strengthening a lord, 6/8/12
afflicting it, an own or exalted sign protecting it, a lord in the 12th from its
house weakening the house, neecha bhanga, viparita raja yoga, the sub-lord counted
from the main lord, the friendship table, favourable transit houses, four or more
bindus supporting a transit, Sade Sati. What is ours: the size of each weight
that turns those rules into a tone (supportive, mixed, demanding). The directions
are classical, the numbers are a convention, and no verse is quoted for them.

Functional nature comes from lordship: a kendra lord plus a trikona lord is a
yogakaraka; the lagna lord and any trikona lord are auspicious; 3rd, 6th, 11th
lords are malefic, and so are 8th and 12th lords except for the Sun and Moon; a
natural benefic that owns only kendras loses some goodness and a natural malefic
that owns a kendra loses its sting. Rahu and Ketu own no sign and are read through
the lord of the sign they stand in.

Honesty rules, held by tests: the readings never touch death, illness, pregnancy,
examinations, legal outcomes or investment returns, never carry doom language, and
a hard period is described by what it asks of the person. An affliction is always
followed by the classical relief that applies to it, or by a plain statement that
none stands in this chart. Where the tradition's schools differ, as with the
friendships of the nodes, the text says so.

Left out on purpose: the divisional charts in the reading (no D9 or D10 weighting
yet), yogini and other dashas, fast transits of the Sun, Mars, Mercury and Venus,
transit vedha, and any dated transit overlay on the whole timeline. The timeline
reads dashas only; the transits are read for the moment asked, and the sign-entry
dates are only as good as the series, which are fitted to 1900 to 2070, so ask for
a moment inside that range. The classical rules that schools dispute (the nodes'
friendships, whether the nodes aspect, the 12th lord as a malefic, which
conditions make a viparita raja yoga) are hedged in the text rather than stated
as settled.

### Strength of indication

Every house, graha, period (all three levels), timeline window and transit
carries a band that says how strongly the chart itself points at the reading,
with the factors behind it listed, the ones that agree and the ones that do
not. It is a count of agreeing chart factors, this app's own convention. It is
not a classical measure, and it is not a probability: nothing in phaladesh
gives the chance of any event, no percentage appears anywhere, and a test scans
every output for percentages and for words of chance.

A factor is one separate fact of the chart that points either to the matter
going with support or to it asking effort. A fact that takes no side (a neutral
sign, a bindu count of four, a pair of company that cancels out) is not a
factor, and being merely unafflicted is never counted as support. A factor is
*firm* when it is a plainly measured, weighty fact (exaltation or fall, a
kendra or a difficult house, shadbala against its minimum, five bindus or
three) and *light* when it is a mild nudge (a friend's sign, the company a graha
keeps). Firm and light are this app's own convention, like the weights that
make the tone.

| Reading | Its factors |
|---|---|
| `grahaPhala` | dignity (and neecha bhanga as its own factor, pointing the other way), functional nature for the lagna, the house it stands in, viparita raja yoga, shadbala against its minimum, ashtakavarga (its own bindus, else the sign's), combustion, company, aspects, each yoga it takes part in |
| `bhavaPhala` | where the lord stands from the lagna, the lord in the 12th from its house, the lord's dignity, combustion, viparita, the occupants, the aspects on the house, the sign's sarvashtakavarga, the lord's shadbala, yogas the lord takes part in |
| `dashaPhala` | the lord's own factors as above; for a sub-period also its place counted from the lord of the period around it, their friendship, and how that period fares (as one fact each) |
| `gocharPhala` | the house from the natal Moon against the favourable table, the bindus (own, or the sign's for the nodes), the sign's sarvashtakavarga, the sign the graha passes through (own, exaltation or fall), what the graha is in the natal chart (nature, shadbala) |

The band counts the factors that agree with the reading's tone and sets them
against those that do not:

| Band | When |
|---|---|
| Strong (प्रबल संकेत) | at least four factors agree, at most one disagrees, and at least two of those that agree are firm |
| Moderate (मध्यम संकेत) | at least three agree and they outnumber those that disagree by two or more |
| Weak (हल्का संकेत) | anything less, which includes every reading resting on one or two factors |
| Mixed (मिला-जुला संकेत) | the reading itself says support and effort go together, so the split is shown as it stands ("3 factors point to support, 2 to effort") |

It is written as the count behind it: "Strong indication - 4 of 5 factors agree"
(प्रबल संकेत - 5 में से 4 कारक सहमत). A reading that rests on a single factor is
never strong and says so in plain words, and says if that factor is a light one.
A reading with no factor on its side says that nothing but the app's own
weighing stands behind it. The tone is the app's weighted summary and the band
is a count, so they can disagree, and when they do the band says it
(a "supportive" tone with more factors against than for is a weak band, with a
caution beside it).

The factors are separate facts of the chart, not statistically independent
measurements: dignity feeds shadbala, and the sarvashtakavarga is the sum of the
other ashtakavargas. That is one more reason a high count is a stronger pointer
and never a promise. The thresholds are a convention, no verse is quoted for
them, and the sweep of twelve lagnas in `test/engine/phaladesh_test.dart` checks
that the scale tells readings apart (every band turns up).

### What tends to come up

Every house, every period (and so every timeline window) and every transit also
carries `tends`: the areas of life the tradition associates with it and what it
says tends to come up there, phrased as tendencies and as what the time asks of
the person ("Questions of home and peace of mind tend to come up..."). It is
built from the house or houses in focus, the occupants of a house or the lord of
a period, the tone, and for a transit the way the graha tends to colour what it
touches. It never carries a date or an event, and the tests check that it holds
no digit, no month, no future tense and no refused subject. For the childhood
years it says the home and the family carry it.

### Remedies

An upaya is attached to every finding that calls for one: a house or graha the
rules found strained (the same test that gives it a relief note) or whose tone is
demanding, a difficult period (its tone asks for effort, or its lord stands in
the 6th, 8th or 12th from the lord of the period around it; a lord that is
merely strained in its own right has its remedies in the graha reading, not in
every period it rules), a testing transit (the house from the Moon is not a
favourable one, or the tone asks for effort), and every dosha the chart does not
itself cancel. A finding that does not call for one carries none. Each remedy says which graha it is for and which
of the reading's own pressing factors it answers, word for word, so it is never
a generic list: a house is remedied through its lord or through the malefic
occupants and aspectors that press on it (at most three), a graha through itself,
a period through its own lord first and then the lord of the period around it
when that one is under strain (at most two), a transit through the transiting
graha, and a yoga through the grahas that make it (at most two; the node that
joins the Sun or Moon in a grahan dosha, the Sun and the touching node in pitra
dosha, Rahu and Ketu in Kaal Sarpa, and so on).

What a remedy holds (`GrahaRemedyKit` in `remedies.dart`) is the graha's mantra
with its traditional japa count, the fasting day, the deity, the daan and one
plain act:

| Graha | Count | Day | Deity commonly named |
|---|---|---|---|
| Sun | 7,000 | Sunday | Surya Dev |
| Moon | 11,000 | Monday | Shiva, with Parvati |
| Mars | 10,000 | Tuesday | Hanuman, or Kartikeya |
| Mercury | 9,000 | Wednesday | Vishnu |
| Jupiter | 19,000 | Thursday | Vishnu, and Brihaspati |
| Venus | 16,000 | Friday | Lakshmi, and Durga |
| Saturn | 23,000 | Saturday | Hanuman, and Shani Dev |
| Rahu | 18,000 | Saturday | Durga |
| Ketu | 17,000 | Tuesday | Ganesha |

The counts are the ones the remedy tables commonly list; lineages differ a
little (Ketu is 17,000 in the usual table and was entered as 7,000 earlier, which
was a slip). They are common practice and no verse is quoted for any of them. The
text says so beside every set of remedies, and says the full count is the
traditional target and not a requirement, that a fast is light and is skipped
by anyone for whom it does not suit, and that the daan is whatever one already
has at home or can spare, given by one's own hand.

Held by tests: a remedy is a mantra, a fast, giving, a service or a discipline.
Nothing in it has to be bought, nothing is a paid ritual, and no gemstone, ring,
yantra, amulet or priest is ever named. It is offered as what the tradition
prescribes to strengthen a graha and as nothing more: no remedy says or implies
that anything will change, and the refusal scan (death, illness, pregnancy,
examinations, courts, investments) and the doom scan run over every remedy text
too.

The older `remediesFor` (the three grahas the whole chart leans on, shown on the
Remedies screen) is unchanged, and it still lists a gemstone and a yantra for each
graha. Those two fields do not meet the rule above and are not used anywhere in
phaladesh.

Left out on purpose: remedies for the Nabhasa yogas that the library marks as
adverse (they describe the pattern of the whole chart, so no one graha is the one
to address, and phaladesh does not show them in a graha reading at all); a
remedy for a supportive reading; any count of how often a remedy should be done
beyond the traditional total and the one-mala start; and any timing of a remedy
to a date.

## Varshphal, read the Tajika way

The annual chart is the kundli of the moment the Sun returns to its natal
sidereal longitude (`solarReturnMoment`, a bisection on the Sun alone). On
top of that chart `computeVarshphal` builds what a Tajika reader works with.
The code is split by job: `tajika_common.dart` (bilingual text type, tables,
the honesty scanner), `tajika_bala.dart` (five-fold strength),
`tajika_aspects.dart` (aspects, yogas, the year grid), `saham.dart`,
`varshphal_dasha.dart` (Mudda and Patyayini), `varshphal_months.dart` (the
dated windows) and `varshphal.dart` (Muntha, the five office-bearers, the
lord of the year, and the assembly).

Every output object carries its working: a `factors` list of `Bi` lines (a
`Bi` is an English and a Hindi string that are always both present) saying
which chart facts it came from, which is what the screen's "Why this"
opens.

### Pancha-vargiya bala (five-fold strength)

Weights 30 (griha), 20 (uchcha), 15 (hadda), 10 (drekkana), 5 (navamsha),
summed (at most 80) and quartered into vishwa out of 20: Tajika Neelakanthi,
Samjnatantra 1.39, and Hayanaratna 2.5. A graha that is the lord of the
division it stands in takes the whole weight; a friend of that lord three
quarters, a neutral half, an enemy a quarter (Neelakanthi 1.40; Hayanaratna
2.5). Uchcha is the arc from the graha's deepest fall times 20/180.

* Friendship is the Tajika positional one, from the annual chart: the lord's
  sign is a friend if it is the 3rd, 5th, 9th or 11th from the graha's own,
  neutral if the 2nd, 6th, 8th or 12th, an enemy if the 1st, 4th, 7th or 10th
  (Hayanaratna 2.4, the three-fold scheme from the Romakatajika). PyJHora uses
  the Parashari natural table instead.
* Hadda is the Tajika term table as printed in Hayanaratna 2.5 and in
  Mahidhara's commentary on Neelakanthi 1.33-38. It is the Egyptian scheme
  with Venus and Jupiter transposed in Mithuna and Mars and Saturn in Dhanu.
* Drekkana is the Tajika (Chaldean) decan: Mars, Sun, Venus, Mercury, Moon,
  Saturn, Jupiter in turn from 0° Mesha (Hayanaratna 2.5 for Mesha; the "every
  sixth planet" rule in Mahidhara's commentary on 1.42).
* Bands (Hayanaratna 2.5): under 5 powerless, 5 to 10 weak, 10 to 15 middling,
  above 15 excellent.

### Lord of the year (varshesha)

The five office-bearers (panchadhikari), in the order Hayanaratna 5.8 lists
them: the lord of the Muntha sign; the lord of the year Lagna; the tri-rashi
pati of the year Lagna (day ruler by day, night ruler by night: Sun/Jupiter,
Venus/Moon, Saturn/Mercury, Venus/Mars, Hayanaratna 5.7); the lord of the
Sun's sign by day or of the Moon's sign by night; the lord of the birth Lagna.
Of these, the one that aspects the year Lagna (a conjunction counts) and has
the highest vishwa is varshesha. A strong graha that does not aspect the Lagna
does not qualify, and a weak one that does is still eligible (Yadava, quoted
in Hayanaratna 5.8). Equal strength goes to the day-night lord, then the
tri-rashi lord. If none of the five aspects the Lagna the Muntha lord is taken
(Yadava; Tuka Jyotirvid and Ganesa Daivajna differ, as Hayanaratna records).
The task brief named the janma-rashi lord among the five; the Tajika books name
the birth Lagna lord, and that is what is used. Charak's further rule that a
mild Moon is disqualified is not applied.

### Tajika aspects

The orb of light (deeptamsha) is Sun 15, Moon 12, Mars 8, Mercury 7, Venus 7,
Jupiter 9, Saturn 9; a pair shares half the sum. Two grahas are in aspect only
if their signs are in conjunction or the 3rd, 4th, 5th, 7th, 9th, 10th or 11th
from each other (never the 2nd, 6th, 8th, 12th), and the gap is then the
difference of their degrees WITHIN their signs. The swifter graha (the fixed
Tajika ranking Moon, Mercury, Venus, Sun, Mars, Jupiter, Saturn) behind the
slower is Ittasala (Muthashila): applying. Past it is Ishrafa (Mushariph):
separating. A retrograde swifter graha does not apply (Hayanaratna 3.3).

The date an Ittasala becomes exact, or a pair leaves its orb, or a sign change
ends the aspect first, is found from the grahas' real motion over the year
(`YearGrid`: cubic interpolation through daily samples, six-hourly for the
Moon), not from a rule of thumb. It holds only while neither graha turns or
changes sign, and the screen says so.

Yogas implemented, each with its condition and a plain statement of what the
tradition reads it to mean (never a forecast): Ikkabala, Induvara, Ittasala,
Ishrafa, Nakta, Yamaya, Manau, Kamboola, Khallasara, Radda, Duhphali-kuttha,
Dutthottha-davira. The matter yogas read the lagna lord against the lord of
each house (Hayanaratna ch. 3). Nakta and Yamaya measure the third graha's reach
by ITS OWN deeptamsha, as Hayanaratna 3.5-3.6 words it.

Gairi-kamboola, Tambira, Kuttha and Durapha used to be left out because their
definitions are not agreed. They are now worked out on the year chart under each
definition that could be read, as "two views" (see "Where the texts disagree"
below). Of Durapha's list only "in the mouth or tail of Rahu" is still not
computed: the book that lists it does not say what mouth and tail are.

### Sahams

Formulas follow Hayanaratna ch. 4 (quoting the Samjnatantra for Punya), read in
Martin Gansten's English translation, and are checked against PyJHora's saham
code (version 4.9.3) and the Jagannatha Hora values kept in PyJHora's test file.
Dr. Shanker Adawal's book could not be reached, and nothing is credited to it
(earlier versions of this note did). Day or night is the Sun's altitude against
the standard horizon at the place, so it flips at the sunrise and sunset the
panchang uses.
Houses are equal-house points (lagna degree repeated through the signs) so a
house point's sign is the whole-sign house it names.

One sign (30°) is added when the ascendant is not in the arc from B forward to
A. This is PyJHora's current rule for most sahams, and what Hayanaratna 4.2
does for Fortune, where the added term is the ascendant itself. An earlier
version of this note said JHora tests the third term C instead; that is not so:
Hayanaratna 4.3 tests C (for Mitra at Venus, for Mrityu at Saturn, for Shastra at
Mercury), JHora's recorded values for Shastra, Karyasiddhi and Santapa are
reproduced only by testing the ascendant, and some authors Balabhadra reports
(Keshava Daivajna, Haribhatta, Ganesha Daivajna) add no sign at all. The three
rules are worked out on every saham of the year chart by `extraSignMatbhed`.

| Saham | Day | Night |
|---|---|---|
| Punya | Moon − Sun + Lagna | Sun − Moon + Lagna |
| Vidya | Sun − Moon + Lagna | Moon − Sun + Lagna |
| Yasha | Jupiter − Punya + Lagna | Punya − Jupiter + Lagna |
| Mahatmya | Punya − Mars + Lagna | Mars − Punya + Lagna |
| Asha | Saturn − Venus + Lagna | Venus − Saturn + Lagna |
| Samartha | Mars − lagna lord + Lagna (Jupiter for Mars if Mars is the lagna lord) | lagna lord − Mars + Lagna |
| Bhratri | Jupiter − Saturn + Lagna | same |
| Gaurava | Jupiter − Moon + Sun | Jupiter − Sun + Moon |
| Pitri, Rajya | Saturn − Sun + Lagna | Sun − Saturn + Lagna |
| Matri | Moon − Venus + Lagna | Venus − Moon + Lagna |
| Putra | Jupiter − Moon + Lagna | same |
| Jeeva | Saturn − Jupiter + Lagna | Jupiter − Saturn + Lagna |
| Karma | Mars − Mercury + Lagna | Mercury − Mars + Lagna |
| Roga | Lagna − Moon + Lagna | same |
| Kali | Jupiter − Mars + Lagna | Mars − Jupiter + Lagna |
| Paradesha | 9th house − 9th lord + Lagna | same |
| Artha | 2nd house − 2nd lord + Lagna | same |
| Karyasiddhi | Saturn − Sun + lord of Sun's sign | Saturn − Moon + lord of Moon's sign |
| Jadya | Mars − Saturn + Mercury | Saturn − Mars + Mercury |
| Labha | 11th house − 11th lord + Lagna | same |
| Bandhana | Punya − Saturn + Lagna | Saturn − Punya + Lagna |
| Mrityu | 8th house − Moon + Saturn | same |
| Shatru | Mars − Saturn + Lagna | Saturn − Mars + Lagna |
| Jalapatana | Cancer 15° − Saturn + Lagna | Saturn − Cancer 15° + Lagna |

Where the sources differ the app no longer picks a side silently or leaves the
saham out; each is worked out under every position and shown as "two views", the
Hayanaratna form the default (see below). That covers Asha (Venus or Mars
subtracted), Mrityu (Saturn or the Lagna added), Putra (swapped at night or not),
and the sahams that used to be left out:

* Mitra: Hayanaratna 4.3 subtracts Fortune from "the lot of the teacher", which
  it names as the Teacher and Learning saham (Vidya), so the first term is a
  point, not the planet Jupiter; PyJHora takes Jupiter, and its recorded JHora
  value fits Jupiter.
* Vanik, Vivaha, Santapa, Shraddha, Bandhu (and Putra): Hayanaratna gives them
  "at all times"; PyJHora swaps the terms at night. Vivaha has a third form,
  Venus minus Jupiter, found on one website that names no book.
* Preeti: Vidya minus Fortune (Hayanaratna, "at all times" read as no night swap,
  which is our reading) or Shastra minus Fortune, swapped at night (PyJHora).
* Vyapara: Mars minus Mercury (Hayanaratna) or Mars minus Saturn (PyJHora and
  JHora).
* Gaurava (Jupiter − Moon + Sun in Hayanaratna, Sun − Moon + Jupiter in PyJHora)
  is the same sum; only the extra-sign test differs. Jalapatana: Hayanaratna
  calls this formula "travel by water"; JHora's name is kept and the reading
  stays with journeys over water. Roga is the same in Hayanaratna and PyJHora;
  the earlier note that Adawal adds a sign was not verified and is gone.

Still not computed: Vishwasghata. No formula for it is in Hayanaratna's list of 75
names, PyJHora's 36 sahams, or a developer's transcription of Charak's 41, and a
search found none; Hayanaratna's "ghata" (Jupiter minus Fortune) is a different
point and tying the two would be a guess.

Roga, Mrityu and Jeeva are computed and shown with their formula, and are
never interpreted: no reading, no tone, no mention in any dated window. (Jeeva
is "life" in the books and could not be given an honest reading that stays
clear of longevity.) For every other saham the reading is built from its lord:
the lord's dignity, house (6, 8 and 12 weaken, Hayanaratna 4.6), five-fold
strength, retrogression and combustion, the point's own house, and the benefic
and malefic grahas in aspect with its sign. The tally that turns those clauses
into "supported", "mixed" or "strained" is the app's, not the books'; the
clauses are shown beside it.

### Mudda and Patyayini dasha

Mudda: the nine Vimshottari lords share the year in proportion to their years,
120 mapped to the year's actual length. The first lord is the birth nakshatra
lord advanced along the Vimshottari order by the year number, and the part of
its dasha already gone at the pravesh is the fraction of the birth nakshatra
the natal Moon had crossed, as in the natal balance: at age 0 the Mudda dasha is
the natal Vimshottari compressed. The first lord comes round again for the
elapsed part, so the year is exactly one cycle. Antardashas divide each period
in Vimshottari proportions. PyJHora starts from the Moon's nakshatra in the
annual chart instead.

Patyayini (Hayanaratna 7.1): the seven grahas and the lagna are ordered by the
degrees they stand at within their signs, the signs left out; each takes the
degrees between it and the one before; the year is divided in that proportion.
(The books count 360 days; the app divides the real length of the year.) It is
not based on five-fold strength: that only breaks a tie. No source read sizes
the periods by five-fold strength (an earlier brief said so; it appears to be a
mix-up with the tie-break). The second position that Hayanaratna 7.2 records,
that the signs are counted too (order by full longitude from Mesha), is worked
out beside it. Yadava's version by distance from the lagna is not: the working
Hayanaratna prints for it does not add up (the distances should sum to 360° and
the printed total is 404°) and Balabhadra says it is unclear to him.

### The dated windows

The windows are the Mudda periods, so they tile the year exactly. Each lists
the placement of the period's lord, the houses it rules, its Tajika aspects,
the dated moments from the real motion that fall inside it, and the sahams it
is lord of. Using the lord of a saham to place it in a window is the app's way
of ordering the material, not a classical rule; the Sun's passage through each
saham's sign (Yadava's solar-ingress timing, Hayanaratna 4.7) is shown beside
each saham as a time marker.

### What the varshphal tests hold

`test/engine/varshphal_test.dart`: the windows tile the year with no gap or
overlap; the Mudda periods and antardashas sum to the year and follow the
Vimshottari order; every saham longitude is in [0, 360); a hand-worked table of
saham longitudes (the +30° rule both ways); the day and night forms switch at
sunrise and sunset; a hand-worked five-fold strength; the hadda, decan and
triplicity tables; the lord of the year is deterministic and is the strongest
aspecting office-bearer (else the Muntha lord); Ittasala and Ishrafa on built
charts; each yoga on a chart built to show it; every reading names a chart
factor and both languages are present; and nothing the engine writes mentions
death, illness, pregnancy, examinations, courts or investments.
`test/varshphal_screen_test.dart` scrolls the whole page and opens every card,
in both languages and at a larger text size, and finds the two-view cards in the
dasha, Tajika and saham sections.

The two-view findings are held by tests in each area (`varshphal_test.dart`,
`classical_test.dart`, `panchang_test.dart`, `jyotish_test.dart` for the shared
type, and the screen tests): every finding carries its positions with non-empty
text in both languages, exactly one is marked as the default, the computed results
differ where the formulas differ (and are the same where they agree, as for the
night-only disputes on a day chart), the defaults match what the rest of the app
already computes, the Drik labels and changeover times are reproduced, and none
of it mentions what the app never speaks of.

## Where the texts disagree: two views

Where classical texts or traditions disagree, the app does not choose silently
and does not drop the item. `lib/engine/jyotish/mat.dart` defines the shared
type: a `Mat` (मत) is one position, with the rule, who holds it, the reasoning
they give, the computed result under it, and whether it is the position the app
computes by default; a `Matbhed` (मतभेद) carries two or three of them with the
reason for the default. `lib/widgets/matbhed_card.dart` shows it as "दो मत" /
"Two views" (three: "तीन मत"), the results side by side, each position's holder
and argument, and the default marked. Every string is in both languages. Nothing
about death, illness, pregnancy, examinations, courts or investment returns is
said, and Roga, Mrityu and Jeeva stay computed but unread.

Where it appears, and what the default is:

| Where | Disagreement | Default |
|---|---|---|
| Sahams | Mitra, Vanik, Vivaha, Santapa, Shraddha, Preeti, Bandhu, Vyapara; Asha, Mrityu, Putra; the rule for the extra sign (three positions) | Hayanaratna; the Lagna test |
| Tajika | Orb of a pair (mean, swifter's own, 12°); when Ishrafa begins (any distance, or a full degree); Gairi-kamboola, Tambira, Kuttha, Durapha | the mean; any distance; Hayanaratna's definitions |
| Patyayini | Degrees within the sign, or the signs counted too | degrees within the sign |
| Yogas | Ardha Chandra, Punarphoo, Adhi, Lakshmi, Kahala, Parvata, Dhana, Daridra, Mala, Sarpa, Vajra, Yava | the reading `findYogas` uses |
| Panchang | Name of the Vikram year; Ravi Yoga; Tripushkar; the kind of Panchak; Chandra bala; the Janma tara | Drik Panchang |
| Ghat chakra | Common table or Sanjay Rath's lineage (ghat Moon, ghat lagna); how the month column is matched to a day | the common table; the lunar month |
| Upagrahas | Where Mandi is taken in Saturn's part (end, middle, start); the lordless eighth part | end; lordless (BPHS 3.67) |
| Sudarshan | Whether Rahu and Ketu aspect (none, the 7th, the 5th, 7th and 9th) | none |

`findYogas` is unchanged: a yoga that only the other reading finds is shown in
`findYogaMatbhed`, not added to the findings the rest of the app reads.

What the research found that changes earlier notes:

* The Vikram year's name. Drik prints Vikram 2083 as Siddharthi and also shows
  Raudra from 21 April 2026 on its Brihaspati row; the Hindi dailies call 2083
  Raudra; the southern count (the Shaka year) gives Parabhava. They are 13 and 14
  places apart in the sixty-cycle, not 12. "12" is the gap of the Gujarati count
  (Vikram + 9) and, on our model, was also the Jupiter count's gap until about
  1942; each name the Jupiter count skips adds one (the next skip is Durmati in
  April 2028). Drik does not state its rule; the model in `panchang_calendar.dart`
  (mean Jovian year of 361.026721 days, anchored on the changeover Drik prints for
  21 April 2026, the Vikram year named by the samvatsara running at Mesha
  Sankranti) reproduces every Drik label from Vikram 2079 to 2086 and its
  changeover times to within an hour.
* The ghat lagna: the common table has no lagna column. Its two sign columns are
  the ghat Moon for a man and for a woman; the lagna appears only in Sanjay
  Rath's lineage, whose ghat Moon also differs from the common one in nine of the
  twelve signs. No table keyed on the lunar birth month was found anywhere; what
  is disputed is how the month column is matched to a day (lunar month, or the
  Sun's sign, as one calculator approximates it).
* Adhi: BPHS 37.5 ranks king, minister or commander by strength, not by how many
  benefics stand there; the count-based grading is from Phaladeepika, Raman and a
  commentator on the Brihat Jataka. Ardha Chandra: no BPHS verse defines it
  (35.5 names it, 35.40 gives its effect); Varahamihira does. Lakshmi: the verse
  reads kendra only; Raman's "kendra or trikona" and Phaladeepika's Venus form are
  the other two. Daridra: the app's strict form is from BPHS chapter 13 as
  Santhanam glosses it, not chapter 42.
* Ishrafa: Hayanaratna 3.4 (quoting Tajikabhushana) and the Hindi commentary on
  the Tajika Neelakanthi wait for a full degree; PyJHora's code, and the app so
  far, do not.
* The Janma tara: Drik and Vedpanchang leave it out of their lists of good taras
  without calling it bad; Wilhelm grades it by round of nine.
* Bhadra's heaven and netherworld split: no second table of signs was found, so
  it is not a two-view item; what the sources differ on is how harmful a Bhadra
  that is not on earth is.

How it was checked. Hayanaratna was read in Gansten's English on wisdomlib; the
Sanskrit pages could not be opened. The BPHS verses were read in the Sanskrit on
enjoylearningsanskrit.com and in Santhanam's English; PyJHora's saham, Tajaka,
yoga, upagraha and panchang code was read as source; the Tajika Neelakanthi was
read in the Hindi commentary printed with the Venkateshwar Press edition on
Sanskrit Wikisource; Drik Panchang's pages were read and, where it prints only
dates (Ravi Yoga, Tripushkar), its October 2026 and 2026 rows were recomputed
against the rules. What is credited to K. S. Charak is what a developer's
transcription of the book (the teistro-sdk project) says, and every such line
says so; the book was not seen. Adawal, Sarvartha Chintamani, the Saravali, the
Sanskrit of the Muhurta Chintamani and of Narada, Rath's own article and the
Jagannatha Hora software itself were not reached. No verse is credited that was
not seen. Where a rule needed a threshold the text does not give (strength by
time for Kuttha, "powerful", "unqualified", "touched by a maraka lord"), the
choice is called "our reading" on the card.
