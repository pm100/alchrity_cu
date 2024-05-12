

`include "/work/alchrity_cu/lib/ice40/uart_rx.v"
`include "/work/alchrity_cu/lib/ice40/uart_tx.v"
`include "/work/alchrity_cu/lib/al_cu/io_lcd.v"

`default_nettype none

module Shell (
    input CLK,
    output UART_TX,
    input UART_RX,
    input RST,  // low is reset

    output [3:0] IO_AN,
    output [7:0] IO_SEG,

    output [7:0] LED

);

  initial begin
    r_reset <= 0;
  end

  `include "../lib/ice40/hex_ascii.v"
  // power up reset logic
  reg [3:0] r_reset;
  always @(posedge CLK) begin
    if (r_reset[3] == 0) begin
      r_reset <= r_reset + 1;
    end
  end
  wire w_reset = r_reset[3] == 0 ? 1'b0 : RST;

  wire [15:0] w_ROM_bus;
  wire [15:0] w_o_ROM_data;
  wire w_Bus_CS;
  wire i_Bus_Rd_DV;
  reg [15:0] r_Bus_Rd_Data;
  reg r_Bus_Wr_Rd_n;


  // address read from coomand for read or write
  reg [15:0] r_RX_Cmd_Addr;
  // data read from uart for write command
  reg [15:0] r_RX_Cmd_Data;


  // shell command interpreter
  // 

  localparam CMD_MAX = 13;  // max length of input or output

  // do we have a valid command in the buffer?

  reg r_RX_Cmd_Done;

  // contents of the buffer

  localparam NONE = 4'h0;
  localparam READ_ROM = 4'h1;
  localparam WRITE_ROM = 4'h2;
  localparam READ_RAM = 4'h3;
  localparam WRITE_RAM = 4'h4;
  localparam RUN = 4'h5;
  localparam ERROR = 4'h6;

  reg [3:0] r_command_state;
  reg r_command_processed;

  reg [$clog2(CMD_MAX)-1:0] r_RX_Index;
  reg [$clog2(CMD_MAX)-1:0] r_TX_Index;
  reg [$clog2(CMD_MAX)-1:0] r_TX_Cmd_Length;
  reg [$clog2(CMD_MAX)-1:0] r_RX_Cmd_Length;
  // input command
  reg [7:0] r_RX_Cmd_Array[0:CMD_MAX-1];
  // response
  // TODO - do we need two buffers?
  reg [7:0] r_TX_Cmd_Array[0:CMD_MAX-1];


  reg r_TX_Cmd_Start;
  reg r_command_completed;

  // 0 means shell active, 1 means cpu running
  reg r_running;



  // read command from uart, buffer into r_RX_Cmd_Array
  always @(posedge CLK) begin
    if (~w_reset) begin
      r_RX_Index <= 0;
      r_RX_Cmd_Length <= 0;
    end else begin
      r_RX_Cmd_Done <= 1'b0;
      if (w_RX_DV == 1'b1) begin
        // data is buffered here, but length updated later
        r_RX_Cmd_Array[r_RX_Index] <= w_RX_Byte;

        // See if most recently received command is CR (Command Done)
        if (w_RX_Byte == 8'h0d) begin
          r_RX_Cmd_Done   <= 1'b1;
          r_RX_Index      <= 0;
          r_RX_Cmd_Length <= r_RX_Index;
        end  // See if most recently received comamnd is Backspace
             // If so, move pointer backward
        else if (w_RX_Byte == 8'h08)  // back space
          r_RX_Index <= r_RX_Index - 1;

        // Normal Data
        else begin
          r_RX_Index    <= r_RX_Index + 1;
          r_RX_Cmd_Done <= 1'b0;
        end
      end
    end
  end

  // Decode received command.  Parses command and acts accordingly.
  always @(posedge CLK) begin
    if (~w_reset) begin
      r_command_state <= NONE;
    end else begin
      // Default Assignments
      r_command_state <= NONE;
      r_command_processed <= 0;
      if (r_RX_Cmd_Done == 1'b1) begin
        // Decode Read Command
        //leds[0] <= 1;
        // rd xxxx, reply 0xxxxx
        if (r_RX_Cmd_Array[0] == "r" && r_RX_Cmd_Array[1] == "d" && r_RX_Cmd_Array[2] == " ") begin
          r_command_state <= READ_ROM;
          r_command_processed <= 1;
        end  // wr xxxx yyyy, response OKxxxxyyyy
        else if (r_RX_Cmd_Array[0] == "w" &&
                 r_RX_Cmd_Array[1] == "r" &&
                 r_RX_Cmd_Array[2] == " ")
                 begin
          if (r_RX_Cmd_Length == 12) begin
            r_command_state <= WRITE_ROM;
            r_command_processed <= 1;
            r_RX_Cmd_Data <= {
              f_ASCII_To_Hex(r_RX_Cmd_Array[8]),
              f_ASCII_To_Hex(r_RX_Cmd_Array[9]),
              f_ASCII_To_Hex(r_RX_Cmd_Array[10]),
              f_ASCII_To_Hex(r_RX_Cmd_Array[11])
            };
          end else r_command_state <= ERROR;
        end else if (r_RX_Cmd_Array[0] == "g") begin
          r_command_state <= RUN;
          r_command_processed <= 1;
        end else begin
          r_command_state <= ERROR;
          r_command_processed <= 1;
        end  // Decode Failed, Erroneous Command

        begin

          r_RX_Cmd_Addr <= {
            f_ASCII_To_Hex(r_RX_Cmd_Array[3]),
            f_ASCII_To_Hex(r_RX_Cmd_Array[4]),
            f_ASCII_To_Hex(r_RX_Cmd_Array[5]),
            f_ASCII_To_Hex(r_RX_Cmd_Array[6])
          };
        end
      end
    end
  end

  reg r_bus_write;
  assign w_Bus_CS = (r_command_state == WRITE_ROM || r_command_state == READ_ROM) ? 1'b1 : 1'b0;

  // // Perform a read or write to Bus based on cmd from UART
  always @(posedge CLK) begin
    if (~w_reset) begin
      r_running <= 1'b0;
    end else if (r_command_processed) begin
      r_bus_write <= 0;
      case (r_command_state)
        READ_ROM: begin
        end
        WRITE_ROM: begin
          r_bus_write <= 1;
        end
        RUN: begin
          r_running <= 1'b1;
        end
        default: begin
        end
      endcase
    end
  end
  always @* begin
    leds[0] <= r_running;
  end

  // Form a command response to a Received Command
  always @(posedge CLK) begin
    if (~w_reset) begin
      r_TX_Cmd_Start <= 1'b0;

    end else begin
      r_TX_Cmd_Start <= 1'b0;
      r_command_completed <= 0;
      // Erroneous Command Response
      case (r_command_state)
        ERROR: begin

          r_TX_Cmd_Array[0] <= "\n";
          r_TX_Cmd_Array[1] <= f_Hex_To_ASCII(0);
          r_TX_Cmd_Array[2] <= f_Hex_To_ASCII(r_RX_Cmd_Length[3:0]);

          r_TX_Cmd_Array[3] <= "\015";
          r_TX_Cmd_Array[4] <= "\n";
          r_TX_Cmd_Array[5] <= "\n";
          r_TX_Cmd_Length   <= 5;
          r_TX_Cmd_Start    <= 1'b1;
          r_command_completed <= 1;
        end  // Read Command Response
        READ_ROM: begin
          r_TX_Cmd_Array[0] <= "\n";
          r_TX_Cmd_Array[1] <= "0";
          r_TX_Cmd_Array[2] <= "X";
          r_TX_Cmd_Array[3] <= f_Hex_To_ASCII(w_o_ROM_data[15:12]);
          r_TX_Cmd_Array[4] <= f_Hex_To_ASCII(w_o_ROM_data[11:8]);
          r_TX_Cmd_Array[5] <= f_Hex_To_ASCII(w_o_ROM_data[7:4]);
          r_TX_Cmd_Array[6] <= f_Hex_To_ASCII(w_o_ROM_data[3:0]);
          r_TX_Cmd_Array[7] <="\015";
          r_TX_Cmd_Array[8] <= "\n";
          r_TX_Cmd_Length   <= 9;
          r_TX_Cmd_Start    <= 1'b1;
          r_command_completed <= 1;
        end  // Write Command Response
        WRITE_ROM: begin
          leds[6] <= 1;
          r_TX_Cmd_Array[0] <= "\n";
          r_TX_Cmd_Array[1] <= "o";
          r_TX_Cmd_Array[2] <= "k";
          r_TX_Cmd_Array[3] <= f_Hex_To_ASCII(r_RX_Cmd_Addr[15:12]);
          r_TX_Cmd_Array[4] <= f_Hex_To_ASCII(r_RX_Cmd_Addr[11:8]);
          r_TX_Cmd_Array[5] <= f_Hex_To_ASCII(r_RX_Cmd_Addr[7:4]);
          r_TX_Cmd_Array[6] <= f_Hex_To_ASCII(r_RX_Cmd_Addr[3:0]);

          r_TX_Cmd_Array[7] <= f_Hex_To_ASCII(r_RX_Cmd_Data[15:12]);
          r_TX_Cmd_Array[8] <= f_Hex_To_ASCII(r_RX_Cmd_Data[11:8]);
          r_TX_Cmd_Array[9] <= f_Hex_To_ASCII(r_RX_Cmd_Data[7:4]);
          r_TX_Cmd_Array[10] <= f_Hex_To_ASCII(r_RX_Cmd_Data[3:0]);

          r_TX_Cmd_Array[11] <= "\n";
          r_TX_Cmd_Array[12] <= "\015";
          r_TX_Cmd_Length   <= 13;
          r_TX_Cmd_Start    <= 1'b1;
          r_command_completed <= 1;

        end
        RUN: begin
          r_TX_Cmd_Array[0] <= "\n";
          r_TX_Cmd_Array[1] <= "r";
          r_TX_Cmd_Array[2] <= "u";
          r_TX_Cmd_Array[3] <= "n";
          r_TX_Cmd_Array[4] <= "\015";
          r_TX_Cmd_Array[5] <= "\n";
          r_TX_Cmd_Length   <= 6;
          r_TX_Cmd_Start    <= 1'b1;
          r_command_completed <= 1;
        end
      endcase
    end
  end
  // the hack system we are running

  wire [15:0] w_7seg;
  System hack (
      .CLK(CLK),

      .bus_RAM_data  (),
      .i_bus_ROM_data(r_RX_Cmd_Data),
      .o_bus_ROM_data(w_o_ROM_data),

      .bus_RAM_addr(),
      .bus_ROM_addr(r_RX_Cmd_Addr),

      .bus_RAM_write(),
      .bus_ROM_write(r_bus_write),
      .bus_ROM_cs(w_Bus_CS),

      .o_7seg(w_7seg),

      .i_mode(r_running)

  );
  //==============================================================================
  //         beyond here is all plumbing and hw debugging support
  //==============================================================================
  wire w_RX_DV;



  //==============================================================================
  //           UART plumbing
  //==============================================================================

  // are we echoing or talking ourselves
  wire [7:0] w_TX_Byte_Mux;
  assign w_TX_Byte_Mux = w_RX_DV ? w_RX_Byte : r_TX_Byte;

  // Drive UART line high when transmitter is not active
  assign UART_TX = w_TX_Active ? w_TX_Serial : 1'b1;

  reg  [7:0] r_RX_Byte;
  wire [7:0] w_RX_Byte;
  wire w_TX_Active, w_TX_Serial;

  // echo received byte
  always @(posedge CLK) begin
    if (w_RX_DV == 1'b1) begin
      r_RX_Byte <= w_RX_Byte;
    end
  end


  // Simple State Machine to Transmit a command response.

  localparam IDLE = 3'b000;
  localparam TX_START = 3'b001;
  localparam TX_WAIT_READY = 3'b010;
  localparam TX_DONE = 3'b011;
  localparam TX_WAIT_DONE = 3'b100;

  reg        r_TX_DV;
  reg  [7:0] r_TX_Byte;
  wire       w_TX_Done;
  reg  [2:0] r_SM_Main;  //= IDLE;



  always @(posedge CLK) begin
    if (~w_reset) begin
      r_SM_Main <= IDLE;
      r_TX_DV   <= 1'b0;
    end else begin

      // Default Assignments
      r_TX_DV <= 1'b0;

      case (r_SM_Main)
        IDLE: begin
          r_TX_Index <= 0;
          // leds[4] <= 0;
          // leds[3] <= 0;

          if (r_TX_Cmd_Start == 1'b1) begin
            leds[3]   <= 1;
            r_SM_Main <= TX_WAIT_READY;
          end
        end

        TX_WAIT_READY: begin

          if (w_TX_Active == 1'b0) r_SM_Main <= TX_START;
        end

        TX_START: begin
          leds[4]   <= 1;

          r_TX_DV   <= 1'b1;
          r_TX_Byte <= r_TX_Cmd_Array[r_TX_Index];
          r_SM_Main <= TX_WAIT_DONE;
        end

        TX_WAIT_DONE: begin
          if (w_TX_Done == 1'b1) begin
            if (r_TX_Index == r_TX_Cmd_Length - 1) begin
              r_SM_Main <= TX_DONE;
            end else begin
              leds[1] <= 0;

              r_TX_Index <= r_TX_Index + 1;
              r_SM_Main <= TX_START;
            end
          end
        end

        TX_DONE: r_SM_Main <= IDLE;

        default: r_SM_Main <= IDLE;

      endcase

    end
  end

  // *4 because we are running at 100mhz, not 25mhz on the go board

  UART_RX #(
      .CLKS_PER_BIT(217 * 4)
  ) UART_RX_Inst (
      .i_Clock(CLK),
      .i_Rst_L(w_reset),
      .i_RX_Serial(UART_RX),
      .o_RX_DV(w_RX_DV),
      .o_RX_Byte(w_RX_Byte)
  );


  UART_TX #(
      .CLKS_PER_BIT(217 * 4)
  ) UART_TX_Inst (
      .i_Clock    (CLK),
      .i_TX_DV    (r_TX_DV | w_RX_DV),  // Pass RX to TX module for loopback
      .i_TX_Byte  (w_TX_Byte_Mux),      // Pass RX to TX module for loopback
      .i_Rst_L    (w_reset),
      .o_TX_Active(w_TX_Active),
      .o_TX_Serial(w_TX_Serial),
      .o_TX_Done  (w_TX_Done)
  );

  // lcd support for debugging

  io_lcd io_lcd (
      .clk(CLK),
      .rst(w_reset),
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

  // the numbers written to the io daughter board seven seg display

  reg [3:0] value[3:0];

  // mother board leds

  reg [7:0] leds;
  assign LED[0] = leds[0];
  assign LED[1] = leds[1];
  assign LED[2] = leds[2];
  assign LED[3] = leds[3];
  assign LED[4] = leds[4];
  assign LED[5] = leds[5];
  assign LED[6] = leds[6];
  assign LED[7] = leds[7];



  reg [7:0] r_byte;  // = 8'h42;
  always @(posedge CLK) begin
    if (~w_reset) begin
      value[0] <= 0;
      value[1] <= 0;
      value[2] <= 0;
      value[3] <= 0;
      // leds[0] <= 0;
      // leds[1] <= 0;
      // leds[2] <= 0;
      // leds[3] <= 0;
      // leds[4] <= 0;
      // leds[5] <= 0;
      // leds[6] <= 0;
      // leds[7] <= 0;

    end else begin
      if (r_running == 1'b1) begin
        value[0] <= w_7seg[3:0];
        value[1] <= w_7seg[7:4];
        value[2] <= w_7seg[11:8];
        value[3] <= w_7seg[15:12];
      end else begin
        value[3] <= r_command_state;
        value[2] <= r_RX_Cmd_Length[3:0];

        if (w_RX_DV == 1'b1) begin
          r_RX_Byte <= w_RX_Byte;
          r_byte <= w_RX_Byte;
          value[0] <= w_RX_Byte[3:0];
          value[1] <= w_RX_Byte[7:4];
          //value[2] <= r_RX_Index[3:0];

        end
      end
    end
  end
endmodule
