"""Render the met5 heart/ECG engraving of the final cg2 GDS (read-only).

The GDS is not modified. met5 is drawn solid gold (power straps plus the
floating art pieces added by scripts/chip_art.py); met4 and met2 are drawn
faintly underneath for context.

    python3 scripts/chip_art_render.py        # needs: pip install klayout pillow
Output: reports/chip_art_cg2.png
"""
from pathlib import Path
import os

try:
    import klayout.lay as lay
    import klayout.db as db
except ImportError:
    import pya as lay
    import pya as db

root = Path(__file__).resolve().parents[1]
VARIANT = os.environ.get('VARIANT', 'cg2')
gds = root / f'physical/results/sky130hd/ecg_snn_core/{VARIANT}/6_final.gds'
out = root / f'reports/chip_art_{VARIANT}.png'

LAYERS = [  # (source, fill, frame, dither)
    ('69/20', 0x1f4a3a, 0x1f4a3a, 0),   # met2, faint
    ('71/20', 0x2a3f6e, 0x34508a, 0),   # met4, faint
    ('72/20', 0xf2b632, 0xf2b632, 0),   # met5, solid gold
]

view = lay.LayoutView()
view.set_config('background-color', '#0f1420')
view.set_config('grid-visible', 'false')
view.set_config('text-visible', 'false')
view.set_config('cell-box-visible', 'false')
view.load_layout(str(gds), True)
view.clear_layers()
for src, fill, frame, dither in LAYERS:
    p = lay.LayerPropertiesNode()
    p.source = src + '@1'
    p.fill_color = fill
    p.frame_color = frame
    p.dither_pattern = dither
    p.width = 1
    view.insert_layer(view.end_layers(), p)
view.max_hier()

layout = db.Layout()
layout.read(str(gds))
die = layout.top_cell().dbbox()
view.zoom_box(die)
size = 1600
view.save_image_with_options(str(out), size, size, 0, 2, 0, die, False)

try:
    from PIL import Image, ImageDraw, ImageFont
    im = Image.open(out).convert('RGB')
    band = 60
    canvas = Image.new('RGB', (im.width, im.height + band), (15, 20, 32))
    canvas.paste(im, (0, 0))
    d = ImageDraw.Draw(canvas)
    try:
        f = ImageFont.truetype('DejaVuSans.ttf', 22)
    except OSError:
        f = ImageFont.load_default()
    d.text((24, im.height + 16),
           f'ecg_snn_core ({VARIANT}) met5 engraving, die {die.width():.2f} x {die.height():.2f} um '
           '(floating met5, DRC 0, LVS match)', fill=(230, 232, 240), font=f)
    canvas.save(out)
except ImportError:
    pass
print('wrote', out)
