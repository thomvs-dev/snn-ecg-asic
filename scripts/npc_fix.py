# KLayout (pya) script: merge npc (95/20) notches/gaps narrower than 0.27 um.
#
# SKY130 rule npc.2 (min. npc spacing 0.27 um) says such gaps "should be
# manually merged". They arise when standard cells abut (e.g. conb_1 next to
# o21ai_0). For each spacing violation this applies a morphological closing
# (grow by 0.135 um, shrink by 0.135 um, square corners) in a small window
# around it, and inserts only the added area into the top cell. The result is
# checked: no npc spacing or width violations, Manhattan edges, 5 nm grid.
#
# Run: klayout -b -r scripts/npc_fix.py   with env GDS_IN, GDS_OUT, REPORT
import os
import pya

src, dst, rep = os.environ['GDS_IN'], os.environ['GDS_OUT'], os.environ['REPORT']
ly = pya.Layout()
ly.read(src)
top = ly.top_cell()
dbu = ly.dbu
um = lambda v: int(round(v / dbu))
SPACE, HALF, WIN, GRID = um(0.27), um(0.135), um(0.6), um(0.005)
li = ly.find_layer(95, 20)
npc = pya.Region(top.begin_shapes_rec(li))
npc.merge()

viol = npc.space_check(SPACE)
lines = [f'input {src}', f'npc spacing violations before: {viol.count()}']
added = pya.Region()
for ep in viol.each():
    box = ep.bbox().enlarged(WIN, WIN)
    local = npc & pya.Region(box)
    # mode 5 keeps square corners, so the result stays Manhattan
    closed = local.sized(HALF, HALF, 5).sized(-HALF, -HALF, 5)
    inner = pya.Region(box.enlarged(-HALF, -HALF))
    add = (closed - local) & inner
    added += add
    lines.append(f'  violation at {ep.bbox().to_dtype(dbu)}: added {add.area() * dbu * dbu:.4f} um2')
added.merge()

after = (npc + added).merged()
checks = {
    'spacing violations after': after.space_check(SPACE).count(),
    'width violations after': after.width_check(SPACE).count(),
    'non-Manhattan edges in added area': sum(1 for e in added.edges().each() if e.dx() != 0 and e.dy() != 0),
    'off-grid vertices in added area': sum(1 for p in added.each() for q in p.each_point_hull() if q.x % GRID or q.y % GRID),
}
lines += [f'{k}: {v}' for k, v in checks.items()]
ok = all(v == 0 for v in checks.values())
lines.append('RESULT: ' + ('PASS' if ok else 'FAIL (GDS not written)'))
if ok:
    top.shapes(li).insert(added)
    ly.write(dst)
    lines.append(f'output {dst}')
open(rep, 'w').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
if not ok:
    raise SystemExit(1)
