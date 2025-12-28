



/*clk,rst_n in 50MHz clock and active low asynch reset
nxt in Initiates A2D conversion on next measurand
lft_ld[11:0] out Result of last conversion on channel 0 (left load cell)
rght_ld[11:0] out Result of last conversion on channel 4 (right load cell)
steer_pot[11:0] Result of last conversion on channel 5 (steering potentiometer)
batt[11:0] out Result of last conversion on channel 5 (battery voltage)
SPI Interface Out/
in
SS_n, SCLK, MOSI, MISO of a SPI interface. Comes from copy
of SPI_mnrch embedded into this unit.
*/
/* 
A2D_intf: Interface to external A/D converter via SPI_mnrch

clk, rst_n     : 50 MHz clock, active-low async reset
nxt            : request to perform next conversion in round-robin

lft_ld[11:0]   : last conversion on channel 0 (left load cell)
rght_ld[11:0]  : last conversion on channel 4 (right load cell)
steer_pot[11:0]: last conversion on channel 5 (steering potentiometer)
batt[11:0]     : last conversion on channel 6 (battery voltage)

SPI interface:
  MISO         : from A/D
  SCLK, MOSI,
  SS_n         : driven by embedded SPI_mnrch
*/


module A2D_intf(
    input logic clk,
    input logic rst_n,
    input logic nxt,
    output logic [11:0]lft_ld,
    output logic [11:0]rght_ld,
    output logic [11:0]steer_pot,
    output logic [11:0]batt,
    //spi interface
    input logic MISO,
    output logic SCLK,
    output logic MOSI,
    output logic SS_n

);
    /*The SM will sit idle till it is told to perform a conversion (nxt asserted). Then it will kick off two SPI transactions
via SPI_mnrch. The first SPI transaction determines what channel to convert, and the second SPI transaction
reads the result for that channel. The round robin counter is then incremented, and on the nxt request it will
convert the next channel in the sequence.*/
    logic wrt;
    logic done;
    logic [15:0] wt_data;
    logic [15:0] rd_data;
    logic update;//indicates we are going to the next channel on the robin counter
    logic [2:0] channel; //3-bit channel 
    logic [1:0] channel_sel;
    localparam channel_0 = 3'b000;
    localparam channel_4 = 3'b100;
    localparam channel_5 = 3'b101;
    localparam channel_6 = 3'b110;
    typedef enum logic [1:0] {IDLE, CHANNEL, WAIT, READ} state_t;
    state_t state, next_state;
    //state register
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    //next state logic
    always_comb begin
        //default values
        next_state = state;
        wrt = 1'b0;
        update = 1'b0;
        
        case(state)
            IDLE: begin
                if(nxt) begin
                    wrt = 1'b1; //start the write to select channel
                    next_state = CHANNEL;
                    
                end
            end
            CHANNEL: begin
                //combinational logic to determine channel and wt_data               
                if(done) begin //back to back transactions, no resting time
                    next_state = WAIT;
                    //go to the wait state to wait one clock cycle                 
                end
            end
            WAIT: begin
                //a wait state so things work specified by professor hoffman
                wrt = 1'b1; //start to get the reading ( the wt_data doesn't matter here)
                next_state = READ;
            end
            READ: begin               
                if(done) begin //reading complete                   
                    next_state = IDLE;
                    update = 1'b1;
                end
            end
            
        endcase
    end

    always_comb begin 
        case(channel_sel)
            2'b00: begin
                //channel 0
                wt_data = {2'b00, channel_0, 11'h000};
            end
            2'b01: begin
                //channel 4
                wt_data = {2'b00, channel_4, 11'h000};
            end
            2'b10: begin
                //channel 5
                wt_data = {2'b00, channel_5, 11'h000};
            end
            2'b11: begin
                //channel 6
                wt_data = {2'b00, channel_6, 11'h000};
           end
        endcase
    end
    //robin counter
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            channel_sel <= 2'b00;
        else if(update)
            channel_sel <= channel_sel + 2'b01;
    end


    //output registers for the readings
    always_ff @(posedge clk) begin
        if((channel_sel == 2'b00) & update)
            lft_ld <= rd_data[11:0];
    end

    always_ff @(posedge clk) begin
        if((channel_sel == 2'b01) & update)
            rght_ld <= rd_data[11:0];
    end

    always_ff @(posedge clk) begin
        if((channel_sel == 2'b10) & update)
            steer_pot <= rd_data[11:0];
    end

    always_ff @(posedge clk) begin
        if((channel_sel == 2'b11) & update) 
            batt <= rd_data[11:0];       
    end

    //instance of SPI_mnrch
    SPI_mnrch SPI_inst(
        .clk(clk),
        .rst_n(rst_n),
        .wrt(wrt),
        .wt_data(wt_data),
        .rd_data(rd_data),
        .done(done),
        .MISO(MISO),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .SS_n(SS_n)
    );
endmodule