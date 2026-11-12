"""Generate rtl_cg3/ (root clock gate) from rtl_cg/ (two-gate variant).

rtl/ and rtl_cg/ are only read, so the base, cg and cg2 layouts are not
disturbed (ORFS make sees no new timestamps).

Adds a third SKY130 integrated clock gate, icg_root, on the clock input. Every
flip-flop and both existing gates (icg_load, icg_net) are clocked from its
output, so the whole clock tree is static while the core is idle.

  root enable = reset || load_valid || start || state != IDLE || done

Why this is cycle-equivalent to rtl_cg (and so to the baseline):
  With the enable low the wrapper is in IDLE with done = 0 and reset,
  load_valid and start all low. In that condition no wrapper register changes
  on a clock edge (loaded, state, busy, result_class, no_spike and
  inference_cycles hold; done is already 0), icg_load is disabled
  (load_valid = 0) and icg_net is disabled (state == IDLE, reset = 0). The
  suppressed edges therefore changed nothing in rtl_cg either.
  done is in the enable so the one-clock done pulse is cleared on the next edge.
  The enable uses the raw inputs, not load_ready/input_complete: a rejected
  load_valid or start only costs clock power, never function.

The enable is sampled by the gate's latch while clk is low, so the inputs must
meet the same synchronous timing as before. A host that needs the outputs to
change must supply clock edges, as before; nothing else in the port protocol
changes.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'rtl_cg'
OUT = ROOT / 'rtl_cg3'
OUT.mkdir(exist_ok=True)


def sub(s, old, new):
    assert s.count(old) == 1, f'expected exactly one match for: {old!r}'
    return s.replace(old, new)


def write_if_changed(path, text):
    """Rewrite only when content changes, so file timestamps (and ORFS make) are not disturbed."""
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


assert (SRC / 'ecg_snn_core.v').exists(), 'run scripts/generate_rtl_cg.py first'
for p in sorted(SRC.glob('*.v')):
    s = p.read_text()
    if p.name == 'ecg_snn_core.v':
        s = sub(s, ' wire clk_load, clk_net;\n',
                ' wire clk_load, clk_net;\n'
                ' // Root clock gate: the whole clock tree is static while the core is idle\n'
                ' // (IDLE, done low, no reset, no load_valid, no start). See\n'
                ' // scripts/generate_rtl_cg3.py for the equivalence argument.\n'
                ' wire clk_root;\n'
                ' wire root_clk_en = reset || load_valid || start || state != IDLE || done;\n'
                ' clock_gate icg_root(.clk(clk), .en(root_clk_en), .gclk(clk_root));\n')
        s = sub(s, 'clock_gate icg_load(.clk(clk),', 'clock_gate icg_load(.clk(clk_root),')
        s = sub(s, 'clock_gate icg_net(.clk(clk),', 'clock_gate icg_net(.clk(clk_root),')
        s = sub(s, ' always @(posedge clk) begin\n', ' always @(posedge clk_root) begin\n')
        s = sub(s, '// MIT; clock-gated wrapper for the upstream ECG SNN.',
                '// MIT; clock-gated wrapper (root, storage and network gates) for the upstream ECG SNN.')
    write_if_changed(OUT / p.name, s)
print(f'Generated {OUT.relative_to(ROOT)} from {SRC.relative_to(ROOT)} (rtl and rtl_cg unchanged).')
