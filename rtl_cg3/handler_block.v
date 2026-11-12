// Derived from HDL-SpikingNet-ECG (MIT); see vendor license.
module handler_block(spikes_in, ack_in, spike_out, address, acks_out);
input [15:0] spikes_in;
input ack_in;
output wire spike_out;
output reg [3:0] address;
output reg [15:0] acks_out;

assign spike_out = (|spikes_in);

wire [15:0] ack16;
assign ack16 = {16{ack_in}};


always@(*) begin
    casez (spikes_in)
      16'b????_????_????_???1 : begin
          address = 0;
          acks_out = (16'h0001 & ack16);
          end
      16'b????_????_????_??10 : begin
          address = 1;
          acks_out = (16'h0002 & ack16);
          end
      16'b????_????_????_?100 : begin
          address = 2;
          acks_out = (16'h0004 & ack16);
          end
      16'b????_????_????_1000 : begin
          address = 3;
          acks_out = (16'h0008 & ack16);
          end
      16'b????_????_???1_0000 : begin
          address = 4;
          acks_out = (16'h0010 & ack16);
          end
      16'b????_????_??10_0000 : begin
          address = 5;
          acks_out = (16'h0020 & ack16);
          end
      16'b????_????_?100_0000 : begin
          address = 6;
          acks_out = (16'h0040 & ack16);
          end
      16'b????_????_1000_0000 : begin
          address = 7;
          acks_out = (16'h0080 & ack16);
          end
      16'b????_???1_0000_0000 : begin
          address = 8;
          acks_out = (16'h0100 & ack16);
          end
      16'b????_??10_0000_0000 : begin
          address = 9;
          acks_out = (16'h0200 & ack16);
          end
      16'b????_?100_0000_0000 : begin
          address = 10;
          acks_out = (16'h0400 & ack16);
          end
      16'b????_1000_0000_0000 : begin
          address = 11;
          acks_out = (16'h0800 & ack16);
          end
      16'b???1_0000_0000_0000 : begin
          address = 12;
          acks_out = (16'h1000 & ack16);
          end
      16'b??10_0000_0000_0000 : begin
          address = 13;
          acks_out = (16'h2000 & ack16);
          end
      16'b?100_0000_0000_0000 : begin
          address = 14;
          acks_out = (16'h4000 & ack16);
          end
      16'b1000_0000_0000_0000 : begin
          address = 15;
          acks_out = (16'h8000 & ack16);
          end
      default : begin
          address = 0;
          acks_out = (16'h0000 & ack16);
          end
    endcase
end



endmodule
