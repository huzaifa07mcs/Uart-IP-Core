# UART IP Core

A UART transceiver written in SystemVerilog, with a 16-entry TX FIFO, a 16-entry RX FIFO, optional parity (even or odd), and framing and parity error flags. It was extended from a baseline Verilog TX/RX design into a peripheral-style IP block and verified in Vivado XSIM with a self-checking, class-based SystemVerilog testbench (no UVM).

The project follows a specification, implementation, testbench, simulation, fix flow. The testbench found a real RTL bug in the TX control logic during bring-up, and its scoreboard was checked with a mutation test to show that it can actually fail.

Author: Huzaifa, Electrical Engineering, NUST 

---

## Table of Contents
- [Highlights](#highlights)
- [UART Specifications](#uart-specifications)
- [Frame Format](#frame-format)
- [Block Overview](#block-overview)
- [Port Description](#port-description)
- [Module Descriptions](#module-descriptions)
- [Repository Structure](#repository-structure)
- [Development Workflow](#development-workflow)
- [Module Status](#module-status)
- [Verification](#verification)
- [Testbench Architecture](#testbench-architecture)
- [Simulation Results Summary](#simulation-results-summary)
- [Mutation Test](#mutation-test)
- [Bug Found by the Testbench](#bug-found-by-the-testbench)
- [How to Run](#how-to-run)
- [Known Limitations](#known-limitations)
- [Future Work](#future-work)
- [Tools](#tools)
- [License](#license)

---

## Highlights
- Parameterized clock frequency and baud rate, with the bit period derived at compile time
- Even, odd, or no parity, selected at runtime with two input pins
- 16-entry synchronous FIFOs on both the TX and RX sides
- Framing and parity error flags on the receiver
- Self-checking testbench with a queue-based scoreboard and no manual waveform review needed for pass or fail
- A second scoreboard check decodes the frame straight off the `tx` pin and computes parity independently of the DUT
- Scoreboard validated with a mutation test (parity polarity deliberately flipped)
- The testbench caught a real RTL bug in the TX control logic, now fixed

---

## UART Specifications

| Feature | Specification |
| :--- | :--- |
| **Language** | RTL in SystemVerilog, testbench in SystemVerilog |
| **Clock** | 50 MHz default (`CLK_FREQ` parameter) |
| **Baud Rate** | 9600 default (`BAUD_RATE` parameter), 5208 clocks per bit |
| **Data Bits** | 8, LSB first |
| **Parity** | None, even, or odd, set by `parity_en` and `parity_odd` |
| **Stop Bits** | 1 |
| **FIFO Depth** | 16 entries (`FIFO_DEPTH` parameter), 8 bits wide |
| **Reset** | Asynchronous, active-high |
| **Clock Domains** | Single |
| **Simulation Tool** | Xilinx Vivado 2019.1 (XSIM) |

---

## Frame Format

```text
idle  start  D0 D1 D2 D3 D4 D5 D6 D7  [parity]  stop  idle
 1      0    <---- LSB first ------>  optional    1     1
```

| Frame type | Bits | Duration at 9600 baud |
| :--- | :---: | :--- |
| Without parity | 10 | 520.8 us |
| With parity | 11 | 572.9 us |

One bit is 5208 clock cycles. With the 10 ns simulation clock, that is 52.08 us.

Parity rule: for even parity the parity bit is the XOR of the 8 data bits, and for odd parity it is the inverse of that.

---

## Block Overview

```text
              +---------------------------- uart_top ----------------------------+
              |                                                                  |
 tx_din ----->|--> [ TX FIFO ] --> TX control FSM --> [ uart_tx ] ------------------> tx
 tx_wr_en --->|     (16 x 8)       IDLE/WAIT/BUSY       baud gen + frame FSM     |
              |                                                                  |
 rx_dout <----|<-- [ RX FIFO ] <-- [ uart_rx ] <---------------------------------- rx
 rx_rd_en --->|     (16 x 8)        sampling, parity, framing checks             |
              |                                                                  |
              +------------------------------------------------------------------+
```

The host writes a byte into the TX FIFO. The TX control FSM pulls the byte out of the FIFO when the transmitter is idle and starts `uart_tx`, which serializes it onto `tx`. The receiver watches `rx`, rebuilds each byte, and pushes it into the RX FIFO. The host reads bytes out of the RX FIFO at its own pace.

---

## Port Description

Ports of `uart_top`:

| Port | Direction | Description |
| :--- | :---: | :--- |
| `clk` | in | System clock |
| `reset` | in | Asynchronous reset, active-high |
| `rx` | in | Serial receive line |
| `tx` | out | Serial transmit line |
| `parity_en` | in | Enable parity generation and checking |
| `parity_odd` | in | 1 = odd parity, 0 = even parity |
| `tx_din[7:0]` | in | Byte to transmit |
| `tx_wr_en` | in | Write `tx_din` into the TX FIFO |
| `tx_full` | out | TX FIFO is full |
| `tx_empty` | out | TX FIFO is empty |
| `rx_dout[7:0]` | out | Byte read from the RX FIFO |
| `rx_rd_en` | in | Read one byte from the RX FIFO |
| `rx_full` | out | RX FIFO is full |
| `rx_empty` | out | RX FIFO is empty |
| `err_frame` | out | Stop bit was not 1 |
| `err_parity` | out | Received parity did not match |

Behaviour notes:
- `rx_dout` is registered. The byte appears one clock after `rx_rd_en` is accepted, not in the same cycle.
- A write to a full TX FIFO is ignored.
- A byte that completes while the RX FIFO is full is dropped silently. There is no overrun flag yet.
- A byte with a parity error is still pushed into the RX FIFO. Only `err_parity` is raised.

---

## Module Descriptions

### `sync_fifo`
Single-clock FIFO with a memory array, a write pointer, a read pointer, and an item counter. `full` is `count == DEPTH` and `empty` is `count == 0`. A write is ignored when full, and a read is ignored when empty. `dout` is a register, so read data appears one clock after the read. `dout` keeps its last value when the FIFO is empty. The same module is used for both TX and RX.

### `uart_tx`
Baud tick generator plus a five-state frame FSM.

| State | Action |
| :--- | :--- |
| `IDLE` | `tx` high. On `txstart`, latch the data and go to `START_BIT`. |
| `START_BIT` | Drive `tx` low for one baud tick. |
| `DATA_BITS` | Send `tx_data[bit_cnt]`, LSB first, advance on each baud tick. |
| `PARITY_BIT` | Send the computed parity, only if `parity_en` is set. |
| `STOP_BIT` | Drive `tx` high for one baud tick, then return to `IDLE`. |

`txbusy` is high from the moment `txstart` is accepted until the stop bit finishes. The baud counter counts up to `CLK_FREQ / BAUD_RATE - 1` and produces a one-cycle tick.

### `uart_rx`
Receiver that detects the falling edge of `rx` as a start bit, samples data at the middle of each bit, checks parity when enabled, checks the stop bit, and pulses `rx_done` with the received byte. It drives `err_frame` and `err_parity`. Full behaviour is in `docs/uart_rx_spec.md`.

### `uart_top`
Instantiates both FIFOs, `uart_tx`, and `uart_rx`, and contains the TX control FSM that moves bytes from the TX FIFO into the transmitter.

| TX control state | Action |
| :--- | :--- |
| `IDLE_CTRL` | If the TX FIFO is not empty and `tx_busy` is low, pulse `tx_fifo_rd_en` and go to `WAIT_CTRL`. |
| `WAIT_CTRL` | Pulse `tx_start` and go to `BUSY_CTRL`. |
| `BUSY_CTRL` | Wait for `tx_busy` to go high, then return to `IDLE_CTRL`. |

The RX FIFO write enable is `rx_done && !rx_full`.

---

## Repository Structure

```text
UART-IP-Core/
│
├── README.md
├── verification_results.md
│
├── docs/                           Specifications and block descriptions
│   ├── UART IP Core Specification.md
│   ├── sync_fifo_spec.md
│   ├── uart_rx_spec.md
│   ├── uart_tx_spec.md
│   ├── uart_top_spec.md
│   └── Working.md
│
├── rtl/                            Synthesizable design
│   ├── uart_top.sv
│   ├── uart_tx.sv
│   ├── uart_rx.sv
│   └── sync_fifo.sv
│
└── tb/                             Self-checking SystemVerilog testbench
    ├── uart_if.sv
    ├── uart_trans.sv
    ├── generator.sv
    ├── driver.sv
    ├── monitor.sv
    ├── uart_sco.sv
    ├── environment.sv
    └── tb_top.sv
```

---

## Development Workflow

1. **Specify**: write the block spec before any RTL, covering ports, behaviour, and edge cases.
2. **Implement**: write the SystemVerilog RTL.
3. **Test**: write a self-checking testbench that reports pass or fail by itself.
4. **Simulate**: run behavioural simulation in Vivado XSIM.
5. **Verify**: compare the results against the spec.
6. **Fix**: debug and correct what the testbench finds.
7. **Integrate**: merge the verified blocks into `uart_top`.

This follows a normal hardware development flow rather than writing everything first and debugging at the end.

---

## Module Status

| Module | Spec | RTL | Testbench | Simulation | Status |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **sync_fifo** | ✅ | ✅ | Integration TB | ✅ | Complete |
| **uart_tx** | ✅ | ✅ | Integration TB | ✅ | Complete |
| **uart_rx** | ✅ | ✅ | Integration TB | ✅ | Complete |
| **uart_top** | ✅ | ✅ | Integration TB | ✅ | Complete |
| **Testbench environment** | ✅ | n/a | ✅ | ✅ | Complete for loopback and parity scope |

Not started:

| Item | Status |
| :--- | :--- |
| Error injection (framing, parity) | Not started |
| RX FIFO overrun flag and test | Not started |
| FIFO stress and full-duplex tests | Not started |
| Functional coverage | Not started |

---

## Verification

The DUT is verified in loopback: `tb_top` connects the DUT `tx` output to its own `rx` input. The test sends 30 random bytes, each with a random parity setting, and checks everything that comes back.

**Verified:**
- Every byte written to the TX FIFO comes back unchanged from the RX FIFO, in order
- Parity off, even parity, and odd parity
- Start bit, 8 data bits, parity bit, and stop bit on the `tx` pin, checked by the testbench with its own computed parity
- Frame length and timing: 10-bit and 11-bit frames match 52.08 us per bit

**Not verified yet:** framing and parity error flags, RX FIFO overrun, FIFO full behaviour, full-duplex traffic, functional coverage.

---

## Testbench Architecture

```text
 generator --mbx_gen_drv--> driver --> [ uart_if ] <--> DUT
                                           |
                                        monitor --mbx_mon_sco--> scoreboard
```

| File | Role |
| :--- | :--- |
| `uart_if.sv` | Interface with a clocking block for the driver (`cb_drv`) and one for the monitor (`cb_mon`) |
| `uart_trans.sv` | Transaction class with a random byte, random `parity_en`, and random `parity_odd`. A constraint forces `tx_wr_en` to 1. |
| `generator.sv` | Creates 30 random transactions and puts them in the mailbox |
| `driver.sv` | `main` writes one byte, drops `tx_wr_en` on the next clock, then waits for `tx_busy` to rise and fall so the parity setting stays fixed for the whole frame. `read_main` reads the RX FIFO whenever it is not empty. |
| `monitor.sv` | `main` reports FIFO write events and FIFO read events (read data is sampled one clock after the read). `tx_frame_main` decodes each frame from the `tx` pin by sampling the middle of every bit. |
| `uart_sco.sv` | Runs the two checks below |
| `environment.sv` | Creates all components, starts them in parallel, waits, and prints the summary |
| `tb_top.sv` | Instantiates the DUT, clock, and reset. Wires `tx` to `rx` for loopback and exposes `tx_busy` to the interface. |

Scoreboard checks:

1. **Data check.** Every byte written into the TX FIFO is pushed into a queue. Every byte read out of the RX FIFO is compared with the oldest queue entry.
2. **Frame check.** Each frame decoded from the `tx` pin is checked for start bit, data, parity, and stop bit. The expected parity is computed inside the scoreboard from the data bits, so a parity bug inside the DUT cannot hide.

---

## Simulation Results Summary

| Metric | Value |
| :--- | :--- |
| **Bytes written to TX FIFO** | 30 |
| **Bytes read back correct** | 30 |
| **Data mismatches** | 0 |
| **Bytes still expected at end** | 0 |
| **Frames decoded on `tx` pin, correct** | 30 |
| **Frame failures** | 0 |
| **Parity off frames** | 8 |
| **Even parity frames** | 12 |
| **Odd parity frames** | 10 |
| **Result** | All checks passed |

Final log lines:

```text
[Environment] Pass: 30 | Fail: 0 | Still expected: 0
[Environment] Frame Pass: 30 | Frame Fail: 0
[Environment] Verification Environment Finished.
```

Spot check of parity bits taken from the log:

| Data | Ones | Mode | Parity bit seen | Expected |
| :--- | :---: | :--- | :---: | :---: |
| `f2` | 5 | even | 1 | 1 |
| `b2` | 4 | odd | 1 | 1 |
| `51` | 3 | odd | 0 | 0 |

Full details are in [verification_results.md](verification_results.md).

---

## Mutation Test

A passing scoreboard only means something if it can fail. To test that, the parity line in `uart_tx.sv` was flipped on purpose so even and odd were swapped.

| Run | Data check | Frame check |
| :--- | :--- | :--- |
| Original RTL | 30 pass, 0 fail | 30 pass, 0 fail |
| Parity swapped in `uart_tx` | 30 pass, 0 fail | 8 pass, 22 fail |

The 8 passing frames are the ones with parity off. All 22 frames with parity on failed. The data check stayed at 30/30, so loopback alone cannot catch a parity bug that TX and RX share. The pin-level frame check does catch it. The line was restored afterwards.

---

## Bug Found by the Testbench

| | |
| :--- | :--- |
| **Location** | TX control FSM in `uart_top.sv` |
| **Symptom** | 5 bytes written, only 3 came back (`f2`, `51`, `6e`). `b2` and `7c` were lost. |
| **Cause** | After `tx_start` was issued, `tx_busy` stayed low for one more clock. The controller saw "FIFO not empty and TX idle" and read the next byte out of the FIFO while `uart_tx` was already busy and ignoring `txstart`. That byte was lost. |
| **Fix** | Added a third state, `BUSY_CTRL`, that waits for `tx_busy` to go high before the controller returns to `IDLE_CTRL`. The state enum grew from 1 bit to 2 bits. |
| **Result** | 5 of 5 pass, then 30 of 30 |

---

## How to Run

Tool: Vivado 2019.1 (XSIM).

1. Create a Vivado project and add the four files in `rtl/` as design sources.
2. Add the files in `tb/` as simulation sources.
3. Set the class files (`uart_trans.sv`, `generator.sv`, `driver.sv`, `monitor.sv`, `uart_sco.sv`, `environment.sv`) to **Verilog Header**, so they compile only through `` `include `` and are not declared twice.
4. Keep `uart_if.sv` and `tb_top.sv` as normal SystemVerilog sources and set `tb_top` as the simulation top.
5. Launch behavioural simulation, then in the Tcl console:

```tcl
run all
```

The run covers about 27 ms of simulated time. If you change `CLK_FREQ` or `BAUD_RATE`, also change `BIT_CLKS` in `monitor.sv`, which is hardcoded to 5208.

`tb_top.sv` needs this line so the driver can see the transmitter status:

```systemverilog
assign vif.tx_busy = DUT.tx_busy;
```

---

## Known Limitations

- `tx_wr_en` is forced to 1 and the driver waits for each frame to finish, so the TX FIFO never fills.
- `err_frame` and `err_parity` are not connected in the testbench yet, so those flags are unchecked.
- `BIT_CLKS` in the monitor is hardcoded to 5208 and must match `CLK_FREQ / BAUD_RATE`.
- The environment waits a fixed 25 ms. The last frame returns at about 16.8 ms, so the run is longer than needed.
- The generator's `$fatal` call should be `$fatal(1, "...")`. Vivado assumes 1 and prints a warning.
- The `uart_tx` baud counter is free running and is not reset on `txstart`, so the start bit can be shorter than one full bit period. This did not cause a failure in the 30 frames run.
- Only one random seed was run.

---

## Future Work

- Connect `err_frame` and `err_parity` to the interface and check them.
- Add a mux in `tb_top` so the driver can send malformed frames on `rx`: a bad stop bit for a framing error and a flipped parity bit for a parity error.
- Add an overrun flag to the RTL and test a full RX FIFO with a defined drop-new policy.
- Back-to-back FIFO stress and full-duplex tests.
- Functional coverage for parity modes, error flags, and FIFO full and empty boundaries.
- Multi-seed random regression.

---

## Tools

- **SystemVerilog**: RTL and testbench
- **Xilinx Vivado 2019.1 (XSIM)**: simulation
- **Git / GitHub**: version control

---

## License

This project was developed for learning, educational, and portfolio purposes.
