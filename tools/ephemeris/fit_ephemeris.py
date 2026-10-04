"""Fit a compact Poisson series ephemeris to JPL DE421 and emit Dart tables.

The app ships no third-party ephemeris code. This script samples geometric
heliocentric positions from the public-domain JPL DE440s kernel (via skyfield,
MIT) and fits, for every body, a VSOP-style series

    f(T) = sum_k (A_k + B_k*T + C_k*T^2) * sin(arg_k) + (D_k + E_k*T + F_k*T^2) * cos(arg_k)

where arg_k is an integer combination of linear mean longitudes. The fitted
coefficients are facts about the solar system, not copied code, and the
generated Dart is MIT like the rest of the project.

    python3 fit_ephemeris.py --out ../../lib/engine/astro/series_data.dart \
                             --fixtures ../../test/fixtures/ephemeris_fixtures.json
"""

import argparse, itertools, json, math, os, sys
import numpy as np
from skyfield.api import load
from skyfield.framelib import ecliptic_frame

J2000 = 2451545.0
CENTURY = 36525.0

PLANETS = [
    ('sun', None),  # handled via earth
    ('mercury', 'mercury barycenter'),
    ('venus', 'venus barycenter'),
    ('earth', 'earth barycenter'),
    ('mars', 'mars barycenter'),
    ('jupiter', 'jupiter barycenter'),
    ('saturn', 'saturn barycenter'),
]

FIT_BODIES = ['mercury', 'venus', 'earth', 'mars', 'jupiter', 'saturn']

# Mercury needs the dense grid; the slow outer planets do not.
WORK_STRIDE = {'mercury': 1, 'venus': 2, 'earth': 2, 'mars': 2, 'jupiter': 4, 'saturn': 4}
TERM_BUDGET = {'mercury': 120, 'venus': 80, 'earth': 90, 'mars': 100, 'jupiter': 70, 'saturn': 70}


def wrap_pi(x):
    return (x + math.pi) % (2 * math.pi) - math.pi


def sample_helio(eph, ts, jd):
    """Geometric heliocentric position per body, in the true ecliptic of date."""
    out = {}
    t = ts.tdb_jd(jd)
    sun = eph['sun']
    for name in FIT_BODIES:
        target = eph[dict(PLANETS)[name]]
        pos = (target - sun).at(t)
        lat, lon, dist = pos.frame_latlon(ecliptic_frame)
        out[name] = (np.unwrap(lon.radians), lat.radians, dist.au)
    moon = (eph['moon'] - eph['earth']).at(t)
    lat, lon, dist = moon.frame_latlon(ecliptic_frame)
    out['moon'] = (np.unwrap(lon.radians), lat.radians, dist.au)
    return out


def linear_fit(T, y):
    A = np.vstack([np.ones_like(T), T]).T
    coef, *_ = np.linalg.lstsq(A, y, rcond=None)
    return coef  # [a0, a1]


def build_basis(T, args, n_poisson):
    """Design matrix: for each argument, sin/cos times 1, T, ... T^(n-1)."""
    cols = [np.ones_like(T), T, T * T]
    for arg in args:
        s, c = np.sin(arg), np.cos(arg)
        for p in range(n_poisson):
            tp = T ** p
            cols.append(s * tp)
            cols.append(c * tp)
    return np.vstack(cols).T


