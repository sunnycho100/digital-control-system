module SPI_mnrch(
    input logic clk,
    input logic rst_n,
    // SPI signals
    output logic SCLK,
    output logic MOSI,
    output logic SS_n,
    input logic MISO,
    // Control signals
    input logic wrt,
    input logic[15:0] wt_data,
    output logic[15:0] rd_data,
    output logic done
);  
    //load sclk register
    logic ld_SCLK;
    logic smpl;
    logic shift_im;
    logic [3:0] sclk_div;
    assign smpl = sclk_div == 4'b0111;
    //bit wise and ( when all bits are 1 )
    assign shift_im = &sclk_div;
    //MSB is SCLK
    assign SCLK = sclk_div[3];
    always_ff @(posedge clk) begin
        if (ld_SCLK)
            sclk_div <= 4'b1011;
        else
            sclk_div <= sclk_div +1;
    end

    //MISO shift register
    logic MISO_smpl;
    always_ff @(posedge clk) begin
        if (smpl)
            MISO_smpl <= MISO;
        //else hold value          
    end

    logic  [15:0] shft_reg;
    logic init;//from the state machine
    logic shift;//from the state machine
    assign MOSI = shft_reg[15];
    always_ff @(posedge clk) begin
        if (init)
            shft_reg <= wt_data;
        else if (shift)
            shft_reg <= {shft_reg[14:0], MISO_smpl};
        //else hold value
    end

    //bit counter
    logic [3:0] bit_cntr;
    logic done15;//input to state machine
    assign done15 = &bit_cntr;
    always_ff @(posedge clk) begin
        if (init)
            bit_cntr <= 4'b0000;
        else if (shift)
            bit_cntr <= bit_cntr + 1;
        //else hold value
    end

    //enum state machine
    typedef enum logic [1:0] {
        IDLE,
        FRONT,//front porch
        SHIFT,
        BACK //back porch
    } state_t;
    state_t state, next_state;
    logic set_done;
    //idle--> when wrt is high we assert init, and we go first fall of sclk but not shift
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        //default values
        ld_SCLK = 0;
        init = 0;
        shift = 0;
        set_done = 0;
        next_state = state;
        unique case (state)
            IDLE: begin
                if (wrt) begin
                    init = 1;
                    ld_SCLK = 1;
                    next_state = FRONT;                   
                end 
            end
            FRONT: begin
                
                if(shift_im) begin
                    next_state = SHIFT;
                    //we don't actually shift the first first fall of the SCLK
                end
            end
            SHIFT: begin
                if(done15) begin
                    next_state=BACK;
                    //shift=1;
                end
                if(shift_im)
                    shift = 1;
            end
            BACK: begin
                if(shift_im) begin
                    shift=1;
                    set_done=1;
                    next_state = IDLE;
                    ld_SCLK = 1;//we don't want SCLK to go back down
                end
            end
        endcase
    end
    //we don't want SS_n and done to glitch, so they out put directly from a flop
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            SS_n <= 1'b1;//preset SS_n high
        else if (init)
            SS_n <= 1'b0;
        else if (set_done)
            SS_n <= 1'b1;       
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            done <= 1'b0;//reset done low
        else if (init)
            done <= 1'b0;
        else if (set_done)
            done <= 1'b1;        
    end
    
    //read data output
    always_ff @(posedge clk) begin
        if (shift)
            rd_data <= {rd_data[14:0], MISO_smpl};        
    end


    
endmodule