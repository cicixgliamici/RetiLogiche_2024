# Reti_Logiche_2024
**RAM Sequence Processing FSM (Finite State Machine)**

Welcome to the **RAM Sequence Processing** project! This repository showcases a hardware-based approach to processing sequences stored in RAM using a custom Finite State Machine (FSM). Written in **VHDL** and designed for **FPGA** deployment, this project highlights efficient memory interactions, robust state management, and a clear, verifiable architecture.

---

## Table of Contents
1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Architecture](#architecture)
4. [Design Choices](#design-choices)
5. [Experimental Results](#experimental-results)
6. [Getting Started](#getting-started)
7. [Authors](#authors)

---

## Overview
This project processes a sequence of words stored in RAM, modifying their **useful** and **credibility** values under specific rules. The aim is to ensure that zeros in the sequence are replaced by the last valid nonzero value and that the **credibility** value is computed correctly for each item. The design is entirely implemented as an FSM and can be **synthesized on FPGAs** for high-performance applications.

---

## Key Features
- **Fully Hardware-Based**: Implemented in VHDL, ideal for FPGA/ASIC deployment.
- **Dynamic Sequence Processing**:
  - Reads a sequence of **K** words from memory.
  - Updates their **useful** and **credibility** fields based on predefined conditions.
  - Writes the processed results back to memory.
- **Robust Handling of Zero Values**:
  - Replaces zero `useful` values with the last nonzero encountered.
  - Adjusts `credibility` to 31 for nonzero `useful` values.
  - Calculates `credibility = 31 - N` for consecutive zeros.
- **Efficiency**:
  - FSM ensures minimal latency between reads and writes.
  - Approximately 4.251 ns per testbench cycle (suitable for high-frequency clocking).
- **Scalability**:
  - Easily handles sequences starting with zeros or containing long runs of zeros.
  - Modular design: new states or conditions can be added without impacting core functionality.

---

## Architecture
### Finite State Machine
- **14 States** manage the system flow:
  1. **Initialization**: Set up internal registers, memory addresses, and reset signals.
  2. **Processing (Non-Zero)**: Capture and store the last valid `useful` value; reset credibility to 31.
  3. **Processing (Zero)**: Replace zero with last valid nonzero `useful` value; compute reduced credibility.
  4. **Memory Read/Write**: Synchronized operations with RAM to ensure data integrity.
  5. **Final State**: Complete processing and reinitialize for subsequent computations.

### Data Structure
Each **word** in memory includes:
- **Useful** (integer, can be zero or nonzero).
- **Credibility** (initially zero, recalculated during processing).

### Flow Diagram (Conceptual)
```
+--------------+         +----------------+         +----------------+
|  Initialize  |  --->   |  Process Word  |  --->   |  Update Memory |
+--------------+         +----------------+         +----------------+
                           (handles zero/
                           non-zero logic)
```

---

## Design Choices
- **VHDL for Readability & Reliability**: Strongly typed, making it easier to catch type mismatches and ensure deterministic behavior.
- **FSM-Based Approach**: Promotes a clean, modular design. Each state has a clear responsibility, simplifying debugging and future extensions.
- **Synchronous RAM Access**: Ensures data consistency and predictability, leveraging clock edges for read/write operations.
- **Vivado Toolchain**: Used for synthesis, implementation, and simulation. Chosen for its FPGA-centric features, robust IP integration, and verification capabilities.

---

## Experimental Results
- **Multiple Testbenches**: Verified functionality with various scenarios, including edge cases (e.g., sequences of all zeros, interspersed zeros, or consecutive reads).
- **Synthesis & Timing**:
  - Minimal LUT and FF usage, leaving room for additional logic on the target FPGA.
  - Timing closure achieved at **4.251 ns** per cycle in a standard 28nm FPGA process.
- **Scalable Performance**: The design can be re-parameterized to handle larger sequences or more complex operations without significant modification.

---

## Getting Started
1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   ```
2. **Open in Vivado** (or your preferred VHDL-compatible environment).
3. **Run Testbenches**:
   - Check out the provided test benches in the `test` folder.
   - Verify that all sequences pass the simulation without errors.
4. **Synthesize & Deploy**:
   - Generate the bitstream for your FPGA board.
   - Deploy the design for real-time operation and monitoring.

---

## Authors
- [**Leonardo Chiaretti**](https://github.com/cicixgliamici)
- **James Enrico Busato**

We hope this project demonstrates both our technical expertise in **FSM design** and our commitment to **reliable, high-performance hardware solutions**. Feel free to open issues or pull requests if you have questions, suggestions, or want to contribute.
