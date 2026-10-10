`timescale 1ns / 1ps
`include "environment.sv" // Include environment file

module tb_top;
    
    logic clk;
    logic reset;
    
    // Pass clock to the interface
    uart_if vif(clk);
    
    // Declare Environment handle
    environment env;
    
    // 
    uart_top DUT (
        .clk(clk),
        .reset(reset),
        .tx_din(vif.tx_din),
        .tx_wr_en(vif.tx_wr_en),
        .rx_rd_en(vif.rx_rd_en),
        .parity_en(vif.parity_en),
        .parity_odd(vif.parity_odd),
        .rx(vif.tx),
        .rx_dout(vif.rx_dout),
        .tx_full(vif.tx_full),
        .rx_empty(vif.rx_empty),
        .tx(vif.tx)
    );
    
    assign vif.tx_busy = DUT.tx_busy; // 
    always #5 clk = ~clk; 
    
   
    initial begin
      
        clk = 0;
        reset = 1;
        vif.reset = 1; // Send reset to interface as well
        
      
        #20;
        reset = 0;
        vif.reset = 0;
        
        // Create environment object and pass the interface to it
        env = new(vif);
        
        // Start the environment and this will run Generator, Driver, Monitor, Scoreboard
        env.main();
        
       
        $finish;
    end

endmodule
