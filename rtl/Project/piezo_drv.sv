// module piezo_drv #(
//     parameter fast_sim = 0
// )(
//     input logic clk,
//     input logic rst_n,
//     input logic en_steer,
//     input logic too_fast,
//     input logic batt_low,
//     output logic piezo,
//     output logic piezo_n
// );
//     //add a parameter for fast_sim mode
//     localparam int unsigned G6 = 15944;//1568 Hz 1568/2 = 784
//     localparam int unsigned C7 = 11944;//2093 Hz 2093/2 = 1046
//     localparam int unsigned E7 = 9480;//2637 Hz 2637/2 = 1318 
//     localparam int unsigned G7 = 7972;//3136 Hz 3136/2 = 1568
//     //counter timer for piezo duration
//     logic[25:0] clk_counter;
//     logic [13:0] freq_counter;
//     //the half frequency of the current note being played
//     logic [13:0] current_frequency;
//     //asserted when we need to move to the next note(clk_counter finished counting)
//     logic next_note;
//     //asserted to reset the 3 second timer when we start playing fanfare or reverse fanfare
//     logic reset_timer;
//     //repeat counter
//     //generate a signal after we reset it 
//     logic[27:0] repeat_counter;
//     logic three_sec;
    
//     generate
//         if (fast_sim)
//             always_ff @(posedge clk) begin
//                 if(next_note)
//                     clk_counter <= 0;
//                 else 
//                     //if fast_sim is enabled, increment by a value of 64
//                     clk_counter <= clk_counter + 64;
//             end
//         else
//             always_ff @(posedge clk) begin
//                 if(next_note)
//                     clk_counter <= 0;
//                 else
//                     clk_counter <= clk_counter + 1;
//             end
//     endgenerate
//     //logic [24:0] counter_duration;
//     //no need for reset, just reset when we move to next note
    
//     //each state represents a note to be played
//     typedef enum logic [3:0] {
//         IDLE,
//         NOTE1,
//         NOTE2,
//         NOTE3,
//         NOTE4,
//         NOTE5,
//         NOTE6
//     } state_t;
//     state_t state, next_state;
//     always_ff @(posedge clk or negedge rst_n) begin
//         if (!rst_n)
//             state <= IDLE;
//         else
//             state <= next_state;
//     end
//     logic clk_23, clk_22, clk_25;
//     //combinational logic for next state and outputs
//     assign clk_23 = clk_counter[23]; //when bit 23 is set, we have counted 2^23 cycles
//     assign clk_22 = clk_counter[22]; //when bit 22 is set, we have counted 2^22 cycles
//     assign clk_25 = clk_counter[25]; //when bit 25 is set, we have counted 2^25 cycles
//     logic idle;
//     always_comb begin
//         next_state = state;
//         current_frequency = 12'd0;
//         next_note = 0;
//         reset_timer = 0;
//         idle = 0;
//         //state transitions - each note lasts a certain duration, then
//         //go to their own notes based on the inputs
//         unique case (state)
//             IDLE: begin
//                 idle = 1;
//                 if(too_fast) begin
//                     next_state = NOTE1;
//                     next_note = 1;
//                 end
//                 //we only reset the timer when we start playing a note
//                 //so it can continue counting while in too_fast state
//                 //the three_sec signal will be preseted so we can used it right away,               
//                 else if(batt_low && three_sec) begin
//                     next_state = NOTE6;
//                     next_note = 1;
//                     //the reset_timer signal to reset the three second timer
//                     //and clear the three_sec flag
//                     reset_timer = 1;
//                 end            
//                 else if (en_steer && three_sec) begin
//                     next_state = NOTE1;
//                     next_note = 1;
//                     reset_timer = 1;
//                 end
//             end
//             //too_fast will play the first three notes, and repeat back
//             NOTE1: begin
//                 current_frequency = G6; // G6
//                 //2^23 clk cycles
//                 if (clk_23) begin
//                     //too_fast has priority over batt_low
//                     if(batt_low&&~too_fast)
//                         next_state = IDLE;
//                     else
//                         next_state = NOTE2;
//                     next_note = 1;
//                 end
//             end
//             NOTE2: begin
//                 current_frequency = C7; // C7
//                 //2^23 clk cycles
//                 if (clk_23) begin
//                     if(batt_low&&~too_fast)
//                         next_state = NOTE1;
//                     else
//                         next_state = NOTE3;
//                     next_note = 1;
//                 end
//             end
//             NOTE3: begin
//                 current_frequency = E7; // E7
//                 if (clk_23) begin
//                     if(too_fast)
//                         next_state = NOTE1;
//                         //repeat the first three notes
//                     else if(batt_low)
//                         next_state = NOTE2;
//                     else
//                         next_state = NOTE4;
//                     next_note = 1;
//                 end
//             end
//             //too_fast won't reach here
//             //the fourth notes are combined
//             NOTE4: begin
//                 current_frequency = G7; // G7
//                 //2^23 clk cycles+ 2^22 clk cycles
//                 if (clk_23&&clk_22) begin
//                     //goes to NOTE4_2 no matter what
//                     if(batt_low)
//                         next_state = NOTE3;
//                     else
//                         next_state = NOTE5;
//                     next_note = 1;
//                 end
//             end
//             NOTE5: begin
//                 current_frequency = E7; // E7
//                 //2^22 clk cycles
//                 if (clk_22) begin
//                     //goes to NOTE4 if batt_low
//                     if(batt_low)
//                         next_state = NOTE4;
//                     else
//                         next_state = NOTE6;
//                     next_note = 1;
//                 end
//             end
//             NOTE6: begin
//                 current_frequency = G7; // G7
//                 //2^25 clk cycles
//                 if (clk_25) begin
//                     if(batt_low)
//                         next_state = NOTE5;
//                     else
//                         next_state = IDLE;
//                     next_note = 1;
//                 end
//             end
//             default: begin
//                 //don't cares
//                 current_frequency = 12'hxxx;
//                 reset_timer = 1'bx;
//                 next_note = 1'bx;
//             end
//         endcase
//     end

