# UART Transmitter (TX) IP Core Specification

## 1. Module Overview

The `uart_tx` module is a parameterized, FSM-based digital transmitter implemented in SystemVerilog. It performs parallel-to-serial conversion of 8-bit data payloads, framing them according to the standard asynchronous serial protocol (Start bit, Data bits, optional Parity bit, and Stop bit). 

The module features a built-in parameterized baud rate generator, allowing it to derive the correct serial bit timing directly from the main system clock without requiring an external clock divider.

---

## 2. Parameter Definitions

The module timing is fully scalable through compile-time parameters.

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `CLK_FREQ` | 50,000,000 | The frequency of the system clock (`clk`) in Hertz. Default is 50 MHz. |
| `BAUD_RATE` | 9600 | The target transmission speed in bits per second (bps). |

*Note: The internal baud tick generator calculates the clock divider value automatically using the formula: `Cycles per Baud = CLK_FREQ / BAUD_RATE`.*

---

## 3. Interface Signals

All ports utilize the SystemVerilog `logic` data type.

| Port Name | Direction | Width | Description |
|-----------|-----------|-------|-------------|
| `clk` | Input | 1 | Main system clock. |
| `reset` | Input | 1 | Active-high synchronous reset. Forces FSM to IDLE and `tx` to Logic 1. |
| `datain` | Input | 8 | The 8-bit parallel data payload to be transmitted. |
| `txstart` | Input | 1 | Control signal from the host/FIFO. A high pulse initiates transmission. |
| `parity_en` | Input | 1 | Configuration flag: `1` = Enable hardware parity, `0` = No parity. |
| `parity_odd`| Input | 1 | Configuration flag: `1` = Odd parity, `0` = Even parity. (Ignored if `parity_en` = 0). |
| `tx` | Output | 1 | The serial transmission line. Idles at Logic 1. |
| `txbusy` | Output | 1 | Status flag. Asserted high when a transmission is in progress. |

---

## 4. Protocol & Framing Requirements

When `txstart` is asserted, the transmitter will serialize the frame in the following strict order:
1. **Start Bit:** Drive `tx` to `0` for exactly one baud period.
2. **Data Bits:** Drive `datain` onto `tx`, LSB first (Bit 0 to Bit 7), holding each for one baud period.
3. **Parity Bit (Optional):** If `parity_en` is `1`, drive the calculated parity bit onto `tx` for one baud period.
4. **Stop Bit:** Drive `tx` to `1` for at least one baud period.

---

## 5. Finite State Machine (FSM) Architecture

The transmission control logic is governed by a synchronous Mealy/Moore FSM with the following states:

| State | Name | Description |
|---|---|---|
| `3'b000` | `IDLE` | `tx` is held HIGH. `txbusy` is LOW. Waiting for `txstart` to go HIGH. |
| `3'b001` | `START_BIT` | `tx` is driven LOW. `txbusy` goes HIGH. Internal baud counter starts. |
| `3'b010` | `DATA_BITS` | Shifting out `datain` LSB first. Bit counter tracks progress (0 to 7). |
| `3'b011` | `PARITY_BIT`| Driven only if `parity_en` is high. Transmits computed Even/Odd parity bit. |
| `3'b100` | `STOP_BIT` | `tx` is driven HIGH. Once complete, FSM returns to `IDLE` and lowers `txbusy`. |

---

## 6. Hardware Parity Calculation

Parity is calculated combinationally using XOR reduction operators on the `datain` payload.
- **Even Parity:** The total number of `1`s in the data + parity bit must be an even number. (e.g., `^datain`).
- **Odd Parity:** The total number of `1`s in the data + parity bit must be an odd number. (e.g., `~^datain`).

---

## 7. Timing & Baud Rate Generation

Instead of generating a physical slower clock (which violates FPGA design best practices), the module uses an internal counter (`baud_cnt`). 
- The counter increments every system clock cycle.
- When `baud_cnt == (CLK_FREQ / BAUD_RATE) - 1`, a single-cycle `baud_tick` is generated, and the counter resets.
- The FSM state transitions and data shifts *only* occur when `baud_tick` is high.
