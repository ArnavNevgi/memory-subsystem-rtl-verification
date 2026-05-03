module backing_memory #(
  parameter int ADDR_WIDTH = cache_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = cache_pkg::DATA_WIDTH,
  parameter int STRB_WIDTH = cache_pkg::STRB_WIDTH,
  parameter int MEM_WORDS  = cache_pkg::MEM_WORDS,
  parameter int RESP_LATENCY = 2
)(
  input  logic clk,
  input  logic rst_n,

  cache_if.slave mem_if
);

  import cache_pkg::*;

  // ------------------------------------------------------------
  // Internal memory storage
  // ------------------------------------------------------------

  logic [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];

  // ------------------------------------------------------------
  // FSM state encoding
  // ------------------------------------------------------------

  typedef enum logic [1:0] {
    IDLE,
    WAIT_LATENCY,
    RESPOND
  } mem_state_t;

  mem_state_t state_q, state_d;

  // ------------------------------------------------------------
  // Latched request fields
  // ------------------------------------------------------------

  logic [ADDR_WIDTH-1:0] addr_q;
  logic [DATA_WIDTH-1:0] wdata_q;
  logic [STRB_WIDTH-1:0] wstrb_q;
  logic                  write_q;

  logic [$clog2(RESP_LATENCY+1)-1:0] latency_cnt_q;

  logic [DATA_WIDTH-1:0] read_data_q;
  logic                  error_q;

  // Word address. Phase 1 uses word-aligned access.
  logic [$clog2(MEM_WORDS)-1:0] word_index;

  assign word_index = addr_q[($clog2(MEM_WORDS)+1):2];

  // ------------------------------------------------------------
  // Ready/valid outputs
  // ------------------------------------------------------------

  assign mem_if.req_ready = (state_q == IDLE);

  assign mem_if.rsp_valid = (state_q == RESPOND);
  assign mem_if.rsp_rdata = read_data_q;
  assign mem_if.rsp_error = error_q;

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q       <= IDLE;
      addr_q        <= '0;
      wdata_q       <= '0;
      wstrb_q       <= '0;
      write_q       <= 1'b0;
      latency_cnt_q <= '0;
      read_data_q   <= '0;
      error_q       <= 1'b0;
    end else begin
      state_q <= state_d;

      // Accept request
      if ((state_q == IDLE) && mem_if.req_valid && mem_if.req_ready) begin
        addr_q        <= mem_if.req_addr;
        wdata_q       <= mem_if.req_wdata;
        wstrb_q       <= mem_if.req_wstrb;
        write_q       <= mem_if.req_write;
        latency_cnt_q <= RESP_LATENCY[$bits(latency_cnt_q)-1:0];
      end

      // Count latency cycles
      if (state_q == WAIT_LATENCY) begin
        if (latency_cnt_q != 0) begin
          latency_cnt_q <= latency_cnt_q - 1'b1;
        end
      end

      // Perform memory operation at the end of latency
      if ((state_q == WAIT_LATENCY) && (latency_cnt_q == 0)) begin
        error_q <= 1'b0;

        if (word_index >= MEM_WORDS) begin
          read_data_q <= '0;
          error_q     <= 1'b1;
        end else begin
          if (write_q) begin
            for (int i = 0; i < STRB_WIDTH; i++) begin
              if (wstrb_q[i]) begin
                mem[word_index][8*i +: 8] <= wdata_q[8*i +: 8];
              end
            end

            // For writes, return written data as acknowledgement data.
            read_data_q <= wdata_q;
          end else begin
            read_data_q <= mem[word_index];
          end
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Next-state logic
  // ------------------------------------------------------------

  always_comb begin
    state_d = state_q;

    case (state_q)

      IDLE: begin
        if (mem_if.req_valid && mem_if.req_ready) begin
          state_d = WAIT_LATENCY;
        end
      end

      WAIT_LATENCY: begin
        if (latency_cnt_q == 0) begin
          state_d = RESPOND;
        end
      end

      RESPOND: begin
        if (mem_if.rsp_valid && mem_if.rsp_ready) begin
          state_d = IDLE;
        end
      end

      default: begin
        state_d = IDLE;
      end

    endcase
  end

endmodule