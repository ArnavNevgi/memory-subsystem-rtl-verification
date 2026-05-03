# Memory Subsystem RTL with 2-Way Set-Associative Cache, SECDED ECC, MBIST, and SystemVerilog Verification

## Project Overview

This project implements and verifies a parameterized memory subsystem in SystemVerilog. The design is centered around a 2-way set-associative write-back cache with pseudo-LRU replacement, SECDED ECC protection, fault injection support, and MBIST functionality using a March C- memory test algorithm.

The project is structured as a full RTL and verification portfolio project, targeting Digital VLSI, RTL Design, ASIC Verification, SoC Verification, Memory Subsystem, and semiconductor roles.

This is not intended to be a minimal cache demo. The goal is to model a realistic memory subsystem with industry-style RTL organization, directed and randomized verification, assertions, functional coverage, regression automation, and professional documentation.

---

## Key Features

- Parameterized SystemVerilog RTL
- 2-way set-associative cache architecture
- Tag RAM and data RAM organization
- Valid and dirty bit tracking
- Pseudo-LRU replacement policy
- Read hit and write hit handling
- Read miss refill path
- Write-back dirty eviction path
- Backing memory model with programmable latency
- SECDED ECC encoder and decoder
- Syndrome-based error detection
- Single-bit error correction
- Double-bit error detection
- Fault injection support for ECC verification
- MBIST controller for memory array testing
- March C- memory test algorithm
- BIST start, done, pass, and fail status
- Fail address and fail data capture
- SystemVerilog assertions
- Self-checking testbench
- Scoreboard and reference model
- Directed tests
- Randomized tests
- Functional coverage
- Regression automation
- Documentation, diagrams, logs, and waveform evidence

---

## Target Architecture

```text
CPU / Test Request Generator
        |
        v
Cache Request Interface
        |
        v
2-Way Set-Associative Cache Controller
        |
        +--> Tag Array
        +--> Data Array
        +--> Valid Bits
        +--> Dirty Bits
        +--> Pseudo-LRU Replacement Logic
        +--> SECDED ECC Encoder / Decoder
        |
        v
Backing Memory Model


Separate Test / DFT Path
        |
        v
MBIST Controller
        |
        +--> March C- Engine
        +--> Address Generator
        +--> Pattern Generator
        +--> Comparator
        +--> Fail Address Register
        +--> Fail Data Register
        +--> BIST Status Registers