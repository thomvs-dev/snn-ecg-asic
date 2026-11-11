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

- [ ] Fast/slow corner STA (hold margin is 47 ps at TT).
- [ ] Power activity simulated on 6_final.v (ACT_NETLIST option) to remove the 1,482 unannotated pins.
- [ ] Full FEOL/density DRC with a foundry signoff deck.
- [ ] SDF-annotated gate simulation.
- [ ] Labelled data and corrected six-bit input encoding before any accuracy claim.
- [x] Clock-gated variant: RTL + mapped-netlist verification (docs/CLOCK_GATING.md).
- [ ] Clock-gated variant: ORFS run, post-route regression, power comparison (scripts/run_physical_cg.sh, verify_cg.sh, activity_power_variant.sh).
