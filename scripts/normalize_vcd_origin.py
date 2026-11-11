"""Shift a VCD's first timestamp to 0 (duration unchanged). Usage: normalize_vcd_origin.py FILE"""
import sys
from pathlib import Path

p = Path(sys.argv[1])
lines = p.read_text().splitlines()
origin = next(int(s[1:]) for s in lines if s.startswith('#'))
p.write_text('\n'.join('#' + str(int(s[1:]) - origin) if s.startswith('#') else s for s in lines) + '\n')
print(f'{p}: time origin shifted by {origin} ps; duration preserved.')
