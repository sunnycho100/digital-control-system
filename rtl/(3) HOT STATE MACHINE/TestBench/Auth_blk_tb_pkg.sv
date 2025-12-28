package Auth_blk_tb_pkg;

  // ==============================================================
  // === Parameters
  // ==============================================================
  parameter int POST_TX_DELAY = 60000;

  // ==============================================================
  // === ANSI Color Codes
  // ==============================================================
  localparam string RED     = "\033[1;31m";
  localparam string GREEN   = "\033[1;32m";
  localparam string YELLOW  = "\033[1;33m";
  localparam string CYAN    = "\033[1;36m";
  localparam string RESET   = "\033[0m";

  // ==============================================================
  // === Task: send_byte
  // ==============================================================
  task automatic send_byte(
      ref logic        clk,
      ref logic [7:0]  stim,
      ref logic        trmt,
      input byte       b
  );
    @(posedge clk);
    stim = b;
    trmt = 1'b1;
    @(posedge clk);
    trmt = 1'b0;
    repeat (POST_TX_DELAY) @(posedge clk);
    $display("%s[%0t] INFO:%s Sent byte 0x%02h", CYAN, $time, RESET, b);
  endtask

  // ==============================================================
  // === Task: check_pwr (direct compare)
  // ==============================================================
  task automatic check_pwr(
      input  string msg,
      ref    logic  clk,
      input  bit    pwr_up,
      input  bit    exp
  );
    @(posedge clk);
    if (pwr_up === exp)
      $display("%s[%0t] PASS:%s %s (pwr_up=%0b)", GREEN, $time, RESET, msg, pwr_up);
    else
      $display("%s[%0t] FAIL:%s %s (pwr_up=%0b, exp=%0b)",
               RED, $time, RESET, msg, pwr_up, exp);
  endtask

  // ==============================================================
  // === Task: check_pwr_posedge
  // ==============================================================
  task automatic check_pwr_posedge(
    input  string       msg,
    ref    logic        clk,
    ref    logic        sig,
    input  int unsigned clk2wait,
    input  bit          exp = 1
  );
    logic didnCatch = sig & exp;
    fork
      begin : wait_timeout
        repeat (clk2wait) @(posedge clk);
        $fatal(1, {"%s[%0t] CRITICAL ERROR:%s (Timeout) %s (pwr_up=%0b, exp=%0b)",
                   RED, $time, RESET, msg, sig, exp});
      end
      begin : Successfull
        @(posedge sig);
        $display("%s[%0t] PASS:%s %s (pwr_up=%0b)", GREEN, $time, RESET, msg, sig);
        disable wait_timeout;
      end
      begin : Ncatch
        if (didnCatch)
          $display("%s[%0t] WARN:%s %s (pwr_up=%0b)", YELLOW, $time, RESET, msg, sig);
        disable wait_timeout;
        disable Successfull;
      end
    join
  endtask

  // ==============================================================
  // === Task: check_pwr_negedge
  // ==============================================================
  task automatic check_pwr_negedge(
    input  string       msg,
    ref    logic        clk,
    ref    logic        sig,
    input  int unsigned clk2wait,
    input  bit          exp = 0
  );
    logic didnCatch = sig & exp;
    fork
      begin : wait_timeout
        repeat (clk2wait) @(posedge clk);
        $fatal(1, {"%s[%0t] CRITICAL ERROR:%s (Timeout) %s (pwr_up=%0b, exp=%0b)",
                   RED, $time, RESET, msg, sig, exp});
      end
      begin : Successfull
        @(negedge sig);
        $display("%s[%0t] PASS:%s %s (pwr_up=%0b)", GREEN, $time, RESET, msg, sig);
        disable wait_timeout;
      end
      begin : Ncatch
        if (didnCatch)
          $display("%s[%0t] WARN:%s %s (pwr_up=%0b)", YELLOW, $time, RESET, msg, sig);
        disable wait_timeout;
        disable Successfull;
      end
    join
  endtask

  // ==============================================================
  // === Task: expect_no_change_pwr
  // ==============================================================
  task automatic expect_no_change_pwr(
    input  string       msg,
    ref    logic        clk,
    ref    logic        sig,
    input  int unsigned cycles
  );
    fork
      begin : timeout
        repeat (cycles) @(posedge clk);
        $display("%s[%0t] PASS (no change):%s %s", GREEN, $time, RESET, msg);
        disable posedge_det;
        disable negedge_det;
      end
      begin : posedge_det
        @(posedge sig);
        $fatal(1, {"%s[%0t] FAIL (unexpected ON):%s %s", RED, $time, RESET, msg});
      end
      begin : negedge_det
        @(negedge sig);
        $fatal(1, {"%s[%0t] FAIL (unexpected OFF):%s %s", RED, $time, RESET, msg});
      end
    join
  endtask

endpackage : Auth_blk_tb_pkg


package Segway_math_tb_pkg;

  // ==============================================================
  // === Parameters
  // ==============================================================
  parameter int POST_TX_DELAY = 60000;

  // ==============================================================
  // === ANSI Color Codes
  // ==============================================================
  localparam string RED     = "\033[1;31m";
  localparam string GREEN   = "\033[1;32m";
  localparam string YELLOW  = "\033[1;33m";
  localparam string CYAN    = "\033[1;36m";
  localparam string RESET   = "\033[0m";

  // ==============================================================
  // === TASK: initialize_signals
  task automatic initialize_signals(
      ref logic        clk,
      ref logic signed [11:0] PID_cntrl,
      ref logic        [7:0]  ss_tmr,
      ref logic        [11:0] steer_pot,
      ref logic               en_steer,
      ref logic               pwr_up,
      ref logic               rst_n
  );
    clk        = 1'b0;
    PID_cntrl  = 12'sd0;
    ss_tmr     = 8'd0;
    steer_pot  = 12'd2048; // center position
    en_steer   = 1'b0;
    pwr_up     = 1'b0;
    rst_n      = 1'b0;
    @(posedge clk);
    rst_n      = 1'b1;
    @(posedge clk);
  endtask

  // ==============================================================
  // === Task: toggle_clk
  

endpackage : Segway_math_tb_pkg