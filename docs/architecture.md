# Architecture

## High-Level Block Diagram

```text
CPU / Test Request Generator
        |
        v
Cache Request Interface
        |
        v
Cache Top
        |
        +--> Cache Controller FSM
        |
        +--> Tag Array
        |
        +--> Data Array + ECC
        |
        +--> Valid / Dirty Metadata
        |
        +--> Pseudo-LRU Logic
        |
        +--> MBIST Access Mux
        |
        v
Backing Memory Model


Main Blocks
Cache Top

The top-level module integrates the cache controller, tag array, data array, metadata arrays, ECC logic, MBIST logic, and backing memory interface.

Cache Controller

The cache controller handles request acceptance, tag lookup, hit/miss decision, write hits, read hits, refill, dirty eviction, and response generation.

Tag Array

The tag array stores address tags for each set and way.

Data Array

The data array stores cache line data. Each line is protected using SECDED ECC.

Valid and Dirty Array

The valid bit indicates whether a cache line contains usable data. The dirty bit indicates whether the cache line has been modified and must be written back before eviction.

Pseudo-LRU Logic

The pseudo-LRU logic tracks which way should be replaced on a miss. For a 2-way cache, one replacement bit per set is sufficient.

ECC Logic

The ECC encoder generates check bits when data is written. The ECC decoder checks and corrects data when it is read.

MBIST Controller

The MBIST controller runs March C- tests on internal memory arrays and records fail information.

Backing Memory Model

The backing memory model represents external memory. It supports cache line reads and writes with configurable latency.