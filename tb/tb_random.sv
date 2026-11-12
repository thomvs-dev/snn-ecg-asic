`timescale 1ns/1ps
// Pseudo-random protocol stimulus with a cycle-by-cycle output trace.
// Run on two designs with the same +SEED and compare the trace files: equal
// traces show the same port behaviour under irregular load/start/reset timing
// (pauses, early and repeated starts, loads while busy, resets in any state).
// Zero-delay simulation; not a formal equivalence proof.
module tb_random;
reg clk=0; always #20 clk=~clk;
reg reset=1, load_valid=0, start=0;
reg [3:0] load_data=0;
wire load_ready, busy, done, no_spike, input_complete;
wire [1:0] result_class;
wire [15:0] inference_cycles;
ecg_snn_core dut(.*);
reg [5:0] vectors[0:127999];
integer seed=1, seed0, cycles=400000, fd, n, r, ptr=0, beats=0, resets=0, lv_density=50;
reg [1023:0] trace_file="build/random_trace.txt";
always @(posedge clk) if(done) beats=beats+1;
initial begin
 if($value$plusargs("SEED=%d",seed)) begin end
 seed0=seed;
 if($value$plusargs("CYCLES=%d",cycles)) begin end
 if($value$plusargs("TRACE_FILE=%s",trace_file)) begin end
 $readmemh("vendor/HDL-SpikingNet-ECG/hex_files/input_data.hex",vectors);
 fd=$fopen(trace_file,"w");
 repeat(3) @(negedge clk);
 reset=0;
 for(n=0;n<cycles;n=n+1) begin
   // Inputs change on the falling edge; outputs are sampled just before it.
   r=$random(seed);
   if(r[9:0]==0) begin r=$random(seed); lv_density=$unsigned(r[15:0]) % 101; r=$random(seed); end  // new load duty cycle now and then
   load_valid = ($unsigned(r[16:10]) % 100) < lv_density;
   load_data  = vectors[ptr % 128000][3:0];
   if(load_valid && load_ready) ptr=ptr+1;
   start      = (r[19:17]==0);                               // 1 in 8, in any state
   reset      = (r[31:20]==0);                               // 1 in 4096, in any state
   if(reset) resets=resets+1;
   @(negedge clk);
   $fwrite(fd,"%b%b%b%b%b %0d %0d\n",load_ready,input_complete,busy,done,no_spike,result_class,inference_cycles);
 end
 $fclose(fd);
 $display("DONE random: seed=%0d cycles=%0d beats=%0d resets=%0d",seed0,cycles,beats,resets);
 $finish;
end
endmodule
