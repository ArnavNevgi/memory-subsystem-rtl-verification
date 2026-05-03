```markdown
# Design Specification

## Project Title

Memory Subsystem RTL with 2-Way Set-Associative Cache, SECDED ECC, MBIST, and SystemVerilog Verification

## Objective

The objective of this project is to design and verify a realistic memory subsystem suitable for Digital VLSI, RTL Design, ASIC Verification, SoC Verification, and memory subsystem portfolio demonstration.

The design includes a cache controller, tag/data arrays, metadata arrays, write-back dirty eviction, ECC protection, backing memory, MBIST, and verification infrastructure.

## Initial Configuration

| Parameter | Value |
|---|---:|
| Address width | 32 bits |
| Data width | 32 bits |
| Cache line size | 16 bytes |
| Words per line | 4 |
| Number of sets | 16 |
| Number of ways | 2 |
| Replacement policy | Pseudo-LRU |
| Write policy | Write-back |
| Write miss policy | Write-allocate |
| ECC | SECDED |
| MBIST algorithm | March C- |

## CPU-Side Interface

The CPU-side cache interface uses a ready/valid request-response protocol.

### Request Channel

| Signal | Description |
|---|---|
| `req_valid` | Request valid |
| `req_ready` | Cache ready to accept request |
| `req_write` | 1 = write, 0 = read |
| `req_addr` | Request address |
| `req_wdata` | Write data |
| `req_wstrb` | Byte write strobes |

### Response Channel

| Signal | Description |
|---|---|
| `rsp_valid` | Response valid |
| `rsp_ready` | Response accepted |
| `rsp_rdata` | Read data |
| `rsp_error` | Error response |

## Cache Behavior

### Read Hit

If the requested address matches a valid tag in one of the ways, the cache returns the requested word from the selected cache line.

### Write Hit

If the requested address matches a valid tag, the cache updates the selected word or byte lanes in the cache line and marks the line dirty.

### Read Miss

If no way contains the requested tag, the cache selects a replacement way. If the selected line is clean or invalid, the cache refills the line from backing memory. If the selected line is dirty, the cache writes it back before refill.

### Write Miss

The cache uses write-allocate. The missed line is first loaded into the cache, then the write is applied, and the line is marked dirty.

## ECC Behavior

The cache data array stores data protected by SECDED ECC.

Expected ECC behavior:

| Case | Behavior |
|---|---|
| No error | Return data normally |
| Single-bit data error | Correct and return data |
| Single-bit ECC error | Report corrected error |
| Double-bit error | Report uncorrectable error |
| Fault injection | Used to intentionally corrupt stored data/ECC |

## MBIST Behavior

During BIST mode, normal cache access is blocked. The MBIST controller takes control of internal memory arrays and executes March C- operations.

The MBIST controller reports:

- BIST done
- BIST pass
- BIST fail
- Fail address
- Expected data
- Observed data

## Out of Scope for Initial Version

The initial version does not implement:

- AXI protocol
- Multi-core coherency
- Non-blocking cache
- MSHRs
- Pipeline forwarding
- Physical synthesis closure
- Gate-level DFT insertion

These can be listed as future improvements.