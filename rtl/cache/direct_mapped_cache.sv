module direct_mapped_cache #(
  parameter int ADDR_WIDTH     = cache_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH     = cache_pkg::DATA_WIDTH,
  parameter int STRB_WIDTH     = cache_pkg::STRB_WIDTH,
  parameter int NUM_SETS       = cache_pkg::NUM_SETS,
  parameter int WORDS_PER_LINE = cache_pkg::WORDS_PER_LINE
)(
  input  logic clk,
  input  logic rst_n,

  cache_if.slave  cpu_if,
  cache_if.master mem_if
);

  import cache_pkg::*;

  localparam int BYTE_OFFSET_BITS = $clog2(DATA_WIDTH/8);
  localparam int WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);
  localparam int INDEX_BITS       = $clog2(NUM_SETS);
  localparam int TAG_BITS         = ADDR_WIDTH - BYTE_OFFSET_BITS - WORD_OFFSET_BITS - INDEX_BITS;

  typedef logic [TAG_BITS-1:0] tag_t;
  typedef logic [INDEX_BITS-1:0] index_t;
  typedef logic [WORD_OFFSET_BITS-1:0] word_offset_t;

  typedef enum logic [2:0] {
    IDLE,
    CHECK,
    REFILL_REQ,
    REFILL_WAIT,
    WRITE_THROUGH_REQ,
    WRITE_THROUGH_WAIT,
    RESPOND
  } state_t;

  state_t state_q, state_d;

  // ------------------------------------------------------------
  // Cache arrays
  // ------------------------------------------------------------

  logic  valid_array [0:NUM_SETS-1];
  tag_t  tag_array   [0:NUM_SETS-1];
  data_t data_array  [0:NUM_SETS-1][0:WORDS_PER_LINE-1];

  // Temporary refill buffer
  data_t line_buffer [0:WORDS_PER_LINE-1];

  // ------------------------------------------------------------
  // Latched CPU request
  // ------------------------------------------------------------

  addr_t addr_q;
  data_t wdata_q;
  strb_t wstrb_q;
  logic  write_q;

  data_t rsp_data_q;
  logic  rsp_error_q;

  logic [$clog2(WORDS_PER_LINE)-1:0] refill_cnt_q;

  // ------------------------------------------------------------
  // Address decode helpers
  // ------------------------------------------------------------

  function automatic index_t get_index(input addr_t addr);
    return addr[BYTE_OFFSET_BITS + WORD_OFFSET_BITS +: INDEX_BITS];
  endfunction

  function automatic word_offset_t get_word_offset(input addr_t addr);
    return addr[BYTE_OFFSET_BITS +: WORD_OFFSET_BITS];
  endfunction

  function automatic tag_t get_tag(input addr_t addr);
    return addr[ADDR_WIDTH-1 -: TAG_BITS];
  endfunction

  function automatic addr_t get_line_base(input addr_t addr);
    addr_t base;
    base = addr;
    base[BYTE_OFFSET_BITS + WORD_OFFSET_BITS - 1:0] = '0;
    return base;
  endfunction

  function automatic data_t apply_wstrb(
    input data_t old_data,
    input data_t new_data,
    input strb_t strb
  );
    data_t result;
    result = old_data;

    for (int i = 0; i < STRB_WIDTH; i++) begin
      if (strb[i]) begin
        result[8*i +: 8] = new_data[8*i +: 8];
      end
    end

    return result;
  endfunction

  index_t       req_index;
  word_offset_t req_word_offset;
  tag_t         req_tag;

  logic cache_hit;

  assign req_index       = get_index(addr_q);
  assign req_word_offset = get_word_offset(addr_q);
  assign req_tag         = get_tag(addr_q);

  assign cache_hit = valid_array[req_index] && (tag_array[req_index] == req_tag);

  // ------------------------------------------------------------
  // CPU interface
  // ------------------------------------------------------------

  assign cpu_if.req_ready = (state_q == IDLE);

  assign cpu_if.rsp_valid = (state_q == RESPOND);
  assign cpu_if.rsp_rdata = rsp_data_q;
  assign cpu_if.rsp_error = rsp_error_q;

  // ------------------------------------------------------------
  // Memory interface
  // ------------------------------------------------------------

  assign mem_if.req_valid = (state_q == REFILL_REQ) || (state_q == WRITE_THROUGH_REQ);

  assign mem_if.req_write = (state_q == WRITE_THROUGH_REQ);

  assign mem_if.req_addr =
      (state_q == REFILL_REQ)
      ? (get_line_base(addr_q) + addr_t'(refill_cnt_q << BYTE_OFFSET_BITS))
      : addr_q;

  assign mem_if.req_wdata =
      (state_q == WRITE_THROUGH_REQ)
      ? wdata_q
      : '0;

  assign mem_if.req_wstrb =
      (state_q == WRITE_THROUGH_REQ)
      ? wstrb_q
      : '0;

  assign mem_if.rsp_ready = 1'b1;

  // ------------------------------------------------------------
  // Next-state logic
  // ------------------------------------------------------------

  always_comb begin
    state_d = state_q;

    case (state_q)

      IDLE: begin
        if (cpu_if.req_valid && cpu_if.req_ready) begin
          state_d = CHECK;
        end
      end

      CHECK: begin
        if (cache_hit) begin
          if (write_q) begin
            state_d = WRITE_THROUGH_REQ;
          end else begin
            state_d = RESPOND;
          end
        end else begin
          state_d = REFILL_REQ;
        end
      end

      REFILL_REQ: begin
        if (mem_if.req_valid && mem_if.req_ready) begin
          state_d = REFILL_WAIT;
        end
      end

      REFILL_WAIT: begin
        if (mem_if.rsp_valid) begin
          if (refill_cnt_q == WORDS_PER_LINE-1) begin
            if (write_q) begin
              state_d = WRITE_THROUGH_REQ;
            end else begin
              state_d = RESPOND;
            end
          end else begin
            state_d = REFILL_REQ;
          end
        end
      end

      WRITE_THROUGH_REQ: begin
        if (mem_if.req_valid && mem_if.req_ready) begin
          state_d = WRITE_THROUGH_WAIT;
        end
      end

      WRITE_THROUGH_WAIT: begin
        if (mem_if.rsp_valid) begin
          state_d = RESPOND;
        end
      end

      RESPOND: begin
        if (cpu_if.rsp_valid && cpu_if.rsp_ready) begin
          state_d = IDLE;
        end
      end

      default: begin
        state_d = IDLE;
      end

    endcase
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q      <= IDLE;
      addr_q       <= '0;
      wdata_q      <= '0;
      wstrb_q      <= '0;
      write_q      <= 1'b0;
      rsp_data_q   <= '0;
      rsp_error_q  <= 1'b0;
      refill_cnt_q <= '0;

      for (int s = 0; s < NUM_SETS; s++) begin
        valid_array[s] <= 1'b0;
        tag_array[s]   <= '0;

        for (int w = 0; w < WORDS_PER_LINE; w++) begin
          data_array[s][w] <= '0;
        end
      end

      for (int w = 0; w < WORDS_PER_LINE; w++) begin
        line_buffer[w] <= '0;
      end

    end else begin
      state_q <= state_d;

      // Latch CPU request
      if ((state_q == IDLE) && cpu_if.req_valid && cpu_if.req_ready) begin
        addr_q       <= cpu_if.req_addr;
        wdata_q      <= cpu_if.req_wdata;
        wstrb_q      <= cpu_if.req_wstrb;
        write_q      <= cpu_if.req_write;
        rsp_error_q  <= 1'b0;
        refill_cnt_q <= '0;
      end

      // Cache hit behavior
      if (state_q == CHECK && cache_hit) begin
        if (write_q) begin
          data_array[req_index][req_word_offset] <=
            apply_wstrb(data_array[req_index][req_word_offset], wdata_q, wstrb_q);

          rsp_data_q <= apply_wstrb(data_array[req_index][req_word_offset], wdata_q, wstrb_q);
        end else begin
          rsp_data_q <= data_array[req_index][req_word_offset];
        end

        rsp_error_q <= 1'b0;
      end

      // Refill response handling
      if ((state_q == REFILL_WAIT) && mem_if.rsp_valid) begin
        line_buffer[refill_cnt_q] <= mem_if.rsp_rdata;

        if (mem_if.rsp_error) begin
          rsp_error_q <= 1'b1;
        end

        if (refill_cnt_q == WORDS_PER_LINE-1) begin
          valid_array[req_index] <= 1'b1;
          tag_array[req_index]   <= req_tag;

          for (int w = 0; w < WORDS_PER_LINE; w++) begin
            if (w == refill_cnt_q) begin
              data_array[req_index][w] <= mem_if.rsp_rdata;
            end else begin
              data_array[req_index][w] <= line_buffer[w];
            end
          end

          // For write miss: refill first, then modify the requested word.
          if (write_q) begin
            if (req_word_offset == refill_cnt_q) begin
              data_array[req_index][req_word_offset] <=
                apply_wstrb(mem_if.rsp_rdata, wdata_q, wstrb_q);

              rsp_data_q <= apply_wstrb(mem_if.rsp_rdata, wdata_q, wstrb_q);
            end else begin
              data_array[req_index][req_word_offset] <=
                apply_wstrb(line_buffer[req_word_offset], wdata_q, wstrb_q);

              rsp_data_q <= apply_wstrb(line_buffer[req_word_offset], wdata_q, wstrb_q);
            end
          end else begin
            if (req_word_offset == refill_cnt_q) begin
              rsp_data_q <= mem_if.rsp_rdata;
            end else begin
              rsp_data_q <= line_buffer[req_word_offset];
            end
          end
        end else begin
          refill_cnt_q <= refill_cnt_q + 1'b1;
        end
      end

      // Write-through response handling
      if ((state_q == WRITE_THROUGH_WAIT) && mem_if.rsp_valid) begin
        if (mem_if.rsp_error) begin
          rsp_error_q <= 1'b1;
        end
      end
    end
  end

endmodule