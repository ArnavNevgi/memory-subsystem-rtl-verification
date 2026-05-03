# Memory Subsystem RTL with 2-Way Set-Associative Cache, SECDED ECC, MBIST, and SystemVerilog Verification

## Project Overview

This project implements and verifies an industry-style memory subsystem in SystemVerilog. The design includes multiple cache design milestones, ending with a 2-way set-associative write-back cache with pseudo-LRU replacement, SECDED ECC protection, fault injection support, and a separate MBIST controller implementing the March C- memory test algorithm.

The project is structured as a Digital VLSI / RTL Design / ASIC Verification portfolio project. It emphasizes not only RTL functionality, but also verification quality through directed tests, randomized tests, assertions, scoreboarding, functional coverage, simulation logs, waveform evidence, and documentation.

---

## Key Features

- Parameterized SystemVerilog RTL
- Ready/valid request-response interface
- Backing memory model with programmable response latency
- Direct-mapped cache baseline
- 2-way set-associative cache
- Tag comparison and way-select logic
- Valid bit tracking
- Dirty bit tracking
- Pseudo-LRU replacement policy
- Write-back and write-allocate cache policy
- Dirty eviction with full-line write-back before refill
- SECDED ECC support
- Single-bit error correction
- Double-bit error detection
- Fault injection for ECC verification
- MBIST controller using March C-
- BIST done/pass/fail status
- Fail address, expected data, and observed data capture
- SystemVerilog assertions
- Reference model and scoreboard
- Directed and randomized tests
- Functional coverage
- QuestaSim simulation scripts
- Waveform and log-based verification evidence

---

## Final Architecture

