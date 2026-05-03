module two_way_cache #(
  parameter int ADDR_WIDTH     = cache_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH     = cache_pkg::DATA_WIDTH,
  parameter int STRB_WIDTH     = cache_pkg::STRB_WIDTH,
  parameter int NUM_SETS       = cache_pkg::NUM_SETS,
  parameter int WORDS_PER_LINE = cache_pkg::WORDS_PER_LINE,
  parameter int NUM_WAYS       = 2
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
  typedef logic [$clog2(NUM_WAYS)-1:0] way_t;

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

  logic  valid_array [0:NUM_SETS-1][0:NUM_WAYS-1];
  tag_t  tag_array   [0:NUM_SETS-1][0:NUM_WAYS-1];
  data_t data_array  [0:NUM_SETS-1][0:NUM_WAYS-1][0:WORDS_PER_LINE-1];

  // For 2-way cache:
  // plru_array[set] = 0 means replace way 0 next
  // plru_array[set] = 1 means replace way 1 next
  logic plru_array [0:NUM_SETS-1];

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

  way_t hit_way;
  way_t replace_way_q;

  logic way0_hit;
  logic way1_hit;
  logic cache_hit;

  // ------------------------------------------------------------
  // Address helper functions
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

  // ------------------------------------------------------------
  // Decoded request fields
  // ------------------------------------------------------------

  index_t       req_index;
  word_offset_t req_word_offset;
  tag_t         req_tag;

  assign req_index       = get_index(addr_q);
  assign req_word_offset = get_word_offset(addr_q);
  assign req_tag         = get_tag(addr_q);

  assign way0_hit = valid_array[req_index][0] && (tag_array[req_index][0] == req_tag);
  assign way1_hit = valid_array[req_index][1] && (tag_array[req_index][1] == req_tag);

  assign cache_hit = way0_hit || way1_hit;

  always_comb begin
    hit_way = '0;

    if (way0_hit) begin
      hit_way = way_t'(0);
    end else if (way1_hit) begin
      hit_way = way_t'(1);
    end
  end

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
      state_q       <= IDLE;
      addr_q        <= '0;
      wdata_q       <= '0;
      wstrb_q       <= '0;
      write_q       <= 1'b0;
      rsp_data_q    <= '0;
      rsp_error_q   <= 1'b0;
      refill_cnt_q  <= '0;
      replace_way_q <= '0;

      for (int s = 0; s < NUM_SETS; s++) begin
        plru_array[s] <= 1'b0;

        for (int way = 0; way < NUM_WAYS; way++) begin
          valid_array[s][way] <= 1'b0;
          tag_array[s][way]   <= '0;

          for (int w = 0; w < WORDS_PER_LINE; w++) begin
            data_array[s][way][w] <= '0;
          end
        end
      end

      for (int w = 0; w < WORDS_PER_LINE; w++) begin
        line_buffer[w] <= '0;
      end

    end else begin
      state_q <= state_d;

      // --------------------------------------------------------
      // Latch CPU request
      // --------------------------------------------------------

      if ((state_q == IDLE) && cpu_if.req_valid && cpu_if.req_ready) begin
        addr_q       <= cpu_if.req_addr;
        wdata_q      <= cpu_if.req_wdata;
        wstrb_q      <= cpu_if.req_wstrb;
        write_q      <= cpu_if.req_write;
        rsp_error_q  <= 1'b0;
        refill_cnt_q <= '0;
      end

      // --------------------------------------------------------
      // Cache lookup result handling
      // --------------------------------------------------------

      if (state_q == CHECK) begin

        if (cache_hit) begin
          // Update pseudo-LRU on hit.
          // If way 0 was used, replace way 1 next.
          // If way 1 was used, replace way 0 next.
          if (hit_way == way_t'(0)) begin
            plru_array[req_index] <= 1'b1;
          end else begin
            plru_array[req_index] <= 1'b0;
          end

          if (write_q) begin
            data_array[req_index][hit_way][req_word_offset] <=
              apply_wstrb(data_array[req_index][hit_way][req_word_offset], wdata_q, wstrb_q);

            rsp_data_q <=
              apply_wstrb(data_array[req_index][hit_way][req_word_offset], wdata_q, wstrb_q);
          end else begin
            rsp_data_q <= data_array[req_index][hit_way][req_word_offset];
          end

          rsp_error_q <= 1'b0;

        end else begin
          // Replacement selection:
          // 1. Prefer invalid way 0
          // 2. Else prefer invalid way 1
          // 3. Else use pseudo-LRU bit
          if (!valid_array[req_index][0]) begin
            replace_way_q <= way_t'(0);
          end else if (!valid_array[req_index][1]) begin
            replace_way_q <= way_t'(1);
          end else begin
            replace_way_q <= way_t'(plru_array[req_index]);
          end
        end
      end

      // --------------------------------------------------------
      // Refill response handling
      // --------------------------------------------------------

      if ((state_q == REFILL_WAIT) && mem_if.rsp_valid) begin
        line_buffer[refill_cnt_q] <= mem_if.rsp_rdata;

        if (mem_if.rsp_error) begin
          rsp_error_q <= 1'b1;
        end

        if (refill_cnt_q == WORDS_PER_LINE-1) begin
          valid_array[req_index][replace_way_q] <= 1'b1;
          tag_array[req_index][replace_way_q]   <= req_tag;

          for (int w = 0; w < WORDS_PER_LINE; w++) begin
            if (w == refill_cnt_q) begin
              data_array[req_index][replace_way_q][w] <= mem_if.rsp_rdata;
            end else begin
              data_array[req_index][replace_way_q][w] <= line_buffer[w];
            end
          end

          // Update pseudo-LRU after filling replacement way.
          // Filled/accessed way becomes most recently used.
          if (replace_way_q == way_t'(0)) begin
            plru_array[req_index] <= 1'b1;
          end else begin
            plru_array[req_index] <= 1'b0;
          end

          // For write miss: refill first, then modify requested word.
          if (write_q) begin
            if (req_word_offset == refill_cnt_q) begin
              data_array[req_index][replace_way_q][req_word_offset] <=
                apply_wstrb(mem_if.rsp_rdata, wdata_q, wstrb_q);

              rsp_data_q <= apply_wstrb(mem_if.rsp_rdata, wdata_q, wstrb_q);
            end else begin
              data_array[req_index][replace_way_q][req_word_offset] <=
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

      // --------------------------------------------------------
      // Write-through response handling
      // --------------------------------------------------------

      if ((state_q == WRITE_THROUGH_WAIT) && mem_if.rsp_valid) begin
        if (mem_if.rsp_error) begin
          rsp_error_q <= 1'b1;
        end
      end

    end
  end

endmodule