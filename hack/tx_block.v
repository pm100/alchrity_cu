// an FSM to transmit a block of data via UART
// params - char buff length, clock speed, baud rate
// inputs data buffer, data length, start signal
// input reset (neg)
// outputs - done signal, uart tx wire, current stat
`include "/work/alchrity_cu/lib/ice40/uart_tx.v"
//
`default_nettype none
module transmit_block #(
    parameter BUFFER_SIZE = 8,
    parameter CLOCK_SPEED = 25_000_000,
    parameter BAUD_RATE   = 115_200
) (
    input clk,
    input reset_n,
    input start,
    input [7*BUFFER_SIZE-1:0] data,
    input data_length,

    output done,
    output o_uart_tx
);

  // unflatten to input data
  wire [7:0] w_char_array[0:BUFFER_SIZE];
  genvar i;
  for (i = 0; i < 32; i = i + 1) assign w_char_array[i] = data[8*i+7:8*i];

  // FSM states
  localparam STATE_IDLE = 3'b000;
  localparam TX_START = 3'b001;
  localparam TX_WAIT_READY = 3'b010;
  localparam TX_DONE = 3'b011;
  localparam TX_WAIT_DONE = 3'b100;

  // FSM sequencer
  reg [2:0] current_state;
  reg [2:0] next_state;

  always @(posedge clk) begin
    if (!reset_n) current_state <= STATE_IDLE;
    else current_state <= next_state;
  end

  reg [$clog2(BUFFER_SIZE)-1:0] r_data_index;
  reg [7:0] r_tx_byte;
  reg r_tx_data_valid;

  wire w_TX_Done;

  // FSM state logic
  always @(*) begin
    // default to not moving state
    next_state = current_state;
    case (current_state)
      STATE_IDLE: begin
        r_data_index = 0;
        r_tx_data_valid = 0;
        // signalled by caller to send data
        if (start) next_state = TX_WAIT_READY;
      end
      TX_WAIT_READY: begin
        // wait until UART TX is high (ie nobody else using it)
        // not really necessary 
        if (o_uart_tx) next_state = TX_START;
      end
      TX_START: begin
        // send next byte
        r_tx_byte = w_char_array[r_data_index];
        r_tx_data_valid = 1'b1;
        next_state = TX_WAIT_DONE;
      end
      TX_WAIT_DONE: begin
        // wait for uart to say it sent the byte
        if (w_TX_Done == 1'b1) begin
          // was it the last one?
          if (r_data_index == data_length - 1) begin
            next_state = TX_DONE;
          end else begin
            r_data_index = r_data_index + 1;
            next_state   = TX_START;
          end
        end
      end
      TX_DONE: begin
        next_state = STATE_IDLE;
      end

    endcase
  end



  //done signal
  assign done = tx_done;

  UART_TX #(
      .CLOCK_SPEED(CLOCK_SPEED),
      .BAUD_RATE  (BAUD_RATE)
  ) UART_TX_Inst (
      .i_Clock(clk),
      .i_TX_DV(r_tx_data_valid),
      .i_TX_Byte(r_tx_byte),
      .i_Rst_L(reset_n),
      .o_TX_Active(),
      .o_TX_Serial(o_uart_tx),
      .o_TX_Done(w_TX_Done)
  );
endmodule
