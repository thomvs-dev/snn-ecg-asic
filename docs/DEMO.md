# Professor demonstration

1. Open README.md and explain the diagram: off-chip periods enter through a
   real ready/valid port, become pending spikes, select constant weights, and
   accumulate in threshold neurons. The final decision is first-spike or timeout.
2. Show rtl/ecg_snn_core.v. Point out that input data is written on an accepted
   load edge, not through testbench hierarchy. Show the generated constant
   ROM cases in rtl/hidden_neuron.v, and their source hex file hashes.
3. Run `bash scripts/verify.sh` from Ubuntu. Show the 500-vector PASS and the
   separate protocol PASS. Compare reports/baseline.csv with
   reports/rtl_predictions.csv and reports/generic_gate_predictions.csv.
4. Open reports/first_beat_waveform.png or the VCD in GTKWave. Beat 0 returns
   class 2 after 24 RUN clocks (0.96 us at 25 MHz). Loading takes 256 accepted
   clocks (10.24 us); one PREP edge is additional. The waveform includes
   deliberately invalid load/start assertions while busy to test rejection.
5. Explain that synthesis turns Verilog storage and equations into gates.
   Generic synthesis is an intermediate check; the SKY130 netlist and the
   routed layout are the physical implementation evidence. Show
   reports/final_gate_simulation.log and final_gate_protocol.log: the
   **post-route** netlist still gives 500/500 matches and passes the protocol bench.
6. Show reports/layout_full_readable.png (whole 609 µm die: met1–met3 signal
   routing, met4/met5 power grid as outlines). Then show
   layout_closeup_readable.png: a 24 × 16 µm window where individual cells are
   visible as poly gates (red), local interconnect (purple), met1 rails and
   wires (blue) and vias (yellow). Optionally open
   physical/results/sky130hd/ecg_snn_core/base/6_final.gds in KLayout with the
   sky130hd layer file.
7. Walk through the status table in reports/RESULTS.md: timing (setup +29.86 ns,
   hold +0.047 ns, TT only), DRC 0 with its coverage limits, LVS match, antenna
   repair history, then power. A layout is not manufactured silicon.
8. Power: 5.74 mW over the 20-vector, 628.861 µs window, giving 3.61 µJ. The
   clock-on idle estimate is 5.68 mW. Point out that about 99 % is clock tree
   plus flip-flop clock pins, so the next design step would be clock gating.

## Questions to be ready for

- **Why no training circuit?** The initial scope freezes pretrained weights.
  Training hardware would substantially increase storage, arithmetic and verification.
- **Why ROM gates?** Only 2096 bytes of constant weights are needed; synthesis
  can simplify fixed values. Input periods and neuron state remain registers.
- **What does class 2 mean?** It is the upstream numeric class. The released
  files do not establish its disease-name mapping.
- **Did you achieve 97.9% accuracy?** No such claim is supported. We compare
  against reference RTL, not labelled patient data. The paper's metrics are
  from a different, patient-specific software evaluation.
- **Is the input encoding validated?** No. This compatibility implementation
  preserves the upstream six-to-four-bit truncation. Correcting the exporter
  and reevaluating labelled data is important future work.
- **Is it ready for fabrication?** No pad ring, board, shuttle review or
  foundry signoff is included. Check the documented DRC/LVS coverage and timing.
- **How is energy calculated?** Average estimated power over a stated window
  times its duration: 5.742569 mW × 628.861 µs = 3.611 µJ for 20 vectors,
  including loading (32.6 % of clocks), RUN (67.0 %) and the always-running
  clock. One long vector dominates that window. Clock-on idle for the same
  duration would be 3.569 µJ, so the activity-dependent part is only about
  42 nJ. Leakage is about 0.03 nJ. This is an OpenSTA estimate from
  zero-delay activity, not a silicon measurement, and it is not comparable
  with the paper's 1.78 µJ/beat.
- **What did clock gating change?** Two ICGs stop the storage and network clocks between beats. In the
  OpenSTA estimate, clock-on idle power drops from 5.68 mW to 0.114 mW and the 20-vector window energy
  from 3.61 to 2.14 µJ, for +3 % cell area. The post-route netlist still matches all 500 vectors.
  See docs/CLOCK_GATING.md.
- **Why was baseline idle power almost as high as active power?** The clock runs and
  2,625 flip-flops toggle their clock pins every cycle. There is no clock
  gating and no power gating, so idle is not leakage-only.
- **Is timing closed?** At the TT 25 °C 1.8 V corner with extracted RC, yes.
  Hold margin is only 47 ps and the fast corner was not analysed, so this is
  not PVT signoff.
- **What did DRC check?** The bundled KLayout deck ran BEOL (metal/via) and
  off-grid/angle rules, with zero violations. Its FEOL section is disabled by
  default, and density and latch-up checks are not covered. Antenna rules were
  checked by OpenROAD after diode insertion. LVS matched the final netlist.
- **Why simulate the post-route netlist?** Placement, CTS, resizing and
  antenna repair edit the netlist. Simulating 6_final.v shows these edits
  preserved function. The ORFS LEC also reports the post-resizer and final
  netlists as identical.
