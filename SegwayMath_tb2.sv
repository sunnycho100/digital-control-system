module SegwayMath_tb2();

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
    PID_cntrl = 12'h3FF; // ramps from 12'h3FF (+1023) to 12'hE00 (-1024)
    ss_tmr = 8'hFF; // stays at this value for the whole simulation
    en_steer = 1'b1;
    pwr_up = 1'b1;
    steer_pot = 12'h000; // from 12'h000 to 12'hFFE (+4096)

    // PID_cntrl falls throughout... stays at 0 in the end
    repeat (2048) begin
        #10;
        PID_cntrl = PID_cntrl - 1'b1;
        steer_pot = steer_pot + 1'b1;
    end

    // pwr_up falls at the very end of the simulation
    #200;
    pwr_up = 1'b0;
    #200;

    $display("YAHOO! Check the waveform.");
    $stop();
end



endmodule