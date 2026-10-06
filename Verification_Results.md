# Verification Results

Design: UART IP core (`uart_top`, `uart_tx`, `uart_rx`, `sync_fifo`)
Simulator: Vivado 2019.1, XSIM, behavioural simulation
Testbench: class-based SystemVerilog, self-checking, no UVM

## Summary

| Check | Result |
|---|---|
| Bytes written to TX FIFO | 30 |
| Bytes read back from RX FIFO, correct | 30 |
| Data mismatches | 0 |
| Bytes still expected at end | 0 |
| Frames decoded on `tx` pin, correct | 30 |
| Frame failures | 0 |

Final lines of the log:

```
[Environment] Pass: 30 | Fail: 0 | Still expected: 0
[Environment] Frame Pass: 30 | Frame Fail: 0
[Environment] Verification Environment Finished.
```

## Scope

Covered:

- TX to RX loopback with random data
- Parity off, even, and odd
- Independent check of the frame on the `tx` pin

Not covered (see the end of this file): error injection, overrun, FIFO stress, full duplex, functional coverage.

This maps to Test 3 (`tx_rx_loopback`) and Test 4 (`parity_even_odd`) in the specification.

## Stimulus

30 transactions with random byte value, random `parity_en`, and random `parity_odd`. The generator forces `tx_wr_en = 1`. The driver waits for each frame to finish before it sends the next one, so the parity setting stays fixed for the whole frame.

| Parity mode | Frames |
|---|---|
| Off | 8 |
| Even | 12 |
| Odd | 10 |
| Total | 30 |

(`parity_odd` is random even when parity is off. Two of the 8 parity-off frames had `parity_odd = 1`, and they are counted as Off.)

## Timing check

Timing in the log matches 5208 clocks per bit at a 10 ns clock, which is 52.08 us per bit.

| Frame type | Bits | Expected | Seen between drives |
|---|---|---|---|
| Parity off | 10 | 520.8 us | about 520.8 us |
| Parity on | 11 | 572.9 us | about 572.9 us |

The gap between driven packets is about 572.9 us after parity frames and 520.8 us after non-parity frames. This confirms parity frames really carry the extra bit on the wire.

## Hand check of parity bits

| Data | Ones | Mode | Parity bit in log | Expected |
|---|---|---|---|---|
| `f2` | 5 | even | 1 | 1 |
| `b2` | 4 | odd | 1 | 1 |
| `51` | 3 | odd | 0 | 0 |

## Scoreboard validation (mutation test)

A passing result only means something if the checker can fail. To test that, the parity line in `uart_tx.sv` was flipped on purpose:

```systemverilog
// original
assign parity_calc = parity_odd ? ~(^tx_data) : (^tx_data);
// mutation, even and odd swapped
assign parity_calc = parity_odd ? (^tx_data) : ~(^tx_data);
```

Result with the mutation:

```
[Environment] Pass: 30 | Fail: 0 | Still expected: 0
[Environment] Frame Pass: 8 | Frame Fail: 22
```

- The 8 frames with parity off still passed, as they should.
- All 22 frames with parity on failed.
- The data check still showed 30/30. TX and RX used the same wrong convention in effect, so loopback alone could not see the bug. The frame check on the `tx` pin did.

The line was restored to the original afterwards.

Observation: RX pushed parity-mismatch bytes into the RX FIFO anyway. This is consistent with the specification, where a parity mismatch raises a flag but does not discard the byte. `err_parity` was not observed, because the testbench does not connect it yet.

## Bug found in RTL

| | |
|---|---|
| Location | TX control state machine in `uart_top.sv` |
| Symptom | 5 bytes written, only 3 came back (`f2`, `51`, `6e`). `b2` and `7c` were lost. |
| Cause | After `tx_start` was issued, `tx_busy` stayed low for one more clock. The controller saw "FIFO not empty and TX idle" and read the next byte out of the FIFO while `uart_tx` was busy and ignored it. |
| Fix | Added a state `BUSY_CTRL` that waits for `tx_busy = 1` before returning to `IDLE_CTRL`. The state enum grew from 1 bit to 2 bits. |
| Result after fix | 5 of 5 pass, later 30 of 30 |

## Testbench issues fixed along the way

| Issue | Fix |
|---|---|
| `transaction` declared multiple times | Include guards on every class file |
| `uart_if.sv` missing from simulation sources | Added to `sim_1` |
| Scoreboard compared `tx_din` with `rx_dout` from the same clock | Queue of expected bytes, compared on read |
| Environment ended after 50 ns | Fixed wait long enough for all frames |
| `tx_wr_en` held high, same byte written repeatedly | Driver clears it on the next clock |
| `rx_rd_en` random and held | Driver reads whenever `rx_empty` is 0 |
| `parity_en` changed while a frame was in flight | Driver waits on `tx_busy` before the next packet |
| Packets with `tx_wr_en = 0` never entered the FIFO | Constraint `tx_wr_en == 1` |

## Known limitations

- The TX FIFO never fills, because the driver sends one byte per frame.
- `err_frame` and `err_parity` are not in the interface, so they are not checked.
- `BIT_CLKS` in the monitor is hardcoded to 5208 and must match `CLK_FREQ / BAUD_RATE`.
- The generator's `$fatal` call has an invalid first argument. Vivado assumes 1 and prints a warning.
- The environment waits a fixed 25 ms. The last frame returned at about 16.8 ms, so the run is longer than needed.
- Only one seed was run.

## Not verified yet

| Item | Specification reference |
|---|---|
| Framing error detection | FR-RX-4, FR-ERR-1, Test 5 |
| Parity error flag | FR-RX-3, FR-ERR-2, Test 6 |
| RX FIFO overrun flag | FR-ERR-3, Test 8 (flag not in the RTL yet) |
| Back-to-back FIFO stress | Test 7 |
| Full duplex | Test 9 |
| Constrained-random regression, multiple seeds | Test 10 |
| Functional coverage | Section 6.3 |
| Single-byte RX from an external frame | Test 2 |

Planned next step: add `err_frame` and `err_parity` to `uart_if`, then add a mux in `tb_top` so the driver can send bad frames on `rx`.
