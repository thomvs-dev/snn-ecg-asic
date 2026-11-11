`timescale 1ns/1ps
// Same stimulus as tb/tb_idle.sv; the VCD path is a plusarg so runs for
// different variants do not overwrite reports/idle_activity.vcd.
module tb_idle;
reg clk=0; always #20 clk=~clk;
reg reset=1,load_valid=0,start=0;
reg [3:0] load_data=1;
wire load_ready,busy,done,no_spike,input_complete;
wire [1:0] result_class;
wire [15:0] inference_cycles;
ecg_snn_core dut(.*);
integer i;
reg [1023:0] vcd_file="reports/idle_activity_variant.vcd";
initial begin
 if($value$plusargs("VCD_FILE=%s",vcd_file)) begin end
 repeat(4) @(negedge clk);
 reset=0;
 for(i=0;i<256;i=i+1) begin
  load_valid=1; @(negedge clk);
 end
 load_valid=0;
 repeat(4) @(negedge clk);
 $dumpfile(vcd_file); $dumpvars(0,dut);
 repeat(2500) @(negedge clk);
 if(busy || done || !input_complete) $fatal(1,"idle state");
 $display("PASS 100 us idle window, clock running, full valid input buffer, start low");
 $finish;
end
endmodule
