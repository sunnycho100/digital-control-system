// includes PID, integrator, ss_tmr
module PID(
    input logic clk, rst_n,         // sync elements 
    input logic vld,                // indicate when a new inertial sensor reading is valid
    input logic signed [15:0] ptch, // signed 16-bit pitch signal
    input logic signed [15:0] ptch_rt, // signed 16-bit pitch rate
//    input logic signed [17:0] integrator, // 18-bit integrator accum reg
    input logic pwr_up, rider_off,  // TODO wil be discussed later

    output logic signed [11:0] PID_cntrl, // 12-bit signed result
    output logic [7:0] ss_tmr      // upper bits of a timer used to effect a soft start
);

// P term
logic signed [9:0] ptch_err_sat;
logic signed [14:0] P_term; // unchanged
logic signed [14:0] I_term; // changed
logic signed [12:0] D_term; // unchanged
logic signed [15:0] PID_sum;

localparam signed P_COEFF = 5'h09;

// 16 bit > 10 bits
assign ptch_err_sat = (~ptch[15] & (|ptch[14:9])) ? 10'h1FF :
                      ( ptch[15] & !(&ptch[14:9])) ? 10'h200 :
                      ptch[9:0];

assign P_term = ptch_err_sat * $signed(P_COEFF);

// I Term (changed)
logic signed [17:0] integrator;
integral integral_operation (.*);

// run ss_tmr as well as the output
ss_tmr ss_tmr_operation (.*);

// 18 bit > 15 bit
assign I_term = { {3{integrator[17]}}, integrator[17:6] };

// D Term
assign D_term = - { {3{ptch_rt[15]}} , ptch_rt[15:6] };


// sum term
// P 15 > 16, I 15 > 16, D 13 > 16
assign PID_sum = { P_term[14] , P_term } + { I_term[14] , I_term } + { {3{D_term[12]}} , D_term };

// 16 bit PID SUM > 12 bit PID CNTRL
// [15:0] > [11:0]
assign PID_cntrl = (~PID_sum[15] & (|PID_sum[14:11])) ? 12'h7FF :
                   ( PID_sum[15] & !(&PID_sum[14:11])) ? 12'h800 :
                   PID_sum[11:0];

endmodule

module integral (
    input logic clk, rst_n,
    input logic rider_off,
    input logic vld,
    input logic signed [9:0] ptch_err_sat,
    output reg signed [17:0] integrator
);

// internal signals
logic signed [17:0] err18; // 18-bit sign extended (10 > 18)
logic signed [17:0] sum;
logic signed [17:0] mux_res; // result of mux1

logic               ov;

// step 1: sign extend to 18 bits
assign err18 = {{8{ptch_err_sat[9]}}, ptch_err_sat};

// step 2: err18 + integrator
assign sum = err18 + integrator;

// ov logic - when both signs are equal but sum results in diff sign
assign ov = (err18[17] == integrator[17]) & (integrator[17] != sum[17]);

// step 3-1: combinational logic for mux_res (2 muxes combined)
always_comb begin
    if (rider_off)     mux_res = '0;
    // from here onwards, we assume rider_off = 0
    else if (!ov & vld) mux_res = sum;
    else                mux_res = integrator;
end


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) integrator <= '0;
    else        integrator <= mux_res;
end

endmodule

module ss_tmr(
    input logic clk, 
    input logic rst_n,
    input logic pwr_up,

    output logic [7:0] ss_tmr
);

// intermediate signal
logic [26:0] long_tmr; 
logic [26:0] mux_res;

// pwr_up 1 > 0 (deasserted) resulting in ss timer remain 0


// comb logic
/*always_comb begin
    if (!pwr_up)                 mux_res = '0;
    else if (long_tmr == 27'd134217727)   mux_res = long_tmr;
    else                         mux_res = long_tmr + 27'd1;
end
*/

// try dataflow style
assign mux_res = (!pwr_up) ? 27'h0 :
                 (&long_tmr[26:19]) ? long_tmr :
                 long_tmr + 27'd1;

// ff
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) long_tmr <= '0;
    else        long_tmr <= mux_res;      
end

assign ss_tmr = long_tmr[26:19]; // provided logic

endmodule