`ifndef ENVIRONMENT_SV
`define ENVIRONMENT_SV

`include "uart_trans.sv"
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "uart_sco.sv"

class environment;
    // Declare handles for each class
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sco;
    
    // Declare mailbox for both gen to driver and monitor to scoreboard
    mailbox mbx_gen_drv; // Wire between Generator and Driver
    mailbox mbx_mon_sco; // Wire between Monitor and Scoreboard
    
    virtual uart_if vif; 
    
    // Top module passes virtual interface
    function new(virtual uart_if vif);
        // Save the interface pointer
        this.vif = vif;    
        // Create mailboxes (Allocating memory for wires)
        mbx_gen_drv = new();
        mbx_mon_sco = new();    
        // Create objects and pass connections to them
        gen = new(mbx_gen_drv);      // Generator only needs mailbox to send data
        drv = new(mbx_gen_drv, vif); // Driver needs mailbox to get data AND interface to drive pins
        mon = new(mbx_mon_sco, vif); // Monitor needs mailbox to send data AND interface to read pins
        sco = new(mbx_mon_sco);      // Scoreboard only needs mailbox to get data
    endfunction
// Main task to run all components
    task main();
        $display("=========================================");
        $display("[Environment] Starting Verification Environment...");
        $display("=========================================");
        
        // All tasks run paralelly
        fork
            gen.main(); // it sends N packets and stop
            drv.main(); // runs forever
            drv.read_main(); // runs forever
            mon.main(); // runs forever
            mon.tx_frame_main(); // runs forever
            sco.main(); // runs forever
        join_any // // Wait for any one task to finish others run in background
        
        // Wait until every packet has come back, or give up after 50 ms
        fork
            wait(sco.pass_cnt + sco.fail_cnt >= gen.count);
            #50000000;
        join_any
        
        // Wait some time to let the last packet reach the scoreboard.
        #10000000; 
        
        $display("=========================================");
        $display("[Environment] Pass: %0d | Fail: %0d | Still expected: %0d", sco.pass_cnt, sco.fail_cnt, sco.exp_q.size());
        $display("[Environment] Frame Pass: %0d | Frame Fail: %0d", sco.frame_pass_cnt, sco.frame_fail_cnt);
        $display("[Environment] Verification Environment Finished.");
        $display("=========================================");
    endtask

endclass

`endif
