module UART_rx(
    input  logic       clk,         // 50MHz system clock
    input  logic       rst_n,       // active low reset
    input  logic       clr_rdy,     // knocks down rdy when asserted
    
    output logic [7:0] rx_data,     // byte received
    output logic rdy                // asserted when byte received, 
    // stays high till start bit of next byte starts, or until clr_rdy asserted
);

// intermediate signals
logic start, shift, receiving;

// block 1
always_ff @(posedge clk, negedge rst_n) begin
    
end




endmodule