//     logic toggle_piezo;
//     //bit wise and when frquency counter reaches 0 and not idling
//     assign toggle_piezo = ~(|freq_counter)&&(~idle);
//     //frequency counter for piezo toggling
//     //no need for reset, just reset when we move to next note
//     //counter down to toggle piezo output
//     generate
//         if (fast_sim)
//             always_ff @(posedge clk) begin
//                 if (next_note||toggle_piezo)
//                 //load half frequency of current note
//                     freq_counter <= current_frequency;
//                 else 
//                     //if fast_sim is enabled, increment by a value of 64
//                     if($signed({1'b0, freq_counter})-64<0)
//                         freq_counter <= 0;
//                     else if(~idle)
//                         freq_counter <= freq_counter - 64;
//             end
//         else
//             always_ff @(posedge clk) begin
//                 if (next_note||toggle_piezo)
//                     freq_counter <= current_frequency;
//                 else  if(~idle)
//                     freq_counter <= freq_counter - 1'b1;
//             end
//     endgenerate
//     assign piezo_n = ~piezo;
//     //piezo output logic
//     always_ff @(posedge clk, negedge rst_n) begin
//         //piezo_n is active low
//         if (!rst_n) begin
//             piezo <= 1'b0;
//         end 
//         else if(toggle_piezo) begin
//             piezo <= ~piezo;
//         end
//         else if(idle) begin
//             piezo <= 1'b0;
//         end
//         //else hold value      
//     end
    
//     logic repeat_done;
//     generate
//         if (fast_sim) begin
//             //make the 3second timer faster for simulation
//             assign repeat_done = (repeat_counter == 28'h6_000_000);
//         end
//         else begin
//             //1/(50^6) seconds per clk cycle
//             //3/(1/(50*10^6)) = 150*10^6 cycles for 3 seconds
//             assign repeat_done = (repeat_counter == 28'd150_000_000);
//         end
//     endgenerate
//     //three second timer logic
//     always_ff @(posedge clk, negedge rst_n) begin
//         if (!rst_n) begin
//             //preset three_sec to 1
//             //so we can start playing notes right after reset
//             three_sec <= 1;
//         end
//         else if (reset_timer) begin
//             three_sec <= 0;
//         end
//         else if(repeat_done) begin
//             three_sec <= 1;
//         end
//         //else hold value
//     end
//     generate
//         if(fast_sim) begin         
//             always_ff @(posedge clk, negedge rst_n) begin
//                 if (!rst_n)
//                     repeat_counter <= 0;
//                 else if (reset_timer||repeat_done)  //when fast_sim make it reset faster
//                     repeat_counter <= 0;             
//                 else 
//                     //if fast_sim is enabled, increment by a value of 64
//                     repeat_counter <= repeat_counter + 64;
//                     //in simulation it should be 0.046875 seconds         
//             end
//         end
//         else begin             
//             always_ff @(posedge clk, negedge rst_n) begin
//                 if (!rst_n)
//                     repeat_counter <= 0;
//                 else if (reset_timer||repeat_done) //reset every 3 seconds
//                     repeat_counter <= 0;
//                 else 
//                     repeat_counter <= repeat_counter + 1;
//             end
//         end
//     endgenerate

