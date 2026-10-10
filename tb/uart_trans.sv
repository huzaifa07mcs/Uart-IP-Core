`ifndef UART_TRANS_SV
`define UART_TRANS_SV

class transaction;
//Outputs from driver 
// RX and tx not included becuse they are physical uart pins
rand logic [7:0] tx_din; // generates random data
rand logic tx_wr_en;
rand logic rx_rd_en; 
rand logic parity_en; 
rand logic parity_odd; 
logic rx;
logic tx;
// Inputs from driver
logic [7:0] rx_dout;
logic tx_full;
logic tx_empty;
logic rx_full;
logic rx_empty;
logic err_frame;
logic err_parity;

// Fields filled by the monitor when it decodes a frame from the tx pin
bit is_frame;
logic [7:0] frame_data;
logic frame_start;
logic frame_parity;
logic frame_stop;

constraint c_wr_en { tx_wr_en == 1; }

// Display Function
    function void display(string name = "TRANSACTION");
        $display("--------------------------------");
        $display("- %s ", name);
        $display("--------------------------------");
        $display("TX Data Sent    : '%c' (8'h%0h)", tx_din, tx_din); 
        $display("RX Data Recv    : '%c' (8'h%0h)", rx_dout, rx_dout);
        $display("Parity En: %0b | Parity Odd: %0b", parity_en, parity_odd);
        $display("Errors -> Frame: %0b | Parity: %0b", err_frame, err_parity);
        $display("--------------------------------");
    endfunction
endclass

`endif
