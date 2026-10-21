"""Reference shaping with HarfBuzz for every Devanagari run the book draws.

usage: make_shaping_reference.py runs.json out.json assets/fonts
runs.json maps a font's PostScript name (Mukta-Regular, Mukta-SemiBold,
Mukta-Bold, TiroDevaHindi-Regular, YatraOne-Regular) to the Devanagari runs to
shape. Needs `pip install uharfbuzz`. The output is
test/kundli_pdf/fixtures/shaping_reference.json, which shaping_test.dart reads.
When the book gains words, shaping_test.dart writes the missing ones to
build/missing_shaping_runs.json; merge those into the runs this fixture already
holds (its keys) and run this script again.
"""
import json, sys, os
import uharfbuzz as hb

runs_path, out_path, fonts_dir = sys.argv[1:4]
files = {
    'Mukta-Regular': 'Mukta-Regular.ttf',
    'Mukta-SemiBold': 'Mukta-SemiBold.ttf',
    'Mukta-Bold': 'Mukta-Bold.ttf',
    'TiroDevaHindi-Regular': 'TiroDevanagariHindi-Regular.ttf',
    'YatraOne-Regular': 'YatraOne-Regular.ttf',
}
runs = json.load(open(runs_path, encoding='utf-8'))
result = {}
for ps, words in runs.items():
    path = os.path.join(fonts_dir, files[ps])
    font = hb.Font(hb.Face(hb.Blob.from_file_path(path)))
    table = {}
    for w in words:
        buf = hb.Buffer()
        buf.add_str(w)
        buf.script = 'Deva'
        buf.language = 'hi'
        buf.direction = 'ltr'
        buf.flags = hb.BufferFlags.DO_NOT_INSERT_DOTTED_CIRCLE
        hb.shape(font, buf, {})
        pen = 0
        glyphs = []
        for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
            glyphs.append([info.codepoint, pen + pos.x_offset, pos.y_offset])
            pen += pos.x_advance
        table[w] = {'adv': pen, 'glyphs': glyphs}
    result[files[ps]] = table
json.dump(result, open(out_path, 'w'), ensure_ascii=False)
print({k: len(v) for k, v in result.items()})
