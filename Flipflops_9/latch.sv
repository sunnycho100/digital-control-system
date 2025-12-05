module latch(
    input d, clk,
    output reg q
);

always @ (clk)
    if (clk)
        q <= d;
    // else implicitly inferred as q <= q;

endmodule

// Is the above code correct?

// Why does it correctly infer and model a latch?
// If not, what is wrong with it?

// latch must be sensitive to both d and q... 
// when EN (clk) is on, latch must reflect the change in d instantly. 

module corrected_latch(
    input d, clk,
    output reg q
);

always @ (clk or d)
    if (clk)
        q <= d;
endmodule

// or we could use always_latch