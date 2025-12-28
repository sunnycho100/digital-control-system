module steer_en #(
    parameter fast_sim = 0
    )(
    input logic clk,
    input logic rst_n,
    input logic signed [11:0]lft_ld,
    input logic signed [11:0]rght_ld,
    output logic en_steer,
    output logic rider_off
);
    // localparam MIN_RIDER_WT = 12'h200;
    // localparam WT_HYSTERESIS = 12'h40;
    //pre calculated the difference between MIN_RIDER_WT and WT_HYSTERESIS
    localparam signed diff = 13'h01C0;
    //pre calculated the sum between MIN_RIDER_WT and WT_HYSTERESIS
    localparam signed sum = 13'h0240;
    logic signed [12:0] spd_sum;
    logic signed [11:0] spd_diff;
    logic signed [11:0] abs_spd_diff;
    //input to sm machines
    logic sum_lt_min, sum_gt_min, diff_gt_1_4, diff_gt_15_16;
    always_comb begin : input_sm_logic
        spd_sum = lft_ld + rght_ld;
        spd_diff = lft_ld - rght_ld;
        //get the absolute value of spd_diff
        if(spd_diff[11]) begin
            if(spd_diff == -12'sd2048)
                abs_spd_diff = 12'sd2047;
            else
                abs_spd_diff = -spd_diff;
        end
        else begin
            abs_spd_diff = spd_diff;
        end
        //logic for sum_gt_min and sum_lt_min
        if(spd_sum > sum) 
            sum_gt_min = 1'b1;
        else
            sum_gt_min = 1'b0;
        if(spd_sum < diff) 
            sum_lt_min = 1'b1;
        else
            sum_lt_min = 1'b0;

        //logic for diff_gt_1_4 and diff_gt_15_16

        if(abs_spd_diff > $signed({{2{spd_sum[12]}}, spd_sum[12:2]}))
            diff_gt_1_4 = 1'b1;
        else
            diff_gt_1_4 = 1'b0;
        //we need to check if abs_spd_diff > (15/16)*sum
        //we will calculate by doing sum - (1/16)*sum and compare with abs_spd_diff
        if(abs_spd_diff > ($signed(spd_sum) - $signed({{4{spd_sum[12]}}, spd_sum[12:4]})))
            diff_gt_15_16 = 1'b1;
        else
            diff_gt_15_16 = 1'b0;
    end

    
    logic tmr_full;
    logic [25:0] tmr_count;
    //clear timer signal from state machine
    logic clr_tmr;
    wire timer_done;
    generate 
        if(fast_sim) begin : fast_sim_block
            //when the lower 14 bits are all 1, we consider the timer is done
            assign timer_done = tmr_count[13:0] == 14'h3FFF;
        end
        else begin : normal_block
            //clk is 50MHz, so 1.34s is 67,000,000 cycles
            //1/50MHz = 20ns
            //1.34s/20ns = 67,000,000 cycles
            //we round up to 67108863
            //which is 26'h3_FFF_FFF
            assign timer_done = tmr_count == 26'h3_FFF_FFF;
        end
    endgenerate
    //timer counter
    always_ff @(posedge clk) begin
        if(clr_tmr)
            tmr_count <= 26'd0;
        else //always count up
            tmr_count <= tmr_count + 26'd1;            
    end
    //timer full logic
    //generate the full signal when when it reached 1.34 seconds
    always_ff @(posedge clk) begin
        if(clr_tmr)
            tmr_full <= 1'b0;       
        else if(timer_done)
            tmr_full <= 1'b1;
        //else hold the value      
    end

    //instance of state machine
    steer_en_SM SM_inst(
        .clk(clk),
        .rst_n(rst_n),
        .sum_lt_min(sum_lt_min),
        .sum_gt_min(sum_gt_min),
        .diff_gt_1_4(diff_gt_1_4),
        .diff_gt_15_16(diff_gt_15_16),
        .tmr_full(tmr_full),
        .en_steer(en_steer),
        .clr_tmr(clr_tmr),
        .rider_off(rider_off)
    );

endmodule