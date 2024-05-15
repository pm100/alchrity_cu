
`default_nettype none


module System (
    input CLK,

    input [15:0] i_bus_ROM_data,
    output [15:0] o_bus_ROM_data,
    input [15:0] bus_ROM_addr,
    input bus_ROM_write,
    input bus_ROM_cs,

    inout [15:0] bus_RAM_data,
    input [15:0] bus_RAM_addr,
    input bus_RAM_write,
    input bus_RAM_cs,  // 1 = shell owns the bus

    output [15:0] o_7seg,

    // uart interface
    output [7:0] o_UART_byte,
    output o_UART_byte_ready,
    input i_UART_byte_sent,
    input [7:0] i_UART_byte,
    input i_UART_byte_ready,

    input i_mode

);
  reg r_run;
  initial begin
    r_run = 0;
  end
  always @(posedge CLK) begin
    if (i_mode) begin
      r_run <= 1;
    end
  end

  wire [15:0] w_ROM_data;
  wire [15:0] w_ROM_addr;
  wire [15:0] o_ram, o_rom, o_pc_loader, o_pc_cpu, o_ramaddr;

  assign w_ROM_addr = i_mode == 0  /* in shell mode*/ ? bus_ROM_addr : o_pc_cpu;
  // explicit instatiate to get neg edge read
  // and facilitate the r/w interface to the shell

  SB_RAM40_4KNR ROM (
      .RDATA(o_bus_ROM_data),
      .RADDR(w_ROM_addr),
      .RCLKN(CLK),
      .RCLKE(1),
      .RE(1),
      .WADDR(bus_ROM_addr),
      .WCLK(CLK),
      .WCLKE(1),
      .WDATA(i_bus_ROM_data),
      .WE(bus_ROM_write),
      .MASK()
  );
  // reg [15:0] ROM[0:20];
  // initial begin
  //   ROM[0] = 16'h04d2;
  //   ROM[1] = 16'hec10;
  //   ROM[2] = 16'h4000;
  //   ROM[3] = 16'he308;
  //   ROM[4] = 16'h0004;
  //   ROM[5] = 16'he307;

  // end
  // assign o_bus_ROM_data = ROM[w_ROM_addr];
  // always @(posedge CLK) begin
  //   if (bus_ROM_write) begin
  //     ROM[bus_ROM_addr] <= i_bus_ROM_data;
  //   end
  // end
  // defparam ROM.INIT_0 = 256'h0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff;
  //   defparam ROM.INIT_1 = 256'h8888ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  `include "init_rom.inc"
  defparam ROM.READ_MODE = 0;
  //
  defparam ROM.WRITE_MODE = 0;
  //
  (* ram_style = "block" *)
  reg [15:0] RAM[0:1000];

  integer i;
  initial begin
    for (i = 0; i < 1000; i = i + 1) begin
      RAM[i] = 16'h0000;
    end
  end

  wire [15:0] i_instruction;
  reg  [15:0] r_inst;
  wire [15:0] i_ram;
  assign i_ram = RAM[o_ramaddr];
  wire [15:0] w_CPU_ROM_addr;
  wire o_Bus_CS = 0;

  wire w_rom_DV = o_bus_wr;
  //reg r_mode = 0;  // 0 = shell 1 = run


  wire o_rom_write, o_ram_write, o_bus_wr;
  wire [15:0] w_D, w_A;
  CPU Cpu (
      .clk(CLK),
      .i_instruction(i_instruction),
      .i_ram(i_ram),
      .i_reset(r_run ? 1'b0 : 1'b1),
      .o_ram(o_ram),
      .o_pc(o_pc_cpu),
      .o_ramaddr(o_ramaddr),
      .o_ram_write(o_ram_write),
      .o_A(w_A),
      .o_D(w_D)
  );

  assign i_instruction = o_bus_ROM_data;

  always @(posedge CLK) begin
    if (w_ram_write) begin
      RAM[o_ramaddr] <= o_ram;
    end
  end


  // ==============================================================================
  //                memory mapped io
  // ==============================================================================

  wire w_io_mapped_write;
  wire w_ram_write;
  assign w_io_mapped_write = w_tolcd;
  assign w_ram_write = ~w_io_mapped_write ? o_ram_write : 1'b0;

  // seven seg display
  // 1 word mapped to 0x4000

  wire w_tolcd;
  reg [15:0] r_7seg;
  assign w_tolcd = o_ramaddr == 16'h4000;
  assign o_7seg  = r_7seg;
  always @(posedge CLK) begin
    //r_7seg <= 42;
    if (w_tolcd && o_ram_write) begin
      r_7seg <= o_ram;
    end
  end

  // uart read write
  // inout byte mapped to 0x4001 lo
  // status byte mapped to 0x4001 hi

  wire w_touart;
  reg [7:0] r_uart_byte;
  reg r_uart_byte_sent;
  reg r_uart_byte_read;
  reg r_send_byte;
  assign w_touart = o_ramaddr == 16'h4001;
  assign o_UART_byte = r_uart_byte;
  assign o_UART_byte_ready = r_send_byte;
  always @(posedge CLK) begin
    r_send_byte <= 0;
    if (w_touart && o_ram_write) begin
      r_uart_byte <= o_ram[7:0];
      r_uart_byte_sent <= 1'b0;
      r_uart_byte_read <= 1'b0;
      // tell shell to send it
      r_send_byte <= 1;
    end
    if (i_UART_byte_sent) begin
      r_uart_byte_sent <= 1;
    end
  end










endmodule
