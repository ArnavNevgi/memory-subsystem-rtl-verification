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