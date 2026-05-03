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