module dff_rst_en (
    input logic clk, en, rst_n, d,
    output logic q
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= 1'b0;
    else if (en)
        q <= d;
    // else implied q <= q;
end


endmodule