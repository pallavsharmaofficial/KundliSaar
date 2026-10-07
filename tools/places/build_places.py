#!/usr/bin/env python3
"""Rebuilds assets/data/places.json from the GeoNames dump.

Two things were wrong with the old file.

First, coverage. India had 2,989 entries and the selection was arbitrary --
Jhansi, half a million people, was simply absent, as were Ratlam, Sikar,
Chhapra, Barmer and Pali. Anyone born in a district town could not find it.

Second, and worse, the names carry diacritics: Jhānsi, Rājkot, Alīgarh. The
search only lowercased, so 1,199 of those 2,989 cities -- forty percent --
could not be found by anyone typing on an ordinary keyboard. They were in the
file and unreachable.

So every entry now also carries "s", an ASCII-folded search key, and the
repository matches on that. The display name keeps its diacritics.

Usage:
    curl -O https://download.geonames.org/export/dump/IN.zip && unzip IN.zip
    curl -O https://download.geonames.org/export/dump/admin1CodesASCII.txt
    python3 tools/places/build_places.py IN.txt admin1CodesASCII.txt
"""
import csv
import json
import pathlib
import sys
import unicodedata

# Places that are the seat of some administrative division are kept whatever
# their recorded population, because a district or tehsil headquarters is
# exactly the sort of town a person is born in and GeoNames often has no
# population figure for one.
ADMIN_SEATS = {'PPLA', 'PPLA2', 'PPLA3', 'PPLA4', 'PPLC'}
POPULATED = {'PPL', 'PPLA', 'PPLA2', 'PPLA3', 'PPLA4', 'PPLC', 'PPLG',
             'PPLL', 'PPLS', 'PPLX'}

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'data' / 'places.json'


def fold(value: str) -> str:
    """Lowercase and strip every combining mark, so "Jhānsi" and "Jhansi"
    are the same string to search against."""
    decomposed = unicodedata.normalize('NFD', value)
    stripped = ''.join(
        c for c in decomposed if unicodedata.category(c) != 'Mn'
    )
    # A few letters carry their mark inside the codepoint and survive NFD.
    for src, dst in (('ł', 'l'), ('đ', 'd'), ('ı', 'i'), ('ø', 'o'),
                     ('æ', 'ae'), ('œ', 'oe'), ('ß', 'ss'), ('ð', 'd'),
                     ('þ', 'th'), ('’', "'")):
        stripped = stripped.replace(src, dst).replace(src.upper(), dst)
    return stripped.lower().strip()


def admin_names(path: pathlib.Path) -> dict:
    """GeoNames stores admin1 as a bare code, which is why the app was
    showing "Mumbai, 16, IN". Map it to the name people would recognise."""
    out = {}
    with path.open(encoding='utf-8') as f:
        for row in csv.reader(f, delimiter='\t', quoting=csv.QUOTE_NONE):
            if len(row) >= 2:
                out[row[0]] = row[1]  # "IN.16" -> "Maharashtra"
    return out


def india(dump: pathlib.Path, admins: dict) -> list:
    """Every Indian town with a recorded population, plus every admin seat.

    GeoNames lists 558,000 populated places in India but has a population
    figure for only about 7,200 of them; the rest are hamlets with a name and
    nothing else. Shipping all of them would add tens of megabytes to the app
    for entries nobody can distinguish from one another, so the line is drawn
    at having a population or being somebody's headquarters.
    """
    best = {}
    with dump.open(encoding='utf-8') as f:
        for row in csv.reader(f, delimiter='\t', quoting=csv.QUOTE_NONE):
            if len(row) < 19 or row[6] != 'P' or row[7] not in POPULATED:
                continue
            population = int(row[14] or 0)
            if population <= 0 and row[7] not in ADMIN_SEATS:
                continue
            name, admin1, tz = row[1], row[10], row[17]
            if not tz:
                continue
            key = (fold(name), admin1)
            # The same name recurs across a state; keep the largest, which is
            # the one somebody searching that name almost certainly means.
            if key in best and best[key]['p'] >= population:
                continue
            best[key] = {
                'n': name,
                's': fold(name),
                'a': admins.get(f'IN.{admin1}', ''),
                'c': 'IN',
                'y': round(float(row[4]), 4),
                'x': round(float(row[5]), 4),
                'z': tz,
                'p': population,
            }
    return list(best.values())


def rest_of_world(previous: list, admins: dict) -> list:
    """Keep the existing world list, but give it the search key it never had
    and turn its bare admin codes into names."""
    out = []
    for p in previous:
        if p.get('c') == 'IN':
            continue
        admin = p.get('a', '')
        out.append({
            'n': p['n'],
            's': fold(p['n']),
            'a': admins.get(f"{p['c']}.{admin}", admin),
            'c': p['c'],
            'y': p['y'],
            'x': p['x'],
            'z': p['z'],
            'p': p.get('p', 0),
        })
    return out


def main() -> int:
    dump = pathlib.Path(sys.argv[1])
    admins = admin_names(pathlib.Path(sys.argv[2]))
    previous = json.loads(OUT.read_text(encoding='utf-8'))['places']

    places = india(dump, admins) + rest_of_world(previous, admins)
    # Biggest first, so an empty query and equal-prefix matches both lead
    # with the place most people mean.
    places.sort(key=lambda p: -p['p'])

    OUT.write_text(
        json.dumps(
            {
                'source': 'GeoNames (CC BY 4.0), geonames.org',
                'places': places,
            },
            ensure_ascii=False,
            separators=(',', ':'),
        ),
        encoding='utf-8',
    )
    ind = sum(1 for p in places if p['c'] == 'IN')
    print(f'{len(places)} places, {ind} in India')
    print(f'{OUT.stat().st_size / 1024:.0f} KB')
    return 0


if __name__ == '__main__':
    sys.exit(main())
