# UART IP Core: Micro-Architecture & Deep Hardware Logic Guide

This document provides a clock-cycle accurate, microscopic view of how data flows through the UART IP. It explains the exact logic conditions, counter values, and register shifts that happen in the background.

---

## 1. Synchronous FIFO (`sync_fifo.sv`) Deep Dive
**Purpose:** A circular memory buffer that decouples the fast host processor from the slow UART.

### Internal Registers & Memory:
*   `logic [7:0] mem [0:15]`: The actual RAM array containing 16 slots of 8-bit data.
*   `logic [3:0] wr_ptr`: Points to the index (0-15) where the *next* incoming byte will be saved.
*   `logic [3:0] rd_ptr`: Points to the index (0-15) from where the *next* outgoing byte will be read.
*   `logic [4:0] count`: Tracks the number of items currently in the FIFO (0 to 16).

### Exact Hardware Behavior (At `posedge clk`):
*   **Write Operation:** If `wr_en == 1` AND `full == 0`:
    *   Hardware does: `mem[wr_ptr] <= din`
    *   Hardware does: `wr_ptr <= wr_ptr + 1`
    *   Hardware does: `count <= count + 1`
*   **Read Operation:** If `rd_en == 1` AND `empty == 0`:
    *   Hardware does: `dout <= mem[rd_ptr]`
    *   Hardware does: `rd_ptr <= rd_ptr + 1`
    *   Hardware does: `count <= count - 1`
*   **Flags Logic (Combinational):** 
    *   `assign empty = (count == 0);`
    *   `assign full = (count == 16);`

---

## 2. UART Transmitter (`uart_tx.sv`) Deep Dive
**Purpose:** Serializes parallel data using a strict hardware timer (`baud_tick`).

### The Math (Baud Generation):
*   Clock = 50,000,000 Hz. Baud = 9,600 bps.
*   `BAUD_LIMIT` = 50,000,000 / 9600 = **5208**.
*   A counter (`baud_cnt`) counts from `0` to `5207` on every clock edge. When it hits `5207`, it resets to `0` and pulses `baud_tick = 1` for exactly 1 clock cycle.
*   **Crucial Concept:** The TX FSM *only* evaluates its `case` statements when `baud_tick == 1`. This forces the FSM to change states exactly at 9600 bps.

### FSM State-by-State Logic:
*   **IDLE State:** `tx` is held HIGH (`1`). `txbusy` is `0`. Waiting for `txstart == 1`. When `txstart` arrives, `tx_data <= datain`, `txbusy <= 1`, and state jumps to `START_BIT`.
*   **START_BIT State:** Wait for `baud_tick`. Drive `tx <= 0`. Clear `bit_cnt <= 0`. Jump to `DATA_BITS`.
*   **DATA_BITS State:** 
    *   Drive `tx <= tx_data[0]` (Extract the Least Significant Bit).
    *   Wait for `baud_tick`.
    *   Shift the register right: `tx_data <= {1'b0, tx_data[7:1]}`. (The next bit falls into the 0th position).
    *   Increment `bit_cnt <= bit_cnt + 1`. 
    *   If `bit_cnt == 7`, all 8 bits are sent. Jump to `PARITY_BIT` (or `STOP_BIT`).
*   **STOP_BIT State:** Drive `tx <= 1`. Wait for `baud_tick`. Jump to `IDLE` and set `txbusy <= 0`.

---

## 3. UART Receiver (`uart_rx.sv`) Deep Dive
**Purpose:** Recovers parallel data from a raw serial wire using mathematically calculated sampling points.

### The Math (16x Oversampling):
*   `OVERSAMPLE_LIMIT` = 50,000,000 / (9600 * 16) = **325**.
*   A counter (`tick_cnt`) counts `0` to `324`. When it hits `324`, it pulses `tick_16x = 1` for 1 clock cycle.
*   *Why 325?* A single bit lasts 5208 clock cycles. $325 \times 16 = 5200$ (approx. 5208). We have sliced one bit width into 16 tiny time segments.

### FSM State-by-State Logic:
*   **IDLE State:** 
    *   It does NOT wait for `tick_16x`. It continuously monitors `rx`.
    *   If `rx == 0`, a Start Bit is beginning. Immediately jump to `START_BIT` and reset `os_cnt <= 0`. (This anchors our timing exactly to the falling edge).
*   **START_BIT State:**
    *   On every `tick_16x`, hardware does `os_cnt <= os_cnt + 1`.
    *   When `os_cnt == 7` (7 * 325 = 2275 cycles later), we are in the physical center of the Start Bit. 
    *   Check `rx`. If `rx == 0`, it's valid. Reset `os_cnt <= 0` and jump to `DATA_BITS`. If `rx == 1`, it was a noise glitch; jump back to `IDLE`.
