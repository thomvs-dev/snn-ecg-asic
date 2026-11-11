# Implementation results

Scope: a digital inference core taken from RTL to routed SKY130HD GDSII and
checked with the ORFS-bundled tools. This is not fabricated silicon and not a
fabrication-ready chip (no pad ring, no foundry or shuttle signoff). Every
number below comes from the listed evidence file. `reports/final_summary.json`
is regenerated from those files by `scripts/summarize.py`.

Evidence type key: **SIM** = zero-delay functional simulation; **STA** =
static timing analysis; **EST** = tool power estimate; **PV** = physical
verification by platform decks; **—** = not available.

## Status

| Item | Result | Type | Evidence |
|---|---|---|---|
| Reference RTL | c6e7fee7040968e4cce95aa7d0394c6f039a247f, unchanged | — | vendor/HDL-SpikingNet-ECG |
| Original baseline | 500 vectors; 95 code-0, 405 code-2, 0 timeouts | SIM | reports/baseline.csv |
| Port-driven RTL | 500/500 exact class, timeout and cycle matches | SIM | reports/core_simulation.log, rtl_predictions.csv |
| Generic synthesized netlist | 500/500 exact matches | SIM | reports/generic_gate_simulation.log |
| SKY130 synthesis netlist (1_2_yosys.v) | 500/500 exact matches | SIM | reports/mapped_gate_simulation.log |
| **Final post-route netlist (6_final.v)** | **500/500 exact matches** | SIM | reports/final_gate_simulation.log, final_gate_predictions.csv |
| Directed protocol bench | PASS on RTL, generic, synthesis and final post-route netlists | SIM | reports/protocol.log, generic_gate_protocol.log, mapped_gate_protocol.log, final_gate_protocol.log |
| Generic synthesis structural check | 0 problems, no inferred latches | — | reports/synthesis.log |
| Post-resizer and final netlist LEC (ORFS) | Circuits IDENTICAL (both) | formal, netlist-to-netlist | physical/logs/.../4_rsz_lec_check.log, 6_final_lec_check.log |
| Setup, TT 25 °C 1.8 V, 40 ns | WNS +29.864 ns, TNS 0 | STA | physical/logs/.../6_report.json, physical/reports/.../6_finish.rpt |
| Hold, same corner | WNS +0.047 ns, TNS 0 | STA | same |
| Max slew / cap / fanout | 0 / 0 / 0 violations | STA | 6_report.json |
| Detailed routing | 0 violations after final iteration | PV (router) | physical/logs/.../5_2_route.log |
| Antenna | 0 net, 0 pin violations at final check | PV (OpenROAD) | 5_1_grt.log, 5_2_route.log |
| KLayout DRC | 0 violations; BEOL + off-grid/angle sections only | PV | physical/reports/.../6_drc_count.rpt, 6_drc.lyrdb, physical/logs/.../6_drc.log |
| KLayout LVS | "Congratulations! Netlists match." | PV | physical/logs/.../6_lvs.log, reports/lvs_driver.log |
| Routed GDS | 6_final.gds, top cell ecg_snn_core, 609.36 × 609.36 µm | — | physical/results/.../6_final.gds, reports/gds_inspection.json |
| Power, 20-vector workload | 5.7426 mW average | EST | reports/power_activity.json |
| Power, clock-running idle | 5.6756 mW average | EST | reports/power_idle.json |
| Accuracy / F1 | Not computable: no labels or provenance | — | docs/RTL_AUDIT.md |

`physical/logs/...` stands for `physical/logs/sky130hd/ecg_snn_core/base/`
(same pattern for `reports` and `results`).

## Functional verification

