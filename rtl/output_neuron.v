// Derived from HDL-SpikingNet-ECG (MIT); see vendor license.
module output_neuron(spike_in, clk, resetn, spike_out, addr_in);
parameter data_bit = 7;
parameter ROM_ID = 0;

input spike_in;
input clk, resetn;
output spike_out;
input [2:0] addr_in;

wire [2:0] ROM_address;
assign ROM_address = addr_in;

wire enable;

wire [data_bit:0] ROM_out;
reg [data_bit:0] IF_in;

IF_neuron_out IF0 (.clk(clk), .resetn(resetn), .input_current(IF_in), .spike(spike_out));
defparam IF0.n_bit = data_bit;

ROMFile_out #(.ROM_ID(ROM_ID)) ROM0 (.address(ROM_address), .data(ROM_out), .read_en(enable));
defparam ROM0.n_bit = data_bit;

assign enable = spike_in;

always @ ( posedge clk ) begin
  if (resetn) IF_in <= 0; else IF_in <= ROM_out;
end

endmodule



module ROMFile_out #(parameter n_bit=7, parameter ROM_ID=0)(input [2:0] address, output [n_bit:0] data, input read_en);
reg [7:0] value;
assign data = read_en ? value : 8'd0;
always @* begin
value=0;
case (ROM_ID)
0: begin case(address)
3'd0: value=8'h0a;
3'd1: value=8'h0f;
3'd2: value=8'h37;
3'd3: value=8'h33;
3'd4: value=8'h0d;
3'd5: value=8'h03;
3'd6: value=8'h14;
3'd7: value=8'h34;
default: value=0;
endcase end
1: begin case(address)
3'd0: value=8'h13;
3'd1: value=8'h14;
3'd2: value=8'h0f;
3'd3: value=8'h0f;
3'd4: value=8'h0a;
3'd5: value=8'h12;
3'd6: value=8'h11;
3'd7: value=8'h16;
default: value=0;
endcase end
2: begin case(address)
3'd0: value=8'h0d;
3'd1: value=8'h0e;
3'd2: value=8'h10;
3'd3: value=8'h09;
3'd4: value=8'h09;
3'd5: value=8'h08;
3'd6: value=8'h17;
3'd7: value=8'h11;
default: value=0;
endcase end
3: begin case(address)
3'd0: value=8'h10;
3'd1: value=8'h14;
3'd2: value=8'h0b;
3'd3: value=8'h13;
3'd4: value=8'h15;
3'd5: value=8'h12;
3'd6: value=8'h09;
3'd7: value=8'h16;
default: value=0;
endcase end
4: begin case(address)
3'd0: value=8'h10;
3'd1: value=8'h0d;
3'd2: value=8'h0d;
3'd3: value=8'h0f;
3'd4: value=8'h10;
3'd5: value=8'h12;
3'd6: value=8'h0b;
3'd7: value=8'h14;
default: value=0;
endcase end
5: begin case(address)
3'd0: value=8'h60;
3'd1: value=8'h17;
3'd2: value=8'h0c;
3'd3: value=8'h0b;
3'd4: value=8'h5d;
3'd5: value=8'h3b;
3'd6: value=8'h2c;
3'd7: value=8'h07;
default: value=0;
endcase end
default: value=0;
endcase
end
endmodule



module IF_neuron_out(clk, resetn, input_current, spike);
parameter n_bit = 7;
parameter theta = 10'b001110000;
parameter max_bit = 10;

input clk, resetn;
input [n_bit:0]input_current;
output spike;

wire [max_bit:0] add_out;
wire overflow;
reg [max_bit:0] membrane_potential;
wire threshold_enable;

assign {overflow,add_out} = resetn ? 0 : (membrane_potential + input_current);
assign spike = (membrane_potential > theta);

always@(posedge clk) begin
    if (resetn | spike) begin
      membrane_potential <= 0;
    end
    else
      membrane_potential <= add_out;
end

endmodule
