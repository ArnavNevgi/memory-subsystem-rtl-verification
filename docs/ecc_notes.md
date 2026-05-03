# SECDED ECC Notes

## Overview

SECDED stands for Single Error Correction, Double Error Detection.

In this project, ECC is used to protect cache data stored in the data array.

## Expected Behavior

| Error Type | Expected Result |
|---|---|
| No error | Data returned normally |
| Single-bit data error | Error corrected and corrected data returned |
| Single-bit ECC/check-bit error | Error detected and handled |
| Double-bit error | Uncorrectable error flag asserted |

## Verification Approach

ECC verification will include:

- Clean data test
- Single-bit data corruption
- Single-bit ECC corruption
- Double-bit corruption
- Fault injection from testbench
- Syndrome checking
- Corrected data comparison
- Uncorrectable error flag checking

## Phase 5 Verification Result

SECDED ECC was verified using directed fault injection.

Verified cases:

| Case | Expected Behavior | Result |
|---|---|---|
| Clean read | Data returned normally | PASS |
| Single-bit data/codeword fault | Corrected data returned, no response error | PASS |
| Single-bit ECC/check-bit fault | Data returned correctly, corrected flag set | PASS |
| Double-bit fault | Uncorrectable flag and response error asserted | PASS |
| Write hit after ECC access | ECC regenerated for updated data | PASS |

## ECC Scrubbing Note

This implementation corrects single-bit errors on read but does not automatically rewrite the corrected codeword back into the cache array.

Therefore, if a single-bit fault is injected, the physical stored codeword remains corrupted until the line is rewritten. This is realistic behavior for a design without ECC scrubbing.

Future improvement:

- Add ECC scrub/writeback after single-bit correction.