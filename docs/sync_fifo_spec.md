# Synchronous FIFO IP Core Specification

## 1. Module Overview

The `sync_fifo` is a parameterized, single-clock domain First-In-First-Out (FIFO) memory buffer implemented in SystemVerilog. In the context of the UART IP Core, it serves as the critical data buffer ("waiting room") between the host system and the asynchronous serial FSMs. It safely decouples the high-speed system bus from the slower, strict-timing serial transmission lines.

The FIFO is designed as a circular buffer utilizing read and write pointers, alongside an internal item counter for precise and robust flag generation.

---

## 2. Parameter Definitions

The module is highly configurable via SystemVerilog parameters, allowing it to scale automatically without modifying the underlying RTL logic.

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `DATA_WIDTH` | 8 | Width of each data word in bits. (8 bits for standard UART). |
| `DEPTH` | 16 | Number of words the FIFO can store. **Note:** Must be a power of 2 (e.g., 8, 16, 32) to allow for natural pointer rollover. |

---

## 3. Interface Signals

All signals utilize the SystemVerilog `logic` data type.

| Port Name | Direction | Width | Description |
|-----------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock. All operations are synchronous to the rising edge. |
| `rst` | Input | 1 | Active-high synchronous reset. Clears pointers, count, and output data. |
| `wr_en` | Input | 1 | Write enable strobe. Writes `din` on the rising clock edge if not full. |
| `din` | Input | `DATA_WIDTH` | Data input bus from the producer. |
| `rd_en` | Input | 1 | Read enable strobe. Pops data out to `dout` on the rising clock edge if not empty. |
| `dout` | Output | `DATA_WIDTH` | Data output bus to the consumer. |
| `full` | Output | 1 | Asserted high when the FIFO contains `DEPTH` elements. |
| `empty` | Output | 1 | Asserted high when the FIFO contains 0 elements. |

---

## 4. Functional Behavior

### Write Operation
When `wr_en` is asserted and the `full` flag is deasserted, the data present on the `din` bus is written into the memory array at the current write pointer location. The write pointer is then incremented by 1.

### Read Operation
When `rd_en` is asserted and the `empty` flag is deasserted, the data at the current read pointer location is latched onto the `dout` bus. The read pointer is then incremented by 1.

### Simultaneous Read and Write
The FIFO supports simultaneous read and write operations in the same clock cycle (provided it is neither completely full nor completely empty). In this scenario, both pointers increment independently, and the internal tracking counter remains unchanged (the +1 and -1 operations cancel out).

### Circular Buffer & Pointer Rollover
Because the `DEPTH` is restricted to powers of 2 (e.g., 16, which requires a 4-bit pointer), the internal pointers (`wr_ptr` and `rd_ptr`) naturally roll over from their maximum binary value (e.g., `4'b1111`) back to zero (`4'b0000`) upon incrementing. This eliminates the need for extra reset multiplexers or modulo logic in the datapath.

---

## 5. Protection Policies (Edge Cases)

To ensure data integrity, the FIFO implements hardware-level protection against illegal operations:

- **Overflow Protection:** If a write operation (`wr_en`) is attempted while the `full` flag is active, the write is explicitly ignored. The write pointer does not advance, and existing data is protected from being overwritten.
- **Underflow Protection:** If a read operation (`rd_en`) is attempted while the `empty` flag is active, the read is explicitly ignored. The read pointer does not advance, and `dout` retains its previous state.
