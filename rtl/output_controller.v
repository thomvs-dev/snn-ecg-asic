// Derived from HDL-SpikingNet-ECG (MIT); see vendor license.
module output_controller(resetn, clk, spikes_in, acks_out, addr_out, spike_out);
input clk, resetn;
input [7:0] spikes_in;
output reg [7:0] acks_out;
output reg [2:0] addr_out;
output reg spike_out;

reg [2:0] addr_out_D;
wire spike_out_D;

assign spike_out_D = |spikes_in;

always @ ( posedge clk ) begin
  if (resetn) begin spike_out <= 0; addr_out <= 0; end
  else begin spike_out <= spike_out_D; addr_out <= addr_out_D; end
end

always@(*) begin
    casez (spikes_in)
      8'b????_???1 : begin
          addr_out_D = 0;
          acks_out = 8'h01;
          end
      8'b????_??10 : begin
          addr_out_D = 1;
          acks_out = 8'h02;
          end
      8'b????_?100 : begin
          addr_out_D = 2;
          acks_out = 8'h04;
          end
      8'b????_1000 : begin
          addr_out_D = 3;
          acks_out = 8'h08;
          end
      8'b???1_0000 : begin
          addr_out_D = 4;
          acks_out = 8'h10;
          end
      8'b??10_0000 : begin
          addr_out_D = 5;
          acks_out = 8'h20;
          end
      8'b?100_0000 : begin
          addr_out_D = 6;
          acks_out = 8'h40;
          end
      8'b1000_0000 : begin
          addr_out_D = 7;
          acks_out = 8'h80;
          end
      default : begin
          addr_out_D = 0;
          acks_out = 8'h00;
          end
    endcase
end

endmodule
