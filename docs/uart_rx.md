# UART Receiver (RX) IP Core Specification

## 1. Module Overview
The `uart_rx` module is a parameterized digital receiver implemented in SystemVerilog. It performs serial-to-parallel conversion, extracting 8-bit data payloads from an asynchronous serial stream. 

To ensure robust data recovery in noisy environments, the receiver utilizes a **16x oversampling** architecture. This allows the FSM to synchronize to the falling edge of the Start bit and sample subsequent data bits exactly in the center of their bit periods.

## 2. Parameter Definitions
| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `CLK_FREQ` | 50,000,000 | System clock frequency in Hz. |
| `BAUD_RATE` | 9600 | Target baud rate in bps. |

*Note: The internal tick generator will run at `16 * BAUD_RATE`.*

## 3. Interface Signals
| Port Name | Direction | Width | Description |
|-----------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock. |
| `reset` | Input | 1 | Active-high synchronous reset. |
| `rx` | Input | 1 | Asynchronous serial input line. |
| `parity_en` | Input | 1 | `1` = Expect hardware parity, `0` = No parity. |
| `parity_odd`| Input | 1 | `1` = Odd parity expected, `0` = Even parity expected. |
| `dataout` | Output | 8 | The extracted parallel data payload. |
| `rx_done` | Output | 1 | Pulses high for 1 clock cycle when a valid frame is fully received. |
| `err_frame` | Output | 1 | Asserts if the Stop bit is missing (sampled as 0). |
| `err_parity`| Output | 1 | Asserts if the received parity bit does not match the computed parity. |

## 4. Oversampling and Synchronization
- A `tick_generator` produces a clock enable pulse 16 times per baud period.
- When `rx` drops to `0` (Start Bit), a counter starts counting these ticks.
- At tick `7` (the center of the start bit), `rx` is sampled again. If it is still `0`, it's a valid Start bit.
- From then on, the FSM waits 16 ticks to sample the center of each subsequent Data, Parity, and Stop bit.

## 5. FSM Architecture
| State | Name | Description |
|---|---|---|
| `3'b000` | `IDLE` | Waiting for `rx` to go LOW. |
| `3'b001` | `START_BIT` | Verifying the start bit at the 7th oversample tick. |
| `3'b010` | `DATA_BITS` | Sampling 8 data bits, each spaced 16 ticks apart. |
| `3'b011` | `PARITY_BIT`| Sampling the parity bit and verifying it against calculated parity. |
| `3'b100` | `STOP_BIT` | Sampling the stop bit, asserting `rx_done` and error flags. |
