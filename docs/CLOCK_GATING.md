# Clock-gated variant (cg)

Purpose: remove the clock-on idle power of the baseline. In the baseline, the
clock tree plus flip-flop clock pins make up about 99 % of the estimated
5.68 mW drawn while waiting between beats.

The baseline (`rtl/`, `flow/`, `physical/*/base/`) is unchanged and remains the
verified reference. The gated design is a separate variant: `rtl_cg/`,
`flow_cg/`, ORFS `FLOW_VARIANT=cg`, results in `physical/*/cg/` and
`reports/cg/`. All steps ran through `scripts/run_cg_all.sh`; the per-step log
is `reports/cg/run_all.log`. The full table is `reports/cg/comparison.md`,
generated from the evidence files by `scripts/compare_cg.py`.

## Design

Two SKY130 integrated clock gates (`sky130_fd_sc_hd__dlclkp_1`, latch-based,
glitch-free); see `rtl_cg/ecg_snn_core.v` and `rtl_cg/clock_gate.v`.

| Gate | Clocks | Enable | Clock active |
|---|---|---|---|
| icg_load | 1,024 input-period flip-flops | `load_valid && load_ready` | only on accepted load writes (256 per beat) |
| icg_net | 1,568 network flip-flops: input counters and spike bits, arbiters, neurons, main timer | `reset \|\| state != IDLE` | reset, PREP and RUN |
| none | 32 wrapper flip-flops: state, load counter, busy/done, results, cycle count | — | always |

Why the outputs are cycle-identical: outside RUN the baseline holds every
network flip-flop except `in_period` in synchronous reset, and each one has a
reset term. The PREP edge is always clock-enabled, so one edge restores the
same reset state, with input counters loaded from `in_period`. The wrapper
only reads network outputs in RUN, and `in_period` changes only when its gate
is enabled. `rtl_cg/` is generated from `rtl/` by
`scripts/generate_rtl_cg.py`, using exact substitutions that are asserted to
match once.

## Results

### Function (zero-delay simulation)

| Check | Result | Evidence |
|---|---|---|
| Gated RTL, 500 vectors | PASS; predictions byte-identical to `reports/baseline.csv` | reports/cg/rtl_simulation.log |
| Gated RTL protocol and idle benches | PASS | reports/cg/rtl_protocol.log, rtl_idle.log |
| **cg post-route netlist, 500 vectors** | **PASS; byte-identical to baseline.csv** | reports/cg/final_gate_simulation.log, final_gate_predictions.csv |
| **cg post-route netlist, protocol bench** | **PASS** | reports/cg/final_gate_protocol.log |
| ORFS netlist equivalence (post-resizer, final) | IDENTICAL, IDENTICAL | physical/logs/.../cg/4_rsz_lec_check.log, 6_final_lec_check.log |
| Negative control (enable without PREP) | Fails at vector 0, as intended | reports/cg/precheck/PROVENANCE.txt |
| ICG cells | 2 in the synthesis netlist, 2 in the final netlist | reports/cg/icg_check.txt |

### Clock tree (physical/logs/.../cg/4_1_cts.log)

CTS found four clock nets. `clk` drives the 2 ICGs, `clk_regs` the 32 wrapper
flip-flops, `clk_net` 1,568 sinks and `clk_load` 1,024 sinks, and each
received its own buffered tree: 209 buffers (4 levels) under `clk_net` and
144 (4 levels) under `clk_load`.

### Timing, TT 25 °C 1.8 V, OpenRCX, 40 ns

| | Baseline | cg |
|---|---|---|
| Setup WNS / TNS | +29.864 ns / 0 | +28.822 ns / 0 |
| Hold WNS / TNS | +0.0466 ns / 0 | +0.0436 ns / 0 |
| Setup clock skew | 0.44 ns | 1.48 ns |
| Single-corner minimum period (not a supported frequency) | 10.14 ns | 11.18 ns |
| Max slew / cap / fanout violations | 0 / 0 / 0 | 0 / 0 / 0 |

