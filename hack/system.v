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
    input bus_RAM_cs  // 1 = shell owns the bus


);


  // core of hack system

  reg [15:0] ROM[0:1000];
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

  assign w_ROM_addr = bus_ROM_cs ? bus_ROM_addr : w_CPU_ROM_addr;
  assign w_ROM_data = (bus_ROM_cs && bus_ROM_write) ? i_bus_ROM_data : ROM[w_ROM_addr];
  assign o_bus_ROM_data = ROM[w_ROM_addr];  //bus_ROM_write ? 16'hZZ : w_ROM_data;

  //assign bus_ROM = bus_ROM_write ? 16'hZZ : ROM[w_ROM_addr];


  wire w_tolcd, w_ram_write, w_read_uart, w_write_uart;

  //   assign w_tolcd = o_ramaddr == 16'h4000;
  //   assign w_read_uart = o_ramaddr == 16'h4001;
  //   assign w_write_uart = o_ramaddr == 16'h4002;
  //   assign w_ram_write = w_tolcd ? o_ram_write : 1'b0;

  always @(posedge CLK) begin
    if (bus_ROM_write) begin
      ROM[bus_ROM_addr] <= w_ROM_data;
    end
  end



  // reg [15:0] RAMs[0:30];
  //reg [15:0] r_D;
  //initial $readmemb("mult.hack", ROM);
  assign i_instruction =  /*r_mode ? ROM[w_rom_addr] :*/ r_inst;
  initial begin

    // `include "mult.bin"
    ROM[0] = 1234;

  end

  always @(posedge CLK) begin
    if (o_Bus_CS) begin
      // ROM[w_rom_addr] <= o_rom;
      // r_inst <= o_rom;
    end else begin
      r_inst <= ROM[w_CPU_ROM_addr];
    end
  end

  assign w_CPU_ROM_addr = r_mode ? o_pc_cpu : bus_ROM_addr;


  //wire reset;


endmodule
