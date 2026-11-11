"""Render presentation-quality views of the final routed GDS (read-only).

The GDS is not modified. Only display layer properties, hierarchy depth,
viewport and annotations are chosen for readability.

Run either with the KLayout Python module (pip install klayout):
    python3 scripts/layout_images_readable.py
or from the ORFS container:
    docker run --rm -v "$PWD:/work" -w /work $IMAGE python3 scripts/layout_images_readable.py
Outputs:
    reports/layout_full_readable.png     whole die, routing and power layers
    reports/layout_closeup_readable.png  small logic region, device + local routing
    reports/layout_images_readable.json  rendered regions and layer legend
"""
from pathlib import Path
import json, sys

try:
    import klayout.lay as lay
    import klayout.db as db
except ImportError:  # running inside the KLayout application
    import pya as lay
    import pya as db

root = Path(__file__).resolve().parents[1]
gds = root / 'physical/results/sky130hd/ecg_snn_core/base/6_final.gds'
out = root / 'reports'

# SKY130 GDS layer/datatype numbers (drawing layers).
L = {
    'nwell': '64/20', 'diff': '65/20', 'tap': '65/44', 'poly': '66/20',
    'licon': '66/44', 'li1': '67/20', 'mcon': '67/44', 'met1': '68/20',
    'via': '68/44', 'met2': '69/20', 'via2': '69/44', 'met3': '70/20',
    'via3': '70/44', 'met4': '71/20', 'via4': '71/44', 'met5': '72/20',
    'prBoundary': '235/4',
}

# (name, fill RGB, frame RGB, dither pattern index, frame width)
# Dither 0 = solid, 1 = hollow, 2..: KLayout stipples.
FULL = [
    ('met1', 0x3b4a6b, 0x3b4a6b, 0, 1),
    ('met2', 0x2e9e6a, 0x2e9e6a, 0, 1),
    ('met3', 0xe0a030, 0xe0a030, 0, 1),
    ('met4 (PDN + signal)', 0x4c7fe0, 0x6f9bf0, 1, 1),
    ('met5 (PDN)', 0xd94a4a, 0xf07070, 1, 1),
]
CLOSE = [
    ('nwell', 0x2a3550, 0x56658a, 1, 1),
    ('diff', 0x2e8b57, 0x2e8b57, 5, 1),
    ('tap', 0x6fbf73, 0x6fbf73, 5, 1),
    ('poly', 0xd9534f, 0xd9534f, 0, 1),
    ('licon', 0xffffff, 0xffffff, 0, 1),
    ('li1', 0x8e6fd8, 0xb39af0, 9, 1),
    ('mcon', 0xf5f5f5, 0xf5f5f5, 0, 1),
    ('met1', 0x3f8fd9, 0x6fb0f0, 2, 1),
    ('via', 0xffe066, 0xffe066, 0, 1),
    ('met2', 0xe39b2f, 0xf0b860, 3, 1),
    ('prBoundary', 0x000000, 0x9aa4b8, 1, 1),
]


def make_view(layers):
    view = lay.LayoutView()
    view.set_config('background-color', '#0f1420')
    view.set_config('grid-visible', 'false')
    view.set_config('text-visible', 'false')
    view.set_config('cell-box-visible', 'false')
    view.set_config('array-border-instances', 'false')
    view.load_layout(str(gds), True)
    view.clear_layers()
    for name, fill, frame, dither, width in layers:
        p = lay.LayerPropertiesNode()
        p.source = L[name.split()[0]] + '@1'
        p.name = name
        p.fill_color = fill
        p.frame_color = frame
        p.dither_pattern = dither
        p.width = width
        view.insert_layer(view.end_layers(), p)
    view.max_hier()
    return view


def render(view, box, path, w, h):
    view.zoom_box(box)
    view.save_image_with_options(str(path), w, h, 0, 2, 0, box, False)


def legend(path, title, items, scale_um, box_w_um, img_w):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return False
    im = Image.open(path).convert('RGB')
    W, H = im.size
    pad, band = 24, 92
    canvas = Image.new('RGB', (W, H + band), (15, 20, 32))
    canvas.paste(im, (0, 0))
    d = ImageDraw.Draw(canvas)
    try:
        f = ImageFont.truetype('DejaVuSans.ttf', 22)
        fs = ImageFont.truetype('DejaVuSans.ttf', 18)
    except OSError:
        f = fs = ImageFont.load_default()
    d.text((pad, H + 10), title, fill=(230, 232, 240), font=f)
    x = pad
    for name, fill, frame, dither, _ in items:
        c = frame if dither == 1 else fill
        rgb = ((c >> 16) & 255, (c >> 8) & 255, c & 255)
        d.rectangle([x, H + 52, x + 22, H + 74], fill=rgb, outline=(200, 200, 200))
        d.text((x + 30, H + 52), name, fill=(220, 224, 235), font=fs)
        x += 30 + int(d.textlength(name, font=fs)) + 26
    px = scale_um / box_w_um * img_w
    x1 = W - pad
    x0 = x1 - px
    y = H + 66
    d.line([x0, y, x1, y], fill=(240, 240, 240), width=4)
    d.line([x0, y - 8, x0, y + 8], fill=(240, 240, 240), width=3)
    d.line([x1, y - 8, x1, y + 8], fill=(240, 240, 240), width=3)
    lbl = f'{scale_um:g} um'
    d.text((x1 - d.textlength(lbl, font=fs), H + 34), lbl, fill=(240, 240, 240), font=fs)
    canvas.save(path)
    return True


def renderer_version():
    try:
        import klayout
        return 'KLayout Python module ' + klayout.__version__
    except Exception:
        return 'KLayout ' + lay.Application.instance().version()


def main():
    layout = db.Layout()
    layout.read(str(gds))
    top = layout.top_cell()
    die = top.dbbox()

    full_path = out / 'layout_full_readable.png'
    v = make_view(FULL)
    render(v, die, full_path, 1800, 1800)
    legend(full_path, 'ecg_snn_core, full die 609.36 x 609.36 um (routed SKY130HD GDS)',
           FULL, 100, die.width(), 1800)

    # Close-up: a 24 x 16 um window near the die centre, snapped to the
    # 2.72 um standard-cell row pitch so whole rows are shown.
    cx, cy = die.center().x, die.center().y
    row = 2.72
    y0 = round((cy - 8.0) / row) * row
    box = db.DBox(cx - 12.0, y0, cx + 12.0, y0 + 16.0)
    close_path = out / 'layout_closeup_readable.png'
    v = make_view(CLOSE)
    render(v, box, close_path, 1800, 1200)
    legend(close_path, f'Close-up {box.width():.0f} x {box.height():.0f} um at '
           f'({box.left:.1f}, {box.bottom:.1f}) um: devices and local routing (met3-met5 hidden)',
           CLOSE, 2, box.width(), 1800)

    meta = {
        'gds': str(gds.relative_to(root)),
        'gds_modified': False,
        'top_cell': top.name,
        'die_um': [die.left, die.bottom, die.right, die.top],
        'full': {'file': full_path.name, 'box_um': [die.left, die.bottom, die.right, die.top],
                 'layers': [x[0] for x in FULL]},
        'closeup': {'file': close_path.name, 'box_um': [box.left, box.bottom, box.right, box.top],
                    'layers': [x[0] for x in CLOSE]},
        'renderer': renderer_version(),
    }
    (out / 'layout_images_readable.json').write_text(json.dumps(meta, indent=2) + '\n')
    print(json.dumps(meta, indent=2))


if __name__ == '__main__':
    sys.exit(main())
