module Auth_blk_tb;
    logic trmt;
    logic [7:0] tx_data;
    logic TX;
    logic tx_done;
    logic clk;
    logic rst_n;
    logic rider_off;
    logic pwr_up;

    //instantiate the Auth_blk module as DUT
    Auth_blk iDUT(
        .RX(TX),
        .clk(clk),
        .rst_n(rst_n),
        .rider_off(rider_off),
        .pwr_up(pwr_up)
    );

    //instantiate the UART_tx module to send data to DUT
    UART_tx uart_transmitter(
        .clk(clk),
        .rst_n(rst_n),
        .trmt(trmt),
        .tx_data(tx_data),
        .TX(TX),
        .tx_done(tx_done)
    );

    //clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; //10 time units clock period
    end

    //test sequence
    initial begin
        rst_n = 1'b0;
        trmt = 1'b0;
        tx_data = 8'h47; //ASCII 'G'
        rider_off = 1'b0;
        @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        //send 'G' to power up
        trmt = 1'b1;
        @(posedge clk);
        trmt = 1'b0;
        @(posedge tx_done);
        if(pwr_up==1'b1) begin
            $display("Power Up Successful");
        end else begin
            $display("Power Up Failed");
            $stop;
        end
        //simulate rider off
        rider_off = 1'b1;
        //the power should be kept on until 'S' is received
        @(posedge clk);
        if(pwr_up==1'b1) begin
            $display("Rider Off Detected, Still Powered Up");
        end else begin
            $display("Power Down Incorrectly");
            $stop;
        end
        tx_data = 8'h53; //ASCII 'S'
        trmt = 1'b1;
        @(posedge clk);
        trmt = 1'b0;
        @(posedge tx_done);
        if(pwr_up==1'b0) begin
            $display("Power Down Successful");
        end else begin
            $display("Power Down Failed");
            $stop;
        end

        rider_off = 1'b0;
        //send 'G' again to power up
        tx_data = 8'h47; //ASCII 'G'
        trmt = 1'b1;
        @(posedge clk);
        trmt = 1'b0;
        @(posedge tx_done);
        //recieve 'S' again to go to disconnected state
        tx_data = 8'h53; //ASCII 'S'
        trmt = 1'b1;
        @(posedge clk);
        trmt = 1'b0;
        @(posedge tx_done);
        if(pwr_up==1'b1) begin
            $display("Remain in Power On successfully when 'S' received with rider on");
        end else begin
            $display("Power ON to Disconnected State Failed");
            $stop;
        end
        //recieve 'G' again to go back to power on state
        tx_data = 8'h47; //ASCII 'G'
        trmt = 1'b1;
        @(posedge clk);
        trmt = 1'b0;
        @(posedge tx_done);
        if(pwr_up==1'b1) begin
            $display("Return to Power On State Successful when 'G' received in Disconnected State");
        end else begin
            $display("Return to Power On State Failed");
            $stop;
        end
        //go to disconnected state again
        tx_data = 8'h53; //ASCII 'S'
        trmt = 1'b1;
        @(posedge clk);
        trmt = 1'b0;
        @(posedge tx_done);
        

        @(posedge clk);
        //simulate rider off again
        rider_off = 1'b1;
        repeat(2) @(posedge clk);
        if(pwr_up==1'b0) begin
            $display("Power Down to IDLE State Successful when rider off");
        end else begin
            $display("Power Down to IDLE State Failed");
            $stop;
        end
        $display("All Tests Passed");
        $stop;
    end

endmodule

