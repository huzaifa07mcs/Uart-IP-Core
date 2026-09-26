module uart_rx #(parameter CLK_FREQ=50000000, parameter BAUD_RATE=9600) (input clk, input reset, input rx, input parity_en, input parity_odd, output reg [7:0] dataout, output reg data_valid, output reg framing_err, output reg parity_err);
endmodule
