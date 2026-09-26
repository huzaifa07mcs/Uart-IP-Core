# Feature-Complete UART IP Core Specification
## 1. Project Overview
This project implements a feature-complete, full-duplex UART IP core using Verilog HDL with independent TX and RX finite state machines. Upgrades include a parameterized baud rate generator, 16-deep synchronous FIFOs, hardware parity, and error detection.
## 2. IP Core Specifications
- **Architecture:** 3-Block FSM Datapath & Control
- **Host Data Width:** 8 bits
- **FIFO Depth:** 16 words (TX), 16 words (RX)
- **System Clock:** Single Clock Domain
- **Error Handling:** Framing, Parity, and Overrun (Drop-New Policy)
## 3. Development Roadmap
- Phase 1: Baseline FSM Architecture
- Phase 2: Core Upgrades (Parity, Errors)
- Phase 3: Memory & Integration (FIFOs)
- Phase 4: SystemVerilog Verification in XSIM
