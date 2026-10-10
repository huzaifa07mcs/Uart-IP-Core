`ifndef DRIVER_SV
`define DRIVER_SV

`include "uart_trans.sv"
class driver;
    
    transaction trans;
    mailbox mbx;
    // This created memory pointer of physical interface
    // virtual is used because interface is static and class is dynamic 
    virtual uart_if vif;
    
    // Environment passes both mailbox and interface to it 
    function new(mailbox mbx, virtual uart_if vif);
        this.mbx = mbx;
        this.vif = vif;
    endfunction
    
    
    task main();
        forever begin
            // Get packet from mailbox and give it to trans
            mbx.get(trans);
            // Clocking block for driver for timing synchronization
            @(vif.cb_drv);
            
            // Assign values that are input to DUT
            vif.cb_drv.tx_din     <= trans.tx_din;
            vif.cb_drv.tx_wr_en   <= trans.tx_wr_en;
            vif.cb_drv.parity_en  <= trans.parity_en;
            vif.cb_drv.parity_odd <= trans.parity_odd;
            vif.cb_drv.rx         <= trans.rx;
            
            $display("[Driver] Data driven to Interface at time %0t", $time);

            // Next clock: write enable low so the byte goes into FIFO only once
            @(vif.cb_drv);
            vif.cb_drv.tx_wr_en <= 1'b0;

            // Wait for this frame to start and finish, so parity_en/parity_odd stay stable for the whole frame
            wait(vif.tx_busy == 1);
            wait(vif.tx_busy == 0);
            repeat(2) @(vif.cb_drv);
        end
    endtask

    // Reads RX FIFO whenever it is not empty
    task read_main();
        forever begin
            @(vif.cb_drv);
            vif.cb_drv.rx_rd_en <= !vif.cb_drv.rx_empty;
        end
    endtask

endclass

`endif