The ICG `GATE` pin has `setup_rising`/`hold_rising` arcs to `CLK` in the
Liberty file, so the enable paths are checked as ordinary setup/hold and are
inside the WNS/TNS above. Skew rises because the ICG clock pins sit early in
the tree (0.22 ns) while wrapper flip-flops are late (1.30 ns). The worst
setup path is an I/O path (`reset` to `load_ready`). The hold margin is still
small (44 ps) and is still only checked at TT.

### Physical (physical/logs/.../cg/6_report.json, 5_2_route.log)

| | Baseline | cg | Change |
|---|---|---|---|
| Die | 609.36 µm square | 614.63 µm square | +1.7 % area |
| Standard cells (excl. fillers) | 16,632 | 17,184 | +3.3 % |
| Their area | 137,481 µm² | 141,565 µm² | +3.0 % |
| Utilization | 39.74 % | 40.17 % | |
| Clock buffers / inverters | 444 / 124 | 527 / 138 | |
| Flip-flops | 2,625 | 2,624 | |
| Routed wire / vias | 347,750 µm / 87,833 | 373,904 µm / 92,019 | +7.5 % wire |
| KLayout DRC (BEOL + off-grid) | 0 | 0 | |
| LVS | match | match | |
| Antenna (final) | 0 (10 diodes) | 0 (7 diodes) | |

### Power and energy (OpenSTA estimate, not a measurement)

Both variants were estimated the same way. Activity comes from zero-delay
simulation of each **final post-route netlist** (2 unannotated pins each), on
the same 628.861 µs, 20-vector window and the same 100 µs clock-running idle
window. Power uses the TT Liberty, the final SDC and the extracted SPEF.
Rerunning the baseline this way reproduces the original estimate to six
significant figures, so the earlier 1,482-unannotated-pin caveat had no
material effect.

| | Baseline | cg | cg / base |
|---|---|---|---|
| Workload window average power | 5.7426 mW | 3.3971 mW | 0.592 (−40.8 %) |
| Workload window energy (20 vectors) | 3.611 µJ | 2.136 µJ | 0.592 |
| **Clock-running idle power** | **5.6756 mW** | **0.1145 mW** | **0.0202 (49.6× lower)** |
| Idle: clock group / sequential | 2.776 / 2.900 mW | 0.0825 / 0.0319 mW | |
| Leakage | 49.4 nW | 51.3 nW | +3.8 % |
| Activity-dependent part of window energy | 42 nJ | 2,064 nJ | |

How to read this:

- **Idle drops 98 %.** What remains (114 µW) is the clock root up to the two
  ICGs, the 32 wrapper flip-flops with their small tree, and the ICGs
  themselves.
- **The workload window drops only 41 %,** because 99.6 % of its clocks are
  loading or RUN. During those clocks one domain is still clocked: storage
  while loading, network during RUN. The saving there comes from the other
  domain being stopped.
- **Clock energy now follows the work.** In cg, most of the window energy is
  activity-dependent (2.06 µJ, about 0.10 µJ per vector averaged over this
  window, which over-represents one long beat). In the baseline the same clock
  power was paid all the time.
- **Average power at one beat per second:** about 0.1145 mW + 0.10 µJ/s ≈
  **0.115 mW**, against 5.68 mW for the baseline (about 50× lower). This uses
  the window-average energy per vector and ignores beat-to-beat variation.

## Variant cg2: denser core, evenly spaced pins, pin metal (2026-11-12)

Same RTL and constraints as cg. `CORE_UTILIZATION` 55 (cg: 35); inputs evenly
spaced on the west edge and outputs on the east edge (`flow_cg2/io.tcl`); pin
rectangles copied onto the drawing layer after GDS export (`scripts/pin_metal.py`;
the ORFS output is kept as `6_final_no_pin_metal.gds`). DRC and LVS ran on the
modified GDS. Run log: `reports/cg2/run_all.log`; table:
`reports/cg2/comparison.md`.