*   **DATA_BITS State:**
    *   On every `tick_16x`, increment `os_cnt`.
    *   When `os_cnt == 15` (16 ticks later, landing in the exact center of the next bit), capture the data: `rx_data_temp[bit_cnt] <= rx`.
    *   Increment `bit_cnt <= bit_cnt + 1`. Reset `os_cnt <= 0`.
    *   Repeat until `bit_cnt == 7`. Jump to `STOP_BIT`.
*   **STOP_BIT State:**
    *   Wait until `os_cnt == 15`. 
    *   Check if `rx == 1` (Valid Stop Bit). 
    *   Output data: `dataout <= rx_data_temp`. Pulse `rx_done <= 1`.

---

## 4. Top Level Integration (`uart_top.sv`) Deep Dive
**Purpose:** Wires the components together and automates data handshakes.

### The TX Glue Logic (The "Middleman" FSM):
Since the TX FIFO and UART TX don't know about each other, the Top Module has a mini-FSM:
*   **State IDLE_CTRL:** 
    *   Condition: `if (!tx_empty && !tx_busy)`. This means "Data is available" AND "Transmitter is ready".
    *   Action: Drive `tx_fifo_rd_en <= 1`. Transition to `WAIT_CTRL`.
*   **State WAIT_CTRL:**
    *   *Why wait?* The `sync_fifo` uses block RAM logic. When `rd_en` is high on clock edge 1, the data (`tx_fifo_dout`) only becomes valid on clock edge 2. 
    *   Action: Drive `tx_start <= 1`. The UART TX latches the valid data. Transition back to `IDLE_CTRL`.

### The RX Direct Wiring:
*   The Top Module uses a continuous assignment for the RX FIFO write enable: 
    `.wr_en (rx_done && !rx_full)`
*   Because `uart_rx` was specifically designed to pulse `rx_done` for exactly 1 clock cycle, we do not need a state machine here. The 1-cycle pulse directly triggers a 1-cycle write into the RX FIFO. The `!rx_full` condition ensures we don't corrupt the FIFO if it's already full (the byte is dropped).

---

## 5. Hyper-Detailed Trace: Sending the Letter 'A'
Let's track variables cycle-by-cycle for sending `8'h41` (`01000001`).

**PHASE 1: Host writes to FIFO**
1.  **Host** sets `tx_din = 8'h41`, `tx_wr_en = 1`.
2.  `posedge clk`: FIFO does `mem[0] = 8'h41`, `wr_ptr = 1`, `count = 1`. `tx_empty` becomes `0`.

**PHASE 2: Glue Logic fetches data**
3.  Top Module FSM sees `tx_empty == 0`. It asserts `tx_fifo_rd_en = 1`.
4.  `posedge clk`: FIFO reads `mem[0]`. Top Module FSM enters `WAIT_CTRL`.
5.  `tx_fifo_dout` now holds `8'h41`. Top Module asserts `tx_start = 1`.

**PHASE 3: TX Serialization (`tx_data` shifting)**
6.  `uart_tx` sees `txstart = 1`. `tx_data` gets `01000001`. `txbusy` becomes `1`.
7.  **Start Bit:** `tx` driven to `0`. FSM waits 5208 cycles.
8.  **Bit 0:** `tx` driven to `tx_data[0]` (which is `1`). Wait 5208 cycles. 
    *   Shift occurs: `tx_data` becomes `00100000`. `bit_cnt` = 1.
9.  **Bit 1:** `tx` driven to `tx_data[0]` (which is `0`). Wait 5208 cycles.
    *   Shift occurs: `tx_data` becomes `00010000`. `bit_cnt` = 2.
10. *(Repeats until bit 7 is sent)*
11. **Stop Bit:** `tx` driven to `1`. Wait 5208 cycles. `txbusy` becomes `0`.

**PHASE 4: RX Deserialization**
12. `uart_rx` sees `rx` go from `1` to `0`. `os_cnt` starts counting `tick_16x`.
13. `os_cnt == 7` (Middle of start bit): `rx` is `0`. Validated. Reset `os_cnt`.
14. `os_cnt == 15` (Middle of Bit 0): `rx` is `1`. `rx_data_temp[0] <= 1`.
15. `os_cnt == 15` (Middle of Bit 1): `rx` is `0`. `rx_data_temp[1] <= 0`.
16. *(Repeats until)* `rx_data_temp` holds `01000001` (`8'h41`).
17. `os_cnt == 15` (Middle of Stop Bit): `rx` is `1`. Validated. 
18. `dataout` gets `8'h41`. `rx_done` pulses `1` for one clock cycle.

**PHASE 5: FIFO Write and Host Read**
19. RX FIFO sees `wr_en = 1` (driven by `rx_done`).
20. `posedge clk`: RX FIFO does `mem[0] = 8'h41`, `wr_ptr = 1`, `count = 1`. `rx_empty` becomes `0`.
21. **Host** sees `rx_empty == 0`. It asserts `rx_rd_en = 1`.
22. `posedge clk`: RX FIFO outputs `mem[0]`.
23. Host successfully reads `8'h41` on `rx_dout`.
