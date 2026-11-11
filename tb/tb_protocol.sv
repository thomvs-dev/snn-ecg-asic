`timescale 1ns/1ps
module tb_protocol;
reg clk=0; always #20 clk=~clk;
reg reset=1, load_valid=0, start=0;
reg [3:0] load_data=0;
wire load_ready,busy,done,no_spike,input_complete;
wire [1:0] result_class;
wire [15:0] inference_cycles;
ecg_snn_core dut(.*);
integer i, k;
reg [1:0] remembered_class;
reg [15:0] remembered_cycles;
task step; begin @(posedge clk); #1; end endtask
task neg; begin @(negedge clk); end endtask
task load(input [3:0] value);
begin
 for(i=0;i<256;i=i+1) begin
   neg(); if(!load_ready) $fatal(1,"unexpected not-ready");
   load_valid=1; load_data=value; step();
 end
 neg(); load_valid=0;
 if(!input_complete || load_ready) $fatal(1,"full state");
 // Excess writes must be ignored.
 load_valid=1; load_data=0; step(); neg(); load_valid=0;
 start=1; step(); if(!busy) $fatal(1,"start"); neg(); start=0;
end endtask
task finish_beat;
begin
 k=0;
 while(!done && k<30100) begin step(); k=k+1; end
 if(!done || busy || !load_ready) $fatal(1,"completion");
 if((^{result_class,no_spike,inference_cycles})===1'bx) $fatal(1,"unknown");
 step(); if(done) $fatal(1,"done width");
end endtask
initial begin
 repeat(3) step(); neg(); reset=0;
 load(15); finish_beat();
 if(result_class!=3 || !no_spike || inference_cycles!=30013) $fatal(1,"timeout semantics: %d %d %d",result_class,no_spike,inference_cycles);
 load(0); finish_beat(); remembered_class=result_class; remembered_cycles=inference_cycles;
 load(0); finish_beat();
 if(result_class!=remembered_class || inference_cycles!=remembered_cycles) $fatal(1,"consecutive determinism");
 load(15); repeat(100) step(); neg(); reset=1; step();
 if(busy || done || input_complete || inference_cycles!=0) $fatal(1,"abort reset");
 neg(); reset=0; start=1; step(); if(busy) $fatal(1,"stale restart");
 neg(); start=0; load(15); finish_beat();
 if(result_class!=3 || !no_spike || inference_cycles!=30013) $fatal(1,"post-abort timeout");
 $display("PASS protocol: timeout, excess load, period zero, consecutive repeat, reset during RUN, stale start");
 $finish;
end
initial begin #10000000; $fatal(1,"watchdog"); end
endmodule
