"""Generate the clock-gated variant rtl_cg/ from the verified baseline rtl/.

Baseline rtl/ (and the routed baseline GDS built from it) is not modified.

Two SKY130 integrated clock gates (sky130_fd_sc_hd__dlclkp, latch_posedge):
  icg_load: clocks the 1024-bit input-period storage only on accepted load
            writes (load_valid && load_ready).
  icg_net : clocks the rest of the network (input counters and spike bits,
            arbitration, hidden/output neurons, main timer) only when
            reset is asserted or the wrapper is in PREP or RUN.
The wrapper (state machine, load counter, result and cycle registers) stays on
the free-running clock.

Why this is cycle-equivalent to the baseline:
  * Outside RUN the baseline holds every network flip-flop except in_period
    in synchronous reset. All of them reset in a single enabled edge, and
    the PREP edge is always enabled, so the network enters RUN in the same
    state as the baseline (counters loaded from in_period).
  * Network outputs are only used by the wrapper in RUN.
  * in_period changes only when load_valid && load_ready; its gate enable is
    exactly that write enable.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'rtl'
OUT = ROOT / 'rtl_cg'
OUT.mkdir(exist_ok=True)


def sub(s, old, new):
    assert s.count(old) == 1, f'expected exactly one match for: {old!r}'
    return s.replace(old, new)


def write_if_changed(path, text):
    """Rewrite only when content changes, so file timestamps (and ORFS make) are not disturbed."""
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


for p in sorted(SRC.glob('*.v')):
    s = p.read_text()
    if p.name == 'snn_network.v':
        s = sub(s, 'module snn_network (clk, resetn,', 'module snn_network (clk, clk_load, resetn,')
        s = sub(s, 'input clk , resetn;', 'input clk , clk_load, resetn;')
        s = sub(s, 'always @(posedge clk) if (load_valid) in_period[load_addr] <= load_data;',
                'always @(posedge clk_load) if (load_valid) in_period[load_addr] <= load_data;')
    elif p.name == 'ecg_snn_core.v':
        s = sub(s, ' wire network_reset = reset || state != RUN;\n',
                ' wire network_reset = reset || state != RUN;\n'
                ' // Clock gating: storage clocked only on accepted writes; network clocked\n'
                ' // only in reset, PREP and RUN (it is held in reset outside RUN anyway).\n'
                ' wire load_fire = load_valid && load_ready;\n'
                ' wire network_clk_en = reset || state != IDLE;\n'
                ' wire clk_load, clk_net;\n'
                ' clock_gate icg_load(.clk(clk), .en(load_fire), .gclk(clk_load));\n'
                ' clock_gate icg_net(.clk(clk), .en(network_clk_en), .gclk(clk_net));\n')
        s = sub(s, 'snn_network network(.clk(clk), .resetn(network_reset),',
                'snn_network network(.clk(clk_net), .clk_load(clk_load), .resetn(network_reset),')
        s = sub(s, '.load_valid(load_valid && load_ready)', '.load_valid(load_fire)')
        s = s.replace('// MIT; wrapper for the upstream ECG SNN.', '// MIT; clock-gated wrapper for the upstream ECG SNN.')
    write_if_changed(OUT / p.name, s)

write_if_changed(OUT / 'clock_gate.v', '''// MIT. Integrated clock gate: SKY130 latch-based ICG (enable latched while
// clk is low, gclk = clk & latched enable), glitch-free by construction.
// Instantiated unconditionally so synthesis never depends on a macro.
// Simulation: add tb/sky130_icg_model.v (behavioural model of this cell).
module clock_gate(input wire clk, input wire en, output wire gclk);
  sky130_fd_sc_hd__dlclkp_1 icg(.CLK(clk), .GATE(en), .GCLK(gclk));
endmodule
''')
print(f'Generated {OUT.relative_to(ROOT)} from {SRC.relative_to(ROOT)} (baseline unchanged).')
