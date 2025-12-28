


// sync a reset push button
module rst_synch(
    input  RST_n,
    input  clk,
    output reg rst_n
);

// Internal Register
reg q;

// First stage (metastability filter)
always @ (posedge clk or negedge RST_n) begin
    if (!RST_n)
        q <= 1'b0;
    else
        q <= 1'b1; // set on
end

// Final stage
always @ (posedge clk or negedge RST_n) begin
    if (!RST_n)
        rst_n <= 1'b0;
    else
        rst_n <= q;
end

endmodule

