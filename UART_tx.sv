module UART_tx(
    input  logic         clk, // 50MHz system clock
    input  logic         rst_n, // active low reset
    
    output logic         TX, // serial data output

    input  logic         trmt, // asserted for 1 clk to initiate transmission
    input  logic [7:0]   tx_data, // byte to transmit
    
    output logic         tx_done // asserted when byte is done transmitting
                                 // stays high till next byte transmitted
);

// LSB D0 goes out first... for 1 BAUD period

// intermediate signals
logic           load;
logic           shift;
logic           transmitting;
logic           set_done;

logic [3:0]     bit_cnt; // counts the number of bits transferred throughout the serial transmitter
logic [12:0]    baud_cnt; // counts the baud rate
logic [8:0]     tx_shft_reg; // data being shifted

// block 1 - counts the number of bits transferred
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        bit_cnt <= '0;
    else if (load) 
        bit_cnt <= '0;
    else if (shift) 
        bit_cnt <= bit_cnt + 1'b1;
    // else hold 
end

// Baud Generator //
// 50MHz / 9600 = 5208

// block 2 - creates the shift logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        baud_cnt <= '0;
    else if (load|shift)
        baud_cnt <= '0;
    else if (transmitting)
        baud_cnt <= baud_cnt + 1'b1;
    // else hold
end

// combinational logic here?
// when do we shift? when baud cnt... 
localparam int unsigned BAUD_COUNT = 5208;
assign shift = (baud_cnt == BAUD_COUNT) & transmitting;

// block 3
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tx_shft_reg <= '0;
    else if (load)
        tx_shft_reg <= {tx_data, 1'b0};
    else if (shift)
        tx_shft_reg <= {1'b1, tx_shft_reg[8:1]};
    // else hold
end

assign TX = tx_shft_reg[0];


// state machine
typedef enum logic {IDLE, TRANSMIT} state_t;
state_t state, nxt_state;

// infer state flops //
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end

always_comb begin
    // defualt outputs //
    load = 1'b0;
    transmitting = 1'b0;
    set_done = 1'b0;
    nxt_state = state;

    case (state)
        IDLE : if (trmt) begin
            load = 1'b1;
            nxt_state = TRANSMIT;
        end
    
        TRANSMIT : begin
            transmitting = 1'b1;
            load = 1'b0;
            // would load be auto 0? or based on prev state?
            if (bit_cnt == 4'b1010) begin
                set_done = 1'b1;
                nxt_state = IDLE;
            end
        end
    endcase
end

// tx_done logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tx_done <= 1'b0;
    else if (load) // behaves as sync rst
        tx_done <= 1'b0; // in progress!
    else if (set_done)
        tx_done <= 1'b1; // when done... set 1
    // else keep tx_done (wtv it had)
end



endmodule