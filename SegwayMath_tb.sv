module SegwayMath_tb();

// inputs //
logic signed [11:0] PID_cntrl;
logic [7:0] ss_tmr;
logic [11:0] steer_pot;
logic en_steer;
logic pwr_up;

// outputs //
logic signed [11:0] lft_spd;
logic signed [11:0] rght_spd;
logic too_fast;

// iDUT instantiation //
SegwayMath iDUT(
    .PID_cntrl(PID_cntrl),
    .ss_tmr(ss_tmr),
    .steer_pot(steer_pot),
    .en_steer(en_steer),
    .pwr_up(pwr_up),
    .lft_spd(lft_spd),
    .rght_spd(rght_spd),
    .too_fast(too_fast)
);

initial begin
    PID_cntrl = 12'h5FF; // ramps from 12'h5FF (+1535) to 12'hE00 (-512)
    ss_tmr = 8'h00; // initially 0, ramps up to 8'hFF (+255)
    en_steer = 1'b0;
    pwr_up = 1'b1;

    // 1. ramp up ss_tmr first
    repeat (255) begin
        #1; // why delay of #1? 
        ss_tmr = ss_tmr + 1'b1;
    end


    // 2. ramp PID_cntrl down
    repeat (2048) begin
        #1;
        PID_cntrl = PID_cntrl - 1'b1;
    end

    $display("YAHOO! Check the waveform.");
    $stop();
end



endmodule