All four netlist levels reproduce the original RTL's class, timeout flag and
RUN cycle count for every one of the 500 supplied vectors. tb_core also checks
that an early start is rejected, writes and starts while busy are ignored,
done is a single-cycle pulse, and reset abandons a partial beat. The separate
directed bench (tb_protocol) covers timeout (30,013 RUN clocks), excess
writes, period zero, consecutive determinism, reset during RUN and a stale
start after reset. Its final-netlist run finished at the same simulation time
(2,460,021 ns) as the synthesis-netlist run.

The final-netlist protocol run executed on a separate Ubuntu host with the same
Icarus 12.0 release. The input hashes match the project copies; see
`reports/final_gate_protocol_provenance.txt`. All other simulations ran on
the WSL2 host.

These are zero-delay functional simulations with cell functions generated from
the TT Liberty (`build/sky130hd_sim.v`). There is no SDF-annotated timing
simulation. The ORFS LEC compares gate netlists before and after
resizing/finishing; it is not an RTL-to-gate equivalence proof. The 500
vectors exercise only classes 0 and 2 and no natural timeouts.

| RUN cycles (500 vectors) | min 19 · mean 281.628 · max 15,017 |
|---|---|
| RUN latency at 25 MHz | min 0.76 µs · mean 11.265 µs · max 600.68 µs |
| Input loading | 256 accepted clocks = 10.24 µs at 25 MHz; host pauses add time |
| Preparation | One PREP edge after accepted start, before the first RUN edge |

## Static timing

The corner is sky130_fd_sc_hd tt_025C_1v80 only. Parasitics were extracted
with OpenRCX (`rcx_patterns.rules`), the SDC is `flow/constraint.sdc` and the
clock is 40 ns.

- Setup WNS +29.864 ns. The 0.4 ns clock uncertainty is included in the slack.
  OpenSTA reports a single-corner minimum period of 10.14 ns (98.66 MHz). This
  is not a supported operating frequency: no other corner or the I/O budget
  was analysed at that period.
- Hold WNS **+0.047 ns** (endpoint `network.neuron_hid0.enable`, includes 0.4 ns
  uncertainty). The margin is small. The fast corner (ff, low temperature, high
  voltage) is the usual hold-limiting case and was **not** analysed.
- Clock tree: 444 clock buffers, 124 clock inverters, setup skew 0.44 ns.
- I/O constraints (4 ns max / 0.5 ns min, 10 fF loads) are assumptions, not
  measurements of a host.

## Physical implementation

| Metric | Value |
|---|---|
| Die | 609.36 × 609.36 µm (371,320 µm²) |
| Core | 588.80 × 587.52 µm (345,932 µm²) |
| Standard cells excluding fillers | 16,632 = 12,044 logic + 4,578 taps + 10 antenna diodes |
| Their area | 137,480.6 µm² |
| Utilization excluding fillers | 39.742 % |
| Filler/decap instances | 32,690 (208,451 µm²) |
| Total instances | 49,322 |
| Sequential cells | 2,625 |
| Synthesis area before physical optimization | 121,571.5968 µm² |
| Routed wire | 347,750 µm (met1 156,499; met2 157,730; met3 21,073; met4 12,447; met5 0) |
| Vias | 87,833 |
| ORFS flow warnings / errors | 0 / 0 |

Sources: `reports/physical_geometry.txt` (counted from 6_final.odb),
`6_report.json`, `5_2_route.log`, `synth_stat.txt`.

## Physical verification coverage

**Antenna.** After global routing the router reported 23 violations. It
inserted 50 jumpers on 22 nets, leaving 1 violation, which 1 diode cleared.
After detailed routing it found 8 new violations and inserted 9 diodes. An
incremental re-route ended at 0 DRC violations, and the final `check_antennas`
reports 0 net and 0 pin violations. The final layout has 10 antenna cells
(1 + 9). This check uses OpenROAD and the platform's LEF antenna rules; the
KLayout deck has no antenna section.

**DRC.** `sky130hd.lydrc` ran with `FEOL = false`, `BEOL = true` and
`OFFGRID = true` (see the deck header and the section markers in 6_drc.log).
Zero violations covers metal/via width, spacing and enclosure from li1 to
met5, plus manufacturing-grid and angle checks. It does **not** cover:

