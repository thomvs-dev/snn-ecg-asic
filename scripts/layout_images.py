# Run in KLayout: QT_QPA_PLATFORM=offscreen klayout -z -r scripts/layout_images.py
import pya
import json
from pathlib import Path
root=Path('/work')
gds=root/'physical/results/sky130hd/ecg_snn_core/base/6_final.gds'
view=pya.LayoutView()
view.load_layout(str(gds),0)
view.max_hier()
view.add_missing_layers()
view.set_config('background-color','#101827')
view.zoom_fit()
view.save_image(str(root/'reports/layout_full.png'),1600,1600)
layout=view.active_cellview().layout()
top=layout.top_cell()
box=top.dbbox()
cx,cy=box.center().x,box.center().y
w=min(box.width(),box.height())*0.16
view.zoom_box(pya.DBox(cx-w/2,cy-w/2,cx+w/2,cy+w/2))
view.save_image(str(root/'reports/layout_closeup.png'),1600,1200)
result={'gds':str(gds),'top':top.name,'dbu_um':layout.dbu,'bbox_um':[box.left,box.bottom,box.right,box.top],
 'top_cells':[c.name for c in layout.top_cells()],'cell_definitions':layout.cells(),'layers':len(layout.layer_indexes())}
(root/'reports/gds_inspection.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
pya.Application.instance().exit(0)
