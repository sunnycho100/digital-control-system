
`timescale 1ns/10ps

// Include Package;
`include "Auth_blk_tb_pkg.sv"
import Auth_blk_tb_pkg::*;



module Segway_tb();
			
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
//logic pwr_up = iDUT.pwr_up;


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

initial begin
  // Initialize signals
  clk         = 0;
  RST_n       = 0;
  send_cmd    = 0;
  cmd         = 8'h00;
  rider_lean  = 16'sd0;
  ld_cell_lft = 12'h0;
  ld_cell_rght= 12'h0;
  steerPot    = 12'h800; // mid of 0x200 and 0xE00 = 0x800
  batt        = 12'hFFF;
  OVR_I_lft   = 0;
  OVR_I_rght  = 0;

  // Release reset
  repeat (5) @(posedge clk);
  RST_n = 1;
  repeat (50000) @(posedge clk);


  $display("BASIC TEST");
  $display("GRAB A COFFEE AND ENJOY THE SHOW :)");



  // Hacker sends 'F' command first (invalid)
  send_byte(clk, cmd, send_cmd, 8'h46);  // 'F
  repeat (50_000) @(posedge clk);
  //expect_no_change_pwr("Segway Should not responed to Wrong Key", clk, pwr_up, 2000);


  // USER sends 'G' command to power up segway
  send_byte(clk, cmd, send_cmd, 8'h47);  // 'G'
  //check_pwr_posedge("Segway did not power up on invalid command", clk, pwr_up, 200_000, 1'b0);

  ld_cell_lft = 12'h7FF;
  ld_cell_rght= 12'h7FF;
  // Hold rider_lean at 0 for ~350k clks cycles
  repeat (240000) @(posedge clk);
  // Step rider_lean to 0xFFF and hold for ~800k cycles
  rider_lean = $signed(16'hFFF);
  repeat (2000000) @(posedge clk);
  // Step back to zero and hold another ~800k cycles
  rider_lean = 16'h0000;
  repeat (2000000) @(posedge clk);





  // tesk #2 send 'S' command to shut off segway
  send_byte(clk, cmd, send_cmd, 8'h53);  // 'S
  //check_pwr_negedge("Segway did not power down on 'S' command", clk, pwr_up, 200_000, 1'b0);
  repeat (50000) @(posedge clk);
  $display("USER FELLL OFF");
  batt        = 12'h8FF;
  rider_lean = 16'sh0F25; // simulate user fall off by leaning FORWARD
  ld_cell_lft = 12'h000;
  ld_cell_rght= 12'h000;




  // USED til battery run out lol
  repeat (2000000) @(posedge clk);
  $display("USER Hopped ON");
  send_byte(clk, cmd, send_cmd, 8'h47);  // 'G'
  //check_pwr_posedge("Segway did not power up on 'G' command", clk, pwr_up, 200_000, 1'b1);
  repeat (600000) @(posedge clk);
  ld_cell_lft = 12'h7FF;
  ld_cell_rght= 12'h7FF;
  rider_lean = 16'sh3211; // simulate user Just Hopped On by leaning FORWARD
  repeat (1000000) @(posedge clk);
  rider_lean = 16'sh0011; // simulate user leaning FORWARD
  batt        = 12'hA18;
  repeat (1000000) @(posedge clk);
  rider_lean = 16'sh0000; // simulate user leanin g STRAIGHT
  batt        = 12'h805;
  repeat (1000000) @(posedge clk);
  $display("BATTERY LOW");
  batt        = 12'h0FF; // battery back to is low
  repeat (4000000) @(posedge clk); // ChecK PIEZO
    $display("BATTERY Charged Full");
  batt        = 12'h80F; // battery back to is full
  repeat (100000) @(posedge clk);







  // USER IS SPEEDING oh NOO!
  $display("USER IS SPEEDING");
  rider_lean = 16'sh1FFF; // simulate user leaning FORWARD hard
  repeat (500000) @(posedge clk);
  $display("Motor IS too fast");
  //force Segway_tb.iDUT.iBAL.segway_math_inst.too_fast = 1; //CHECK PIEZO
  repeat (4000000) @(posedge clk);
  // OVR_I_lft   = 1;
  // OVR_I_rght  = 1;
  // repeat (500000) @(posedge clk);
  // $display("Motor is BACK to NORMAL");
  // OVR_I_lft   = 0;
  // OVR_I_rght  = 0;
  // repeat (1000000) @(posedge clk);
  $display("USER IS banding backwards");
  //release Segway_tb.iDUT.iBAL.segway_math_inst.too_fast;
  rider_lean = 16'shE200; // simulate user leaning FORWARD hard
  repeat (1000000) @(posedge clk);




  // rider hops off
  $display("USER FELLL OFF AGAIN");
  rider_lean  = 16'sd0;
  ld_cell_lft = 12'h0;
  ld_cell_rght= 12'h0;
  repeat (1000000) @(posedge clk);
  $display("USER Hopped ON AGAIN");
  rider_lean  = 16'shEFFF; // decimal  = -4097;
  ld_cell_lft = 12'h0FF;  // IS A CHILDED !!!!
  ld_cell_rght= 12'h0FF;
  repeat (1000000) @(posedge clk);
  rider_lean = 16'sh0000; // simulate user leanin g STRAIGHT
  ld_cell_lft = 12'h7FF;
  ld_cell_rght= 12'h7FF;
  repeat (1000000) @(posedge clk);
  $display("Motor IS burnning OUT");
  OVR_I_lft   = 1;
  OVR_I_rght  = 1;
  repeat (500000) @(posedge clk);
  $display("Motor is BACK to NORMAL");
  OVR_I_lft   = 0;
  OVR_I_rght  = 0;
  repeat (1000000) @(posedge clk);
  $display("USER Quit and Turns OFF for GOOD");
  send_byte(clk, cmd, send_cmd, 8'h53);  // 'S





  $stop;
end


always
  #10 clk = ~clk;

endmodule	




/* NTOE
BATT_THRES = 12'h800; // battery threshold voltage decimal = 2048
  assign batt_low = (batt<BATT_THRES) ? 1'b1 : 1'b0;

rider_lean // Don't exceed 0x1FFF postitive or 0xE000 negative

*/