// Simulation model of sky130_fd_sc_hd__dlclkp_{1,2,4} for gate-level runs.
// Function from the TT Liberty: latch_posedge integrated clock gate,
// GCLK = CLK & M0, M0 = GATE latched while CLK is low.
// build/sky130hd_sim.v (yosys read_liberty) omits latch-based cells.
`define ICG_MODEL(name) \
module name(input CLK, input GATE, output GCLK); \
  reg m0; \
  always @* if (!CLK) m0 = GATE; \
  assign GCLK = CLK & m0; \
endmodule
`ICG_MODEL(sky130_fd_sc_hd__dlclkp_1)
`ICG_MODEL(sky130_fd_sc_hd__dlclkp_2)
`ICG_MODEL(sky130_fd_sc_hd__dlclkp_4)