def greedy_fit(T, y, candidates, max_terms, target_rad, n_poisson=3,
               work_stride=1, fit_stride=1, refit_every=5, seed=()):
    """Matching pursuit over candidate arguments, with periodic full refits.

    Sampling matters more than cleverness here: a body must be searched on a
    grid fine enough for its own highest harmonic, or those harmonics alias and
    the fit silently stalls (Mercury's tenth harmonic has a nine-day period).
    """
    wT, wY = T[::work_stride], y[::work_stride]
    wArg = {k: a[::work_stride] for k, a in candidates}
    keys = [k for k, _ in candidates]
    taken = list(seed)
    residual = wY.copy()

    def full_refit(stride):
        rT = T[::stride]
        design = build_basis(rT, [arg[::stride] for arg in
                                  (dict(candidates)[k] for k in taken)], n_poisson)
        coef, *_ = np.linalg.lstsq(design, y[::stride], rcond=None)
        return coef, y[::stride] - design @ coef

    if taken:
        _, residual = full_refit(work_stride)

    for step in range(max_terms - len(taken)):
        if math.sqrt(float(np.mean(residual ** 2))) < target_rad:
            break
        best, best_score = None, -1.0
        chosen = set(taken)
        for i in range(0, len(keys), 500):
            block = [k for k in keys[i:i + 500] if k not in chosen]
            if not block:
                continue
            argm = np.stack([wArg[k] for k in block])
            score = np.hypot(np.sin(argm) @ residual, np.cos(argm) @ residual)
            j = int(np.argmax(score))
            if float(score[j]) > best_score:
                best_score, best = float(score[j]), block[j]
        if best is None:
            break
        taken.append(best)
        if (step + 1) % refit_every == 0:
            _, residual = full_refit(work_stride)
        else:
            columns = build_basis(wT, [wArg[best]], n_poisson)[:, 3:]
            c, *_ = np.linalg.lstsq(columns, residual, rcond=None)
            residual = residual - columns @ c
    _, residual = full_refit(work_stride)
    coef, residual = full_refit(fit_stride)
    return [(k, None) for k in taken], coef, residual


MOON_ARGS = {  # linear parts of the classical lunar arguments, degrees
    'D': (297.8501921, 445267.1114034),
    'M': (357.5291092, 35999.0502909),
    'Mp': (134.9633964, 477198.8675055),
    'F': (93.2720950, 483202.0175233),
}


def planet_candidates(body, lams):
    """Integer combinations of mean longitudes, as (key, argument array)."""
    names = list(lams.keys())
    out, seen = [], set()

    def add(coefs):
        key = tuple(coefs)
        if key in seen or not any(coefs):
            return
        seen.add(key)
        arg = sum(c * lams[n] for c, n in zip(coefs, names) if c)
        out.append((key, arg))

    i = names.index(body)
    for k in range(-14, 15):
        c = [0] * len(names)
        c[i] = k
        add(c)
    for j in range(len(names)):
        if j == i:
            continue
        for k in range(-12, 13):
            for m in range(-6, 7):
                if abs(k) + abs(m) > 14 or (k == 0 and m == 0):
                    continue
                c = [0] * len(names)
                c[i], c[j] = k, m
                add(c)
    for j, k in itertools.combinations([x for x in range(len(names)) if x != i], 2):
        for a in range(-3, 4):
            for b in range(-2, 3):
                for d in range(-2, 3):
                    c = [0] * len(names)
                    c[i], c[j], c[k] = a, b, d
                    add(c)
    return out


def moon_candidates(args):
    out, seen = [], set()
    for d in range(-6, 7):
        for m in range(-2, 3):
            for mp in range(-6, 7):
                for f in range(-4, 5):
                    key = (d, m, mp, f)
                    if key in seen or not any(key):
                        continue
                    seen.add(key)
                    out.append((key, d * args['D'] + m * args['M'] + mp * args['Mp'] + f * args['F']))
    return out


def fmt(x):
    return repr(round(float(x), 12))


