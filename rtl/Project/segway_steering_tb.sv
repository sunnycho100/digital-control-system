`timescale 1ns/10ps

// Include Package;
`include "Auth_blk_tb_pkg.sv"
import Auth_blk_tb_pkg::*;

module segway_steering_tb;
//testing the steering of the segway hoverboard

    //// Interconnects to DUT/support defined as type wire /////
    wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
    wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
    wire RX_TX;
    wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
    wire piezo,piezo_n;
    wire cmd_sent;
    wire rst_n;					// synchronized global reset

    ////// Stimulus is declared as type reg ///////
    reg clk, RST_n;
    reg [7:0] cmd;				// command host is sending to DUT
    reg send_cmd;				// asserted to initiate sending of command
    reg signed [15:0] rider_lean;
    reg [11:0] ld_cell_lft, ld_cell_rght,steerPot,batt;	// A2D values
    reg OVR_I_lft, OVR_I_rght;

    ///// Internal registers for testing purposes??? /////////


    ////////////////////////////////////////////////////////////////
    // Instantiate Physical Model of Segway with Inertial sensor //
    //////////////////////////////////////////////////////////////	
    SegwayModel iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),
                    .MISO(MISO),.MOSI(MOSI),.INT(INT),.PWM1_lft(PWM1_lft),
                    .PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
                    .PWM2_rght(PWM2_rght),.rider_lean(rider_lean));				  

    /////////////////////////////////////////////////////////
    // Instantiate Model of A2D for load cell and battery //
    ///////////////////////////////////////////////////////
    ADC128S_FC iA2D(.clk(clk),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),
                .MISO(A2D_MISO),.MOSI(A2D_MOSI),.ld_cell_lft(ld_cell_lft),.ld_cell_rght(ld_cell_rght),
                .steerPot(steerPot),.batt(batt));			
        
    ////// Instantiate DUT ////////
    Segway iDUT(.clk(clk),.RST_n(RST_n),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
                .INERT_SCLK(SCLK),.INERT_MISO(MISO),.INERT_INT(INT),.A2D_SS_n(A2D_SS_n),
                .A2D_MOSI(A2D_MOSI),.A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),
                .PWM1_lft(PWM1_lft),.PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
                .PWM2_rght(PWM2_rght),.OVR_I_lft(OVR_I_lft),.OVR_I_rght(OVR_I_rght),
                .piezo_n(piezo_n),.piezo(piezo),.RX(RX_TX));

    //// Instantiate UART_tx (mimics command from BLE module) //////
    UART_tx iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));

    /////////////////////////////////////
    // Instantiate reset synchronizer //
    ///////////////////////////////////
    rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    initial begin
      // Initialize signals
      
      RST_n       = 0;
      send_cmd    = 0;
      cmd         = 8'h00;
      rider_lean  = 16'sd0; //upright position
      ld_cell_lft = 12'd0;
      ld_cell_rght= 12'd0;
      steerPot    = 12'h800; // mid of 0x200 and 0xE00 = 0x800
        batt        = 12'hFFF;
        OVR_I_lft   = 1'b0;
        OVR_I_rght  = 1'b0;

      // Release reset after some time
        @(posedge clk);
        RST_n = 1;
        @(posedge clk);
        // Testcase: rider not yet balanced on segway --> should be no steering
        steerPot = 12'hE00; 
        //min weight is 0x240
        ld_cell_lft = 12'h100;
        ld_cell_rght= 12'h139;
        //power up segway
        send_byte(clk, cmd, send_cmd, 8'h47);  // 'G'
        repeat (200000) @(posedge clk);
        //
        if(iDUT.iBAL.lft_spd != iDUT.iBAL.rght_spd) begin
            $error("FAIL: Steering enabled when rider not balanced");
        end
        
        //try when rider is balanced with same weight on both sides
        ld_cell_lft = 12'h121;
        ld_cell_rght= 12'h121;
        @(posedge iDUT.iSTR.tmr_full); //wait for timer to full so steering can be enabled
        steerPot    = 12'h600; //turn left
        repeat (200000) @(posedge clk);
        //left wheel speed should be smaller than right wheel speed
        if(iDUT.iBAL.lft_spd >= iDUT.iBAL.rght_spd) begin
            $error("FAIL: Steering left not accurate");
        end

        //turn right
        steerPot    = 12'hA00; //turn right
        repeat (200000) @(posedge clk);
        //right wheel speed should be smaller than left wheel speed
        if(iDUT.iBAL.rght_spd >= iDUT.iBAL.lft_spd) begin
            $error("FAIL: Steering right not accurate");
        end
        //Testcase: when the rider has one feet off the segway
        ld_cell_lft = 12'h010;
        ld_cell_rght= 12'h240;
        repeat (200000) @(posedge clk);
        //steering should be disabled
        if(iDUT.iBAL.lft_spd != iDUT.iBAL.rght_spd) begin
            $error("FAIL: Steering enabled when rider has one foot off");
        end

        //try the other foot off
        ld_cell_lft = 12'h240;
        ld_cell_rght= 12'h010;
        repeat (200000) @(posedge clk);
        //steering should be disabled
        if(iDUT.iBAL.lft_spd != iDUT.iBAL.rght_spd) begin
            $error("FAIL: Steering enabled when rider has one foot off");
        end

        //when the rider lean forward/backward, with one foot off
        rider_lean  = 16'sd500; //lean forward
        repeat (200000) @(posedge clk);
        //steering should be disabled
        if(iDUT.iBAL.lft_spd != iDUT.iBAL.rght_spd) begin
            $error("FAIL: Steering enabled when rider has one foot off");
        end
        rider_lean  = -16'sd500; //lean backward
        repeat (200000) @(posedge clk);
        //steering should be disabled
        if(iDUT.iBAL.lft_spd != iDUT.iBAL.rght_spd) begin
            $error("FAIL: Steering enabled when rider has one foot off");
        end
        $stop;
    end
endmodule