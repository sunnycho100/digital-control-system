/*
==========================================================================
    
\clk,rst_n in 50MHz system clock & active low reset
TX out Serial data output
trmt in Asserted for 1 clock to initiate transmission
tx_data[7:0] in Byte to transmit
tx_done out Asserted when byte is done transmitting.
Stays high till next byte transmitted

==========================================================================

*/



module UART_tx(
    input   logic           clk, rst_n,            //  50MHz clock & active-low reset
    input   logic           trmt,                  //  Assert 1 clock to initiate transmission
    input   logic   [7:0]   tx_data,               //  Byte to transmit
    output  logic           tx_done,               //  Asserted when byte done
    output  logic           TX                     //  Serial data output
);

    //  Internal Logic
    logic shift, set_done, load, transmitting;
    //  10-bit: {stop(1), data[7:0], start(0)} -> total 10 bits
    logic   [9:0]   tx_shft_reg;
    logic   [3:0]   bit_cnt;

    // State Definition
    typedef enum logic {
        IDLE  = 1'b0,
        TXing = 1'b1
    } state_t;

    state_t state, next_state;

    //==========================================================================
    // FSM - next state / outputs
    //==========================================================================
    always_comb begin
        // Defaults
        next_state   = state;
        load         = 1'b0;
        set_done     = 1'b0;
        transmitting = 1'b0;

        unique case (state)
            IDLE: begin
                if (trmt) begin
                    next_state = TXing;
                    load       = 1'b1;
                end
            end

            TXing: begin
                transmitting = 1'b1;
                if (bit_cnt == 4'd10) begin
                    next_state = IDLE;
                    set_done   = 1'b1;
                end
            end
        endcase
    end

    //==========================================================================
    // FSM - state register
    //==========================================================================
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;

    //==========================================================================
    // tx_done
    //==========================================================================
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            tx_done <= 1'b0;
        else if (load)
            tx_done <= 1'b0;
        else if (set_done)
            tx_done <= 1'b1;
        // else hold value

    //==========================================================================
    // Baud generator (50MHz / 9600 ≈ 5208.33) -> use 5208 clocks/bit
    //==========================================================================
    localparam int unsigned BANDD_COUNT = 5208;   // clocks per bit
    logic   [12:0]  band_cnt;

    // Generate 1-cycle shift enable at end of bit-time while transmitting
    assign shift = transmitting && (band_cnt == BANDD_COUNT-1);

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            band_cnt <= '0;
        else if (load || shift)
            band_cnt <= '0;
        else if (transmitting)
            band_cnt <= band_cnt + 13'd1;
        // else hold

    //==========================================================================
    // Bit counter (counts 10 bits: 1 start + 8 data + 1 stop)
    //==========================================================================
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            bit_cnt <= '0;
        else if (load)
            bit_cnt <= '0;
        else if (shift)
            bit_cnt <= bit_cnt + 4'd1;
        // else hold

    //==========================================================================
    // 10-bit Shift Register
    //   Load: {stop=1, data[7:0], start=0}
    //   Shift: logical right shift, shifting in 1's to keep line high after stop
    //==========================================================================
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            tx_shft_reg <= '1;                        // idle high
        else if (load)
            tx_shft_reg <= {1'b1, tx_data, 1'b0};     // stop, data, start
        else if (shift)
            tx_shft_reg <= {1'b1, tx_shft_reg[9:1]};  // shift-right, fill with 1
        // else hold

    //==========================================================================
    // Serial output
    //==========================================================================
    assign TX = tx_shft_reg[0];

endmodule





























































