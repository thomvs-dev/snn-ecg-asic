# KLayout (pya) script: put top-level pin rectangles on the drawing layer.
#
# ORFS streams DEF pins only to the <metal>.pin datatype (16); the routed
# drawing metal (datatype 20) covers only part of each pin and stops short of
# the die edge. This copies every top-cell pin shape on met1..met5 onto the
# drawing layer of the same metal, so the pin is real metal up to the boundary.
# Standard-cell internals are untouched (only top-cell shapes are used).
#
# Run: klayout -b -r scripts/pin_metal.py   with env GDS_IN, GDS_OUT, REPORT
import os
import pya

src, dst, rep = os.environ['GDS_IN'], os.environ['GDS_OUT'], os.environ['REPORT']
ly = pya.Layout()
ly.read(src)
top = ly.top_cell()
lines = [f'input  {src}', f'output {dst}', f'top    {top.name}']
for m, name in [(68, 'met1'), (69, 'met2'), (70, 'met3'), (71, 'met4'), (72, 'met5')]:
    pin = ly.find_layer(m, 16)
    if pin is None:
        continue
    pins = pya.Region(top.shapes(pin))
    if pins.is_empty():
        continue
    drw = ly.layer(m, 20)
    before = pya.Region(top.begin_shapes_rec(drw))
    cov0 = (pins & before).area() / pins.area()
    top.shapes(drw).insert(pins)
    after = pya.Region(top.begin_shapes_rec(drw))
    cov1 = (pins & after).area() / pins.area()
    lines.append(f'{name}: {pins.count()} pin shapes; drawing coverage {cov0:.3f} -> {cov1:.3f}')
ly.write(dst)
open(rep, 'w').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
