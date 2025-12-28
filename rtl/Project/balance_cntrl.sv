


/*
clk,rst_n in 50MHz system clock & active low reset
vld in High whenever new inertial sensor reading (ptch) is ready
ptch[15:0] in Pitch of Segway from
inertial_intf
ptch_rt[15:0] in Pitch rate (degrees/sec). Used for D_term of PID
pwr_up in Asserted when Segway balance control is powered up. Used
to keep ss_tmr at zero until then.
rider_off in Asserted when no rider detected. Zeros out integrator.
steer_pot[11:0] in From A2D_intf (converted from steering potentiometer)
en_steer in Enables steering control
lft_spd[11:0] out 12-bit signed speed of left motor
rght_spd[11:0] out 12-bit signed speed of left motor
too_fast out Rider approaching point of minimal control margin
*/



module balance_cntrl #(
    // fast_sim parameter for fast simulation of soft start timer (default 1 for normal operation)
    parameter fast_sim = 12'd0
)(
    input logic clk,rst_n,pwr_up,vld,rider_off,en_steer,
    input logic signed [15:0] ptch,ptch_rt,
    input logic signed [11:0] steer_pot,
    output logic signed [11:0] lft_spd,rght_spd,
    output logic too_fast
);

//Internmidiate signals for PID and Segway_Math
logic [7:0] ss_tmr;               // Soft start timer output from PID
logic signed [11:0] PID_cntrl;    // PID control output




Segway_Math segway_math_inst (
    .clk(clk), // piplne clk
    .rst_n(rst_n), // async active-low reset
    .PID_cntrl(PID_cntrl),
    .ss_tmr(ss_tmr),
    .steer_pot(steer_pot),
    .en_steer(en_steer),
    .pwr_up(pwr_up),
    .lft_spd(lft_spd),
    .rgt_spd(rght_spd),
    .too_fast(too_fast)
);

PID #(
    .fast_sim(fast_sim)
) pid_inst (
    .clk(clk),
    .rst_n(rst_n),
    .pwr_up(pwr_up),
    .ptch(ptch),
    .ptch_rt(ptch_rt),
    .vld(vld),
    .rider_off(rider_off),
    .PID_cntrl(PID_cntrl),
    .ss_tmr(ss_tmr)
);

endmodule

 