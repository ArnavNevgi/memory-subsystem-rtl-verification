package cache_pkg;

  // ------------------------------------------------------------
  // Global cache/memory subsystem parameters
  // ------------------------------------------------------------

  parameter int ADDR_WIDTH = 32;
  parameter int DATA_WIDTH = 32;
  parameter int STRB_WIDTH = DATA_WIDTH / 8;

  // These are not fully used in Phase 1 yet, but they define
  // the intended final cache configuration.
  parameter int LINE_BYTES     = 16;
  parameter int WORDS_PER_LINE = LINE_BYTES / (DATA_WIDTH / 8);
  parameter int NUM_SETS       = 16;
  parameter int NUM_WAYS       = 2;

  // Backing memory configuration for simulation.
  parameter int MEM_WORDS = 1024;

  // ------------------------------------------------------------
  // Common typedefs
  // ------------------------------------------------------------

  typedef logic [ADDR_WIDTH-1:0] addr_t;
  typedef logic [DATA_WIDTH-1:0] data_t;
  typedef logic [STRB_WIDTH-1:0] strb_t;

  // ------------------------------------------------------------
  // Response status
  // ------------------------------------------------------------

  typedef enum logic [1:0] {
    CACHE_RSP_OKAY  = 2'b00,
    CACHE_RSP_ERROR = 2'b01
  } cache_rsp_t;

endpackage