- front-end (well, diffusion, poly, implant) rules;
- density or fill rules;
- latch-up and seal ring checks;
- the full foundry Magic or KLayout signoff decks.

Front-end geometry comes from unmodified sky130_fd_sc_hd cells, which reduces
but does not remove this gap.

**LVS.** The KLayout `sky130hd.lylvs` deck extracts a device netlist from
6_final.gds and compares it with 6_final.cdl, which is generated from the
final Verilog netlist. Result: match. This confirms layout connectivity
against the post-route netlist. It does not check function; that comes from
the simulations above.

## Power and energy estimates (not measurements)

Conditions: OpenSTA `report_power` on 6_final.odb, TT 25 °C 1.8 V Liberty,
6_final.sdc (25 MHz) and the extracted 6_final.spef. Activity comes from
zero-delay Icarus VCDs, so glitch power is not modelled.

The activity VCDs were simulated on the **synthesis netlist (1_2_yosys.v)**,
not the final netlist, and annotated by name onto the routed design. 40,853
pins were annotated and 1,482 were not. That count is comparable to the
signal pins of cells added after synthesis: 444 clock buffers, 124 clock inverters, 220
repair buffers and 10 diodes give about 1,580 signal pins. A per-pin list was
not produced. Their activity is the
tool's default/propagated estimate, not the VCD. Clock-net activity follows the
SDC clock. To regenerate from 6_final.v, set `ACT_NETLIST` in
`scripts/activity_power.sh`; that run has not been done.

| Window | Duration | Internal | Switching | Leakage | Total |
|---|---|---|---|---|---|
| 20-vector workload | 628.861 µs | 4.5712 mW | 1.1713 mW | 49.44 nW | **5.7426 mW** |
| Clock-running idle (full buffer, start low) | 100.000 µs | 4.5464 mW | 1.1291 mW | 49.22 nW | **5.6756 mW** |
| Vectorless (default activity) | — | 4.5689 mW | 1.1627 mW | 49.86 nW | 5.7316 mW |

**What is in the 628.861 µs window** (15,721.5 clocks at 40 ns): reset, a
rejected early start, then 20 supplied vectors, each with 256 load clocks,
start and PREP, three rejected write/start clocks while busy, and RUN to done.
It ends with a reset during a partial load. Split: loading 5,120 clocks
(32.6 %), RUN 10,533 clocks (67.0 %), other ≈ 68 clocks (0.4 %). One vector
(index 3) runs 10,014 clocks, which is 63.7 % of the window. The window
therefore over-represents long inferences relative to the 500-vector mean of
281.6 RUN clocks.

**Energy for this exact window** (average power × duration):

- Total: 5.742569 mW × 628.861 µs = **3.611 µJ**, or 180.6 nJ per vector
  averaged over this window. This includes clock-tree and loading energy.
- The same duration in clock-running idle: 3.569 µJ.
- Increment over clock-on idle: 66.99 µW × 628.861 µs = **42.1 nJ**
  (2.11 nJ per vector on average). This is a difference of two estimates,
  using a different idle state; treat it as an order-of-magnitude figure.
- Leakage over the window: 0.031 nJ, which is negligible.

**Interpretation.** The clock network (2.776 mW, 48.3 %) and flip-flop internal
power (2.918 mW, mostly clock-pin toggling of the 2,625 flops) account for
about 99 % of the total. Clock-on idle is 98.8 % of workload power. There is
no clock gating or power gating, so **idle is not leakage-only**: an idle,
clocked core still draws about 5.7 mW at 25 MHz in this estimate. Clock gating
is the dominant optimisation opportunity.

These numbers are not comparable with the paper's 1.78 µJ/beat. That figure is
an event-cost estimate for a different model and evaluation. No silicon power
has been measured.

