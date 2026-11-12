"""Stretch a VCD in time by an integer-safe factor: scale_vcd.py IN OUT FACTOR.

The simulations are zero-delay and cycle-based, so stretching every timestamp
by FACTOR is identical to rerunning the same stimulus with a clock period
FACTOR times longer. Timestamps must stay integral; an error is raised otherwise.
"""
import sys
from fractions import Fraction

src, dst, k = sys.argv[1], sys.argv[2], Fraction(sys.argv[3])
with open(src) as fi, open(dst, 'w') as fo:
    for line in fi:
        if line.startswith('#'):
            t = int(line[1:]) * k
            if t.denominator != 1:
                raise SystemExit(f'non-integral timestamp after scaling: {line.strip()} x {k}')
            fo.write(f'#{t.numerator}\n')
        else:
            fo.write(line)
print(f'{src} -> {dst}: time x {k}')