def emit_series(name, chosen, coef, n_poisson, nkeys):
    """Dart literal: [arg coefficients..., sin poly..., cos poly...] per term."""
    lines = ['const List<double> %sPoly = <double>[%s, %s, %s];' %
             (name, fmt(coef[0]), fmt(coef[1]), fmt(coef[2])),
             'const List<List<double>> %s = <List<double>>[' % name]
    for i, (key, _) in enumerate(chosen):
        base = 3 + i * 2 * n_poisson
        # build_basis lays each argument out as sin, cos, sin*T, cos*T, ...
        sin_c = [coef[base + 2 * p] for p in range(n_poisson)]
        cos_c = [coef[base + 2 * p + 1] for p in range(n_poisson)]
        lines.append('  <double>[%s, %s, %s],' % (
            ', '.join(str(int(k)) for k in key),
            ', '.join(fmt(v) for v in sin_c),
            ', '.join(fmt(v) for v in cos_c)))
    lines.append('];')
    return '\n'.join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--fixtures', required=True)
    ap.add_argument('--start', type=float, default=2415020.5)   # 1900-01-01
    ap.add_argument('--end', type=float, default=2477100.0)     # ~2070-01-01
    args = ap.parse_args()

    ts = load.timescale()
    eph = load('de440s.bsp')

    jd_p = np.arange(args.start, args.end, 2.0)
    jd_m = np.arange(args.start, args.end, 1.0)
    Tp = (jd_p - J2000) / CENTURY
    Tm = (jd_m - J2000) / CENTURY

    print('sampling planets: %d epochs' % len(jd_p), flush=True)
    helio = sample_helio(eph, ts, jd_p)
    print('sampling moon: %d epochs' % len(jd_m), flush=True)
    moon_s = sample_helio(eph, ts, jd_m)['moon']

    lam_lin = {}
    for body in FIT_BODIES:
        lon = helio[body][0]
        a0, a1 = linear_fit(Tp, lon)
        lam_lin[body] = (a0, a1)
    lams = {b: lam_lin[b][0] + lam_lin[b][1] * Tp for b in FIT_BODIES}

    arcsec = math.pi / 180.0 / 3600.0
    out = ['// GENERATED by tools/ephemeris/fit_ephemeris.py - do not edit by hand.',
           '// Poisson series fitted to JPL DE440s sampled geometry; see docs/ENGINE.md.',
           '']
    report = {}

    for body in FIT_BODIES:
        lon, lat, rad = helio[body]
        cands = planet_candidates(body, lams)
        mean = lam_lin[body][0] + lam_lin[body][1] * Tp
        resid_l = wrap_pi(lon - mean)
        stride = WORK_STRIDE[body]
        chosen, coef, res = greedy_fit(Tp, resid_l, cands, TERM_BUDGET[body],
                                       0.25 * arcsec, work_stride=stride)
        out.append(emit_series('%sL' % body, chosen, coef, 3, 6))
        lrms = float(np.sqrt(np.mean(res ** 2))) / arcsec
        chosen_b, coef_b, res_b = greedy_fit(Tp, lat, cands, 60, 0.25 * arcsec,
                                             work_stride=stride)
        out.append(emit_series('%sB' % body, chosen_b, coef_b, 3, 6))
        brms = float(np.sqrt(np.mean(res_b ** 2))) / arcsec
        chosen_r, coef_r, res_r = greedy_fit(Tp, rad, cands, 60, 2e-8,
                                             work_stride=stride)
        out.append(emit_series('%sR' % body, chosen_r, coef_r, 3, 6))
        rrms = float(np.sqrt(np.mean(res_r ** 2)))
        report[body] = dict(lon_rms_arcsec=lrms, lat_rms_arcsec=brms, rad_rms_au=rrms,
                            terms=[len(chosen), len(chosen_b), len(chosen_r)])
        print(body, report[body], flush=True)

    margs = {k: np.radians(v[0] + v[1] * Tm) for k, v in MOON_ARGS.items()}
    mcands = moon_candidates(margs)
    lon_m, lat_m, rad_m = moon_s
    mean_m = linear_fit(Tm, lon_m)
    resid = wrap_pi(lon_m - (mean_m[0] + mean_m[1] * Tm))
    ch, cf, rs = greedy_fit(Tm, resid, mcands, 130, 1.0 * arcsec, work_stride=2, fit_stride=2)
    out.append(emit_series('moonL', ch, cf, 3, 4))
    mlrms = float(np.sqrt(np.mean(rs ** 2))) / arcsec
    chb, cfb, rsb = greedy_fit(Tm, lat_m, mcands, 90, 1.0 * arcsec, work_stride=2, fit_stride=2)
    out.append(emit_series('moonB', chb, cfb, 3, 4))
    mbrms = float(np.sqrt(np.mean(rsb ** 2))) / arcsec
    chr_, cfr, rsr = greedy_fit(Tm, rad_m, mcands, 60, 1e-7, work_stride=2, fit_stride=2)
    out.append(emit_series('moonR', chr_, cfr, 3, 4))
    report['moon'] = dict(lon_rms_arcsec=mlrms, lat_rms_arcsec=mbrms,
                          rad_rms_au=float(np.sqrt(np.mean(rsr ** 2))),
                          terms=[len(ch), len(chb), len(chr_)])
    print('moon', report['moon'], flush=True)

    out.insert(2, 'const Map<String, List<double>> meanLongitudes = <String, List<double>>{')
    for body in FIT_BODIES:
        a0, a1 = lam_lin[body]
        out.insert(3 + FIT_BODIES.index(body), "  '%s': <double>[%s, %s]," % (body, fmt(a0), fmt(a1)))
    out.insert(3 + len(FIT_BODIES), '};')
    out.insert(4 + len(FIT_BODIES), 'const List<double> moonMeanLongitude = <double>[%s, %s];' %
               (fmt(mean_m[0]), fmt(mean_m[1])))
    out.insert(5 + len(FIT_BODIES), "const List<String> seriesBodies = <String>['%s'];" % "', '".join(FIT_BODIES))
    out.insert(6 + len(FIT_BODIES), '')

    for series, suffix in (('seriesL', 'L'), ('seriesB', 'B'), ('seriesR', 'R')):
        out.append('const Map<String, List<List<double>>> %s = <String, List<List<double>>>{' % series)
        for body in FIT_BODIES:
            out.append("  '%s': %s%s," % (body, body, suffix))
        out.append('};')
    for poly, suffix in (('polyL', 'LPoly'), ('polyB', 'BPoly'), ('polyR', 'RPoly')):
        out.append('const Map<String, List<double>> %s = <String, List<double>>{' % poly)
        for body in FIT_BODIES:
            out.append("  '%s': %s%s," % (body, body, suffix))
        out.append('};')

    with open(args.out, 'w') as fh:
        fh.write('\n'.join(out) + '\n')

    # Fixtures: apparent geocentric positions, J2000 ecliptic and ecliptic of date.
    rng = np.random.default_rng(20261005)
    jd_f = np.sort(rng.uniform(args.start, args.end, 240))
    t = ts.tdb_jd(jd_f)
    earth = eph['earth']
    bodies = {'sun': 'sun', 'moon': 'moon', 'mercury': 'mercury barycenter',
              'venus': 'venus barycenter', 'mars': 'mars barycenter',
              'jupiter': 'jupiter barycenter', 'saturn': 'saturn barycenter'}
    fixtures = {'generated_from': 'de440s.bsp via skyfield', 'jd_tdb': [float(x) for x in jd_f], 'bodies': {}}
    for name, key in bodies.items():
        app = earth.at(t).observe(eph[key]).apparent()
        # skyfield's ecliptic_frame is the TRUE ecliptic and equinox of date,
        # which is the frame astrology works in and the frame these series are
        # fitted to; precession and nutation are inside the numbers already.
        lat, lon, dist = app.frame_latlon(ecliptic_frame)
        fixtures['bodies'][name] = {
            'lon_of_date_deg': [float(x) for x in lon.degrees],
            'lat_of_date_deg': [float(x) for x in lat.degrees],
            'distance_au': [float(x) for x in dist.au],
        }
    fixtures['fit_report'] = report
    with open(args.fixtures, 'w') as fh:
        json.dump(fixtures, fh)
    print('wrote', args.out, 'and', args.fixtures, flush=True)


if __name__ == '__main__':
    main()
