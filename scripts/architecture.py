from pathlib import Path
root=Path(__file__).resolve().parents[1]
boxes=[(30,100,180,100,['Host preprocessing','off chip','256 four-bit periods']),
 (250,100,190,100,['Load / start interface','1024-bit period storage','ready, busy, done']),
 (480,100,180,100,['256 spike encoders','2501-clock timer','pending spike bits']),
 (700,100,180,100,['Priority arbitration','lowest index first','8-bit input address']),
 (920,100,190,100,['8 hidden IF neurons','unsigned 11-bit state','fire when > 320']),
 (700,310,180,100,['6 output IF neurons','unsigned 11-bit state','fire when > 112']),
 (480,310,180,100,['Class / timeout','first spike wins','12-tick timeout']),
 (250,310,190,100,['Latched result','numeric class 0/1/2','no_spike, cycles']),
 (920,20,190,55,['8 x 256 x 8-bit','constant weight ROM']),
 (700,440,180,55,['6 x 8 x 8-bit','constant weight ROM'])]
s=['<svg xmlns="http://www.w3.org/2000/svg" width="1150" height="540" viewBox="0 0 1150 540">',
 '<defs><marker id="a" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L8,3 L0,6" fill="#64748b"/></marker></defs>',
 '<rect width="1150" height="540" fill="#f8fafc"/>']
for x,y,w,h,lines in boxes:
 color='#e0f2fe' if 'ROM' not in lines[-1] else '#fef3c7'
 s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{color}" stroke="#334155"/>')
 for i,line in enumerate(lines):
  s.append(f'<text x="{x+w/2}" y="{y+24+i*24}" text-anchor="middle" font-family="Arial" font-size="15" fill="#0f172a">{line.replace(">","&gt;")}</text>')
for path in ['M210,150 H250','M440,150 H480','M660,150 H700','M880,150 H920','M1015,75 V100',
 'M1015,200 V360 H880','M700,360 H660','M480,360 H440','M790,440 V410']:
 s.append(f'<path d="{path}" stroke="#64748b" stroke-width="2" fill="none" marker-end="url(#a)"/>')
for points in ['250,150 240,145 240,155','480,150 470,145 470,155','700,150 690,145 690,155','920,150 910,145 910,155','1015,100 1010,90 1020,90','880,360 890,355 890,365','660,360 670,355 670,365','440,360 450,355 450,365','790,410 785,420 795,420']:
 s.append(f'<polygon points="{points}" fill="#64748b"/>')
s.append('<text x="790" y="270" font-family="Arial" font-size="14" fill="#334155">hidden-spike arbitration</text>')
s.append('<text x="30" y="525" font-family="Arial" font-size="15" fill="#334155">Synchronous inference core. Training, ECG acquisition, and preprocessing remain off chip.</text></svg>')
(root/'docs/architecture.svg').write_text('\n'.join(s))
