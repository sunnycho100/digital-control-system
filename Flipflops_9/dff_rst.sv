module dff_rst(
    input logic clk, d, R,
    output logic q
);
// active high synchronous reset
always_ff @(posedge clk) begin
    if (R)
        q <= 1'b0;
    else
        q <= d;
end

endmodule