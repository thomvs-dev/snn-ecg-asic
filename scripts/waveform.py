"""Render selected port transitions from the recorded first-beat VCD."""
from pathlib import Path
import html
root=Path(__file__).resolve().parents[1]
p=root/'reports/rtl_first_beat.vcd'
signals={}; events={}; t=0
for line in p.read_text().splitlines():
 if line.startswith('$var'):
  a=line.split(); signals[a[4]]=a[3]; events[a[3]]=[]
 elif line.startswith('#'): t=int(line[1:])/1e6 # ps -> us
 elif line.startswith('b'):
  v,key=line[1:].split(); events[key].append((t,v))
 elif line and line[0] in '01xz' and line[1:] in events:
  events[line[1:]].append((t,line[0]))
names=['load_valid','input_complete','start','busy','done','result_class','inference_cycles']
x0,x1=10.25,11.53
W,H=1200,500
def x(t): return 180+(t-x0)/(x1-x0)*980
s=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
 '<rect width="100%" height="100%" fill="#101827"/>',
 '<g font-family="monospace" font-size="15" fill="#e2e8f0">',
 '<text x="24" y="30">Recorded RTL simulation: beat 0, 25 MHz (last input through completion)</text>']
for tick in [10.3,10.5,10.7,10.9,11.1,11.3,11.5]:
 xx=x(tick); s += [f'<path d="M{xx},50 V430" stroke="#334155"/>', f'<text x="{xx-22}" y="457">{tick:.1f}</text>']
for n,name in enumerate(names):
 y=80+n*50
 s.append(f'<text x="15" y="{y+5}">{name}</text>')
 seq=events[signals[name]]; prev='x'; clipped=[]
 for tt,v in seq:
  if tt<=x0: prev=v
  elif tt<x1: clipped.append((tt,v))
 seq=[(x0,prev)]+clipped+[(x1,None)]
 for (a,v),(b,_) in zip(seq,seq[1:]):
  xa,xb=x(a),x(b)
  if name in ['result_class','inference_cycles']:
   s.append(f'<path d="M{xa},{y-12} H{xb} M{xa},{y+12} H{xb} M{xa},{y-12} V{y+12}" stroke="#38bdf8" fill="none"/>')
   if xb-xa>22:
    value=str(int(v,2)) if set(v)<=set('01') else v
    s.append(f'<text x="{(xa+xb)/2}" y="{y+5}" text-anchor="middle" font-size="12">{html.escape(value)}</text>')
  else:
   yy=y-12 if v=='1' else y+12
   s.append(f'<path d="M{xa},{y-12} V{y+12} M{xa},{yy} H{xb}" stroke="#4ade80" stroke-width="2" fill="none"/>')
s+=['<text x="180" y="488">Time (us). Source: reports/rtl_first_beat.vcd; values sampled after clock edges.</text>','</g></svg>']
(root/'reports/first_beat_waveform.svg').write_text('\n'.join(s))
print('reports/first_beat_waveform.svg')
