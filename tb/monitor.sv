`ifndef MONITOR_SV
`define MONITOR_SV

`include "uart_trans.sv"

class monitor;
    
    transaction trans;
    mailbox mbx;
    virtual uart_if vif;

    // Previous sample: was a read accepted by the FIFO in the last clock
    bit prev_read_ok;

    // Clock cycles in one bit time, must match CLK_FREQ / BAUD_RATE of the DUT
    int BIT_CLKS = 5208;
    
    // Environment passes both mailbox and interface to it 
    function new(mailbox mbx, virtual uart_if vif);
        this.mbx = mbx;
        this.vif = vif;
        this.prev_read_ok = 0;
    endfunction
    
    task main();
        forever begin
            // Clocking block for monitor for timing synchronization
            @(vif.cb_mon);

            // Event 1: a byte was written into TX FIFO (this is the expected data)
            if (vif.cb_mon.tx_wr_en == 1 && vif.cb_mon.tx_full == 0) begin
                trans = new();
                trans.tx_din     = vif.cb_mon.tx_din;
                trans.tx_wr_en   = 1;
                trans.parity_en  = vif.cb_mon.parity_en;
                trans.parity_odd = vif.cb_mon.parity_odd;
                mbx.put(trans);
            end

            // Event 2: dout is valid one clock after a read was accepted (this is the actual data)
            if (prev_read_ok) begin
                trans = new();
                trans.tx_wr_en = 0;
                trans.rx_dout  = vif.cb_mon.rx_dout;
                mbx.put(trans);
            end

            // Remember if this clock had a read that the FIFO accepted
            prev_read_ok = (vif.cb_mon.rx_rd_en == 1 && vif.cb_mon.rx_empty == 0);
        end
    endtask

    // Event 3: decode one frame from the tx pin, sampling each bit in the middle
    task tx_frame_main();
        transaction ftrans;
        forever begin
            // Wait for the line to be idle, then for the falling edge of the start bit
            wait(vif.tx === 1'b1);
            @(negedge vif.tx);

            ftrans = new();
            ftrans.is_frame   = 1;
            ftrans.parity_en  = vif.cb_mon.parity_en;
            ftrans.parity_odd = vif.cb_mon.parity_odd;

            // Move to the middle of the start bit
            repeat(BIT_CLKS/2) @(vif.cb_mon);
            ftrans.frame_start = vif.cb_mon.tx;

            // 8 data bits, LSB first, each sampled in the middle
            for (int i = 0; i < 8; i++) begin
                repeat(BIT_CLKS) @(vif.cb_mon);
                ftrans.frame_data[i] = vif.cb_mon.tx;
            end

            // Parity bit only if parity is enabled
            if (ftrans.parity_en) begin
                repeat(BIT_CLKS) @(vif.cb_mon);
                ftrans.frame_parity = vif.cb_mon.tx;
            end

            // Stop bit
            repeat(BIT_CLKS) @(vif.cb_mon);
            ftrans.frame_stop = vif.cb_mon.tx;

            mbx.put(ftrans);
        end
    endtask

endclass

`endif