| | cg | cg2 |
|---|---|---|
| Die | 614.63 µm square | **494.35 µm square (−35 % area)** |
| Utilization / cells / area | 40.2 % / 17,184 / 141,565 µm² | 61.6 % / 15,357 / 138,239 µm² |
| Post-route netlist 500 vectors + protocol | PASS | PASS (predictions byte-identical to baseline.csv) |
| Pins | clustered by ORFS; drawn metal ~30 % of pin | 8 inputs west, 23 outputs east, evenly spaced; drawn metal 100 % of pin |
| ORFS DRC / LVS / antenna | 0 / match / 0 | 0 / match / 0 |
| Full-chip DRC (sky130A_mr.drc) | 0 | **0** after merging one npc notch (0.255 × 0.05 µm between abutting `conb_1` and `o21ai_0`; `scripts/npc_fix.py`, report `reports/cg2/npc_fix.txt`) |
| TT setup / hold WNS | +28.82 / +0.044 ns | +28.60 / +0.036 ns |
| ff hold | −0.117 ns, 1,147 endpoints | −0.143 ns, 1,426 endpoints, TNS −112.4 ns |
| ss slew / cap violations | 464 / 50 | 547 / 58 (setup +25.03 ns) |
| Window power / energy (25 MHz) | 3.397 mW / 2.136 µJ | 3.251 mW / 2.044 µJ |
| Idle power (25 MHz) | 114.5 µW | 111.1 µW |

The denser placement makes the corner issues slightly worse. They remain
deferred: no timing margins were added. The single npc.2 hit (a notch between
abutting cells, which the rule text says should be merged) was fixed by a
local closing of npc in the GDS. The fix was checked for no npc spacing/width
violations, Manhattan edges and the 5 nm grid. ORFS DRC, LVS and the full-chip
deck were then rerun: 0 / match / 0. During that rerun ORFS repeated the whole
flow (rtl_cg timestamps had changed). A layer-by-layer XOR showed the new
layout identical to the first, so the cg2 timing, power and netlist results
stand.

## Remaining limitations

- Single TT corner; hold margin 44 ps; no fast-corner check.
- Zero-delay activity (no glitch power); tool estimate, no silicon.
- At 25 MHz the remaining 114 µW is still large next to published µW-class
  ECG SNN designs. The next steps would be stopping the root clock when idle,
  for example gating at the clock source or letting the host stop the clock,
  or running at a lower clock. The design is cycle-based, so results are
  unchanged by frequency; only latency scales.
- Same DRC/LVS coverage limits as the baseline (FEOL deck section off).

## Reproduce

```bash
cd /mnt/d/snn
sudo bash scripts/run_cg_all.sh     # flow, checks, verification, power for cg and base, comparison
VARIANT=cg python3 scripts/layout_images_readable.py   # reports/layout_*_readable_cg.png
```

## Variant cg3: root clock gate (2026-11-12) — final design

The 111 µW left in cg2 was the clock root up to the two gates (79 µW in the
clock group) plus the 32 wrapper flip-flops. cg3 adds a third gate on the
clock input (`scripts/generate_rtl_cg3.py`, `rtl_cg3/ecg_snn_core.v`):

    root enable = reset || load_valid || start || state != IDLE || done

Everything, including the wrapper and the two existing gates, is clocked from
the root gate output. With the enable low the wrapper is in IDLE with `done`
low and no input asserted; in that condition no register changes on a clock
edge in the two-gate design, so removing those edges changes nothing. `done`
is in the enable so its one-clock pulse is cleared. The enable uses the raw
inputs, so a rejected `load_valid` or `start` costs clock power but not
function.

| | base | cg2 | cg3 |
|---|---|---|---|
| Idle power, clock input running, 25 MHz | 5.676 mW | 111.1 µW | 0.713 µW |
| Idle clock group | 2.776 mW | 79.3 µW | 0.664 µW |
| 20-vector window energy | 3.611 µJ | 2.044 µJ | 2.018 µJ |
| Leakage | 49.4 nW | 50.7 nW | 52.0 nW |

Verification: `scripts/verify_cg3.sh` (500 vectors, protocol bench,
`tb/tb_root_gate.sv`, random-stimulus traces from `tb/tb_random.sv` compared
with the ungated RTL) and the post-route checks in `scripts/run_cg3.sh`.
The same layout run adds the fast/slow corner timing margins. Full table and
caveats: `reports/RESULTS.md`, section "Variant cg3".
