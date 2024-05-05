module ALU #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 16
) (
    input signed [DATA_WIDTH-1:0] i_Data1,
    input signed [DATA_WIDTH-1:0] i_Data2,
    input                         i_zx,
    input                         i_nx,
    input                         i_zy,
    input                         i_ny,
    input                         i_f,
    input                         i_no,

    output signed [DATA_WIDTH-1:0] o_Result,
    output o_zr,
    output o_ng
);

  wire [DATA_WIDTH-1:0] w_X, w_Y, w_tempX, w_tempY;


  assign w_tempX = i_zx ? 0 : i_Data1;
  assign w_tempY = i_zy ? 0 : i_Data2;
  assign w_X = i_nx ? ~w_tempX : w_tempX;
  assign w_Y = i_ny ? ~w_tempY : w_tempY;

  assign o_Result= (i_f)?
      (i_no)? ~(w_X + w_Y):(w_X + w_Y):
      (i_no)? ~(w_X & w_Y):(w_X & w_Y);
  assign o_zr = (o_Result == 0);
  assign o_ng = (o_Result < 0);
endmodule
