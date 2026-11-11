from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'vendor/HDL-SpikingNet-ECG/tb__top.v').read_text()
# Icarus does not start the self-triggered always @(clk) oscillator from a
# declaration initializer. Use the same intended 1000 ns period explicitly.
s=s.replace('always @(clk)\n      clk <= #500 ~clk;', 'always #500 clk = ~clk;')
# Keep original stimulus, event scheduling and reset. Only add observations.
s=s.replace('integer k, num;', 'integer k, num;\n    integer ticks=0, active_ticks=0, trace;\n    always @(negedge clk) begin\n      ticks=ticks+1;\n      if(reset) active_ticks=0; else active_ticks=active_ticks+1;\n    end')
s=s.replace('file=$fopen("DataOut.txt", "w");', 'file=$fopen("../../reports/original_predictions.txt", "w");\n      trace=$fopen("../../reports/baseline.csv", "w");\n      $fwrite(trace,"vector,class,no_spike,cycles\\n");')
s=s.replace('      num = 0;', '      $dumpfile("../../reports/baseline_first_beat.vcd"); $dumpvars(1,snn__tb); $dumpvars(1,uut);\n      num = 0;')
s=s.replace('num = num +1;', 'num = num +1;\n        if(num==1) $dumpoff;')
s=s.replace('if(end_process == 1) begin', 'if(end_process == 1) begin\n        $fwrite(trace,"%0d,%0d,%0d,%0d\\n",num,output_class,no_spike,active_ticks);')
s=s.replace('mean_time/num', 'mean_time/(num+1)') # fix reporting-only divide by zero
s=s.replace('    top uut', '    initial begin #20000000000; $fatal(1,"baseline watchdog"); end\n    top uut')
(root/'tb/original_instrumented.v').write_text(s)
