

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

  `include "../lib/ice40/hex_ascii.v"

  // the hack system we are running

  System hack (
      .CLK(CLK),

      .bus_RAM(),
      .bus_ROM(),

      .bus_RAM_addr(),
      .bus_ROM_addr(),

      .bus_RAM_write(),
      .bus_ROM_write()

  );

  reg o_Bus_CS;
  wire o_Bus_Wr_Rd_n;
  wire i_Bus_Rd_DV = 0;
  reg [15:0] i_Bus_Rd_Data;
  wire o_go;
  assign o_Bus_Wr_Rd_n = r_Bus_Wr_Rd_n;

  reg r_Bus_Wr_Rd_n;






  // shell command interpreter
  // 

  localparam CMD_MAX = 13;  // max length of input or output

  localparam READ_ROM = 4'h0;
  localparam WRITE_ROM = 4'h1;
  localparam READ_RAM = 4'h2;
  localparam WRITE_RAM = 4'h3;
  localparam RUN = 4'h4;
  localparam ERROR = 4'h5;

  reg [$clog2(CMD_MAX)-1:0] r_RX_Index;
  reg [$clog2(CMD_MAX)-1:0] r_TX_Index;
  reg [$clog2(CMD_MAX)-1:0] r_TX_Cmd_Length;
  reg [$clog2(CMD_MAX)-1:0] r_RX_Cmd_Length;
  reg [7:0] r_RX_Cmd_Array[0:CMD_MAX-1], r_TX_Cmd_Array[0:CMD_MAX-1];
  reg r_RX_Cmd_Done = 0;
  reg r_RX_Cmd_Rd, r_RX_Cmd_Wr;
  reg r_RX_Cmd_Error;
  reg r_TX_Cmd_Start = 0;
  reg [15:0] r_RX_Cmd_Addr = 0;
  reg [15:0] r_RX_Cmd_Data;


  // read command from uart
  always @(posedge CLK) begin
    if (~RST) begin
      r_RX_Index <= 0;
    end else begin
      r_RX_Cmd_Done <= 1'b0;  // Default Assignment
      if (w_RX_DV == 1'b1) begin
        // data is buffered here, but length updated later
        r_RX_Cmd_Array[r_RX_Index] <= w_RX_Byte;

        // See if most recently received command is CR (Command Done)
        if (w_RX_Byte == "\r") begin
          r_RX_Cmd_Done   <= 1'b1;
          r_RX_Index      <= 0;
          r_RX_Cmd_Length <= r_RX_Index;
        end  // See if most recently received comamnd is Backspace
             // If so, move pointer backward
        else if (w_RX_Byte == 8'h08)  // basck space
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
    if (~RST) begin
      r_RX_Cmd_Rd    <= 1'b0;
      r_RX_Cmd_Wr    <= 1'b0;
      r_RX_Cmd_Error <= 1'b0;
    end else begin
      // Default Assignments
      r_RX_Cmd_Rd    <= 1'b0;
      r_RX_Cmd_Wr    <= 1'b0;
      r_RX_Cmd_Error <= 1'b0;


      if (r_RX_Cmd_Done == 1'b1) begin
        // Decode Read Command
        leds[0] <= 1;
        // rd xxxx, reply 0xxxxx
        if (r_RX_Cmd_Array[0] == "r" && r_RX_Cmd_Array[1] == "d" && r_RX_Cmd_Array[2] == " ") begin
          r_RX_Cmd_Rd <= 1'b1;
        end  // Decode Write Command
             // wr xxxx yyyy, response OKxxxxyyyy
        else if (r_RX_Cmd_Array[0] == "w" &&
                 r_RX_Cmd_Array[1] == "r" &&
                 r_RX_Cmd_Array[2] == " ")
                 begin
          if (r_RX_Cmd_Length == 12) begin
            r_RX_Cmd_Wr <= 1'b1;
            leds[7] <= 1;
            r_RX_Cmd_Data <= {
              f_ASCII_To_Hex(r_RX_Cmd_Array[8]),
              f_ASCII_To_Hex(r_RX_Cmd_Array[9]),
              f_ASCII_To_Hex(r_RX_Cmd_Array[10]),
              f_ASCII_To_Hex(r_RX_Cmd_Array[11])
            };
          end else r_RX_Cmd_Error <= 1'b1;
        end else if (r_RX_Cmd_Array[0] == "g") begin
          //o_go <= 1'b1;
        end  // Decode Failed, Erroneous Command
        else begin
          r_RX_Cmd_Error <= 1'b1;
          leds[1] <= 1;
        end
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


  // Perform a read or write to Bus based on cmd from UART
  always @(posedge CLK) begin
    if (~RST) begin
      o_Bus_CS <= 1'b0;
    end else begin
      if (r_RX_Cmd_Rd == 1'b1) begin
        o_Bus_CS      <= 1'b1;
        r_Bus_Wr_Rd_n <= 1'b1;
      end else if (r_RX_Cmd_Wr == 1'b1) begin
        o_Bus_CS      <= 1'b1;
        r_Bus_Wr_Rd_n <= 1'b0;
        // o_Bus_Wr_Data <= r_RX_Cmd_Data;
      end else begin
        o_Bus_CS      <= 1'b0;
        r_Bus_Wr_Rd_n <= 1'b0;

      end
    end
  end


  // Form a command response to a Received Command
  always @(posedge CLK) begin
    if (~RST) begin
      r_TX_Cmd_Start <= 1'b0;
    end else begin
      r_TX_Cmd_Start <= 1'b0;

      // Erroneous Command Response
      if (r_RX_Cmd_Error == 1'b1) begin
        leds[2] <= 1;
        r_TX_Cmd_Array[0] <= "\n";
        r_TX_Cmd_Array[1] <= f_Hex_To_ASCII(0);
        r_TX_Cmd_Array[2] <= f_Hex_To_ASCII(r_RX_Cmd_Length[3:0]);

        r_TX_Cmd_Array[3] <= "\r";
        r_TX_Cmd_Array[4] <= "\n";
        r_TX_Cmd_Array[5] <= "\n";
        r_TX_Cmd_Length   <= 5;
        r_TX_Cmd_Start    <= 1'b1;


      end // if (r_RX_Cmd_Error == 1'b1)

     // Read Command Response
      else if (i_Bus_Rd_DV == 1'b1) begin
        leds[5] <= 1;
        r_TX_Cmd_Array[0] <= "\n";
        r_TX_Cmd_Array[1] <= "0";
        r_TX_Cmd_Array[2] <= "X";
        // r_TX_Cmd_Array[3] <= f_Hex_To_ASCII(i_Bus_Rd_Data[15:12]);gh
        // r_TX_Cmd_Array[4] <= f_Hex_To_ASCII(i_Bus_Rd_Data[11:8]);
        // r_TX_Cmd_Array[5] <= f_Hex_To_ASCII(i_Bus_Rd_Data[7:4]);
        // r_TX_Cmd_Array[6] <= f_Hex_To_ASCII(i_Bus_Rd_Data[3:0]);
        r_TX_Cmd_Array[7] <="\r";
        r_TX_Cmd_Array[8] <= "\n";
        // r_TX_Cmd_Array[9] <= ASCII_LF;
        r_TX_Cmd_Length   <= 9;
        r_TX_Cmd_Start    <= 1'b1;
      end // if (i_Bus_Rd_DV == 1'b1)

      // Write Command Response
      else if (r_RX_Cmd_Wr == 1'b1) begin
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
        r_TX_Cmd_Array[12] <= "\r";
        r_TX_Cmd_Length   <= 13;
        r_TX_Cmd_Start    <= 1'b1;
      end
    end
  end
  //==============================================================================
  //         beyond here is all plumbing and hw debugging support
  //==============================================================================

  // *4 because we are running at 100mhz, not 25mhz on the go board

  UART_RX #(
      .CLKS_PER_BIT(217 * 4)
  ) UART_RX_Inst (
      .i_Clock(CLK),
      .i_Rst_L(RST),
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
      .i_Rst_L    (RST),
      .o_TX_Active(w_TX_Active),
      .o_TX_Serial(w_TX_Serial),
      .o_TX_Done  (w_TX_Done)
  );

  //==============================================================================
  //           UART plumbing
  //==============================================================================

  // are we echoing or talking ourselves
  wire [7:0] w_TX_Byte_Mux;
  assign w_TX_Byte_Mux = w_RX_DV ? w_RX_Byte : r_TX_Byte;

  // Drive UART line high when transmitter is not active
  assign UART_TX = w_TX_Active ? w_TX_Serial : 1'b1;
  wire w_RX_DV;
  reg [7:0] r_RX_Byte;
  wire [7:0] w_RX_Byte;
  wire w_TX_Active, w_TX_Serial;

  // echo received byte
  always @(posedge CLK) begin
    if (w_RX_DV == 1'b1) begin
      r_RX_Byte <= w_RX_Byte;
    end
  end


  // Simple State Machine to Transmit a command.
  reg        r_TX_DV;
  reg  [7:0] r_TX_Byte;
  wire       w_TX_Done;
  reg  [2:0] r_SM_Main = IDLE;

  localparam IDLE = 3'b000;
  localparam TX_START = 3'b001;
  localparam TX_WAIT_READY = 3'b010;
  localparam TX_DONE = 3'b011;
  localparam TX_WAIT_DONE = 3'b100;

  always @(posedge CLK) begin
    if (~RST) begin
      r_SM_Main <= IDLE;
      r_TX_DV   <= 1'b0;
    end else begin

      // Default Assignments
      r_TX_DV <= 1'b0;

      case (r_SM_Main)
        IDLE: begin
          r_TX_Index <= 0;
          leds[4] <= 1;
          if (r_TX_Cmd_Start == 1'b1) begin
            leds[3]   <= 1;
            r_SM_Main <= TX_WAIT_READY;
          end
        end

        TX_WAIT_READY: begin

          if (w_TX_Active == 1'b0) r_SM_Main <= TX_START;
        end

        TX_START: begin
          r_TX_DV   <= 1'b1;
          r_TX_Byte <= r_TX_Cmd_Array[r_TX_Index];
          r_SM_Main <= TX_WAIT_DONE;
        end

        TX_WAIT_DONE: begin
          if (w_TX_Done == 1'b1) begin
            if (r_TX_Index == r_TX_Cmd_Length - 1) begin
              r_SM_Main <= TX_DONE;
            end else begin
              r_TX_Index <= r_TX_Index + 1;
              r_SM_Main  <= TX_START;
            end
          end  // if (w_TX_Done == 1'b1)
        end  // case: TX_WAIT_DONE

        TX_DONE: r_SM_Main <= IDLE;

        default: r_SM_Main <= IDLE;

      endcase

    end
  end


  // lcd support for debugging

  io_lcd io_lcd (
      .clk(CLK),
      .rst(RST),
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

  initial begin
    value[0] = 0;
    value[1] = 0;
    value[2] = 0;
    value[3] = 0;
    // leds[0]=0;
    // leds[1]=0;
    // leds[2]=0;
    // leds[3]=0;
    // leds[4]=0;
    // leds[5]=0;
    // leds[6]=0;
    // leds[7]=0;


  end

  reg [7:0] r_byte = 8'h42;
  always @(posedge CLK) begin
    if (~RST) begin
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
      value[3] <= r_SM_Main;
      value[2] <= r_RX_Cmd_Length[3:0];
      //leds[7] <= r_RX_Cmd_Wr;
      if (w_RX_DV == 1'b1) begin
        r_RX_Byte <= w_RX_Byte;
        r_byte <= w_RX_Byte;
        value[0] <= w_RX_Byte[3:0];
        value[1] <= w_RX_Byte[7:4];
        //value[2] <= r_RX_Index[3:0];

      end
    end
  end
endmodule
