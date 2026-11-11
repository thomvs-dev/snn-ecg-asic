# Third-party material in this package

| Material | Where | Licence / note |
|---|---|---|
| HDL-SpikingNet-ECG RTL, weights and input vectors (A. Amirshahi), commit `c6e7fee7040968e4cce95aa7d0394c6f039a247f` | `vendor/HDL-SpikingNet-ECG/` | MIT, see `vendor/HDL-SpikingNet-ECG/LICENSE` |
| SkyWater SKY130 `sky130_fd_sc_hd` standard-cell geometry, LEF and Liberty data, as instantiated in the routed outputs and in `build/sky130hd_sim.v` (generated from the TT Liberty) | `physical/results/...`, `build/sky130hd_sim.v` | Apache-2.0 (SkyWater PDK) |
| OpenROAD-flow-scripts platform scripts, DRC/LVS decks and flow logs | used from the ORFS container; logs in `physical/logs`, `physical/reports` | BSD-3-Clause (ORFS); platform files keep their upstream licences |
| Local wrapper, generators, testbenches and scripts | `rtl/ecg_snn_core.v`, `scripts/`, `tb/`, `flow/` | MIT, see `LICENSE` |

Not included: installed tools, the ORFS checkout in `tools/`, the IEEE paper
(DOI 10.1109/TBCAS.2019.2948920) and text or images extracted from it.
Cite the paper separately; do not redistribute it with this package.
