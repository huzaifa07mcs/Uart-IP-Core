`timescale 1ns / 1ps

module sync_fifo #(parameter DATA_WIDTH = 8, DEPTH=16 )(
    input logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout,
    input logic clk,rst,wr_en,rd_en,
    output logic full,empty
    );

localparam int ADDR_WIDTH = $clog2(DEPTH); // It calculates exactly how many bits you need to represent a certain number

// Memory Definition
logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

// For writing data and read data 
logic [ADDR_WIDTH-1:0] wr_ptr;
logic [ADDR_WIDTH-1:0] rd_ptr;

// For how many items in the FIFO
logic [ADDR_WIDTH:0] count;

// For FIFO full and empty
assign empty = (count == 0);
assign full  = (count == DEPTH);


always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count  <= '0;
            wr_ptr <= '0;
            rd_ptr <= '0;
            dout   <= '0;
        end else begin
            
            // 1. Write Operation
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr      <= wr_ptr + 1'b1;
            end
            
            // 2. Read Operation
            if (rd_en && !empty) begin
                dout   <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1'b1;
            end
            
            // 3. Count Update Logic
            if ((wr_en && !full) && !(rd_en && !empty)) begin
                // Only Write 
                count <= count + 1'b1;
            end else if (!(wr_en && !full) && (rd_en && !empty)) begin
                // Only Read 
                count <= count - 1'b1;
            end
                
        end
    end

endmodule
