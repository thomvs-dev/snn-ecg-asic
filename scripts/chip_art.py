# KLayout (pya) script: add "chip art" (heart outline with an ECG trace) on met5.
#
# met5 in this design carries only the horizontal PDN straps, which alternate
# VDD/VSS. The art is drawn in the free bands between straps and kept at least
# 1.6 um from all existing met5 and via4, so it never touches a power strap
# (touching two straps would short VDD to VSS). Each art piece is unconnected
# metal; the LVS deck's netlist.simplify purges such nets.
#
# Rules enforced and checked on (existing met5 + art), sky130A_mr.drc:
#   m5.1 width >= 1.6, m5.2 space >= 1.6, m5.4 area >= 4.0 um^2,
#   m5.7 holes >= 0.14 um^2, 5 nm grid, Manhattan edges.
# Nothing is written unless every check passes.
#
# Run: klayout -b -r scripts/chip_art.py  with env GDS_IN, GDS_OUT, REPORT
#      optional ART_CX, ART_CY, ART_W (um; default: die centre, 0.5 x die width)
import os
import math
import pya

src, dst, rep = os.environ['GDS_IN'], os.environ['GDS_OUT'], os.environ['REPORT']
ly = pya.Layout()
ly.read(src)
top = ly.top_cell()
dbu = ly.dbu
um = lambda v: int(round(v / dbu))
die = top.bbox()
cx = um(float(os.environ['ART_CX'])) if 'ART_CX' in os.environ else die.center().x
cy = um(float(os.environ['ART_CY'])) if 'ART_CY' in os.environ else die.center().y
W = um(float(os.environ['ART_W'])) if 'ART_W' in os.environ else int(die.width() * 0.5)
PIX = um(2.0)               # bitmap pixel (> 1.6 um minimum width)
SP, HALF, AREA = um(1.6), um(0.8), 4.0 / (dbu * dbu)

m5 = ly.find_layer(72, 20)
v4 = ly.find_layer(71, 44)
existing = pya.Region(top.begin_shapes_rec(m5)).merged()
vias = pya.Region(top.begin_shapes_rec(v4)) if v4 is not None else pya.Region()
core = pya.Region(die.enlarged(-um(12), -um(12)))
allowed = core - (existing + vias).sized(SP, SP, 5)

# ---- bitmap: heart outline + ECG trace -------------------------------------
n = W // PIX                       # pixels across the heart
H = int(n * 0.9)
bits = set()


def heart(u, v):                   # classic implicit heart, u,v in about [-1.2, 1.2]
    return (u * u + v * v - 1) ** 3 - u * u * v ** 3


thick = max(3, n // 22)            # outline thickness in pixels
for i in range(-n // 2 - 2, n // 2 + 3):
    for j in range(-H // 2 - 2, H // 2 + 3):
        u, v = 2.6 * i / n, 2.6 * j / n + 0.15
        inside = heart(u, v) <= 0
        if inside:
            # pixel is on the outline if a point `thick` pixels away is outside
            near_out = any(heart(2.6 * (i + di) / n, 2.6 * (j + dj) / n + 0.15) > 0
                           for di, dj in ((thick, 0), (-thick, 0), (0, thick), (0, -thick),
                                          (thick, thick), (-thick, thick), (thick, -thick), (-thick, -thick)))
            if near_out:
                bits.add((i, j))


def ecg(t):                        # PQRST shape, t in [0, 1] -> height in [-0.35, 1]
    g = lambda mu, s, a: a * math.exp(-((t - mu) / s) ** 2)
    return (g(0.30, 0.025, 0.12) - g(0.455, 0.014, 0.18) + g(0.50, 0.018, 1.0)
            - g(0.545, 0.016, 0.32) + g(0.72, 0.040, 0.22))


span = int(n * 1.6)                # trace extends beyond the heart on both sides
amp = H * 0.55
lw = 3                             # trace thickness in pixels (6 um)
prev = None
for k in range(span + 1):
    i = -span // 2 + k
    j = int(round(ecg(k / span) * amp)) - H // 8
    ys = [j] if prev is None else range(min(prev, j), max(prev, j) + 1)
    for jj in ys:                  # vertical fill keeps steep spikes continuous
        for a in range(lw):
            for b in range(lw):
                bits.add((i + a, jj + b))
    prev = j

art = pya.Region()
for i, j in bits:
    x, y = cx + i * PIX, cy + j * PIX
    art.insert(pya.Box(x, y, x + PIX, y + PIX))
art.merge()


# ---- fit into the free met5 bands and clean --------------------------------
def closing(r):
    return r.sized(HALF, HALF, 5).sized(-HALF, -HALF, 5)


def opening(r):
    return r.sized(-HALF, -HALF, 5).sized(HALF, HALF, 5)


raw_area = art.area()
for _ in range(3):
    art = opening(closing(art) & allowed) & allowed
    art = art.merged().with_area(int(AREA), None, False)
    art = art.snapped(um(0.005), um(0.005))

# Clipping to the bands can leave pieces that touch only at a corner (zero
# width/space). Cut a 1.6 um square at each such contact, re-clean, repeat.
for _ in range(10):
    bad = art.width_check(SP) + art.space_check(SP)
    if bad.is_empty():
        break
    cut = pya.Region()
    for ep in bad.each():
        c = ep.bbox().center()
        cut.insert(pya.Box(c.x - HALF, c.y - HALF, c.x + HALF, c.y + HALF))
    art = opening(art - cut).merged().with_area(int(AREA), None, False)
    art = art.snapped(um(0.005), um(0.005))

final = (existing + art).merged()
checks = {
    'art touches or is within 1.6 um of existing met5/via4': (art & (existing + vias).sized(SP - 1, SP - 1, 5)).count(),
    'm5.1 width < 1.6': final.width_check(SP).count(),
    'm5.2 space < 1.6': final.space_check(SP).count(),
    'm5.4 area < 4.0': art.with_area(0, int(AREA), False).count(),
    'm5.7 holes < 0.14': final.holes().with_area(0, int(0.14 / (dbu * dbu)), False).count(),
    'non-Manhattan art edges': sum(1 for e in art.edges().each() if e.dx() and e.dy()),
    'off-grid art vertices': sum(1 for p in art.each() for q in p.each_point_hull() if q.x % um(0.005) or q.y % um(0.005)),
}
ok = all(v == 0 for v in checks.values()) and not art.is_empty()
lines = [f'input {src}', f'art centre ({cx * dbu:.2f}, {cy * dbu:.2f}) um, width {W * dbu:.1f} um, pixel {PIX * dbu} um',
         f'bitmap pixels {len(bits)}, drawn area {raw_area * dbu * dbu:.1f} um2 -> kept {art.area() * dbu * dbu:.1f} um2 '
         f'in {art.count()} floating met5 pieces',
         f'art bbox {art.bbox().to_dtype(dbu)}']
lines += [f'{k}: {v}' for k, v in checks.items()]
lines.append('RESULT: ' + ('PASS' if ok else 'FAIL (GDS not written)'))
if ok:
    top.shapes(m5).insert(art)
    ly.write(dst)
    lines.append(f'output {dst}')
open(rep, 'w').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
if not ok:
    raise SystemExit(1)
