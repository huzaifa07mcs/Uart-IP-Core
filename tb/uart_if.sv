interface uart_if(input logic clk);
    
    // Reset signal
    logic reset;
    
    // DUT Inputs (Driven by the Driver)
    logic [7:0] tx_din;
    logic tx_wr_en;
    logic rx_rd_en;
    logic parity_en;
    logic parity_odd;
    logic rx;
    
    // DUT Outputs (Read by the Monitor)
    logic [7:0] rx_dout;
    logic tx_full;
    logic rx_empty;
    logic tx;
    logic tx_busy;
    
    // Clocking block for the Driver (for synchronization)
    clocking cb_drv @(posedge clk);
        default input #1 output #1;
        output tx_din, tx_wr_en, rx_rd_en, parity_en, parity_odd, rx;
        input  rx_dout, tx_full, rx_empty, tx;
    endclocking
    
    // Clocking block for the Monitor (only for reading signals)
    clocking cb_mon @(posedge clk);
        default input #1 output #1;
        input tx_din, tx_wr_en, rx_rd_en, parity_en, parity_odd, rx;
        input rx_dout, tx_full, rx_empty, tx;
    endclocking

endinterface
