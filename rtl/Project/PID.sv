



module PID #(
    // fast_sim = 1 → accelerate soft-start and integrator tapping
    // fast_sim = 0 → normal hardware behavior
    parameter bit fast_sim = 1
)(
    input  logic              clk,
    input  logic              rst_n,      // async active-low reset
    input  logic              pwr_up,     // enables soft-start
    input  logic signed [15:0] ptch,      // pitch (error is effectively ptch wrt 0)
    input  logic signed [15:0] ptch_rt,   // pitch rate
    input  logic              vld,        // new inertial sample valid
    input  logic              rider_off,  // clear integrator
    output logic signed [11:0] PID_cntrl, // saturated PID output
    output logic        [7:0]  ss_tmr     // soft-start ramp (0→255)
);

    //======================================================================
    // Internal wires / regs
    //======================================================================
    logic signed [9:0]  ptch_err_sat;  // pitch error limited to ±512
    logic signed [14:0] P_term;
    logic signed [12:0] D_term;
    logic signed [14:0] I_term;
    logic signed [15:0] PID_pre_sat;
    logic signed [17:0] integrater;    // integrator accumulator

    // Extended P/I/D for 16-bit summation
    logic signed [15:0] P_term_ext;
    logic signed [15:0] I_term_ext;
    logic signed [15:0] D_term_ext;

    // Soft-start increment value (depends on FAST_SIM)
    logic [26:0] fast_sim_inc;

    //======================================================================
    // Parameter: proportional gain
    //======================================================================
    parameter logic [4:0] P_COEFF = 5'h09;

    //======================================================================
    // Pitch saturation to 10 bits (±512) using bit checks
    //======================================================================
    // If upper bits [15:10] are all 0 or all 1 → pass through lower 10 bits.
    // Otherwise saturate to +511 or -512.
    assign ptch_err_sat =
        ptch[15] ?
           ( ~(&ptch[14:9]) ? 10'h200 : ptch[9:0]) :   // negative side
           (  |ptch[14:9]  ? 10'h1FF : ptch[9:0]);    // positive side

    //======================================================================
    // Proportional term
    //======================================================================
    assign P_term = ptch_err_sat * $signed(P_COEFF);

    //======================================================================
    // Integrator (I-term) with overflow protect
    //======================================================================
    // Sign-extend 10-bit error to 18 bits
    logic signed [17:0] err18, sum, integrator_nxt;
    logic ov;

    assign err18 = {{8{ptch_err_sat[9]}}, ptch_err_sat};
    assign sum   = integrater + err18;

    // Signed overflow detect: inputs same sign, result flipped
    assign ov = (integrater[17] == err18[17]) && (integrater[17] != sum[17]);

    always_comb begin
        if (rider_off)          integrator_nxt = '0;   // clear when rider off
        else if (vld && !ov)    integrator_nxt = sum;  // accumulate on valid sample
        else                    integrator_nxt = integrater; // hold
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            integrater <= '0;
        else
            integrater <= integrator_nxt;
    end



    // ---------------- I_term tap & saturation ---------------- GENERATE BLOCK ----
    generate
        if (fast_sim) begin : g_fast
            // For fast_sim, tap bits [15:1] (larger step size) and saturate
            localparam signed [14:0] I_MAX = 15'sd16383;
            localparam signed [14:0] I_MIN = -15'sd16384;

            wire signed [14:0] I_fast_raw = integrater[15:1];

            assign I_term =
                integrater[17] ?
                    ( ~(&integrater[17:15]) ? I_MIN : I_fast_raw ) :
                    (  |integrater[17:15]   ? I_MAX : I_fast_raw );
        end else begin : g_normal
            // Normal mode: tap bits [17:6] ({3 sign bits, 12 data bits})
            assign I_term = { {3{integrater[17]}}, integrater[17:6] };
        end
    endgenerate

    //======================================================================
    // Derivative term
    //======================================================================
    // D_term ≈ -ptch_rt >> 6  (negative sign gives damping)
    assign D_term = -{{3{ptch_rt[15]}}, ptch_rt[15:6]};

    //======================================================================
    // Soft Start Timer
    //======================================================================
    logic [26:0] long_tmr, long_nxt, first_mux;

    // fast_sim controls the step size of the soft-start ramp
    generate
        if (fast_sim)
            assign fast_sim_inc = 27'd256;  // big steps for simulation
        else
            assign fast_sim_inc = 27'd1;    // slow ramp in real hardware
    endgenerate

    // Add or hold (saturate when upper 8 bits are all 1)
    assign first_mux =
        (&long_tmr[26:19]) ? long_tmr : (long_tmr + fast_sim_inc);

    // Gate by pwr_up
    assign long_nxt = pwr_up ? first_mux : 27'd0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            long_tmr <= 27'd0;
        else
            long_tmr <= long_nxt;
    end

    // Upper 8 bits drive soft-start timer output
    assign ss_tmr = long_tmr[26:19];

    //======================================================================
    // PID output: sum P, I, D and saturate to 12-bit signed
    //======================================================================
    // Sign-extend P, I, D to 16 bits for summation
    assign P_term_ext = {{1{P_term[14]}}, P_term};
    assign I_term_ext = {{1{I_term[14]}}, I_term};
    assign D_term_ext = {{3{D_term[12]}}, D_term};

    // Sum all three terms
    assign PID_pre_sat = P_term_ext + I_term_ext + D_term_ext;

    logic signed [11:0] PID_cntrl_pip;

    // Saturate to 12-bit signed range [-2048, +2047]
    assign PID_cntrl_pip =
        PID_pre_sat[15] ?
            // negative side
            ( ~(&PID_pre_sat[15:11]) ? -12'sd2048 : PID_pre_sat[11:0] ) :
            // positive side
            (  |PID_pre_sat[15:11]   ?  12'sd2047 : PID_pre_sat[11:0] );


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PID_cntrl <= 12'sd0;
        end
        else begin
            PID_cntrl <= PID_cntrl_pip;
        end
    end

endmodule



