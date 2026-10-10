module alu32 (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  op,
    output logic [31:0] y
);

    localparam logic [3:0] OP_ADD  = 4'h0;
    localparam logic [3:0] OP_SUB  = 4'h1;
    localparam logic [3:0] OP_SLT  = 4'h2;
    localparam logic [3:0] OP_SLTU = 4'h3;
    localparam logic [3:0] OP_XOR  = 4'h4;
    localparam logic [3:0] OP_OR   = 4'h5;
    localparam logic [3:0] OP_AND  = 4'h6;
    localparam logic [3:0] OP_SLL  = 4'h7;
    localparam logic [3:0] OP_SRL  = 4'h8;
    localparam logic [3:0] OP_SRA  = 4'h9;

    logic [31:0] add_res;
    logic [32:0] sub_ext;
    logic [31:0] sub_res;
    logic [31:0] slt_res;
    logic [31:0] sltu_res;

    logic [31:0] shl1, shl2, shl4, shl8, shl16;
    logic [31:0] shr1, shr2, shr4, shr8, shr16;
    logic        sign;

    assign add_res = a + b;

    // 33-bit subtraction: {carry, result}
    assign sub_ext = {1'b0, a} + {1'b0, ~b} + 33'd1;
    assign sub_res = sub_ext[31:0];

    // Signed less-than
    assign slt_res = {31'b0, (a[31] == b[31]) ? sub_ext[31] : a[31]};

    // Unsigned less-than: no carry means a < b
    assign sltu_res = {31'b0, ~sub_ext[32]};

    // Sign bit used to fill the vacated bits of an arithmetic right shift
    assign sign = (op == OP_SRA) & a[31];

    // Left shift: 1, 2, 4, 8, 16
    assign shl1  = b[0] ? {a[30:0], 1'b0}       : a;
    assign shl2  = b[1] ? {shl1[29:0], 2'b00}   : shl1;
    assign shl4  = b[2] ? {shl2[27:0], 4'b0000} : shl2;
    assign shl8  = b[3] ? {shl4[23:0], 8'b0}    : shl4;
    assign shl16 = b[4] ? {shl8[15:0], 16'b0}   : shl8;

    // Right shift: logical or arithmetic
    assign shr1  = b[0] ? {sign, a[31:1]}           : a;
    assign shr2  = b[1] ? {{2{sign}},  shr1[31:2]}  : shr1;
    assign shr4  = b[2] ? {{4{sign}},  shr2[31:4]}  : shr2;
    assign shr8  = b[3] ? {{8{sign}},  shr4[31:8]}  : shr4;
    assign shr16 = b[4] ? {{16{sign}}, shr8[31:16]} : shr8;

    always_comb begin
        case (op)
            OP_ADD:  y = add_res;
            OP_SUB:  y = sub_res;
            OP_SLT:  y = slt_res;
            OP_SLTU: y = sltu_res;
            OP_XOR:  y = a ^ b;
            OP_OR:   y = a | b;
            OP_AND:  y = a & b;
            OP_SLL:  y = shl16;
            OP_SRL:  y = shr16;
            OP_SRA:  y = shr16;
            default: y = 32'b0;
        endcase
    end

endmodule
