// MIT. Integrated clock gate: SKY130 latch-based ICG (enable latched while
// clk is low, gclk = clk & latched enable), glitch-free by construction.
// Instantiated unconditionally so synthesis never depends on a macro.
// Simulation: add tb/sky130_icg_model.v (behavioural model of this cell).
module clock_gate(input wire clk, input wire en, output wire gclk);
  sky130_fd_sc_hd__dlclkp_1 icg(.CLK(clk), .GATE(en), .GCLK(gclk));
endmodule
