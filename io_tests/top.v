
`include "../lib/al_cu/io_lcd.v"
`include "../lib/ice40/hex_ascii.v"

module top (
    input clk,
    input rst,
    output [3:0] IO_AN,
    output [7:0] IO_SEG,
    input [4:0] IO_SW,
    output UART_TX,
    input UART_RX
);

  io_lcd io_lcd (
      .clk(clk),
      .rst(rst),
      .i_digit1(value[0]),
      .i_show_digit1(1'b1),
      .i_digit2(value[1]),
      .i_show_digit2(1'b1),
      .i_digit3(value[2]),
      .i_show_digit3(1'b1),
      .i_digit4(value[3]),
      .i_show_digit4(1'b1),
      .o_select(IO_AN),
      .o_segment(IO_SEG)
  );
  reg [ 3:0] value[3:0];
  reg [15:0] num;
  always @(posedge clk) begin
    if (IO_SW[0]) begin
      num <= num + 1;
    end
    value[0] <= num[3:0];
    value[1] <= num[7:4];
    value[2] <= num[11:8];
    value[3] <= num[15:12];
  end


  initial begin
    value[0] = 0;
    value[1] = 0;
    value[2] = 0;
    value[3] = 0;
  end

  manta manta_inst (
      .clk(clk),
      .rst(rst),
      .rx(UART_RX),
      .tx(UART_TX),
      .sw0(IO_SW[0]),
      //.select(IO_AN),
      .val0(value[0]),
      .value(value[0])
  );
endmodule
