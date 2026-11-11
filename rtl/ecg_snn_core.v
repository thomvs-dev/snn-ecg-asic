// MIT; wrapper for the upstream ECG SNN. All reset signals are active HIGH.
module ecg_snn_core(
 input wire clk, reset,
 input wire load_valid,
 input wire [3:0] load_data,
 output wire load_ready,
 input wire start,
 output reg busy, done,
 output reg [1:0] result_class,
 output reg no_spike,
 output wire input_complete,
 output reg [15:0] inference_cycles
);
 reg [8:0] loaded;
 reg [1:0] state;
 localparam IDLE=0, PREP=1, RUN=2;
 wire [1:0] network_class;
 wire network_end, network_no_spike;
 wire network_reset = reset || state != RUN;
 assign load_ready = !reset && state == IDLE && loaded < 256;
 assign input_complete = loaded == 256;
 snn_network network(.clk(clk), .resetn(network_reset),
   .load_valid(load_valid && load_ready), .load_addr(loaded[7:0]), .load_data(load_data),
   .output_class(network_class), .no_spike(network_no_spike), .end_process(network_end));
 always @(posedge clk) begin
   if (reset) begin
     loaded <= 0; state <= IDLE; busy <= 0; done <= 0;
     result_class <= 3; no_spike <= 0; inference_cycles <= 0;
   end else begin
     done <= 0;
     case(state)
       IDLE: begin
         if (load_valid && load_ready) loaded <= loaded + 1'b1;
         if (start && input_complete) begin state <= PREP; busy <= 1; inference_cycles <= 0; end
       end
       // One explicit preparation edge after the final input write.
       PREP: state <= RUN;
       RUN: begin
         inference_cycles <= inference_cycles + 1'b1;
         if(network_end) begin
           result_class <= network_class; no_spike <= network_no_spike;
           done <= 1; busy <= 0; state <= IDLE; loaded <= 0;
         end
       end
       default: begin state <= IDLE; busy <= 0; loaded <= 0; end
     endcase
   end
 end
endmodule
