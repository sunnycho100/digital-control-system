//Inside Auth_blk.sv should be uart_rx module and SM wth 3 states:
// pwr_up is asserted upon reception of'G' (0x47) over uart_rx line it is deasserted after the last reception was 'S' and the rider_of signal is high.

module Auth_blk #(
    parameter authorizationn_ON  = 8'h47, //'G'
    parameter authorizationn_OFF = 8'h53 //'S'
)(
    input  logic clk,
    input  logic rst_n,
    input  logic RX,
    output logic pwr_up,
    input  logic rider_off
);

    // UART RX signals
    logic        data_vld, clr_rdy;
    logic [7:0]  rx_data;

    UART_rx u_rx (
        .clk    (clk),
        .rst_n  (rst_n),
        .RX     (RX),
        .clr_rdy(clr_rdy),
        .rx_data(rx_data),
        .rdy    (data_vld)
    );

    // ----------------------------------------------------------------
    // 3-state FSM: IDLE -> ARMED -> WAIT
    // IDLE:      waiting for 'G'
    // ARMED:     pwr_up=1, will go to WAIT on 'S' if rider_off==0
    // WAIT:      pwr_up=1, waiting for rider_off==1 and NO new RX byte
    // ----------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,
        ARMED,
        WAIT
    } state_t;

    state_t state, next_state;

    // Sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Combinational
    always_comb begin
        // defaults
        next_state = state;
        clr_rdy    = 1'b0;

        if (data_vld) begin
            clr_rdy = 1'b1;  // always clear when we consume a byte

            unique case (state)
                IDLE: begin
                    if (rx_data == authorizationn_ON)
                        next_state = ARMED;
                end

                ARMED: begin
                    if (rx_data == authorizationn_OFF) begin
                        if (rider_off)
                            next_state = IDLE;
                        else
                            next_state = WAIT;
                    end
                    // a 'G' here just keeps us ARMED; no change needed
                end

                WAIT: begin
                    // In WAIT, only 'G' brings us back to ARMED.
                    // An 'S' is ignored (matches original behavior).
                    if (rx_data == authorizationn_ON)
                        next_state = ARMED;
                end
            endcase

        end else begin
            // No new byte this cycle
            if (state == WAIT && rider_off)
                next_state = IDLE;
        end
    end

    // pwr_up asserted in ARMED and WAIT
    assign pwr_up = (state != IDLE);

endmodule









/*
==========================================================================
clk,rst_n in 50MHz system clock & active low
reset
RX in Serial data input
clr_rdy In Knocks down
rdy when asserted
rx_data[7:0] out Byte received
rdy out Asserted when byte received. Stays
high till start bit of next byte starts,
or until
clr_rdy asserted
==========================================================================
*/

module UART_rx(
    input   logic           clk, rst_n,        // 50MHz clock & active-low reset
    input   logic           RX,                // Serial data input
    input   logic           clr_rdy,           // Clear 'rdy' when asserted
    output  logic   [7:0]   rx_data,           // Byte received
    output  logic           rdy                // Stays high till next start or clr_rdy
);

    //==========================================================================
    // Sync RX to clk (2-FF)
    //==========================================================================
    logic rx_s1, rx_s2, rx_prev;
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n) begin
            rx_s1  <= 1'b1;
            rx_s2  <= 1'b1;
            rx_prev<= 1'b1;
        end else begin
            rx_s1   <= RX;
            rx_s2   <= rx_s1;
            rx_prev <= rx_s2;
        end
    wire RX_SYNC = rx_s2;

    // Falling-edge detect on start bit
    wire start_edge = (rx_prev == 1'b1) && (RX_SYNC == 1'b0);

    //==========================================================================
    // Internal Logic
    //==========================================================================
    logic         shift, set_rdy, start, receiving;
    logic  [3:0]  bit_cnt;         // counts 0..9 (10 samples: start, d0..d7, stop)
    logic  [12:0] band_cnt;        // baud countdown
    logic  [8:0]  rx_shft_reg;     // 9-bit shift reg per spec (start falls off)

    //==========================================================================
    // State machine
    //==========================================================================
    typedef enum logic {
        IDLE  = 1'b0,
        RXing = 1'b1
    } state_t;

    state_t state, next_state;

    always_comb begin
        next_state = state;
        start      = 1'b0;
        set_rdy    = 1'b0;
        receiving  = 1'b0;

        unique case (state)
            IDLE: begin
                if (start_edge) begin
                    next_state = RXing;
                    start      = 1'b1;  // kick off half-bit delay
                end
            end

            RXing: begin
                receiving = 1'b1;
                // we perform 10 shifts total: start + 8 data + stop
                if (bit_cnt == 4'd10) begin
                    next_state = IDLE;
                    set_rdy    = 1'b1;  // byte ready after stop-bit mid-sample
                end
            end
        endcase
    end

    // state register
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n) state <= IDLE;
        else        state <= next_state;

    // rdy register
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            rdy <= 1'b0;
        else if (clr_rdy || start)       // clear on explicit clear or next start
            rdy <= 1'b0;
        else if (set_rdy)
            rdy <= 1'b1;
        // else hold

    //==========================================================================
    // Baud tick: mid-bit sampling
    // On start: wait HALF a bit to mid-start, then FULL bits thereafter.
    // We shift on EVERY mid-bit, including start & stop => total 10 shifts.
    //==========================================================================
    localparam int unsigned BANDD_COUNT = 5208;

    // 1-cycle shift pulse at mid-bit while receiving
    assign shift = receiving && (band_cnt == 13'd0);

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            band_cnt <= 13'd0;
        else if (start)
            band_cnt <= (BANDD_COUNT/2 - 1);  // to middle of START bit
        else if (shift)
            band_cnt <= (BANDD_COUNT - 1);    // subsequent mid-bit to mid-bit
        else if (receiving)
            band_cnt <= band_cnt - 13'd1;
        // else hold

    // bit counter: count each mid-bit sample (start + 8 data + stop) => 10
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            bit_cnt <= '0;
        else if (start)
            bit_cnt <= 4'd0;
        else if (shift)
            bit_cnt <= bit_cnt + 4'd1;
        // else hold

    //==========================================================================
    // Right-shift capture (LSB-first)
    // We shift on ALL 10 mid-bit samples:
    //   1) START (0) enters MSB first, then data bits d0..d7, then STOP (1).
    // After 10 shifts the 9-bit reg holds: {STOP, d7, d6, d5, d4, d3, d2, d1, d0}
    // Start bit has "fallen off". rx_data = bits [7:0] = {d7..d0}
    //==========================================================================
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            rx_shft_reg <= 9'h1FF;                       // idle-high pattern
        else if (start)
            rx_shft_reg <= 9'h1FF;                       // re-init before capture
        else if (shift)
            rx_shft_reg <= {RX_SYNC, rx_shft_reg[8:1]};  // RIGHT shift, insert at MSB

    assign rx_data = rx_shft_reg[7:0];

endmodule














