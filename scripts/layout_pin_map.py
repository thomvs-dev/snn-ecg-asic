"""Annotated pin map of the routed core: die and core outlines plus every
signal pin, placed from the final DEF on top of the readable KLayout render.

Usage: VARIANT=base|cg python3 scripts/layout_pin_map.py
Needs reports/layout_full_readable[_cg].png (scripts/layout_images_readable.py).
Output: reports/layout_pins[_cg].png. Read-only: the DEF and GDS are not modified.
"""
from pathlib import Path
import os, re
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
V = os.environ.get('VARIANT', 'base')
SUF = '' if V == 'base' else '_' + V
deff = (root / f'physical/results/sky130hd/ecg_snn_core/{V}/6_final.def').read_text()
units = int(re.search(r'UNITS DISTANCE MICRONS (\d+)', deff).group(1))
x0, y0, x1, y1 = map(int, re.search(r'DIEAREA \( (-?\d+) (-?\d+) \) \( (-?\d+) (-?\d+) \)', deff).groups())
rows = re.findall(r'^ROW \S+ \S+ (\d+) (\d+) \w+ DO (\d+) BY 1 STEP (\d+) \d+', deff, re.M)
cx0 = min(int(r[0]) for r in rows); cy0 = min(int(r[1]) for r in rows)
cx1 = max(int(r[0]) + int(r[2]) * int(r[3]) for r in rows); cy1 = max(int(r[1]) for r in rows) + 2720

pins = []
for blk in deff[deff.index('\nPINS'):deff.index('END PINS')].split('\n    - ')[1:]:
    if '+ SPECIAL' in blk:
        continue  # VDD/VSS straps (PDN), not signal pins
    name = blk.split()[0]
    d = re.search(r'DIRECTION (\w+)', blk).group(1)
    layer = re.search(r'LAYER (\w+)', blk).group(1)
    px, py = map(int, re.search(r'(?:PLACED|FIXED) \( (-?\d+) (-?\d+) \)', blk).groups())
    pins.append((name, d, layer, px, py))

base = Image.open(root / f'reports/layout_full_readable{SUF}.png').convert('RGB')
S = base.size[0]                       # square render of exactly the die box
band = base.size[1] - S                # legend band under the render
img = base.crop((0, 0, S, S))
dim = Image.new('RGB', img.size, (15, 20, 32))
img = Image.blend(img, dim, 0.45)       # dim routing so pins/outlines stand out
M = 330
W = S + 2 * M
canvas = Image.new('RGB', (W, W + 90), (15, 20, 32))
canvas.paste(img, (M, M))
dr = ImageDraw.Draw(canvas)
try:
    f = ImageFont.truetype('DejaVuSans.ttf', 17)
    fb = ImageFont.truetype('DejaVuSans-Bold.ttf', 24)
except OSError:
    f = fb = ImageFont.load_default()


def tx(x): return M + (x - x0) / (x1 - x0) * S
def ty(y): return M + (y1 - y) / (y1 - y0) * S


dr.rectangle([tx(x0), ty(y1), tx(x1), ty(y0)], outline=(235, 235, 235), width=3)
for i in range(int(tx(cx0)), int(tx(cx1)), 14):  # dashed core outline
    dr.line([i, ty(cy1), i + 7, ty(cy1)], fill=(150, 200, 255), width=2)
    dr.line([i, ty(cy0), i + 7, ty(cy0)], fill=(150, 200, 255), width=2)
for j in range(int(ty(cy1)), int(ty(cy0)), 14):
    dr.line([tx(cx0), j, tx(cx0), j + 7], fill=(150, 200, 255), width=2)
    dr.line([tx(cx1), j, tx(cx1), j + 7], fill=(150, 200, 255), width=2)

col = {'INPUT': (90, 220, 120), 'OUTPUT': (255, 170, 60), 'INOUT': (220, 120, 255)}
# Group pins by nearest die edge, then spread labels along that edge with a
# minimum pitch and draw a leader line from each label to the true pin position.
edges = {'N': [], 'S': [], 'W': [], 'E': []}
for name, d, layer, px, py in pins:
    dist = {'S': py - y0, 'N': y1 - py, 'W': px - x0, 'E': x1 - px}
    edges[min(dist, key=dist.get)].append((name, d, layer, tx(px), ty(py)))
PITCH, OFF = 24, 70          # label spacing (px), label distance from die edge (px)


def spread(vals, lo, hi):
    """Positions as close as possible to vals, at least PITCH apart, within [lo, hi]."""
    out = []
    for v in vals:
        out.append(max(v, out[-1] + PITCH) if out else max(v, lo))
    over = out[-1] - hi if out else 0
    if over > 0:                       # shift the whole group back inside the range
        out = [o - over for o in out]
        for i in range(len(out) - 2, -1, -1):
            out[i] = min(out[i], out[i + 1] - PITCH)
    return out


for e, lst in edges.items():
    if not lst:
        continue
    horiz = e in 'NS'
    lst.sort(key=lambda p: p[3] if horiz else p[4])
    pos = spread([p[3] if horiz else p[4] for p in lst], M, M + S)
    for (name, d, layer, X, Y), q in zip(lst, pos):
        c = col.get(d, (255, 255, 255))
        lab = f'{name} ({layer})'
        if horiz:
            s = 1 if e == 'S' else -1
            dr.polygon([(X - 7, Y + s * 2), (X + 7, Y + s * 2), (X, Y - s * 14)], fill=c)
            ey = Y + s * OFF
            dr.line([(X, Y + s * 4), (X, Y + s * 25), (q, ey - s * 12), (q, ey)], fill=c, width=2)
            t = Image.new('RGBA', (int(dr.textlength(lab, font=f)) + 4, 22), (0, 0, 0, 0))
            ImageDraw.Draw(t).text((2, 0), lab, font=f, fill=c)
            t = t.rotate(90, expand=True)
            canvas.paste(t, (int(q - t.size[0] / 2), int(ey + 4) if e == 'S' else int(ey - 4 - t.size[1])), t)
        else:
            s = 1 if e == 'W' else -1
            dr.polygon([(X - s * 2, Y - 7), (X - s * 2, Y + 7), (X + s * 14, Y)], fill=c)
            ex = X - s * OFF
            dr.line([(X - s * 4, Y), (X - s * 25, Y), (ex + s * 12, q), (ex, q)], fill=c, width=2)
            w = dr.textlength(lab, font=f)
            dr.text((ex - 6 - w if e == 'W' else ex + 6, q - 10), lab, font=f, fill=c)

um = lambda v: v / units
title = (f'ecg_snn_core ({V}): die {um(x1 - x0):.2f} x {um(y1 - y0):.2f} um, '
         f'{len(pins)} signal pins on the die edge; core block, no pad ring')
dr.text((M, 18), title, font=fb, fill=(235, 235, 240))
ly = W + 20
items = [('die boundary', (235, 235, 235)), ('core (placement rows)', (150, 200, 255)),
         ('input pin', col['INPUT']), ('output pin', col['OUTPUT'])]
x = M
for lab, c in items:
    dr.rectangle([x, ly + 6, x + 22, ly + 28], fill=c)
    dr.text((x + 30, ly + 6), lab, font=f, fill=(220, 224, 235))
    x += 60 + int(dr.textlength(lab, font=f))
dr.text((x + 20, ly + 6), 'pins drawn enlarged; positions from 6_final.def', font=f, fill=(170, 175, 190))
out = root / f'reports/layout_pins{SUF}.png'
canvas.save(out)
print(out, len(pins), 'pins;', sorted({p[2] for p in pins}))
