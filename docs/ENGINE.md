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

Left out, because the definitions cannot be met without guessing:

* Gairi-kamboola and Tambira: both turn on what a graha at the end of a sign
  does on entering the next; Hayanaratna's Tambira example has the slower
  graha applying to the swifter one, which contradicts the rule that the swifter
  applies.
* Kuttha: its definition includes "strength by time", which the engine cannot
  pin to one method.
* Durapha: its clauses include "in the mouth or tail of Rahu" and any malefic
  aspect (which on sign aspects alone would flag nearly every graha).

### Sahams

Formulas follow Hayanaratna ch. 4 (quoting the Samjnatantra for Punya),
cross-checked against Dr. Shanker Adawal's *Encyclopedia of Vedic Astrology:
Tajik Shastra and Annual Horoscopy*, and against Jagannatha Hora's table and
PyJHora's `saham.py`. Day or night is the Sun's altitude against the standard
horizon at the place, so it flips at the sunrise and sunset the panchang uses.
Houses are equal-house points (lagna degree repeated through the signs) so a
house point's sign is the whole-sign house it names.

One sign (30°) is added when the ascendant is not in the arc from B forward to
A (Hayanaratna 4.2, where Balabhadra argues it holds for every saham; JHora
tests the third term instead).

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

Where the sources differ and the app picked a side: Asha (Hayanaratna and
Adawal subtract Venus; JHora and PyJHora subtract Mars), Mrityu (Hayanaratna
and Adawal add Saturn; JHora adds the Lagna), Gaurava (written A − B + C by
Hayanaratna as Jupiter − Moon + Sun, by Adawal as Sun − Moon + Jupiter: the same
sum, but the arc test differs), Jalapatana (Hayanaratna calls this formula
"travel by water"; JHora's name is kept and the reading stays with journeys over
water), Roga (Adawal adds a sign at the end; the others do not).

Left out, with the reason:

* Mitra: the first term is Jupiter in JHora and PyJHora and "the sahama of the
  teacher" in Hayanaratna; the two give different longitudes.
* Vanik, Vivaha, Santapa, Shraddha, Preeti, Bandhu: Hayanaratna gives them
  "at all times" while JHora and PyJHora reverse them at night; Vivaha has a
  third form (Venus − Jupiter) in other books. A wrong longitude is worse than
  none.
* Vyapara: Hayanaratna has Mars − Mercury, JHora Mars − Saturn.
* Vishwasghata: no formula could be established.

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
not based on five-fold strength: that only breaks a tie.

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
in both languages and at a larger text size.
