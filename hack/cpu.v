module CPU (
    input clk,
    input [15:0] i_instruction,
    input [15:0] i_ram,
    input i_reset,

    output [15:0] o_ram,
    output [15:0] o_pc,
    output [15:0] o_ramaddr,
    output o_ram_write,


    output [15:0] o_D,
    output [15:0] o_A

);

  reg [15:0] pc;
  reg [15:0] D;
  reg [15:0] A;
  assign o_A = A;
  assign o_D = D;

  wire [15:0] w_a_input, w_alu_y;

  wire w_write_A = i_instruction[15] == 0 || i_instruction[5];
  wire w_A_source;
  wire [15:0] w_aluout;
  wire zr, ng;
  // mux 1 => load a from bus or alu
  assign w_a_input = i_instruction[15] == 0 ? i_instruction : w_aluout;

  // mux 2 => Y input to alu either A or RAM
  assign w_alu_y = i_instruction[12] ? i_ram : A;

  assign o_ram = w_aluout;
  assign o_ram_write = i_instruction[3] && i_instruction[15] == 1;
  assign o_pc = pc;
  assign o_ramaddr = A;


  // ALU
  ALU #(16, 16) ALU1 (
      .i_Data1(D),
      .i_Data2(w_alu_y),
      .i_zx(i_instruction[11]),
      .i_nx(i_instruction[10]),
      .i_zy(i_instruction[9]),
      .i_ny(i_instruction[8]),
      .i_f(i_instruction[7]),
      .i_no(i_instruction[6]),
      .o_Result(w_aluout),
      .o_zr(zr),
      .o_ng(ng)
  );

  always @(posedge clk) begin
    if (i_reset) begin
      pc <= 16'b0;
      D  <= 16'b0;
      A  <= 16'b0;
    end else begin
      if ((i_instruction[15]) &&
        ((i_instruction[0] && ~zr && ~ng) ||
        (i_instruction[1] && zr ) ||
        (i_instruction[2] && ng)
         ))
        pc <= A;
      else pc <= pc + 1;
      if (w_write_A) A <= w_a_input;
      if (i_instruction[4] && i_instruction[15]) D <= w_aluout;
    end
  end
endmodule
