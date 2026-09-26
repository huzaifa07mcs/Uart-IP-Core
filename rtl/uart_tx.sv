`timescale 1ns / 1ps

module uart_tx #(
    parameter int CLK_FREQ = 50000000,
    parameter int BAUD_RATE = 9600
)(
    input  logic clk,reset,
    input  logic [7:0] datain,
    input  logic txstart,
    input  logic parity_en,
    input  logic parity_odd,
    output logic tx,
    output logic txbusy
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
    
    // Calculate how many clock cycles make up one baud period 
    localparam int BAUD_LIMIT = CLK_FREQ / BAUD_RATE;
    
    // Automatically calculate the required bit width for the counter
    logic [$clog2(BAUD_LIMIT)-1:0] baud_cnt;
    logic baud_tick;

    // Baud Tick Generation Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            baud_cnt  <= '0;
            baud_tick <= 1'b0;
        end else begin
            // Check if we have reached the baud limit
            if (baud_cnt == BAUD_LIMIT - 1) begin
                baud_cnt  <= '0;      
                baud_tick <= 1'b1;  // Generaate 1 cycle pulse
            end else begin
                baud_cnt  <= baud_cnt + 1'b1; // Increment counter
                baud_tick <= 1'b0;            // Keep tick low
            end
        end
    end
    
   
    logic [2:0] bit_cnt;    // For 8 bits
    logic [7:0] tx_data;    // For Data
    logic       parity_calc; // Holds the calculated parity bit

   // Calculate the parity bit 
   assign parity_calc = parity_odd ? ~(^tx_data) : (^tx_data);

 // FSM Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= IDLE;
            tx       <= 1'b1; // IN IDLE
            txbusy   <= 1'b0;
            bit_cnt  <= '0;
            tx_data  <= '0;
        end else begin
            
            case (state)
                IDLE: begin
                    tx     <= 1'b1;
                    txbusy <= 1'b0;
                   
                    if (txstart) begin
                        tx_data <= datain; // Data Stor as latch
                        txbusy  <= 1'b1;   // Status busy
                        state   <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    tx <= 1'b0; // Start bit low
                    
                    if (baud_tick) begin 
                        state   <= DATA_BITS;
                        bit_cnt <= '0; // Bit counter set to 0
                    end
                end
                
                DATA_BITS: begin
                    tx <= tx_data[bit_cnt]; // Serially sent data from LSB 
                    
                    if (baud_tick) begin
                        if (bit_cnt == 3'd7) begin
                            // After 8 bits parity status check(on/off)
                            if (parity_en)
                                state <= PARITY_BIT;
                            else
                                state <= STOP_BIT;
                        end else begin
                            bit_cnt <= bit_cnt + 1'b1; // Next bit
                        end
                    end
                end
                
                PARITY_BIT: begin
                    tx <= parity_calc; // Store calculaated prity bit 
                    
                    if (baud_tick) begin
                        state <= STOP_BIT;
                    end
                end
                
                STOP_BIT: begin
                    tx <= 1'b1; // Stop bit always High
                    
                    if (baud_tick) begin
                        state  <= IDLE; 
                    end
                end
                
                default: state <= IDLE; 
            endcase
            
        end
    end
endmodule
