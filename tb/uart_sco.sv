`ifndef UART_SCO_SV
`define UART_SCO_SV

`timescale 1ns / 1ps
`include "uart_trans.sv" // Compiler needs to know about transaction class

class scoreboard;
    
    transaction trans;
    mailbox mbx; // Mailbox to get data from monitor

    // Queue of expected bytes, oldest at the front
    logic [7:0] exp_q[$];
    logic [7:0] expected;
    // Second queue: bytes we expect to see on the tx pin, oldest at the front
    logic [7:0] tx_q[$];
    logic [7:0] tx_expected;
    logic       exp_parity;
    int pass_cnt;
    int fail_cnt;
    int frame_pass_cnt;
    int frame_fail_cnt;
    
    // Constructor for scoreboard
    // Environment passes the monitor's mailbox to it
    function new(mailbox mbx);
        this.mbx = mbx;
        this.pass_cnt = 0;
        this.fail_cnt = 0;
        this.frame_pass_cnt = 0;
        this.frame_fail_cnt = 0;
    endfunction
    
    task main();
        forever begin
            // Get packet from mailbox and save it in trans object
            mbx.get(trans);

            if (trans.is_frame == 1) begin
                // Frame event: check the tx pin against our own expectation, not the DUT's
                if (tx_q.size() == 0) begin
                    $display("[Scoreboard] FRAME FAIL! Frame seen on tx but no byte was written.");
                    frame_fail_cnt++;
                end
                else begin
                    tx_expected = tx_q.pop_front();
                    // Parity computed here from the data bits, even: xor of bits, odd: inverted
                    exp_parity = trans.parity_odd ? ~(^tx_expected) : (^tx_expected);

                    if (trans.frame_start !== 1'b0) begin
                        $display("[Scoreboard] FRAME FAIL! Start bit is %0b, expected 0.", trans.frame_start);
                        frame_fail_cnt++;
                    end
                    else if (trans.frame_data !== tx_expected) begin
                        $display("[Scoreboard] FRAME FAIL! Data on tx %0h, expected %0h.", trans.frame_data, tx_expected);
                        frame_fail_cnt++;
                    end
                    else if (trans.parity_en && (trans.frame_parity !== exp_parity)) begin
                        $display("[Scoreboard] FRAME FAIL! Data %0h parity bit %0b, expected %0b (odd mode: %0b).", tx_expected, trans.frame_parity, exp_parity, trans.parity_odd);
                        frame_fail_cnt++;
                    end
                    else if (trans.frame_stop !== 1'b1) begin
                        $display("[Scoreboard] FRAME FAIL! Stop bit is %0b, expected 1.", trans.frame_stop);
                        frame_fail_cnt++;
                    end
                    else begin
                        $display("[Scoreboard] FRAME PASS! Data %0h, parity_en %0b, parity_odd %0b, parity bit %0b", tx_expected, trans.parity_en, trans.parity_odd, trans.frame_parity);
                        frame_pass_cnt++;
                    end
                end
            end
            else if (trans.tx_wr_en == 1) begin
                // Write event: remember what we expect to come back
                exp_q.push_back(trans.tx_din);
                tx_q.push_back(trans.tx_din);
                $display("[Scoreboard] Expected byte stored: %0h at time %0t", trans.tx_din, $time);
            end
            else begin
                // Read event: compare with the oldest expected byte
                if (exp_q.size() == 0) begin
                    $display("[Scoreboard] TEST FAIL! Got %0h but nothing was expected.", trans.rx_dout);
                    fail_cnt++;
                end
                else begin
                    expected = exp_q.pop_front();
                    if (expected == trans.rx_dout) begin
                        $display("[Scoreboard] TEST PASS! Expected %0h, Actual %0h", expected, trans.rx_dout);
                        pass_cnt++;
                    end
                    else begin
                        $display("[Scoreboard] TEST FAIL! Expected %0h, Actual %0h", expected, trans.rx_dout);
                        fail_cnt++;
                    end
                end
            end
        end
    endtask

endclass

`endif
