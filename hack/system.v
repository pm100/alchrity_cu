
module System (
    input CLK,

    inout [15:0] bus_RAM,
    inout [15:0] bus_ROM,

    inout [15:0] bus_RAM_addr,
    inout [15:0] bus_ROM_addr,

    input bus_RAM_write,
    input bus_ROM_write

);


  // core of hack system

  reg [15:0] ROM[0:1000];
  reg [15:0] RAM[0:1000];

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


  wire w_tolcd, w_ram_write, w_read_uart, w_write_uart;

  //   assign w_tolcd = o_ramaddr == 16'h4000;
  //   assign w_read_uart = o_ramaddr == 16'h4001;
  //   assign w_write_uart = o_ramaddr == 16'h4002;
  //   assign w_ram_write = w_tolcd ? o_ram_write : 1'b0;



  wire [15:0] w_D, w_A;

  // reg [15:0] RAMs[0:30];
  //reg [15:0] r_D;
  //initial $readmemb("mult.hack", ROM);
  assign i_instruction =  /*r_mode ? ROM[w_rom_addr] :*/ r_inst;
  initial begin

    // `include "mult.bin"

  end
  reg [15:0] r_inst;
  always @(posedge CLK) begin
    if (o_Bus_CS) begin
      ROM[w_rom_addr] <= o_rom;
      r_inst <= o_rom;
    end else begin
      r_inst <= ROM[w_rom_addr];
    end
  end

  wire [15:0] w_rom_addr;
  assign w_rom_addr = r_mode ? o_pc_cpu : o_pc_loader;
  wire [15:0] o_ram, o_rom, o_pc_loader, o_pc_cpu, o_ramaddr;
  wire o_rom_write, o_ram_write, o_bus_wr;
  wire o_Bus_CS;
  wire [15:0] i_instruction, i_ram;
  wire w_rom_DV = o_bus_wr;
  reg  r_mode = 0;  // 0 = boot 1 = run
  //wire reset;


endmodule
