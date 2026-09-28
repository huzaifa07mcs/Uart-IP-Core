# UART Top-Level IP Core Specification

## 1. Module Overview
The `uart_top` module serves as the primary wrapper for the Full-Duplex UART IP. It integrates the Receiver (`uart_rx`), Transmitter (`uart_tx`), and two dedicated Synchronous FIFOs (for TX and RX) to buffer data between the host system and the serial physical layer.

This top-level design abstracts the bit-level timing, baud rate generation, and synchronization, exposing only a clean, parallel FIFO interface to the host system (e.g., a custom SoC or processor).

## 2. System Architecture
The internal architecture consists of 4 instantiated sub-modules and intermediate glue logic:
- **TX FIFO (16-deep):** Buffers outgoing parallel data from the host.
- **TX Module:** Serializes data from the TX FIFO and drives the `tx` pin.
- **RX Module:** Deserializes incoming data on the `rx` pin using 16x oversampling.
- **RX FIFO (16-deep):** Buffers valid, fully-received frames for the host to read.
- **TX Controller (Glue Logic):** A mini-FSM that monitors the TX FIFO. When the FIFO is not empty and the TX module is idle, it pops one byte and triggers the transmission.

## 3. Parameter Definitions
| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `CLK_FREQ` | 50,000,000 | System clock frequency in Hz. Applied to all sub-modules. |
| `BAUD_RATE` | 9600 | Target transmission and reception speed in bps. |
| `FIFO_DEPTH`| 16 | The depth of both the TX and RX FIFOs. Must be a power of 2. |

## 4. Interface Signals

### 4.1 System & Physical Interface
| Port Name | Direction | Width | Description |
|-----------|-----------|-------|-------------|
| `clk` | Input | 1 | Main system clock. |
| `reset` | Input | 1 | Active-high synchronous reset for all internal modules. |
| `rx` | Input | 1 | Asynchronous serial input pin. |
| `tx` | Output | 1 | Asynchronous serial output pin. |

### 4.2 Configuration Interface
| Port Name | Direction | Width | Description |
|-----------|-----------|-------|-------------|
| `parity_en` | Input | 1 | `1` = Enable hardware parity generation/checking, `0` = Disable. |
| `parity_odd`| Input | 1 | `1` = Odd parity, `0` = Even parity. |

### 4.3 Host Interface (Transmit - TX)
| Port Name | Direction | Width | Description |
|-----------|-----------|-------|-------------|
| `tx_din` | Input | 8 | Data payload to be transmitted. |
| `tx_wr_en` | Input | 1 | Pulses high to write `tx_din` into the TX FIFO. |
| `tx_full` | Output | 1 | When high, host must pause writing. TX FIFO is full. |
| `tx_empty` | Output | 1 | When high, TX FIFO has no pending data. |

### 4.4 Host Interface (Receive - RX)
| Port Name | Direction | Width | Description |
|-----------|-----------|-------|-------------|
| `rx_dout` | Output | 8 | Unread data payload received from the serial line. |
| `rx_rd_en` | Input | 1 | Pulses high to pop the current data from the RX FIFO. |
| `rx_full` | Output | 1 | When high, RX FIFO is full. Incoming frames may be dropped. |
| `rx_empty` | Output | 1 | When high, no new data is available to read. |
| `err_frame` | Output | 1 | Pulses high if a framing error (missing Stop bit) occurred. |
| `err_parity`| Output | 1 | Pulses high if a parity mismatch occurred. |

## 5. Host Interaction Protocol
1. **To Transmit Data:** The host checks if `tx_full` is `0`. If not full, it places data on `tx_din` and asserts `tx_wr_en` for 1 clock cycle. The IP handles the rest automatically.
2. **To Receive Data:** The host polls (or uses an interrupt for) `rx_empty`. When `rx_empty` is `0`, valid data is waiting. The host asserts `rx_rd_en` for 1 clock cycle, and reads `rx_dout` on the subsequent clock edge.
