module SPI_mnrch (
    input  logic        clk,
    input  logic        rst_n,

    // SPI interface
    output logic        SS_n,
    output logic        SCLK,
    output logic        MOSI,
    input  logic        MISO,

    // Control / data
    input  logic        wrt,
    input  logic [15:0] wt_data,
    output logic        done,
    output logic [15:0] rd_data
);

    // ----------------------------------------------------------------
    // State machine declaration
    // ----------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,
        FRONT_PORCH,
        WORK_HORSE,
        BACK_PORCH
    } state_t;

    state_t state, nxt_state;

    // ----------------------------------------------------------------
    // State register
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    // ----------------------------------------------------------------
    // Control signals for SM and datapath
    // ----------------------------------------------------------------
    logic shft_imm;
    logic done15;
    logic init;
    logic shft;
    logic ld_SCLK;
    logic set_done;

    // ----------------------------------------------------------------
    // State machine next-state and control logic
    // ----------------------------------------------------------------
    always_comb begin
        // Defaults
        init     = 1'b0;
        shft     = 1'b0;
        ld_SCLK  = 1'b0;
        set_done = 1'b0;
        nxt_state = state;

        unique case (state)
            IDLE: begin
                ld_SCLK = 1'b1;  // Moore output in IDLE
                if (wrt) begin
                    init      = 1'b1;
                    nxt_state = FRONT_PORCH;
                end
            end

            FRONT_PORCH: begin
                if (shft_imm)
                    nxt_state = WORK_HORSE;
                // else: stay in FRONT_PORCH
            end

            WORK_HORSE: begin
                if (done15) begin
                    nxt_state = BACK_PORCH;
                end else if (shft_imm) begin
                    shft = 1'b1;
                end
                // else: stay in WORK_HORSE
            end

            BACK_PORCH: begin
                if (shft_imm) begin
                    ld_SCLK  = 1'b1;
                    set_done = 1'b1;
                    shft     = 1'b1;
                    nxt_state = IDLE;
                end
                // else: stay in BACK_PORCH
            end

            default: begin
                // Fallback to IDLE behavior
                ld_SCLK = 1'b1;
                nxt_state = IDLE;
            end
        endcase
    end

    // ----------------------------------------------------------------
    // Bit counter (counts 16 bits)
    // ----------------------------------------------------------------
    logic [3:0] bit_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= '0;
        else if (init)
            bit_cnt <= '0;
        else if (shft)
            bit_cnt <= bit_cnt + 4'd1;
        // else: hold
    end

    assign done15 = &bit_cnt;  // all ones => 15

    // ----------------------------------------------------------------
    // SCLK divider and timing decode
    // ----------------------------------------------------------------
    logic [3:0] SCLK_div;
    logic       smpl;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            SCLK_div <= 4'd0;
        else if (ld_SCLK)
            SCLK_div <= 4'b1011;
        else
            SCLK_div <= SCLK_div + 4'd1;
    end

    assign SCLK     = SCLK_div[3];
    assign shft_imm = (SCLK_div == 4'b1111); // just before falling edge
    assign smpl     = (SCLK_div == 4'b0111); // just before rising edge

    // ----------------------------------------------------------------
    // MISO sampling
    // ----------------------------------------------------------------
    logic MISO_smpl;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            MISO_smpl <= 1'b0;
        else if (smpl)
            MISO_smpl <= MISO;
        // else: hold
    end

    // ----------------------------------------------------------------
    // Shift register for MOSI / rd_data
    // ----------------------------------------------------------------
    logic [15:0] shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= '0;
        else if (init)
            shift_reg <= wt_data;
        else if (shft)
            shift_reg <= {shift_reg[14:0], MISO_smpl};
        // else: hold
    end

    assign MOSI    = shift_reg[15];
    assign rd_data = shift_reg;

    // ----------------------------------------------------------------
    // done flag (SR-style)
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            done <= 1'b0;
        else if (init)
            done <= 1'b0;
        else if (set_done)
            done <= 1'b1;
        // else: hold
    end

    // ----------------------------------------------------------------
    // SS_n (slave select) SR-style
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            SS_n <= 1'b1;
        else if (init)
            SS_n <= 1'b0;
        else if (set_done)
            SS_n <= 1'b1;
        // else: hold
    end

endmodule