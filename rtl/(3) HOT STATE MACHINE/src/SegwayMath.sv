module Segway_Math(
    // I/O 
    input  logic signed [11:0] PID_cntrl, // Signed 12-bit control from PID
    input  logic        [7:0]  ss_tmr,    // Unsigned 8-bit scaling quantity (soft start)
    input  logic        [11:0] steer_pot, // 12-bit unsigned steering potentiometer
    input  logic               en_steer,  // Enable steering
    input  logic               pwr_up,    // Power up signal

    input  logic               rst_n,     // async active-low reset
    input  logic               clk,       // pipeline clock

    output logic signed [11:0] lft_spd,   // Left speed
    output logic signed [11:0] rgt_spd,   // Right speed
    output logic               too_fast   // Overspeed flag
);

    // ========================================================
    // === SoftStart logic  PIPLINED
    // ========================================================
    logic signed [19:0] PID_scaled;
    logic signed [11:0] PID_ss;

    // 12 x 8 multiply -> 20 bits. ss_tmr treated as +ve magnitude.
    assign PID_scaled = PID_cntrl * $signed({1'b0, ss_tmr}); // (PID_cntrl * ss_tmr) / 256

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            PID_ss <= 12'sd0;
        else
            PID_ss <= PID_scaled[19:8]; // upper 12 bits
    end

    // ========================================================
    // === Steering logic
    // ========================================================
    logic [11:0]        steer_pot_clamped;
    logic signed [11:0] steer_cntrl_clipd;
    logic signed [11:0] steer_cntrl_scaled;

    // Clamp steering pot between 0x200 and 0xE00
    assign steer_pot_clamped =
          (steer_pot < 12'h200) ? 12'h200 :
          (steer_pot > 12'hE00) ? 12'hE00 :
                                   steer_pot;

    // Center around ~0 (signed)
    assign steer_cntrl_clipd = $signed(steer_pot_clamped) - 12'sh7FF;

    // Scale by 3/16: x * (1 + 2) / 16
    // (one adder + shifts, no true mult)
    logic signed [12:0] steer_ext;       // 13-bit sign-extended
    logic signed [12:0] steer_times3;    // 13-bit

    assign steer_ext    = {steer_cntrl_clipd[11], steer_cntrl_clipd};
    assign steer_times3 = steer_ext + (steer_ext <<< 1); // 3*x
    assign steer_cntrl_scaled = (steer_times3 >>> 4);  //[11:0];

    // ========================================================
    // === Combine steering + PID
    // ========================================================
    logic signed [12:0] PID_ext;
    logic signed [12:0] steer_ext_scaled;
    logic signed [12:0] lft_torque, rgt_torque;

    assign PID_ext          = {PID_ss[11], PID_ss};
    assign steer_ext_scaled = {steer_cntrl_scaled[11], steer_cntrl_scaled};

    assign lft_torque = en_steer ? (PID_ext + steer_ext_scaled) : PID_ext;
    assign rgt_torque = en_steer ? (PID_ext - steer_ext_scaled) : PID_ext;

    // ========================================================
    // === Deadzone shaping
    // ========================================================
    logic signed [12:0] lft_shaped, rgt_shaped;

    deadzn_shaping deadzone_inst_lft (
        .torque (lft_torque),
        .pwr_up (pwr_up),
        .shaped (lft_shaped)
    );

    deadzn_shaping deadzone_inst_rgt (
        .torque (rgt_torque),
        .pwr_up (pwr_up),
        .shaped (rgt_shaped)
    );

    // ========================================================
    // === Saturation + overspeed detection
    // ========================================================
    // Saturate to +/-2048 range
    // lft_shaped[12:11] patterns:
    //   01x... => large positive
    //   10x... => large negative
    //   00x/11x => in-range
    //
    function automatic logic signed [11:0] sat_13_to_12(input logic signed [12:0] in);
        logic sign   = in[12];
        logic [1:0] hi = in[12:11];
        begin
            case (hi)
                2'b01:  sat_13_to_12 =  12'sd2047;  // clamp +max
                2'b10:  sat_13_to_12 = -12'sd2048;  // clamp -max
                default: sat_13_to_12 = in[11:0];   // already in range
            endcase
        end
    endfunction

    always_comb begin
        lft_spd = sat_13_to_12(lft_shaped);
        rgt_spd = sat_13_to_12(rgt_shaped);
    end

    // Too fast detection: look at high bits only (>|0x600|)
    // Positive overspeed if magnitude >= 0x600 (0110_0000_0000)
    wire lft_pos_ovr = ~lft_spd[11] &&
                       ( (lft_spd[11:9] >  3'b011) ||
                         (lft_spd[11:9] == 3'b011 && |lft_spd[8:0]) );

    wire rgt_pos_ovr = ~rgt_spd[11] &&
                       ( (rgt_spd[11:9] >  3'b011) ||
                         (rgt_spd[11:9] == 3'b011 && |rgt_spd[8:0]) );

    assign too_fast = lft_pos_ovr | rgt_pos_ovr;

endmodule



module deadzn_shaping(
    input  logic signed [12:0] torque,
    input  logic               pwr_up,
    output logic signed [12:0] shaped
);
    // Signed constants (13-bit)
    localparam logic signed [12:0] MIN_DUTY        = 13'sd168; // 0x0A8 0000000010101000 and 1111111101011000
    localparam logic signed [12:0] LOW_TORQUE_BAND = 13'sd42;  // 0x02A 0000000000101010 and  1111111111010110

    // Dead-zone test without abs(): |torque| > 42  <=> torque > +42 OR torque < -42
    // Convert to bit comparison
    // |torque| > 42  <=>  (torque positive and > +42) or (torque negative and < -42)
    wire torque_neg = torque[12];
    wire gt_deadzone = (~torque_neg & (torque[12:0] > 13'sd42)) |
                   ( torque_neg & (torque[12:0] < -13'sd42));
    // Fast small-signal gain: *4 == <<< 2 (arithmetic shift left)
    wire logic signed [12:0] torque_x4 = torque <<< 2;

    // Compensation add/sub: torque ± MIN_DUTY, chosen by sign bit
    wire logic signed [12:0] torque_comp =
        torque_neg ? (torque - MIN_DUTY) : (torque + MIN_DUTY);

    // Select path: outside dead-zone → compensate; inside → small-signal gain
    wire logic signed [12:0] shaped_raw = gt_deadzone ? torque_comp : torque_x4;

    // Gate with pwr_up
    always_comb begin
        shaped = pwr_up ? shaped_raw : 13'sd0;
    end
endmodule


