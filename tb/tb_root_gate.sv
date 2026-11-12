`timescale 1ns/1ps
// RTL-only check of the root clock gate (rtl_cg3): the gated clocks must be
// static in every idle phase and must wake for load, start, done and reset.
// Uses hierarchical names, so it is not run on netlists.
module tb_root_gate;
reg clk=0; always #20 clk=~clk;
reg reset=1,load_valid=0,start=0;
reg [3:0] load_data=1;
wire load_ready,busy,done,no_spike,input_complete;
wire [1:0] result_class;
wire [15:0] inference_cycles;
ecg_snn_core dut(.*);
integer root_edges=0, load_edges=0, net_edges=0, i, k;
always @(posedge dut.clk_root) root_edges=root_edges+1;
always @(posedge dut.clk_load) load_edges=load_edges+1;
always @(posedge dut.clk_net)  net_edges=net_edges+1;
task idle_must_be_static(input [255:0] what);
begin
 @(negedge clk); root_edges=0; load_edges=0; net_edges=0;
 repeat(2500) @(negedge clk);
 if(root_edges!=0 || load_edges!=0 || net_edges!=0)
   $fatal(1,"%0s: clocks not static: root=%0d load=%0d net=%0d",what,root_edges,load_edges,net_edges);
end endtask
initial begin
 repeat(4) @(negedge clk);
 reset=0;
 idle_must_be_static("after reset, empty buffer");
 // Partial load, then pause: counter and storage must keep their contents.
 for(i=0;i<100;i=i+1) begin load_valid=1; @(negedge clk); end
 load_valid=0;
 idle_must_be_static("partial load");
 if(input_complete || !load_ready) $fatal(1,"partial load state lost");
 root_edges=0; load_edges=0;
 for(i=0;i<156;i=i+1) begin load_valid=1; @(negedge clk); end
 load_valid=0;
 if(root_edges!=156 || load_edges!=156) $fatal(1,"load edges root=%0d load=%0d",root_edges,load_edges);
 if(!input_complete || load_ready) $fatal(1,"full state");
 idle_must_be_static("full buffer, start low");
 // Start wakes the clock; done must pulse for exactly one clock and then the tree stops.
 start=1; @(negedge clk); start=0;
 if(!busy) $fatal(1,"start did not wake the core");
 k=0; while(!done && k<30100) begin @(negedge clk); k=k+1; end
 if(!done) $fatal(1,"no completion");
 @(negedge clk); if(done || busy) $fatal(1,"done not cleared");
 idle_must_be_static("after completion");
 if(done || busy || !load_ready) $fatal(1,"idle state after completion");
 // Reset alone wakes the clock and clears visible state.
 reset=1; @(negedge clk); reset=0;
 if(result_class!=3 || no_spike || inference_cycles!=0) $fatal(1,"reset from stopped clock");
 idle_must_be_static("after reset from idle");
 $display("PASS root clock gate: static in 5 idle phases (2500 clocks each), wakes for load, start, done clear and reset");
 $finish;
end
initial begin #100000000; $fatal(1,"watchdog"); end
endmodule
