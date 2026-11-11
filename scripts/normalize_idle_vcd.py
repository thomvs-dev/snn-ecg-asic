from pathlib import Path
p=Path(__file__).resolve().parents[1]/'reports/idle_activity.vcd'
lines=p.read_text().splitlines()
origin=next(int(s[1:]) for s in lines if s.startswith('#'))
p.write_text('\n'.join('#'+str(int(s[1:])-origin) if s.startswith('#') else s for s in lines)+'\n')
print(f'Idle VCD time origin shifted by {origin} ps; duration preserved.')
