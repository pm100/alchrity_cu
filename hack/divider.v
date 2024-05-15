module clock_divider #(
    parameter DIVIDER = 4
) (

    input  clk,
    output clk_out
);
  reg [$clog2(DIVIDER/2)-1:0] count = 0;
  reg r_clk_out = 0;
  assign clk_out = r_clk_out;
  //reg clk_out;
  always @(posedge clk) begin
    if (count >= (DIVIDER / 2) - 1) begin
      r_clk_out <= ~r_clk_out;
      count <= 0;
    end

    count <= count + 1;
  end

endmodule
