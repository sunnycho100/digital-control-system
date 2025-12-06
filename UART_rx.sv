module UART_rx(
    input  logic       clk,         // 50MHz system clock
    input  logic       rst_n,       // active low reset
    input  logic       clr_rdy,     // knocks down rdy when asserted
    input  logic       RX,          // serial data input
    
    output logic [7:0] rx_data,     // byte received
    output logic       rdy          // asserted when byte received, 
    // stays high till start bit of next byte starts, or until clr_rdy asserted
);

// intermediate signals
logic start, shift, receiving;
logic [3:0] bit_cnt;
logic [12:0] baud_cnt;
logic rx0, rx1; // intermediate 2-ff metastability

// metastability RX
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        rx0 <= 1'b1;
        rx1 <= 1'b1;
        rx_synch <= 1'b1;
    else
        rx0 <= RX;
        rx1 <= rx0;
end

wire rx_synch = rx1;

// receiver detects falling edge of start bit
wire start_edge = (rx0 == 1'b1) & (rx_synch == 1'b0);

// block 1
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        bit_cnt <= '0;
    else if (start)
        bit_cnt <= '0;
    else if (shift)
        bit_cnt <= bit_cnt + 1'b1;
    // else hold
end

// block 2
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        baud_cnt <= '0;
    else if (start|shift)
        // TODO: some logic with start signal
    else if (receiving)
        baud_cnt <= baud_cnt - 1'b1;
    // else hold
end

// block 3
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        rx_data <= '0;
    else if ()
end



endmodule