`timescale 1ns / 1ps
module uart_top #(
    parameter int CLK_FREQ   = 50000000,
    parameter int BAUD_RATE  = 9600,
    parameter int FIFO_DEPTH = 16
)(
    input  logic clk,
    input  logic reset,
    
    // UART Physical Pins
    input  logic rx,
    output logic tx,
    input  logic parity_en,
    input  logic parity_odd,
    
    // Host Interface for TX 
    input  logic [7:0] tx_din,
    input  logic       tx_wr_en,
    output logic       tx_full,
    output logic       tx_empty,
    
    // Host Interface for RX 
    output logic [7:0] rx_dout,
    input  logic       rx_rd_en,
    output logic       rx_full,
    output logic       rx_empty,
    
    // Error Flags from RX
    output logic err_frame,
    output logic err_parity
);

    
    // Internal Wires 
    logic [7:0] tx_fifo_dout;
    logic       tx_fifo_rd_en;
    logic       tx_start;
    logic       tx_busy;
    
    logic [7:0] rx_data_out;
    logic       rx_done;

    // TX FIFO Instance  
    sync_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(FIFO_DEPTH)
    ) tx_fifo_inst (
        .clk   (clk),
        .rst   (reset),
        .wr_en (tx_wr_en),
        .din   (tx_din),
        .rd_en (tx_fifo_rd_en),
        .dout  (tx_fifo_dout),
        .full  (tx_full),
        .empty (tx_empty)
    );

    //  UART Transmitter Instance 
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) tx_inst (
        .clk        (clk),
        .reset      (reset),
        .datain     (tx_fifo_dout),
        .txstart    (tx_start),
        .parity_en  (parity_en),
        .parity_odd (parity_odd),
        .tx         (tx),
        .txbusy     (tx_busy)
    );

    
    // Connecting TX FIFO to TX
    typedef enum logic {IDLE_CTRL, WAIT_CTRL} tx_ctrl_state_t;
    tx_ctrl_state_t tx_ctrl_state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_ctrl_state <= IDLE_CTRL;
            tx_fifo_rd_en <= 1'b0;
            tx_start      <= 1'b0;
        end else begin
            tx_fifo_rd_en <= 1'b0; 
            tx_start      <= 1'b0; 
            
            case (tx_ctrl_state)
                IDLE_CTRL: begin
                    // If data exists and TX is free
                    if (!tx_empty && !tx_busy) begin
                        tx_fifo_rd_en <= 1'b1; 
                        tx_ctrl_state <= WAIT_CTRL;
                    end
                end
                
                WAIT_CTRL: begin
                    // Wait on cycle and start tx
                    tx_start      <= 1'b1;
                    tx_ctrl_state <= IDLE_CTRL;
                end
            endcase
        end
    end

    // UART Receiver Instance 
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) rx_inst (
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),
        .parity_en  (parity_en),
        .parity_odd (parity_odd),
        .dataout    (rx_data_out),
        .rx_done    (rx_done),
        .err_frame  (err_frame),
        .err_parity (err_parity)
    );

    // RX FIFO Instance 
    sync_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(FIFO_DEPTH)
    ) rx_fifo_inst (
        .clk   (clk),
        .rst   (reset),
        .wr_en (rx_done && !rx_full), 
        .din   (rx_data_out),
        .rd_en (rx_rd_en),
        .dout  (rx_dout),
        .full  (rx_full),
        .empty (rx_empty)
    );

endmodule
