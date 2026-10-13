module alu32_reg (
  input  logic        clk,
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic [3:0]  op,
  output logic [31:0] y
);
  logic [31:0] a_q, b_q, y_d;
  logic [3:0]  op_q;

  always_ff @(posedge clk) begin
    a_q  <= a;
    b_q  <= b;
    op_q <= op;
  end

  alu32 u_alu (
    .a  (a_q),
    .b  (b_q),
    .op (op_q),
    .y  (y_d)
  );

  always_ff @(posedge clk) y <= y_d;
endmodule
