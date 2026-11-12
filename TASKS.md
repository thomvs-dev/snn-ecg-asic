# ECG SNN implementation checklist

- [x] Read supplied request and prior audit; preserve prior workspace.
- [x] Fetch full upstream RTL at c6e7fee7040968e4cce95aa7d0394c6f039a247f.
- [x] Inspect all original modules and testbench.
- [x] Establish simulation, synthesis, ORFS/SKY130 and layout tools.
- [x] Reproduce original 500-vector baseline and record cycle counts.
- [x] Generate port-driven ASIC RTL, constant weights and defined reset.
- [x] Verify predictions, protocol, reset and consecutive beats.
- [x] Synthesize and verify generic and SKY130-mapped netlists (500 vectors each).
- [x] Produce routed GDSII and inspect it using KLayout renders.
- [x] KLayout platform DRC: zero violations; LVS: netlists match.
- [x] Final post-route logical netlist: 500 vectors, zero mismatches.
- [x] Final post-route netlist: directed protocol bench PASS.
- [x] Consolidate final timing, antenna, physical-check coverage and power results (reports/RESULTS.md, final_summary.json).
- [x] Readable full-die and close-up layout images (scripts/layout_images_readable.py).
- [x] Capture final-netlist, activity/idle and power commands in scripts (verify_final.sh, activity_power.sh).
- [x] Package evidence, architecture, commands, attribution and limitations (scripts/package.py).

## Open items (not required for the demonstration)

- [x] Fast/slow corner STA: ff hold fails, ss slew/cap fail (reports/signoff_extra/).
- [x] Full-chip DRC with open_pdks mr deck: cg 0, base 2 (m3.6 at pins).
- [x] Power vs clock frequency: cg 4.73 µW at 1 MHz, 1 beat/s.
- [ ] Deferred (2026-11-12): rerun with hold/slew/cap margins and separate hold uncertainty (ff hold, ss slew/cap).
- [x] cg2: evenly spaced pins, denser core (61.6 %, die 494 µm), pin metal on drawing layer; LVS match, 500/500 PASS.
- [x] cg2: npc.2 notch merged; full-chip DRC 0, ORFS DRC 0, LVS match.
- [ ] Power activity simulated on 6_final.v (ACT_NETLIST option) to remove the 1,482 unannotated pins.
- [ ] Density/fill checks.
- [ ] SDF-annotated gate simulation.
- [ ] Labelled data and corrected six-bit input encoding before any accuracy claim.
- [x] Clock-gated variant: RTL + mapped-netlist verification (docs/CLOCK_GATING.md).
- [x] Clock-gated variant: ORFS run, DRC/LVS, post-route regression, power comparison (reports/cg/comparison.md).
- [ ] Stop the root clock when idle (remaining 114 µW is root tree + wrapper).
