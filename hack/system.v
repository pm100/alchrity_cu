//`include "/work/alchrity_cu/lib/ice40/RAM_1Port.v"

`default_nettype none

// // Russell Merrick - http://www.nandland.com
// //
// // Creates a Single Port RAM. (Random Access Memory)
// // Single port RAM has one port, so can only access one memory location at a time.
// // Dual port RAM can read and write to different memory locations at the same time.
// //
// // WIDTH sets the width of the Memory created.
// // DEPTH sets the depth of the Memory created.
// // Likely tools will infer Block RAM if WIDTH/DEPTH is large enough.
// // If small, tools will infer register-based memory.
// `ifndef RAM_1Port_
// `define RAM_1Port_ 1
module RAM_1Port #(
    parameter WIDTH = 16,
    parameter DEPTH = 256
) (
    input                          i_Clk,
    // Shared address for writes and reads
    input      [$clog2(DEPTH)-1:0] i_Addr,
    // Write Interface
    input                          i_Wr_DV,
    input      [        WIDTH-1:0] i_Wr_Data,
    // Read Interface
    input                          i_Rd_En,
    output reg                     o_Rd_DV,
    output reg [        WIDTH-1:0] o_Rd_Data
);

  reg [WIDTH-1:0] r_Mem[DEPTH-1:0];

  always @(posedge i_Clk) begin
    // Handle writes to memory
    if (i_Wr_DV) begin
      r_Mem[i_Addr] <= i_Wr_Data;
    end

    // Handle reads from memory
    // o_Rd_Data <= r_Mem[i_Addr];
    // o_Rd_DV   <= i_Rd_En;  // Generate DV pulse
  end
  always @(negedge i_Clk) begin
    o_Rd_Data <= r_Mem[i_Addr];
    o_Rd_DV   <= i_Rd_En;  // Generate DV pulse
  end
  //assign o_Rd_Data = r_Mem[i_Addr];


endmodule


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
    input bus_RAM_cs  // 1 = shell owns the bus


);


  // core of hack system
  // (* ram_style = "block" *)
  // reg [15:0] ROM[0:1000];
  SB_RAM40_4KNR ROM (
      .RDATA(o_bus_ROM_data),

      .RADDR(bus_ROM_addr),
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
  defparam ROM.INIT_0 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
      defparam ROM.INIT_1 = 256'h8888ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
      defparam ROM.READ_MODE = 0; defparam ROM.WRITE_MODE = 0;
  // RAM_1Port #(
  //     .WIDTH(16),
  //     .DEPTH(1000)
  // ) ROM (
  //     .i_Clk(CLK),
  //     .i_Wr_DV(bus_ROM_write),
  //     .i_Addr(bus_ROM_addr),
  //     .i_Wr_Data(i_bus_ROM_data),
  //     .o_Rd_Data(o_bus_ROM_data)
  // );

  (* ram_style = "block" *)
  reg [15:0] RAM[0:1000];
  wire [15:0] i_instruction;
  reg [15:0] r_inst;
  wire [15:0] i_ram;

  wire [15:0] w_CPU_ROM_addr;
  wire o_Bus_CS = 0;

  wire w_rom_DV = o_bus_wr;
  reg r_mode = 0;  // 0 = boot 1 = run

  wire [15:0] o_ram, o_rom, o_pc_loader, o_pc_cpu, o_ramaddr;
  wire o_rom_write, o_ram_write, o_bus_wr;
  wire [15:0] w_D, w_A;
  CPU Cpu (
      .clk(CLK),
      .i_instruction(i_instruction),
      .i_ram(i_ram),
      .i_reset(r_mode ? 1'b0 : 1'b1),
      .o_ram(o_ram),
      .o_pc(o_pc_cpu),
      .o_ramaddr(o_ramaddr),
      .o_ram_write(o_ram_write),
      .o_A(w_A),
      .o_D(w_D)
  );

  // always @* begin
  //   if (bus_ROM_cs) begin
  //     w_ROM_addr = bus_ROM_addr;
  //     w_ROM_data = bus_ROM_data;
  //   end else begin
  //     w_ROM_addr = w_CPU_ROM_addr;
  //     w_ROM_data = ROM[w_ROM_addr];
  //   end
  // end

  wire [15:0] w_ROM_data;

  wire [15:0] w_ROM_addr;

  assign w_ROM_addr =  /*bus_ROM_cs ? */ bus_ROM_addr;  // : w_CPU_ROM_addr;
  //assign w_ROM_data = (bus_ROM_cs && bus_ROM_write) ? i_bus_ROM_data : ROM[w_ROM_addr];
  //assign o_bus_ROM_data = ROM[w_ROM_addr];  //bus_ROM_write ? 16'hZZ : w_ROM_data;

  //assign bus_ROM = bus_ROM_write ? 16'hZZ : ROM[w_ROM_addr];


  wire w_tolcd, w_ram_write, w_read_uart, w_write_uart;

  //   assign w_tolcd = o_ramaddr == 16'h4000;
  //   assign w_read_uart = o_ramaddr == 16'h4001;
  //   assign w_write_uart = o_ramaddr == 16'h4002;
  //   assign w_ram_write = w_tolcd ? o_ram_write : 1'b0;

  // always @(posedge CLK) begin
  //   if (bus_ROM_write) begin
  //     ROM[bus_ROM_addr] <= i_bus_ROM_data;
  //   end
  // end



  // reg [15:0] RAMs[0:30];
  //reg [15:0] r_D;
  //initial $readmemb("mult.hack", ROM);
  assign i_instruction =  /*r_mode ? ROM[w_rom_addr] :*/ r_inst;
  // initial begin

  //   // `include "mult.bin"
  //   //ROM[0] = 1234;
  //   //$readmemh("rom.txt", ROM);

  // end

  always @(posedge CLK) begin
    if (o_Bus_CS) begin
      // ROM[w_rom_addr] <= o_rom;
      // r_inst <= o_rom;
    end else begin
      r_inst <= o_bus_ROM_data;  //ROM[w_CPU_ROM_addr];
    end
  end

  assign w_CPU_ROM_addr = r_mode ? o_pc_cpu : bus_ROM_addr;


  //wire reset;


endmodule
