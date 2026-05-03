# Verification Plan

## Verification Objective

The objective is to verify functional correctness of the memory subsystem using directed tests, randomized tests, assertions, scoreboarding, and functional coverage.

## Verification Components

| Component | Purpose |
|---|---|
| Driver | Drives cache read/write transactions |
| Monitor | Observes requests and responses |
| Scoreboard | Compares DUT behavior against reference model |
| Reference Model | Golden memory/cache model |
| Assertions | Check protocol and design properties |
| Coverage | Tracks verified functionality |

## Directed Test Plan

| Test | Purpose |
|---|---|
| Basic read/write | Verify memory interface behavior |
| Read miss | Verify refill behavior |
| Read hit | Verify cache hit behavior |
| Write hit | Verify cache update and dirty bit |
| Write miss | Verify write-allocate behavior |
| Conflict miss | Verify replacement behavior |
| Clean eviction | Verify clean replacement |
| Dirty eviction | Verify write-back before refill |
| ECC no error | Verify clean ECC decode |
| ECC single-bit data error | Verify correction |
| ECC single-bit check-bit error | Verify detection/correction behavior |
| ECC double-bit error | Verify uncorrectable error reporting |
| MBIST pass | Verify clean memory test |
| MBIST fail | Verify fail capture |
| Random traffic | Verify mixed read/write stress cases |

## Assertion Plan

Initial assertion targets:

- Request valid remains stable until ready
- Response valid remains stable until ready
- No normal cache access during BIST
- Dirty line is written back before refill
- Cache does not respond with invalid data
- ECC double-bit error raises uncorrectable flag
- BIST done eventually asserts after BIST start

## Coverage Plan

Functional coverage targets:

- Read hit
- Read miss
- Write hit
- Write miss
- Way 0 hit
- Way 1 hit
- Way 0 replacement
- Way 1 replacement
- Clean eviction
- Dirty eviction
- ECC no error
- ECC single-bit correction
- ECC double-bit detection
- MBIST pass
- MBIST fail
- Back-to-back requests
- Random read/write sequences

## Final Verification Summary

| Phase | Verification Focus | Result |
|---|---|---|
| Phase 1 | Interface, backing memory, ready/valid behavior | PASS |
| Phase 2 | Direct-mapped cache hit/miss/refill behavior | PASS |
| Phase 3 | 2-way associativity and pseudo-LRU replacement | PASS |
| Phase 4 | Write-back policy and dirty eviction | PASS |
| Phase 5 | SECDED ECC and fault injection | PASS |
| Phase 6 | MBIST March C- controller | PASS |
| Phase 7 | Assertions, scoreboard, coverage, randomized tests | PASS |

## Assertion Summary

Implemented assertions check:

- CPU request stability until ready
- CPU response stability until ready
- Memory request stability until ready
- Memory response stability until ready
- Word-aligned CPU requests
- Nonzero write strobes for write requests
- No unknown CPU response when valid

## Scoreboard Summary

The Phase 7 scoreboard compares DUT read responses against a reference memory model updated on every write transaction.

## Random Test Summary

The Phase 7 testbench runs:

```text
500 randomized read/write operations

Fail Count = 0