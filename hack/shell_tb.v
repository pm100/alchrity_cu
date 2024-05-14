`timescale 100 ns / 10 ns
//
`default_nettype none

`define DUMPSTR(x) `"x.vcd`"
module shell_tb ();

  reg r_reset;
  Shell UUT (
      .CLK(   r_Clock ),
      .RST(r_reset),
      .UART_RX(r_RX_Serial),
      .UART_TX(r_TX_Serial)
      // .IO_AN(IO_AN),
      // .IO_SEG(IO_SEG)
      // .IO_SW(IO_SW)
  );



  reg r_Clock = 0;
  reg r_RX_Serial = 1;
  wire [7:0] w_RX_Byte;
  parameter c_CLOCK_PERIOD_NS = 40;
  parameter c_CLKS_PER_BIT = 217 * 4;
  parameter c_BIT_PERIOD = 8600 * 4;
  always #(c_CLOCK_PERIOD_NS / 2) r_Clock <= !r_Clock;
  initial begin
    #10__000_000;  // Wait a long time in simulation units (adjust as needed).
    $display("Caught by trap");
    $finish;
  end
  UART_RX #(
      .CLKS_PER_BIT(c_CLKS_PER_BIT)
  ) UART_RX_INST (
      .i_Clock(r_Clock),
      .i_RX_Serial(r_TX_Serial),
      .o_RX_DV(),
      .o_RX_Byte(w_RX_Byte)
  );
  wire r_TX_Serial;


  // Takes in input byte and serializes it 
  task UART_WRITE_BYTE;
    input [7:0] i_Data;
    integer ii;
    begin

      // Send Start Bit
      r_RX_Serial <= 1'b0;
      #(c_BIT_PERIOD);
      #1000;

      // Send Data Byte
      for (ii = 0; ii < 8; ii = ii + 1) begin
        r_RX_Serial <= i_Data[ii];
        #(c_BIT_PERIOD);
      end

      // Send Stop Bit
      r_RX_Serial <= 1'b1;
      #(c_BIT_PERIOD);
    end
  endtask  // UART_WRITE_BYTE


  // Main Testing:
  initial begin

    $dumpfile(`DUMPSTR(`VCD_OUTPUT));
    $dumpvars(0, shell_tb);
    $dumpvars(0, UUT.r_RX_Cmd_Array[0]);
    $dumpvars(0, UUT.r_RX_Cmd_Array[1]);
    $dumpvars(0, UUT.r_RX_Cmd_Array[2]);
    $dumpvars(0, UUT.r_RX_Cmd_Array[3]);
    $dumpvars(0, UUT.r_RX_Cmd_Array[4]);
    $dumpvars(0, UUT.r_RX_Cmd_Array[5]);
    $dumpvars(0, UUT.r_RX_Cmd_Array[6]);
    $dumpvars(0, UUT.r_RX_Cmd_Array[7]);
    $dumpvars(0, UUT.r_RX_Cmd_Array[8]);
    $dumpvars(0, UUT.r_RX_Cmd_Array[9]);
    $dumpvars(0, UUT.hack.RAM[0]);
    $dumpvars(0, UUT.hack.RAM[1]);
    $dumpvars(0, UUT.hack.RAM[2]);
    $dumpvars(0, UUT.value[0]);
    $dumpvars(0, UUT.value[1]);
    $dumpvars(0, UUT.value[2]);
    r_reset <= 1;
    #100 r_reset <= 0;
    #100 r_reset <= 1;
    // $dumpvars(0, UUT.RAM.r_Mem[0]);
    // $dumpvars(0, UUT.RAM.r_Mem[1]);
    //$dumpvars(0, UUT.RAM.r_Mem[2]);
    // Send a command to the UART (exercise Rx)
    #50000 @(posedge r_Clock);
    UART_WRITE_BYTE("g");
    #5000 @(posedge r_Clock);
    // UART_WRITE_BYTE("d");
    // #5000 @(posedge r_Clock);
    // UART_WRITE_BYTE(" ");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE("0");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE("0");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE("0");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE("0");
    #5000 UART_WRITE_BYTE(8'h0D);

    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE(" ");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE("1");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE("1");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE("1");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE("1");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE("g");
    // #5 @(posedge r_Clock);
    // UART_WRITE_BYTE(" ");
    // #5 @(posedge r_Clock);
    // #1 UART_WRITE_BYTE(8'h0D);
    // //   #100000
    //     UART_WRITE_BYTE(8'h30);
    // Check that the correct command was received
    //if (w_RX_Byte == 8'h37) $display("Test Passed - Correct Byte Received");
    //else $display("Test Failed - Incorrect Byte Received");
    #30000 $finish;
  end
endmodule
