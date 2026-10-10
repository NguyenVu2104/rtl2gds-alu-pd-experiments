module tb;
    logic [31:0] a, b, y, expected;
    logic [3:0]  op;
    int          errors = 0;

    alu32 dut (.a(a), .b(b), .op(op), .y(y));

    function automatic logic [31:0] ref_model(input logic [31:0] ra, rb,
                                              input logic [3:0]  rop);
        case (rop)
            4'h0:    return ra + rb;
            4'h1:    return ra - rb;
            4'h2:    return {31'b0, $signed(ra) < $signed(rb)};
            4'h3:    return {31'b0, ra < rb};
            4'h4:    return ra ^ rb;
            4'h5:    return ra | rb;
            4'h6:    return ra & rb;
            4'h7:    return ra << rb[4:0];
            4'h8:    return ra >> rb[4:0];
            4'h9:    return $signed(ra) >>> rb[4:0];
            default: return 32'b0;
        endcase
    endfunction

    initial begin
        for (int i = 0; i < 200000; i++) begin
            a  = $urandom;
            b  = $urandom;
            op = 4'($urandom_range(0, 10));
            if (i % 7 == 0)  a = (i % 2 == 0) ? 32'h8000_0000 : 32'h7FFF_FFFF;
            if (i % 11 == 0) b = a;
            #1;
            expected = ref_model(a, b, op);
            if (y !== expected) begin
                errors++;
                if (errors <= 5)
                    $display("FAIL: op=%0d a=%h b=%h y=%h expected=%h", op, a, b, y, expected);
            end
        end

        if (errors == 0) $display("PASS: 200000 random vectors OK");
        else             $fatal(1, "FAILED: %0d error(s)", errors);
        $finish;
    end
endmodule
