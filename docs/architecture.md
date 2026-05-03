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