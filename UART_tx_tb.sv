module UART_tx_tb();

// inputs // 
logic           clk;
logic           rst_n;
logic           trmt;
logic   [7:0]   tx_data;

// outputs //
logic           TX;
logic           tx_done;

// intanstiate iDUT //
UART_tx iDUT(
    .clk(clk),
    .rst_n(rst_n),
    .trmt(trmt),
    .tx_data(tx_data),
    .TX(TX),
    .tx_done(tx_done)
);

// check whether load = 1 clears ffs well

initial begin
    // deault values
    clk = 0;
    rst_n = 0;
    trmt = 0;
    tx_data = '0;
    //TX = 0;
    //tx_done = 0;

    // how do you test the overall behavior of the state machine...
    
    repeat(5208) @(posedge clk);
    // ff should have been resetted, now we turn off reset
    rst_n = 1;

    // testing how data is being transmitted
    repeat(10) @(posedge clk);
    tx_data = 8'hA5; // 1010_0101
    trmt = 1'b1; // start transmitting
    repeat(10)@(posedge clk);
    trmt = 1'b0; // deactive as the process has started already

    // wait long enough to see the whole frame
    repeat(5208*15) @(posedge clk);

    $display("Check waveform!");
    $stop();
end

// clock //
initial    clk = 0;
always  #5 clk = ~clk;

endmodule