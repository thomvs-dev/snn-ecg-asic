`timescale 1ns/1ps
module tb_core;
reg clk=0; always #20 clk=~clk;
reg reset=1, load_valid=0, start=0;
reg [3:0] load_data=0;
wire load_ready, busy, done, no_spike, input_complete;
wire [1:0] result_class;
wire [15:0] inference_cycles;
ecg_snn_core dut(.*);
reg [5:0] vectors[0:127999];
integer fd, logfd, rc, id, cls, ns, cyc, n, j, elapsed, tested=0;
reg [1023:0] header;
integer count=500;
reg activity=0;
reg [1023:0] pred_file="reports/core_predictions.csv";
reg [1023:0] vcd_file="reports/core_first_beat.vcd";
task step; begin @(posedge clk); #1; end endtask
task tick; begin @(negedge clk); end endtask
task submit(input integer beat);
begin
 for(j=0;j<256;j=j+1) begin
   tick(); if(!load_ready) $fatal(1,"load backpressure at %d",j);
   load_valid=1; load_data=vectors[beat*256+j][3:0]; step();
 end
 tick(); load_valid=0;
 if(!input_complete || load_ready) $fatal(1,"incorrect full state");
 start=1; step();
 if(!busy) $fatal(1,"start not accepted");
 tick(); start=0;
 // Writes and starts while busy must not disturb the in-flight beat.
 load_valid=1; load_data=0; start=1;
 repeat(3) step();
 tick(); load_valid=0; start=0;
 elapsed=0;
 while(!done && elapsed<30100) begin step(); elapsed=elapsed+1; end
 if(!done || busy || !load_ready) $fatal(1,"completion protocol failure");
 if((^{result_class,no_spike,inference_cycles}) === 1'bx) $fatal(1,"unknown result");
end endtask
initial begin
 if($value$plusargs("COUNT=%d",count)) begin end
 activity=$test$plusargs("ACTIVITY");
 if($value$plusargs("PRED_FILE=%s",pred_file)) begin end
 if($value$plusargs("VCD_FILE=%s",vcd_file)) begin end
 $readmemh("vendor/HDL-SpikingNet-ECG/hex_files/input_data.hex",vectors);
 fd=$fopen("reports/baseline.csv","r");
 if(!fd) $fatal(1,"missing baseline");
 rc=$fgets(header,fd);
 logfd=$fopen(pred_file,"w");
 $fwrite(logfd,"vector,class,no_spike,cycles\n");
 $dumpfile(vcd_file);
 if(activity) $dumpvars(0,dut); else $dumpvars(1,tb_core);
 repeat(4) step(); tick(); reset=0;
 // Early start must be ignored.
 start=1; step(); if(busy || done) $fatal(1,"early start accepted");
 tick(); start=0;
 for(n=0;n<count;n=n+1) begin
   rc=$fscanf(fd,"%d,%d,%d,%d\n",id,cls,ns,cyc);
   if(rc!=4 || id!=n) $fatal(1,"bad baseline row");
   submit(n);
   if(result_class!==cls[1:0] || no_spike!==ns[0] || inference_cycles!==cyc[15:0])
     $fatal(1,"mismatch vector %d: got %d/%d/%d expected %d/%d/%d",n,result_class,no_spike,inference_cycles,cls,ns,cyc);
   $fwrite(logfd,"%0d,%0d,%0d,%0d\n",n,result_class,no_spike,inference_cycles);
   tested=tested+1;
   step(); if(done) $fatal(1,"done must pulse for one cycle");
   if(n==0 && !activity) $dumpoff;
 end
 // Reset abandons a partially loaded beat and clears visible result state.
 tick(); load_valid=1; load_data=15; step(); tick(); reset=1; step();
 if(busy || done || input_complete || result_class!=3) $fatal(1,"reset failed");
 tick(); reset=0; load_valid=0; start=1; step();
 if(busy) $fatal(1,"reset did not invalidate partial beat");
 $display("PASS vectors=%0d mismatches=0 protocol_checks=pass",tested);
 $finish;
end
initial begin #1000000000; $fatal(1,"watchdog"); end
endmodule