// endmodule
module piezo_drv#(
    parameter fast_sim = 0
)(
    input logic clk,
    input logic rst_n,
    input logic en_steer,
    input logic too_fast,
    input logic batt_low,
    output logic piezo,
    output logic piezo_n
);
    //add a parameter for fast_sim mode
    
    localparam int unsigned G6 = 15944;//1568 Hz 1568/2 = 784
    localparam int unsigned C7 = 11944;//2093 Hz 2093/2 = 1046
    localparam int unsigned E7 = 9480;//2637 Hz 2637/2 = 1318 
    localparam int unsigned G7 = 7972;//3136 Hz 3136/2 = 1568
    //counter timer for piezo duration
    logic[3:0] clk_counter;
    logic [13:0] freq_counter;
    //the half frequency of the current note being played
    logic [13:0] current_frequency;
    //asserted when we need to move to the next note(clk_counter finished counting)
    logic next_note;
    //asserted to reset the 3 second timer when we start playing fanfare or reverse fanfare
    logic reset_timer;
    //repeat counter
    //generate a signal after we reset it 
    //logic[27:0] repeat_counter;
    logic[26:0] repeat_counter;
    logic three_sec;

    // edge detect on repeat_counter[22] in the clk domain
    logic rep22_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rep22_q <= 1'b0;
        else        rep22_q <= repeat_counter[22];
    end
    wire rep22_rise = repeat_counter[22] & ~rep22_q;  // 1-cycle pulse
    wire rep22_fall = ~repeat_counter[22] & rep22_q; // 1-cycle pulse
    // use next_note as sync clear and rep22_rise as enable
    always_ff @(posedge clk) begin
        if (next_note) clk_counter <= '0;             // sync clear
        //we need to account for both rising edge and falling edge of bit 22
        else if (rep22_rise||rep22_fall) clk_counter <= clk_counter + 1;
        //else hold
    end
    
    //no need for reset, just reset when we move to next note
    
    //each state represents a note to be played
    typedef enum logic [3:0] {
        IDLE,
        NOTE1,
        NOTE2,
        NOTE3,
        NOTE4,
        NOTE5,
        NOTE6
    } state_t;
    state_t state, next_state;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    wire clk_23, clk_22, clk_25;
    //combinational logic for next state and outputs
    assign clk_23 = clk_counter[1]; //when bit 23 is set, we have counted 2^23 cycles
    assign clk_22 = clk_counter[0]; //when bit 22 is set, we have counted 2^22 cycles
    assign clk_25 = clk_counter[3]; //when bit 25 is set, we have counted 2^25 cycles
    logic idle;
    always_comb begin
        next_state = state;
        current_frequency = 12'd0;
        next_note = 0;
        reset_timer = 0;
        idle = 0;
        //state transitions - each note lasts a certain duration, then
        //go to their own notes based on the inputs
        unique case (state)
            IDLE: begin
                idle = 1;
                if(too_fast) begin
                    next_state = NOTE1;
                    next_note = 1;
                end
                //we only reset the timer when we start playing a note
                //so it can continue counting while in too_fast state
                //the three_sec signal will be preseted so we can used it right away,               
                else if(batt_low && three_sec) begin
                    next_state = NOTE6;
                    next_note = 1;
                    //the reset_timer signal to reset the three second timer
                    //and clear the three_sec flag
                    reset_timer = 1;
                end            
                else if (en_steer && three_sec) begin
                    next_state = NOTE1;
                    next_note = 1;
                    reset_timer = 1;
                end
            end
            //too_fast will play the first three notes, and repeat back
            NOTE1: begin
                current_frequency = G6; // G6
                //2^23 clk cycles
                if (clk_23) begin
                    //too_fast has priority over batt_low
                    if(batt_low&&~too_fast)
                        next_state = IDLE;
                    else
                        next_state = NOTE2;
                    next_note = 1;
                end
            end
            NOTE2: begin
                current_frequency = C7; // C7
                //2^23 clk cycles
                if (clk_23) begin
                    if(batt_low&&~too_fast)
                        next_state = NOTE1;
                    else
                        next_state = NOTE3;
                    next_note = 1;
                end
            end
            NOTE3: begin
                current_frequency = E7; // E7
                if (clk_23) begin
                    if(too_fast)
                        next_state = NOTE1;
                        //repeat the first three notes
                    else if(batt_low)
                        next_state = NOTE2;
                    else
                        next_state = NOTE4;
                    next_note = 1;
                end
            end
            //too_fast won't reach here
            //the fourth notes are combined
            NOTE4: begin
                current_frequency = G7; // G7
                //2^23 clk cycles+ 2^22 clk cycles
                if (clk_23&&clk_22) begin
                    //goes to NOTE4_2 no matter what
                    if(batt_low)
                        next_state = NOTE3;
                    else
                        next_state = NOTE5;
                    next_note = 1;
                end
            end
            NOTE5: begin
                current_frequency = E7; // E7
                //2^22 clk cycles
                if (clk_22) begin
                    //goes to NOTE4 if batt_low
                    if(batt_low)
                        next_state = NOTE4;
                    else
                        next_state = NOTE6;
                    next_note = 1;
                end
            end
            NOTE6: begin
                current_frequency = G7; // G7
                //2^25 clk cycles
                if (clk_25) begin
                    if(batt_low)
                        next_state = NOTE5;
                    else
                        next_state = IDLE;
                    next_note = 1;
                end
            end
            default: begin
                //don't cares
                current_frequency = 12'hxxx;
                reset_timer = 1'bx;
                next_note = 1'bx;
            end
        endcase
    end

    logic toggle_piezo;
    //bit wise and when frquency counter reaches 0 and not idling
    assign toggle_piezo = ~(|freq_counter)&&(~idle);
    //frequency counter for piezo toggling
    //no need for reset, just reset when we move to next note
    //counter down to toggle piezo output
    generate
        if (fast_sim)
            always_ff @(posedge clk) begin
                if (next_note||toggle_piezo)
                //load half frequency of current note
                    freq_counter <= current_frequency;
                else 
                    //if fast_sim is enabled, increment by a value of 64
                    if($signed({1'b0, freq_counter})-64<0)
                        freq_counter <= 0;
                    else if(~idle)
                        freq_counter <= freq_counter - 64;
            end
        else
            always_ff @(posedge clk) begin
                if (next_note||toggle_piezo)
                    freq_counter <= current_frequency;
                else  if(~idle)
                    freq_counter <= freq_counter - 1'b1;
            end
    endgenerate
    assign piezo_n = ~piezo;
    //piezo output logic
    always_ff @(posedge clk or negedge rst_n) begin
        //piezo_n is active low
        if (!rst_n) begin
            piezo <= 1'b0;
        end 
        else if(toggle_piezo) begin
            piezo <= ~piezo;
        end
        else if(idle) begin
            piezo <= 1'b0;
        end
        //else hold value      
    end
    
    logic repeat_done;
    generate
        if (fast_sim) begin
            //make the 3second timer faster for simulation
            assign repeat_done = (repeat_counter == 27'h6_000_000);
        end
        else begin
            //1/(50^6) seconds per clk cycle
            //3/(1/(50*10^6)) = 150*10^6 cycles for 3 seconds
            
            //assign repeat_done = (repeat_counter == 28'd150_000_000);
            //134_217_727
            assign repeat_done = (repeat_counter == 27'h7_FFF_FFF);
        end
    endgenerate
    //three second timer logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            //preset three_sec to 1
            //so we can start playing notes right after reset
            three_sec <= 1;
        end
        else if (reset_timer) begin
            three_sec <= 0;
        end
        else if(repeat_done) begin
            three_sec <= 1;
        end
        //else hold value
    end
    generate
        if(fast_sim) begin         
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    repeat_counter <= 0;
                else if (reset_timer||repeat_done)  //when fast_sim make it reset faster
                    repeat_counter <= 0;             
                else 
                    //if fast_sim is enabled, increment by a value of 64
                    repeat_counter <= repeat_counter + 64;
                    //in simulation it should be 0.046875 seconds         
            end
        end
        else begin             
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    repeat_counter <= 0;
                else if (reset_timer||repeat_done) //reset every 3 seconds
                    repeat_counter <= 0;
                else 
                    repeat_counter <= repeat_counter + 1;
            end
        end
    endgenerate

endmodule