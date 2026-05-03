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

## Phase 1 Results
        

Phase 1 implemented the basic request/response memory interface and a backing memory model with programmable response latency.

### Implemented Files

- `rtl/pkg/cache_pkg.sv`
- `rtl/interfaces/cache_if.sv`
- `rtl/memory/backing_memory.sv`
- `tb/top/tb_top.sv`

### Verified Features

- Ready/valid request handshake
- Ready/valid response handshake
- Full-word write
- Full-word read
- Read-after-write correctness
- Byte strobe write behavior
- Back-to-back memory accesses
- Programmable memory response latency

### Expected Phase 1 Simulation Result


[PHASE 1 PASS] Basic memory interface and backing memory model verified.

## Phase 2 Results

Phase 2 implemented a direct-mapped cache baseline between the CPU-side request interface and the backing memory model.

### Implemented Files

- `rtl/cache/direct_mapped_cache.sv`
- Updated `tb/top/tb_top.sv`
- Updated compile filelists

### Cache Features Verified

- Direct-mapped tag lookup
- Valid bit behavior
- Read miss refill
- Read hit
- Write miss with write-allocate
- Write hit
- Byte strobe update
- Same-index conflict replacement
- Backing memory write-through behavior

### Phase 2 Cache Policy

For this baseline phase, the cache uses:

| Feature | Policy |
|---|---|
| Mapping | Direct-mapped |
| Line size | 16 bytes |
| Words per line | 4 |
| Write policy | Write-through |
| Write miss policy | Write-allocate |

Write-back and dirty eviction will be added in Phase 4.

### Expected Phase 2 Simulation Result

```text
[PHASE 2 PASS] Direct-mapped cache baseline verified.

## Phase 3 Results

Phase 3 upgraded the cache baseline from direct-mapped to 2-way set-associative.

### Implemented Files

- `rtl/cache/two_way_cache.sv`
- Updated `tb/top/tb_top.sv`
- Updated compile filelists
- Updated waveform script

### Cache Features Verified

- 2-way tag comparison
- Way 0 hit
- Way 1 hit
- Same-index different-tag coexistence
- Pseudo-LRU replacement selection
- Read miss refill
- Read hit
- Write miss with write-allocate
- Write hit with byte strobe update

### Phase 3 Cache Policy

| Feature | Policy |
|---|---|
| Mapping | 2-way set-associative |
| Replacement | Pseudo-LRU |
| Line size | 16 bytes |
| Words per line | 4 |
| Write policy | Write-through |
| Write miss policy | Write-allocate |

Write-back and dirty eviction will be added in Phase 4.

### Expected Phase 3 Simulation Result

```text
[PHASE 3 PASS] 2-way set-associative cache with pseudo-LRU verified.

## Phase 4 Results

Phase 4 upgraded the cache from write-through behavior to a write-back, write-allocate cache policy with dirty bit tracking and dirty eviction handling.

### Implemented Files

- `rtl/cache/two_way_wb_cache.sv`
- Updated `tb/top/tb_top.sv`
- Updated compile filelists
- Updated waveform script

### Cache Features Verified

- Dirty bit tracking
- Write hit updates cache without immediately updating backing memory
- Write miss with write-allocate
- Dirty victim detection
- Dirty write-back before refill
- Clean eviction path
- Data preservation in backing memory after dirty eviction
- Byte strobe write hit behavior
- 2-way set-associative replacement with write-back policy

### Phase 4 Cache Policy

| Feature | Policy |
|---|---|
| Mapping | 2-way set-associative |
| Replacement | Pseudo-LRU |
| Write policy | Write-back |
| Write miss policy | Write-allocate |
| Dirty eviction | Write back full cache line before refill |

### Expected Phase 4 Simulation Result

```text
[PHASE 4 PASS] Write-back cache and dirty eviction verified.