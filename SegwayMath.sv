module SegwayMath(
    input logic signed [11:0] PID_cntrl,   // signed 12-bit control from PID that dictates frwrdrev drive of motors to maintain platform balance
    input logic [7:0] ss_tmr,       // unsigned 8-bit scaling quantity used to provide a soft start to control loop. PID_cntrl is scaled by the timer that ramps up slowly from power on.
    input logic [11:0] steer_pot,   // 12-bit unsigned measure of steering potentiometer, comes from A2D_intf.
    input logic en_steer,           // indicates steering has been enabled. enabled by rider having equal weight distribution on load cells.
    input logic pwr_up,             // if ~pwr_up then both lft_spd & rght_spd are forced to 0

    output logic signed [11:0] lft_spd,    // desired output speed/torque for each of left/right motors.
    output logic signed [11:0] rght_spd,   // 12 bit signed quantity
    output logic too_fast           // if either lft_spd or right_spd exceeds 12'd1792, too_fast asserted
);

///////////////////////////
// 1. Soft Start Scaling //
///////////////////////////

logic signed [11:0] PID_ss;
logic signed [8:0] ss_tmr_ext;
logic signed [19:0] prod;


// zero-extend ss_tmr before...

// assign PID_ss = ( $signed(PID_cntrl) * $signed({1'b0,ss_tmr}) ) >>> 8;

assign ss_tmr_ext = $signed({1'b0, ss_tmr});

// multiplication (8 bit ss_tmr_ext, * 12 bit PID_cntrl = 20 bit)
assign prod = PID_cntrl * ss_tmr_ext;
// >>> 8
assign PID_ss = {prod[19:8]};

///////////////////////
// 2. Steering Input //
///////////////////////

logic [11:0] steer_pot_sat;
logic signed [11:0] steer_sum;
logic signed [13:0] steer_interm;
logic signed [13:0] steer_mult;
logic signed [12:0] steer_cntrl;

logic signed [12:0] PID_ss_ext;

logic signed [12:0] lft_torque;
logic signed [12:0] rght_torque;

// 2-1 clip to 0x200 or 0xE00 (12 bit > 12 bit)
assign steer_pot_sat = (steer_pot < 12'h200) ? 12'h200 :
                       (steer_pot > 12'hE00) ? 12'hE00 :
                       steer_pot;

// 2-2 sum
assign steer_sum = $signed(steer_pot_sat - 12'h7FF);

// 2-3 * 3
assign steer_interm = steer_sum * 3;

// 2-4 / 16
assign steer_mult = {{3{steer_interm[13]}}, steer_interm[13:4]};

// how many bits do we need for steer_mult?
// previously 12 bits (2's comp) 11 bit max val > 2048... log2 (2048 * 3) = 12.585
// we need 13 bits, but 2's comp, therefore 13 + 1 = 14 bits

// BUT due to clipping, it's way less than 2048, therefore, we could reduce one more bit
assign steer_cntrl = steer_mult[12:0]; // is this even ok?

// 2-4 sign-extend PID_ss to sum it up
assign PID_ss_ext = {PID_ss[11], PID_ss};

// 2-5 sum and pass it to lft, rght torque
// steer_cntrl (13 bit signed) + PID_ss_ext (13 bit signed)
assign lft_torque = (en_steer) ? (PID_ss_ext + steer_cntrl) : PID_ss_ext;
assign rght_torque = (en_steer) ? (PID_ss_ext - steer_cntrl) : PID_ss_ext;

/////////////////////////
// 3. Deadzone Shaping //
/////////////////////////


localparam MIN_DUTY = 13'h0A8;
localparam LOW_TORQUE_BAND = 7'h2A;
localparam GAIN_MULT = 4'h4;

// LEFT //
logic signed [13:0] lft_torque_comp; // always leave extra bits in case of OVERFLOW
logic [12:0] lft_abs;
logic signed [15:0] lft_torque_interm; // always leave extra bits in case of OVERFLOW
logic signed [12:0] lft_shaped;

assign lft_torque_comp = (lft_torque[12]) ? (lft_torque - $signed(MIN_DUTY)) : (lft_torque + $signed(MIN_DUTY));

assign lft_abs = (lft_torque[12]) ? -lft_torque : lft_torque;

// MULT by GAIN_MULT which is 4, therefore, 2 more bits to be safe
assign lft_torque_interm = (lft_abs > LOW_TORQUE_BAND) ? 
                            lft_torque_comp : ($signed(GAIN_MULT) * lft_torque);

assign lft_shaped = (pwr_up) ? lft_torque_interm[12:0] : 13'h0000;
// scale lft_torque_interm before assigning

// RIGHT //
logic signed [13:0] rght_torque_comp; // always leave extra bits in case of OVERFLOW
logic [12:0] rght_abs;
logic signed [15:0] rght_torque_interm; // always leave extra bits in case of OVERFLOW
logic signed [12:0] rght_shaped;

assign rght_torque_comp = (rght_torque[12]) ? (rght_torque - $signed(MIN_DUTY)) : (rght_torque + $signed(MIN_DUTY));

assign rght_abs = (rght_torque[12]) ? -rght_torque : rght_torque;

// MULT by GAIN_MULT which is 4, therefore, 2 more bits to be safe
assign rght_torque_interm = (rght_abs > LOW_TORQUE_BAND) ? 
                            rght_torque_comp : ($signed(GAIN_MULT) * rght_torque);

assign rght_shaped = (pwr_up) ? rght_torque_interm[12:0] : 13'h0000;
// scale rght_torque_interm before assigning

/////////////////////////////////////////////
// 4. Final Saturation & Over speed Detect //
/////////////////////////////////////////////

// trying a new method
final_sat_over_detect calculating_both(
    .lft_shaped(lft_shaped),
    .rght_shaped(rght_shaped),
    .too_fast(too_fast),
    .lft_spd(lft_spd),
    .rght_spd(rght_spd)
);

endmodule

// extra module, practicing OOP style
module final_sat_over_detect(
    input logic signed [12:0] lft_shaped, 
    input logic signed [12:0] rght_shaped,

    output logic too_fast, 
    output logic signed [11:0] lft_spd, 
    output logic signed [11:0] rght_spd
);

logic signed [11:0] lft_shaped_sat;
logic signed [11:0] rght_shaped_sat;

// 4.1 13 bit > 12 bit saturation (signed)
assign lft_shaped_sat = (~lft_shaped[12] &&  lft_shaped[11]) ? 12'h7FF :
                        (lft_shaped[12]  && ~lft_shaped[11]) ? 12'h800 :
                        lft_shaped[11:0];

assign rght_shaped_sat = (~rght_shaped[12] &&  rght_shaped[11]) ? 12'h7FF :
                        (rght_shaped[12]  && ~rght_shaped[11]) ? 12'h800 :
                        rght_shaped[11:0];


assign too_fast = (lft_shaped_sat > $signed(12'd1536) || rght_shaped_sat > $signed(12'd1536));

assign lft_spd = lft_shaped_sat;
assign rght_spd = rght_shaped_sat;

endmodule


