# Clock-gated variant (cg)

Purpose: remove the clock-on idle power of the baseline. In the baseline, clock
tree plus flip-flop clock pins are about 99 % of the estimated 5.68 mW drawn
while waiting between beats.

The baseline (`rtl/`, `flow/`, `physical/*/base/`, `reports/power_*`) is kept
unchanged as the verified reference. The gated design is a separate variant:
`rtl_cg/`, `flow_cg/`, ORFS `FLOW_VARIANT=cg`, `reports/cg/`.

## Design

Two SKY130 integrated clock gates (`sky130_fd_sc_hd__dlclkp_1`, latch-based,
glitch-free); see `rtl_cg/ecg_snn_core.v` and `rtl_cg/clock_gate.v`.

| Gate | Clocks | Enable | Clock active |
|---|---|---|---|
| icg_load | 1,024-bit input-period storage | `load_valid && load_ready` | only on accepted load writes (256 per beat) |
| icg_net | all other network flip-flops: input counters and spike bits, arbiters, hidden/output neurons, main timer | `reset \|\| state != IDLE` | reset, PREP and RUN |
| none | wrapper: state, load counter, busy/done, result and cycle registers (~35 flip-flops) | — | always |

Why the outputs are cycle-identical to the baseline:

- Outside RUN, the baseline holds every network flip-flop except `in_period`
  in synchronous reset, and every one of them has a reset term. The PREP edge
  is always clock-enabled, so one edge restores the same reset state (with
  input counters loaded from `in_period`) that the baseline reaches.
- The wrapper only uses network outputs in RUN.
- `in_period` changes only when `load_valid && load_ready`, and that is
  exactly its gate enable.

`rtl_cg/` is generated from `rtl/` by `scripts/generate_rtl_cg.py`. Each edit
is an exact string substitution asserted to match once. The generator
reproduces the committed `rtl_cg/` byte for byte.

## Evidence so far (before ORFS)

| Check | Result | Evidence |
|---|---|---|
| RTL, 500 vectors | PASS, predictions byte-identical to `reports/baseline.csv` | reports/cg/rtl_simulation.log, rtl_predictions.csv |
| RTL protocol bench | PASS, same end time as baseline (2,460,021 ns) | reports/cg/rtl_protocol.log |
| RTL idle window (100 µs) | PASS; gated clocks 0 rising edges vs 2,500 on `clk` | reports/cg/rtl_idle.log |
| Negative control | Enabling the network clock only in RUN (no PREP edge) fails at vector 0 | reports/cg/precheck/PROVENANCE.txt |
| Yosys 0.33 SKY130 mapping | 2,624 flip-flops + 2 ICGs, 0 check problems | reports/cg/precheck/cg_synth_check.log |
| Mapped-netlist gate simulation | 500/500 PASS (byte-identical) and protocol PASS | reports/cg/precheck/ |

The Yosys 0.33 mapping is a sanity check only; the ORFS synthesis inside the
pinned container is the implementation. All checks are zero-delay functional
simulations. There are **no timing, area or power results for cg yet**.

## Remaining steps (WSL2, ORFS container)

```bash
cd /mnt/d/snn
sudo bash scripts/run_physical_cg.sh          # ORFS flow + DRC + LVS -> */cg/  (about as long as the baseline run)
cat reports/cg/icg_check.txt                  # expect ICG count >= 2 in both netlists
bash scripts/verify_cg.sh                     # RTL + cg post-route netlist: 500 vectors + protocol
sudo bash scripts/activity_power_variant.sh cg    # power, activity from cg final netlist
sudo bash scripts/activity_power_variant.sh base  # same method for baseline (fair comparison)
python3 scripts/compare_cg.py                 # reports/cg/comparison.md
```

`activity_power_variant.sh` simulates each variant's **final** netlist, so
clock-tree buffers are annotated from the VCD. The original baseline estimate
annotated a synthesis-netlist VCD with 1,482 unannotated pins. Rerunning
the baseline with the same method gives an apples-to-apples ratio.

## What to check in the ORFS logs

- `4_1_cts.log`: CTS should build separate trees below `icg_load` and
  `icg_net`. A gated net with ~1,024 or ~1,560 sinks left without clock buffers
  would show up as large skew or as max-slew/cap repairs.
- Timing: OpenSTA checks the ICG enable as a clock-gating setup/hold check.
  `load_fire` depends on the `load_valid` and `reset` inputs (4 ns input delay),
  so look at that path in `6_finish.rpt`.
- Hold: the baseline hold margin was 47 ps at TT. The extra ICG insertion
  delay changes skew between gated and ungated flip-flops, especially on paths
  from network outputs to the wrapper.

## Expected effect, stated as expectation, not result

Idle power should fall sharply, because no flip-flop downstream of the gates
toggles its clock pin while idle. What remains is the clock root up to the two
ICGs, about 35 wrapper flip-flops and leakage. Active-window power changes
less: the network is clocked throughout RUN, and loading clocks the storage
for 256 cycles. The ORFS run and `compare_cg.py` give the actual numbers.
