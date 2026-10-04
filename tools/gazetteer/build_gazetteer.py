"""Builds the offline place list from the GeoNames cities15000 dump.

GeoNames data is CC BY 4.0; the attribution lives in assets/data/ATTRIBUTION.md
and on the about screen. Run:

    python3 tools/gazetteer/build_gazetteer.py
"""
import io, json, os, urllib.request, zipfile

URL = 'https://download.geonames.org/export/dump/cities15000.zip'
OUT = os.path.join('assets', 'data', 'places.json')
WORLD_MIN_POPULATION = 400000
INDIA_MIN_POPULATION = 20000
NEIGHBOURS = {'IN', 'NP', 'BD', 'PK', 'LK', 'BT', 'MM'}


def main():
    with urllib.request.urlopen(URL) as response:
        blob = response.read()
    rows = []
    with zipfile.ZipFile(io.BytesIO(blob)) as zf:
        with zf.open('cities15000.txt') as fh:
            for line in io.TextIOWrapper(fh, encoding='utf-8'):
                f = line.rstrip('\n').split('\t')
                name, country, population, timezone = f[1], f[8], int(f[14] or 0), f[17]
                latitude, longitude = float(f[4]), float(f[5])
                admin = f[10]
                if country in NEIGHBOURS:
                    if population < INDIA_MIN_POPULATION:
                        continue
                elif population < WORLD_MIN_POPULATION:
                    continue
                rows.append({
                    'n': name,
                    'a': admin,
                    'c': country,
                    'y': round(latitude, 4),
                    'x': round(longitude, 4),
                    'z': timezone,
                    'p': population,
                })
    rows.sort(key=lambda r: (-r['p'], r['n']))
    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump({'source': 'GeoNames cities15000 (CC BY 4.0)', 'places': rows}, fh,
                  ensure_ascii=False, separators=(',', ':'))
    indian = sum(1 for r in rows if r['c'] == 'IN')
    print('wrote %s: %d places, %d in India' % (OUT, len(rows), indian))


if __name__ == '__main__':
    main()
