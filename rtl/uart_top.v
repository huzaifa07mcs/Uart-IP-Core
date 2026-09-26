module uart_top #(parameter CLK_FREQ=50000000, parameter BAUD_RATE=9600) (input clk, input reset, input rx, output tx, input [7:0] datain, input txstart, output txbusy, output tx_fifo_full, output [7:0] dataout, output data_valid, output rx_fifo_empty, input parity_en, input parity_odd, output framing_err, output parity_err, output overrun_err);
endmodule
