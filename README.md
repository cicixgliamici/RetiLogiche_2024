# Reti_Logiche_2024
RAM Sequence Processing FSM

Project Overview

This project implements a Finite State Machine (FSM) for processing sequences stored in RAM. The system reads a sequence of words from memory, modifies them based on specific conditions, and writes back the results. The primary goal is to manage the useful and credibility values within the sequence, ensuring correct updates based on predefined rules.

Functionality

Reads a sequence of K words from a given starting memory address.

Each word consists of:

A useful value (can be any number, including zero).

A credibility value (initially zero, updated based on the useful value).

If a useful value is 0, it is replaced by the last nonzero value encountered.

The credibility value follows these rules:

If the useful value is nonzero, credibility is set to 31.

If one or more consecutive useful values are 0, the credibility is computed as 31 - N, where N is the number of consecutive zeros.

Architecture

The system is implemented as a Finite State Machine (FSM) with 14 states:

Initialization states: Setup memory addresses and manage the start/reset signals.

Processing states:

Handle nonzero useful values.

Handle zero useful values by replacing them with the last seen nonzero value.

Compute the credibility value accordingly.

Final state: Ensures correct completion and resets for new computations.

The FSM is designed for efficient RAM access and ensures correct synchronization with memory operations.

Experimental Results

Multiple testbenches were used to verify correctness.

The system successfully handles various scenarios, including sequences starting with zeros and long sequences requiring credibility updates.

The FSM is optimized for FPGA implementation with minimal hardware usage.

Execution time is approximately 4.251 ns per testbench cycle, allowing for high-frequency clock operation.

Conclusion

This project demonstrates an efficient FSM-based approach to handling memory sequences with dynamic value updates. The system is robust, capable of handling large data sequences, and ensures correct operation even under reset conditions or consecutive executions.

How to Use

Clone the repository:

git clone <repository-url>

Open the VHDL project in an FPGA development environment (we used Vivado).

Run the provided testbenches to verify functionality.

Synthesize and deploy the FSM on an FPGA board if you want.

Authors

Leonardo Chiaretti

James Enrico Busato
