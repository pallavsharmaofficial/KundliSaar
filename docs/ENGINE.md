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

## What is tested

- Every body against JPL fixtures at 240 random instants, 1900–2070.
- The Sun at six March equinox instants: zero degrees, within 0.4″.
- Houses against brute-force geometry.
- Divisional charts: every degree of the zodiac maps into a real sign in all
  sixteen vargas, with the hora, drekkana and trimsamsa boundaries checked by
  hand.
- Vimshottari: the first lord is the janma nakshatra lord, antardashas tile
  their mahadasha exactly, and the running chain contains the moment asked for.
- Panchang: at JPL's new and full moon instants the elongation is zero and
  180° to within an arc-minute.
