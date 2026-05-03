# MBIST Notes

## Overview

MBIST stands for Memory Built-In Self-Test. It is used to test memory arrays for manufacturing-related or structural faults.

This project implements an educational RTL-level MBIST controller for the cache memory arrays.

## March C- Algorithm

The planned March C- sequence is:

```text
1. ↑  write 0
2. ↑  read 0, write 1
3. ↑  read 1, write 0
4. ↓  read 0, write 1
5. ↓  read 1, write 0
6. ↑  read 0

BIST Status

The MBIST logic will report:

bist_done
bist_pass
bist_fail
fail_addr
fail_expected_data
fail_observed_data
Verification Approach

MBIST verification will include:

BIST pass with clean memory
BIST fail with injected memory fault
Fail address capture
Fail data capture
Normal cache access blocked during BIST
BIST done timing

## Phase 6 Verification Result

The MBIST controller was verified using a standalone memory array model.

Verified cases:

| Case | Expected Behavior | Result |
|---|---|---|
| Clean MBIST run | Done = 1, Pass = 1, Fail = 0 | PASS |
| Normal access during BIST | Normal access blocked | PASS |
| Fault-injected MBIST run | Done = 1, Pass = 0, Fail = 1 | PASS |
| Fail address capture | Captures injected fault address | PASS |
| Expected data capture | Captures expected March data | PASS |
| Observed data capture | Captures corrupted read data | PASS |

Final result:

```text
[PHASE 6 PASS] MBIST March C- controller verified.

Integration Note

The Phase 6 MBIST engine is verified on a standalone memory array model. Future work can integrate the MBIST controller directly with the cache tag and data arrays through a BIST access mux.