// =============================================================
// PWM11: 11-bit PWM with non-overlap, 50 MHz clock → ~24.41 kHz
// - Free-running 11-bit counter (0..2047)
// - PWM1: high from NONOVERLAP up to 'duty'
// - PWM2: high from NONOVERLAP + duty up to end of period (2047)
// - Both low for NONOVERLAP clocks at the beginning of the period
//   and again for NONOVERLAP clocks between PWM1 falling and PWM2 rising
//   → guaranteed non-overlap between PWM1 and PWM2
// - PWM_synch: 1 cycle pulse when counter wraps (cnt == 0)
// - ovr_I_blank: overcurrent blanking windows after each output turn-on
// =============================================================
module PWM11
(
    input  logic        clk,        // 50 MHz clock
    input  logic        rst_n,      // async active-low reset
    input  logic [10:0] duty,       // duty count (0..2047)
    output logic        PWM1,       // first PWM output
    output logic        PWM2,       // complementary PWM output
    output logic        PWM_synch,  // 1-cycle pulse at counter wrap
    output logic        ovr_I_blank // blanking gate for over-current detect
);

    // ------------------------------------------------------------------
    // 11-bit free-running counter
    // period = 2^11 = 2048 counts → 50e6 / 2048 ≈ 24.41 kHz
    // ------------------------------------------------------------------
    logic [10:0] cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 11'd0;          // async reset to 0
        else
            cnt <= cnt + 11'd1;    // wraps naturally from 2047→0
    end

    // ------------------------------------------------------------------
    // Non-overlap and SR-FF set/reset conditions
    // NONOVERLAP defines the "dead time" between switching events.
    // ------------------------------------------------------------------
    localparam logic [10:0] NONOVERLAP = 11'h040; // 64 counts of dead time

    // Internal control signals for the SR-FF style PWM outputs
    logic pwm_1_set, pwm_1_reset;
    logic pwm_2_set, pwm_2_reset;

    // PWM1:
    //  - stays low from cnt=0 .. NONOVERLAP-1
    //  - goes high once cnt ≥ NONOVERLAP
    //  - goes low again when cnt > duty
    //    (reset has priority if both conditions true)
    assign pwm_1_set   = (cnt == NONOVERLAP);
    assign pwm_1_reset = (cnt >= duty);

    // PWM2:
    //  - low at the start of the period
    //  - goes high once cnt ≥ NONOVERLAP + duty
    //  - goes low at the very end of the period (cnt == 2047)
    // This creates another NONOVERLAP-sized dead time between
    // PWM1 falling and PWM2 rising.
    assign pwm_2_set   = (cnt == NONOVERLAP + duty);
    assign pwm_2_reset = &cnt;  // &cnt == 1 when cnt == 11'b111_1111_1111 (2047)

    // ------------------------------------------------------------------
    // SR-FFs for PWM1 and PWM2 (reset has priority over set)
    // ------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            PWM1 <= 1'b0;            // async clear
        else if (pwm_1_reset)
            PWM1 <= 1'b0;            // reset wins
        else if (pwm_1_set)
            PWM1 <= 1'b1;
        // else: hold previous value
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            PWM2 <= 1'b0;            // async clear
        else if (pwm_2_reset)
            PWM2 <= 1'b0;            // reset wins
        else if (pwm_2_set)
            PWM2 <= 1'b1;
        // else: hold previous value
    end

    // ------------------------------------------------------------------
    // PWM_synch: high for one clock when the counter wraps to 0
    // ------------------------------------------------------------------
    assign PWM_synch = ~(|cnt);//all bits of cnt are 0

    // ------------------------------------------------------------------
    // Over-current blanking windows
    //  - First window: starts NONOVERLAP counts after PWM1 turn-on
    //  - Second window: starts NONOVERLAP counts after PWM2 turn-on
    //  - Each window lasts 128 counts (tunable)
    // NOTE: if NONOVERLAP + duty + 128 > 2047, the second window wraps;
    //       depending on your use-case you may want to clip duty.
    // ------------------------------------------------------------------
    localparam BLANK_LEN = 11'd128;

    wire window1 = (cnt >  NONOVERLAP) &&
                   (cnt <  NONOVERLAP + BLANK_LEN);

    wire window2 = (cnt >  NONOVERLAP + duty) &&
                   (cnt <  NONOVERLAP + duty + BLANK_LEN);

    assign ovr_I_blank = window1 || window2;

endmodule