## Layout images

| File | Content |
|---|---|
| reports/layout_full_readable.png | Whole die; met1–met3 routing; met4 (PDN straps plus signal) and met5 (PDN only) drawn as outlines; 100 µm scale bar |
| reports/layout_closeup_readable.png | 24 × 16 µm window at (292.7, 296.5) µm; nwell, diff, tap, poly, licon, li1, mcon, met1, via, met2 and cell boundaries; 2 µm scale bar |
| reports/layout_full.png, layout_closeup.png | Earlier all-layer default renders, kept as raw evidence |

Readable views come from `scripts/layout_images_readable.py` (KLayout Python
module 0.30.13). Only display properties change; the GDS is read-only. The
region rendered is recorded in `reports/layout_images_readable.json`.

## Clock-gated variant (cg): in progress

Two SKY130 integrated clock gates stop the clock to the input storage outside
load writes, and to the rest of the network outside reset, PREP and RUN
(docs/CLOCK_GATING.md). The baseline above is unchanged.

| Check | Status | Evidence |
|---|---|---|
| RTL: 500 vectors, protocol, idle | PASS; predictions byte-identical to baseline.csv | reports/cg/ |
| Yosys 0.33 SKY130 mapping + gate simulation (sanity check, not ORFS) | PASS; 2 ICGs, 2,624 flip-flops | reports/cg/precheck/ |
| ORFS implementation, timing, DRC/LVS | **pending** (scripts/run_physical_cg.sh) | physical/*/cg/ |
| Post-route netlist regression | **pending** (scripts/verify_cg.sh) | reports/cg/final_gate_* |
| Power, base vs cg on final netlists | **pending** (scripts/activity_power_variant.sh) | reports/cg/comparison.md |

No power, timing or area result is claimed for cg until those files exist.

## Limitations and negative findings

- Supplied inputs are six-bit; the RTL keeps the low four bits. 125,332 of
  128,000 values exceed 15 and 1,793 become period zero. This is preserved
  deliberately for compatibility and is not validated preprocessing.
- No labels, patient provenance or authoritative class-name mapping were
  supplied. Baseline agreement is not accuracy. The paper's 97.9 % accuracy,
  88.0 % F1 and 1.78 µJ/beat are not claimed for this hardware, and the
  released RTL differs from the paper's model (docs/RTL_AUDIT.md).
- Timing covers one TT corner. Hold margin is 47 ps at TT, and the fast
  corner has not been checked.
- DRC ran without FEOL, density or antenna deck sections. This is not foundry
  signoff.
- Power is a tool estimate from zero-delay activity on the synthesis netlist,
  with 1,482 unannotated pins.
- There is no SDF simulation and no RTL-to-gate formal equivalence.
- There is no pad ring, analog acquisition, on-chip training or fabricated
  chip.

## Reproduction

Run from Ubuntu/WSL2 in the project root:

```bash
bash scripts/verify.sh            # baseline, RTL, generic netlist + protocol
sudo bash scripts/run_physical.sh # ORFS flow (long; not needed to inspect results)
sudo bash scripts/physical_checks.sh   # KLayout DRC + LVS
bash scripts/verify_mapped.sh     # synthesis netlist, 500 vectors + protocol
bash scripts/verify_final.sh      # final post-route netlist, 500 vectors + protocol
sudo bash scripts/activity_power.sh    # activity/idle VCDs and OpenSTA power
python3 scripts/layout_images_readable.py   # needs: pip install klayout pillow
python3 scripts/summarize.py      # regenerate final_summary.json
python3 scripts/package.py        # build and check the ZIP
```

The ORFS container is `openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174`.
Its OpenROAD binary reports version "unknown" and the image carries no Git
metadata, so the digest is the reproducible reference. The TT Liberty used for
the cell models matches the container copy after CRLF normalization
(`reports/liberty_hash_check.txt`).
