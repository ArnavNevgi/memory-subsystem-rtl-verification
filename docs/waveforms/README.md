# Waveform Evidence

This folder will contain screenshots or notes from simulation waveforms.

Planned waveform captures:

- Basic read/write transaction
- Read miss followed by refill
- Read hit
- Write hit with dirty bit set
- Dirty eviction and write-back
- ECC single-bit correction
- ECC double-bit detection
- MBIST pass
- MBIST fail capture

## Phase 1: Basic Memory Interface and Backing Memory Model

Waveform file:

- `phase1_basic_memory_interface.png`

### Purpose

Phase 1 verifies the basic ready/valid request-response interface and the backing memory model before adding cache logic.

### Signals Captured

- `clk`
- `rst_n`
- `mem_bus.req_valid`
- `mem_bus.req_ready`
- `mem_bus.req_write`
- `mem_bus.req_addr`
- `mem_bus.req_wdata`
- `mem_bus.req_wstrb`
- `mem_bus.rsp_valid`
- `mem_bus.rsp_ready`
- `mem_bus.rsp_rdata`
- `mem_bus.rsp_error`
- `u_backing_memory.state_q`
- `u_backing_memory.latency_cnt_q`
- `u_backing_memory.addr_q`
- `u_backing_memory.read_data_q`

### Verified Behavior

- Request is accepted only when `req_valid && req_ready` are asserted.
- Response is returned using `rsp_valid`.
- Backing memory waits for the configured response latency.
- Full-word write and read-after-write behavior are correct.
- Byte strobe write behavior is verified.
- Response error remains deasserted for valid accesses.

### Result

```text
[PHASE 1 PASS] Basic memory interface and backing memory model verified.

## Phase 2 verifies the first cache implementation using a direct-mapped cache structure.

Signals Captured
clk
rst_n
cpu_bus.req_valid
cpu_bus.req_ready
cpu_bus.req_write
cpu_bus.req_addr
cpu_bus.req_wdata
cpu_bus.req_wstrb
cpu_bus.rsp_valid
cpu_bus.rsp_rdata
mem_bus.req_valid
mem_bus.req_ready
mem_bus.req_write
mem_bus.req_addr
mem_bus.req_wdata
mem_bus.rsp_valid
mem_bus.rsp_rdata
u_cache.state_q
u_cache.req_index
u_cache.req_tag
u_cache.req_word_offset
u_cache.cache_hit
u_cache.refill_cnt_q

Verified Behavior

Read miss triggers line refill from backing memory.
Read hit returns data directly from the cache.
Write miss uses write-allocate behavior.
Write hit updates cached data.
Byte strobe write updates selected byte lanes.
Valid bit and tag match behavior are exercised.
Same-index conflict replacement is observed.
Result
[PHASE 2 PASS] Direct-mapped cache baseline verified.

## Phase 3: 2-Way Set-Associative Cache with Pseudo-LRU

Waveform file:

phase3_two_way_cache_plru.png
Purpose

Phase 3 upgrades the cache from direct-mapped to 2-way set-associative and verifies way selection plus pseudo-LRU replacement.

Signals Captured
clk
rst_n
cpu_bus.req_addr
cpu_bus.rsp_rdata
mem_bus.req_addr
mem_bus.rsp_rdata
u_cache.state_q
u_cache.req_index
u_cache.req_tag
u_cache.req_word_offset
u_cache.way0_hit
u_cache.way1_hit
u_cache.cache_hit
u_cache.hit_way
u_cache.replace_way_q
u_cache.refill_cnt_q
u_cache.rsp_data_q
Verified Behavior
Two tags are compared for each set.
Way 0 hit and way 1 hit behavior are verified.
Two same-index, different-tag cache lines can coexist.
Conflict miss loads the second way instead of immediately evicting the first line.
Pseudo-LRU selects the replacement way once both ways are valid.
Read miss, read hit, write miss, and write hit behavior remain functional after upgrading associativity.
Result
[PHASE 3 PASS] 2-way set-associative cache with pseudo-LRU verified.


## Phase 4: Write-Back and Dirty Eviction

Waveform file:

phase4_writeback_dirty_eviction.png
Purpose

Phase 4 replaces the Phase 3 write-through behavior with a write-back, write-allocate cache policy and verifies dirty eviction.

Signals Captured
clk
rst_n
cpu_bus.req_addr
cpu_bus.req_write
cpu_bus.rsp_rdata
cpu_bus.rsp_error
mem_bus.req_valid
mem_bus.req_ready
mem_bus.req_write
mem_bus.req_addr
mem_bus.req_wdata
mem_bus.rsp_valid
u_cache.state_q
u_cache.req_index
u_cache.req_tag
u_cache.selected_line_dirty
u_cache.replace_way_q
u_cache.wb_cnt_q
u_cache.refill_cnt_q
u_cache.rsp_data_q
Verified Behavior
Write miss allocates a cache line and marks it dirty.
Write hit updates the cache line and sets the dirty bit.
Backing memory is not immediately updated on write hit or write miss.
Dirty victim line is detected during conflict replacement.
Dirty line write-back occurs before the new line refill.
Full cache line write-back is performed word by word.
Clean eviction path works without unnecessary write-back.
Backing memory preserves updated data after dirty eviction.
Result
[PHASE 4 PASS] Write-back cache and dirty eviction verified.


## Phase 5: SECDED ECC and Fault Injection

Waveform file:

- `phase5_secded_ecc_fault_injection.png`

Signals captured:

- Cache read address
- ECC decoded data
- ECC corrected flag
- ECC uncorrectable flag
- CPU response data
- CPU response error
- Fault injection behavior for single-bit and double-bit corruption

Result:

```text
[PHASE 5 PASS] SECDED ECC and fault injection verified.