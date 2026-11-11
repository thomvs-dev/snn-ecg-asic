`timescale 1ns/1ps
module tb_idle;
reg clk=0; always #20 clk=~clk;
reg reset=1,load_valid=0,start=0;
reg [3:0] load_data=1;
wire load_ready,busy,done,no_spike,input_complete;
wire [1:0] result_class;
wire [15:0] inference_cycles;
ecg_snn_core dut(.*);
integer i;
initial begin
 repeat(4) @(negedge clk);
 reset=0;
 for(i=0;i<256;i=i+1) begin
  load_valid=1; @(negedge clk);
 end
 load_valid=0;
 repeat(4) @(negedge clk);
 $dumpfile("reports/idle_activity.vcd"); $dumpvars(0,dut);
 repeat(2500) @(negedge clk);
 if(busy || done || !input_complete) $fatal(1,"idle state");
 $display("PASS 100 us idle window, clock running, full valid input buffer, start low");
 $finish;
end
endmodule
