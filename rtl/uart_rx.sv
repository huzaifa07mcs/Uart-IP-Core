`timescale 1ns / 1ps
module uart_rx #(
    parameter int CLK_FREQ = 50000000,
    parameter int BAUD_RATE = 9600
)(
    input  logic clk,
    input  logic reset,
    input  logic rx,
    input  logic parity_en,
    input  logic parity_odd,
    output logic [7:0] dataout,
    output logic rx_done,
    output logic err_frame,
    output logic err_parity
);

    // FSM State Definition
    typedef enum logic [2:0] {
        IDLE       = 3'b000,
        START_BIT  = 3'b001,
        DATA_BITS  = 3'b010,
        PARITY_BIT = 3'b011,
        STOP_BIT   = 3'b100
    } state_t;

    state_t state, next_state;

    // Oversampling Generator incrase 16x baud rate Speed
    localparam int OVERSAMPLE_LIMIT = CLK_FREQ / (BAUD_RATE * 16);   
    logic [$clog2(OVERSAMPLE_LIMIT)-1:0] tick_cnt;
    logic tick_16x; 
    
    // 16x Baud Tick Generation Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            tick_cnt <= '0;
            tick_16x <= 1'b0;
        end else begin
            // Check if we have reached the 16x oversample limit
            if (tick_cnt == OVERSAMPLE_LIMIT - 1) begin
                tick_cnt <= '0;      
                tick_16x <= 1'b1;  // Generate 1 cycle pulse
            end else begin
                tick_cnt <= tick_cnt + 1'b1;
                tick_16x <= 1'b0;            
            end
        end
    end
    
    logic [3:0] os_cnt;       // Oversample counter (0 to 15)
    logic [2:0] bit_cnt;      // Data bit counter (0 to 7)
    logic [7:0] rx_data_temp; // Temporary register to hold received bits
    logic       rx_parity;    // To store the received parity bit
    
    logic expected_parity; // For parity checking 
    assign expected_parity = parity_odd ? ~(^rx_data_temp) : (^rx_data_temp);
    
    // FSM Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            os_cnt      <= '0;
            bit_cnt     <= '0;
            rx_data_temp<= '0;
            rx_parity   <= 1'b0;
            dataout     <= '0;
            rx_done     <= 1'b0;
            err_frame   <= 1'b0;
            err_parity  <= 1'b0;
        end else begin
            
            // Default
            rx_done <= 1'b0; 

            // FSM only changes state on oversample ticks 
            if (tick_16x) begin
                
                case (state)
                    IDLE: begin
                        os_cnt <= '0;
                        if (rx == 1'b0) begin 
                            // Start bit 
                            state <= START_BIT;
                        end
                    end
                    
                    START_BIT: begin
                        if (os_cnt == 4'd7) begin
                            // exact center of the start bit 
                            if (rx == 1'b0) begin
                                os_cnt <= '0; // Reset counter for data bits
                                bit_cnt<= '0;
                                state  <= DATA_BITS;
                            end else begin
                                // It was a glitch 
                                state  <= IDLE;
                            end
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                    
                    DATA_BITS: begin
                        if (os_cnt == 4'd15) begin
                            // 15 because one bit to second bit center diff
                            os_cnt <= '0;
                            rx_data_temp[bit_cnt] <= rx; // Shift in the bit
                            
                            if (bit_cnt == 3'd7) begin
                                // 8 bits received
                                if (parity_en)
                                    state <= PARITY_BIT;
                                else
                                    state <= STOP_BIT;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                    
                    PARITY_BIT: begin
                        if (os_cnt == 4'd15) begin
                            os_cnt    <= '0;
                            rx_parity <= rx; // Save received parity bit
                            state     <= STOP_BIT;
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                    
                    STOP_BIT: begin
                        if (os_cnt == 4'd15) begin
                            os_cnt <= '0;
                            
                            // Check Framing Error because stop bit must be 1
                            if (rx == 1'b0)
                                err_frame <= 1'b1;
                            else
                                err_frame <= 1'b0;
                                
                            // Check Parity Error 
                            if (parity_en && (rx_parity != expected_parity))
                                err_parity <= 1'b1;
                            else
                                err_parity <= 1'b0;
                                
                            dataout <= rx_data_temp;
                            rx_done <= 1'b1; // Generate 1 pulse for rxdone
                            
                            state <= IDLE; // Wait for next frame
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                    
                    default: state <= IDLE;
                endcase
                
            end else if (state == IDLE && rx == 1'b0) begin
                // In IDLE,don't wait for tick_16x to detect the start edge, so the center (tick 7) is aligned
                state  <= START_BIT;
                os_cnt <= '0;
            end
            
        end
    end

   

endmodule