```text
CPU / Test Request Generator
        |
        v
Cache Request Interface
        |
        v
2-Way Set-Associative Write-Back Cache
        |
        +--> Tag Storage
        +--> ECC-Protected Data Storage
        +--> Valid Bits
        +--> Dirty Bits
        +--> Pseudo-LRU Replacement
        +--> SECDED ECC Encode / Decode
        |
        v
Backing Memory Model


Separate DFT-Oriented Test Path
        |
        v
MBIST Controller
        |
        +--> March C- Engine
        +--> Address Generation
        +--> Pattern Generation
        +--> Comparator
        +--> Status Registers
        +--> Fail Address / Data Capture
        |
        v
Standalone Memory Array Model

Design Parameters

| Parameter        | Value | Description                     |
| ---------------- | ----: | ------------------------------- |
| `ADDR_WIDTH`     |    32 | Address width                   |
| `DATA_WIDTH`     |    32 | CPU data width                  |
| `LINE_BYTES`     |    16 | Cache line size                 |
| `WORDS_PER_LINE` |     4 | Number of 32-bit words per line |
| `NUM_SETS`       |    16 | Number of cache sets            |
| `NUM_WAYS`       |     2 | Associativity                   |
| `MEM_WORDS`      |  1024 | Backing memory depth            |

Cache Policy

| Feature           | Policy                             |
| ----------------- | ---------------------------------- |
| Mapping           | 2-way set-associative              |
| Replacement       | Pseudo-LRU                         |
| Write policy      | Write-back                         |
| Write miss policy | Write-allocate                     |
| Dirty eviction    | Full-line write-back before refill |
| ECC               | SECDED                             |
| Fault injection   | Supported for ECC verification     |

MBIST Policy

| Feature                   | Implementation                             |
| ------------------------- | ------------------------------------------ |
| Algorithm                 | March C-                                   |
| Test direction            | Up and down address traversal              |
| Status                    | Start, busy, done, pass, fail              |
| Failure capture           | Fail address, expected data, observed data |
| Normal access during BIST | Blocked                                    |


March C- Sequence

1. ↑ write 0
2. ↑ read 0, write 1
3. ↑ read 1, write 0
4. ↓ read 0, write 1
5. ↓ read 1, write 0
6. ↑ read 0

Verification Strategy

The verification environment includes:

Directed feature tests
Randomized read/write tests
Reference memory model
Scoreboard-based checking
SystemVerilog assertions
Functional coverage
ECC fault injection tests
MBIST fault injection tests
Simulation logs
Waveform evidence

Project Phases and Result

| Phase   | Description                                               | Status   |
| ------- | --------------------------------------------------------- | -------- |
| Phase 0 | Project setup, folder structure, design specification     | Complete |
| Phase 1 | Basic request/response interface and backing memory model | Complete |
| Phase 2 | Direct-mapped cache baseline                              | Complete |
| Phase 3 | 2-way set-associative cache with pseudo-LRU               | Complete |
| Phase 4 | Write-back policy and dirty eviction                      | Complete |
| Phase 5 | SECDED ECC and fault injection                            | Complete |
| Phase 6 | MBIST controller with March C-                            | Complete |
| Phase 7 | Assertions, scoreboard, coverage, and random tests        | Complete |
| Phase 8 | Documentation and GitHub polish                           | Complete |


Phase 1: Basic Memory Interface

Implemented:

cache_pkg.sv
cache_if.sv
backing_memory.sv
Basic self-checking testbench

Verified:

Ready/valid request handshake
Ready/valid response handshake
Full-word read/write
Byte strobe behavior
Memory response latency

Result:

[PHASE 1 PASS] Basic memory interface and backing memory model verified.
Phase 2: Direct-Mapped Cache Baseline

Implemented:

direct_mapped_cache.sv

Verified:

Direct-mapped tag lookup
Valid bit behavior
Read miss and refill
Read hit
Write miss with write-allocate
Write hit
Same-index conflict replacement

Result:

[PHASE 2 PASS] Direct-mapped cache baseline verified.
Phase 3: 2-Way Set-Associative Cache

Implemented:

two_way_cache.sv

Verified:

2-way tag comparison
Way 0 hit
Way 1 hit
Same-index different-tag coexistence
Pseudo-LRU replacement selection
Read/write hit and miss behavior

Result:

[PHASE 3 PASS] 2-way set-associative cache with pseudo-LRU verified.
Phase 4: Write-Back and Dirty Eviction

Implemented:

two_way_wb_cache.sv

Verified:

Dirty bit tracking
Write hit updates cache without immediately updating backing memory
Write miss with write-allocate
Dirty victim detection
Dirty write-back before refill
Clean eviction path
Data preservation in backing memory after dirty eviction

Result:

[PHASE 4 PASS] Write-back cache and dirty eviction verified.
Phase 5: SECDED ECC and Fault Injection

Implemented:

ecc_encoder.sv
ecc_decoder.sv
two_way_wb_ecc_cache.sv

Verified:

ECC generation on cache refill
ECC regeneration on write hit
Clean ECC read
Single-bit data/codeword error correction
Single-bit ECC/check-bit correction
Double-bit error detection
Fault injection into cached ECC-protected data
Response error asserted for uncorrectable double-bit error

Result:

[PHASE 5 PASS] SECDED ECC and fault injection verified.

Important verification note:

During testing, the double-bit ECC fault test was corrected to first rewrite clean data before injecting the two-bit fault. This is required because a previously injected single-bit fault remains physically present in the stored cache codeword unless the line is rewritten or scrubbed. The design corrects single-bit errors on read, but does not implement persistent ECC scrubbing in this version.

Phase 6: MBIST Controller with March C-

Implemented:

mbist_controller.sv
mbist_addr_gen.sv
mbist_pattern_gen.sv
mbist_status_regs.sv
mbist_memory_array.sv

Verified:

March C- sequencing
Up-counting and down-counting address traversal
Write-0 operation
Read-0/write-1 operation
Read-1/write-0 operation
Final read-0 operation
BIST start, busy, done, pass, fail status
Normal access blocked during BIST
Fault injection during memory read
Fail address and fail data capture

Result:

[PHASE 6 PASS] MBIST March C- controller verified.
Phase 7: Assertions, Coverage, Scoreboard, and Random Tests

Implemented:

cache_assertions.sv
cache_coverage.sv
Reference model and scoreboard logic inside the testbench
Randomized read/write tests

Verified:

CPU-side ready/valid protocol assertions
Memory-side ready/valid protocol assertions
Word-aligned request assertion
Write-strobe assertion
No-X response assertion
Scoreboard-based read checking
Directed tests
ECC fault tests
500 randomized operations
Functional coverage collection

Result:

Phase 7 Summary
FAIL count      = 0
Random ops      = 500
Coverage        = 82.42%
[PHASE 7 PASS] Assertions, scoreboard, coverage, and random tests verified.

Coverage note:

The Phase 7 coverage model tracks access type, address region, write strobe type, cache hit/miss behavior, way hit behavior, response error behavior, ECC correction, ECC uncorrectable events, and selected cross coverage. Coverage closure beyond 82.42% is listed as a future improvement.

Waveform Evidence

Waveform screenshots are stored in:

docs/waveforms/
Phase	Waveform Evidence
Phase 1	phase1_basic_memory_interface.png
Phase 2	phase2_direct_mapped_cache.png
Phase 3	phase3_two_way_cache_plru.png
Phase 4	phase4_writeback_dirty_eviction.png
Phase 5	phase5_secded_ecc_fault_injection.png
Phase 6	phase6_mbist_march_c.png
Phase 7	phase7_assertions_coverage_random.png

Simulation logs are stored in:

sim/logs/

How to Run

Open QuestaSim and use the Transcript window.

cd C:/cache-ecc-mbist-rtl/memory-subsystem-rtl-verification/sim/questa
do compile.do
do run.do

For waveform viewing:

do wave.do

Repository Structure
rtl/        SystemVerilog RTL design files
tb/         Testbench, assertions, coverage, and verification components
docs/       Architecture, design spec, verification plan, ECC, MBIST, and waveform documentation
sim/        QuestaSim scripts and simulation logs
filelists/  RTL and testbench compile filelists

Coverage Model

The functional coverage model is implemented in:

tb/coverage/cache_coverage.sv
Covered Features

The coverage model tracks:

Access type: read and write
Address regions
Write strobe patterns
Response error behavior
Cache hit and miss behavior
Way 0 hit
Way 1 hit
ECC corrected event
ECC uncorrectable event
Access type × hit/miss cross coverage
Way hit cross coverage
ECC status cross coverage
Verification Scope

The Phase 7 testbench includes:

Directed cache tests
ECC single-bit and double-bit fault tests
500 randomized read/write operations
Scoreboard-based checking
SystemVerilog assertions
Result
[PHASE 7 PASS] Assertions, scoreboard, coverage, and random tests verified.

Coverage Interpretation

82.42% functional coverage is acceptable for this portfolio-stage project. It demonstrates that the coverage infrastructure is active and meaningful.

Coverage is not 100% because some bins are structurally rare or intentionally difficult to hit, including selected response-error and cross-coverage combinations.

Future Coverage Improvements

Planned improvements:

Add more directed coverage-closure tests
Increase randomized operations
Ignore structurally illegal cross bins
Add coverage for dirty write-back before refill
Add coverage for ECC scrub behavior if implemented
Add UVM-style coverage subscribers
Target 90%+ functional coverage