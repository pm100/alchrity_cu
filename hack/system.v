
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
  // defparam ROM.INIT_0 = 256'h0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff;
  //   defparam ROM.INIT_1 = 256'h8888ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  `include "init_rom.inc"
  defparam ROM.READ_MODE = 0; defparam ROM.WRITE_MODE = 0; (* ram_style = "block" *)
  reg [15:0] RAM[0:1000];

  wire [15:0] i_instruction;
  reg [15:0] r_inst;
  wire [15:0] i_ram;
  assign i_ram = RAM[o_ramaddr];
  wire [15:0] w_CPU_ROM_addr;
  wire o_Bus_CS = 0;

  wire w_rom_DV = o_bus_wr;
  //reg r_mode = 0;  // 0 = shell 1 = run

  wire [15:0] o_ram, o_rom, o_pc_loader, o_pc_cpu, o_ramaddr;
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


  wire [15:0] w_ROM_data;
  wire [15:0] w_ROM_addr;

  assign w_ROM_addr = i_mode == 0  /* in shell mode*/ ? bus_ROM_addr : o_pc_cpu;
  assign i_instruction = o_bus_ROM_data;

  always @(posedge CLK) begin
    if (w_ram_write) begin
      RAM[o_ramaddr] <= o_ram;
    end
    //r_inst <= o_bus_ROM_data;
  end


  // ==============================================================================
  //                memory mapped io
  // ==============================================================================

  wire w_io_mapped_write;
  wire w_ram_write;
  assign w_io_mapped_write = w_tolcd;
  assign w_ram_write = w_io_mapped_write ? o_ram_write : 1'b0;

  // seven seg display
  // 1 word mapped to 0x4000

  wire w_tolcd;
  reg [15:0] r_7seg;
  assign w_tolcd = o_ramaddr == 16'h4000;
  assign o_7seg  = r_7seg;
  always @(posedge CLK) begin
    if (w_tolcd && w_ram_write) begin
      r_7seg <= o_ram;
    end
  end












endmodule
