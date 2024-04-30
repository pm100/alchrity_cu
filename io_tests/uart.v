`include "../lib/al_cu/io_lcd.v"
`include "../lib/ice40/uart_rx.v"
`include "../lib/ice40/uart_tx.v"
module uart (
    input clk,
    input rst,
    input UART_RX,
    output UART_TX,
    output [3:0] IO_AN,
    output [7:0] IO_SEG,
    input [4:0] IO_SW
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
  reg [3:0] value[3:0];

  initial begin
    value[0] = 0;
    value[1] = 0;
    value[2] = 0;
    value[3] = 0;
  end

  UART_RX #(
      .CLKS_PER_BIT(217 * 4)
  ) UART_RX_Inst (
      .i_Clock(clk),
      .i_Rst_L(rst),
      .i_RX_Serial(UART_RX),
      .o_RX_DV(w_RX_DV),
      .o_RX_Byte(w_RX_Byte)
  );
  wire w_reset;
  assign w_reset = 1'b1;
  UART_TX #(
      .CLKS_PER_BIT(217 * 4)
  ) UART_TX_Inst (
      .i_Clock    (clk),
      .i_TX_DV    (w_RX_DV),      // Pass RX to TX module for loopback
      .i_TX_Byte  (w_RX_Byte),    // Pass RX to TX module for loopback
      .i_Rst_L    (rst),
      .o_TX_Active(w_TX_Active),
      .o_TX_Serial(w_TX_Serial),
      .o_TX_Done  ()
  );

  // Drive UART line high when transmitter is not active
  assign UART_TX = w_TX_Active ? w_TX_Serial : 1'b1;
  //assign LED1 = RX;
  wire w_RX_DV;
  //reg [7:0] r_TX_Byte = 8'h21;
  // assign w_RX_DV = i_Switch_1;
  reg [7:0] r_RX_Byte;
  wire [7:0] w_RX_Byte;
  //assign r_byte = r_RX_Byte;
  wire w_TX_Active, w_TX_Serial;
  reg [7:0] r_byte = 8'h42;
  always @(posedge clk) begin
    if (w_RX_DV == 1'b1) begin
      r_RX_Byte <= w_RX_Byte;
      r_byte <= w_RX_Byte;
      value[0] <= w_RX_Byte[3:0];
      value[1] <= w_RX_Byte[7:4];
    end
  end
  reg [15:0] RAM[0:32000];
endmodule
