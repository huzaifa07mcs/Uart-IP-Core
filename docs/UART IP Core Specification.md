# Feature-Complete UART IP Core Specification

## 1. Project Overview

This project implements a feature-complete, full-duplex Universal Asynchronous Receiver/Transmitter (UART) IP core using SystemVerilog. The core is built around independent Transmit (TX) and Receive (RX) finite state machines to enable simultaneous bidirectional communication.

The project will be developed incrementally. A functionally correct baseline single-byte TX/RX processor will be verified first. After successful verification, the design will be upgraded to a robust communication peripheral by adding a parameterized baud rate generator, 16-deep synchronous FIFOs, hardware parity generation and checking, and comprehensive error detection.

The objective of this project is to gain practical experience in RTL design, FSM development, synchronous memory integration, and asynchronous protocol handling while following a strict specification-first hardware development practice.

---

## 2. Design Goals

The main goals of this project are:

- Design and implement an 8-bit full-duplex UART IP core in SystemVerilog.
- Develop and verify a baseline unbuffered TX and RX datapath.
- Convert the baseline design into a buffered system using 16-deep synchronous FIFOs.
- Implement parameterized baud rate generation for dynamic clock scaling.
- Implement hardware parity generation and checking (Even/Odd).
- Implement robust error detection (Framing, Parity, and Overrun) with a "Drop-New" policy.
- Verify every module using self-checking SystemVerilog testbenches in Vivado XSIM.
- Follow modular RTL design and version control using Git and GitHub.

---

## 3. Protocol Specification

The UART implements standard asynchronous serial communication.

### Communication Configuration

| Parameter | Value |
|-----------|-------|
| Protocol | Asynchronous Serial |
| Data Width | 8 bits |
| Bit Order | LSB First |
| Start Bit | 1 bit (Logic 0) |
| Stop Bit | 1 bit (Logic 1) |
| Parity | Configurable (Even, Odd, None) |
| Baud Rate | Parameterized (Compile-time) |

---

## 4. Supported Features

| Feature Type | Description |
|--------------|-------------|
| Transmitter (TX) | Parallel-to-serial conversion, automatic parity insertion, busy flag generation |
| Receiver (RX) | Serial-to-parallel conversion, half-baud oversampling, glitch filtering |
| Error Handling | Independent Framing, Parity, and Overrun error flags |
| Buffering | Independent TX and RX data queues via Synchronous FIFOs |

---

## 5. IP Core Specifications

| Feature | Specification |
|----------|---------------|
| Architecture | 3-Block FSM Datapath & Control |
| Host Data Width | 8 bits |
| FIFO Depth | 16 words (TX), 16 words (RX) |
| System Clock | Single Clock Domain |
| Reset | Synchronous Active-High |
| Verification Environment | AMD Vivado XSIM |
| Implementation Language | SystemVerilog (RTL & TB) |

---

## 6. FSM Operational States

Both the TX and RX modules utilize a standard state machine architecture.

| State | Description |
|--------|-------------|
| IDLE | Waiting for host write (TX) or monitoring line for Start bit (RX) |
| START | Transmitting Start bit (TX) or synchronizing to half-baud center (RX) |
| DATA | Shifting 8-bit payload serially |
| PARITY | Generating (TX) or validating (RX) the parity bit |
| STOP | Transmitting Stop bit (TX) or asserting data valid and error flags (RX) |

---

## 7. Buffer Organization

### TX FIFO (Transmit Buffer)

- Stores parallel data written by the host system.
- Popped automatically by the TX FSM when the serial line is IDLE.
- Generates `tx_fifo_full` status flag.

### RX FIFO (Receive Buffer)

- Stores validated data payloads from the RX FSM.
- Pushed automatically upon successful Stop bit detection.
- Generates `rx_fifo_empty` status flag.

---

## 8. Error Handling

The upgraded UART will implement:

- **Framing Error Detection:** Asserts if the STOP bit is sampled as logic 0.
- **Parity Error Detection:** Asserts if the calculated parity does not match the received parity bit.
- **Overrun Error Detection:** Asserts if a frame arrives while the RX FIFO is full.
- **Drop-New Policy:** In the event of an overrun, the newly arrived byte is discarded to protect the older, unread data in the FIFO.

---

## 9. Verification Strategy

Every module will be verified individually before integration.

Verification flow:

1. Module Specification
2. RTL Implementation
3. Testbench Development
4. Functional Simulation
5. Bug Fixes
6. Integration
7. System-Level Verification

---

## 10. Development Roadmap

### Phase 1

Baseline FSM Architecture

- Parameterized Baud Rate Generator
- Transmitter (TX) FSM and Datapath
- Receiver (RX) FSM and Datapath
- Baseline Integration

### Phase 2

Core Upgrades

- Parity Generation Logic (TX)
- Parity Validation Logic (RX)
- Framing Error Detection Logic
- FSM State Expansions

### Phase 3

Memory & Integration

- Synchronous FIFO Module Design
- TX FIFO Instantiation
- RX FIFO Instantiation & Drop-New Logic
- Top-Level Flag Routing

### Phase 4

Verification

- Directed SystemVerilog Testbenches
- Error Injection Testing (Negative testing)
- FIFO Burst and Overrun Validation
- Self-Checking Scoreboard Integration

---
