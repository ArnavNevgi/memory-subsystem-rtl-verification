module two_way_wb_ecc_cache #(
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

  localparam int ECC_WIDTH        = 7;
  localparam int CODE_WIDTH       = DATA_WIDTH + ECC_WIDTH;
  localparam int BYTE_OFFSET_BITS = $clog2(DATA_WIDTH/8);
  localparam int WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);
  localparam int INDEX_BITS       = $clog2(NUM_SETS);
  localparam int TAG_BITS         = ADDR_WIDTH - BYTE_OFFSET_BITS - WORD_OFFSET_BITS - INDEX_BITS;

  typedef logic [TAG_BITS-1:0] tag_t;
  typedef logic [INDEX_BITS-1:0] index_t;
  typedef logic [WORD_OFFSET_BITS-1:0] word_offset_t;
  typedef logic [$clog2(NUM_WAYS)-1:0] way_t;
  typedef logic [CODE_WIDTH-1:0] codeword_t;

  typedef enum logic [2:0] {
    IDLE,
    CHECK,
    WRITEBACK_REQ,
    WRITEBACK_WAIT,
    REFILL_REQ,
    REFILL_WAIT,
    RESPOND
  } state_t;

  state_t state_q, state_d;

  logic      valid_array [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic      dirty_array [0:NUM_SETS-1][0:NUM_WAYS-1];
  tag_t      tag_array   [0:NUM_SETS-1][0:NUM_WAYS-1];
  codeword_t data_array  [0:NUM_SETS-1][0:NUM_WAYS-1][0:WORDS_PER_LINE-1];

  logic plru_array [0:NUM_SETS-1];

  data_t line_buffer [0:WORDS_PER_LINE-1];

  addr_t addr_q;
  data_t wdata_q;
  strb_t wstrb_q;
  logic  write_q;

  data_t rsp_data_q;
  logic  rsp_error_q;

  logic ecc_corrected_q;
  logic ecc_uncorrectable_q;

  logic [$clog2(WORDS_PER_LINE)-1:0] refill_cnt_q;
  logic [$clog2(WORDS_PER_LINE)-1:0] wb_cnt_q;

  way_t hit_way;
  way_t replace_way_q;
  way_t selected_way_comb;

  logic way0_hit;
  logic way1_hit;
  logic cache_hit;
  logic selected_line_dirty;

  data_t hit_decoded_data;
  logic  hit_corrected;
  logic  hit_uncorrectable;

  data_t wb_decoded_data;
  logic  wb_corrected;
  logic  wb_uncorrectable;

  function automatic bit is_power_of_two(input int value);
    return (value == 1)  ||
           (value == 2)  ||
           (value == 4)  ||
           (value == 8)  ||
           (value == 16) ||
           (value == 32);
  endfunction

    function automatic codeword_t ecc_encode(input data_t data);
    codeword_t cw;
    int data_idx;
    int parity_pos;

    cw = '0;
    data_idx = 0;

    for (int pos = 1; pos <= 38; pos++) begin
      if (!is_power_of_two(pos)) begin
        cw[pos-1] = data[data_idx];
        data_idx++;
      end
    end

    for (int p = 0; p < 6; p++) begin
      parity_pos = 1 << p;
      cw[parity_pos-1] = 1'b0;

      for (int pos = 1; pos <= 38; pos++) begin
        if ((pos & parity_pos) != 0) begin
          cw[parity_pos-1] ^= cw[pos-1];
        end
      end
    end

    cw[38] = ^cw[37:0];

    return cw;
  endfunction

   task automatic ecc_decode(
    input  codeword_t cw_in,
    output data_t     data_out,
    output logic      corrected,
    output logic      uncorrectable
  );
    codeword_t cw;
    logic [5:0] syndrome;
    logic overall_error;
    int parity_pos;
    int data_idx;

    cw = cw_in;
    syndrome = '0;

    for (int p = 0; p < 6; p++) begin
      parity_pos = 1 << p;

      for (int pos = 1; pos <= 38; pos++) begin
        if ((pos & parity_pos) != 0) begin
          syndrome[p] ^= cw[pos-1];
        end
      end
    end

    overall_error = ^cw;

    corrected     = 1'b0;
    uncorrectable = 1'b0;

    if ((syndrome != 0) && overall_error) begin
      corrected = 1'b1;

      if (syndrome <= 38) begin
        cw[syndrome-1] = ~cw[syndrome-1];
      end

    end else if ((syndrome == 0) && overall_error) begin
      corrected = 1'b1;

    end else if ((syndrome != 0) && !overall_error) begin
      uncorrectable = 1'b1;
    end

    data_idx = 0;
    data_out = '0;

    for (int pos = 1; pos <= 38; pos++) begin
      if (!is_power_of_two(pos)) begin
        data_out[data_idx] = cw[pos-1];
        data_idx++;
      end
    end
  endtask

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

  function automatic addr_t make_line_base(
    input tag_t   tag,
    input index_t index
  );
    addr_t base;
    base = '0;
    base[ADDR_WIDTH-1 -: TAG_BITS] = tag;
    base[BYTE_OFFSET_BITS + WORD_OFFSET_BITS +: INDEX_BITS] = index;
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

  assign req_index       = get_index(addr_q);
  assign req_word_offset = get_word_offset(addr_q);
  assign req_tag         = get_tag(addr_q);

  assign way0_hit = valid_array[req_index][0] && (tag_array[req_index][0] == req_tag);
  assign way1_hit = valid_array[req_index][1] && (tag_array[req_index][1] == req_tag);

  assign cache_hit = way0_hit || way1_hit;

  always_comb begin
    hit_way = way_t'(0);

    if (way0_hit) begin
      hit_way = way_t'(0);
    end else if (way1_hit) begin
      hit_way = way_t'(1);
    end
  end

  always_comb begin
    selected_way_comb = way_t'(0);

    if (!valid_array[req_index][0]) begin
      selected_way_comb = way_t'(0);
    end else if (!valid_array[req_index][1]) begin
      selected_way_comb = way_t'(1);
    end else begin
      selected_way_comb = way_t'(plru_array[req_index]);
    end
  end

  assign selected_line_dirty =
      valid_array[req_index][selected_way_comb] &&
      dirty_array[req_index][selected_way_comb];

  always_comb begin
    ecc_decode(data_array[req_index][hit_way][req_word_offset],
               hit_decoded_data,
               hit_corrected,
               hit_uncorrectable);

    ecc_decode(data_array[req_index][replace_way_q][wb_cnt_q],
               wb_decoded_data,
               wb_corrected,
               wb_uncorrectable);
  end

  assign cpu_if.req_ready = (state_q == IDLE);

  assign cpu_if.rsp_valid = (state_q == RESPOND);
  assign cpu_if.rsp_rdata = rsp_data_q;
  assign cpu_if.rsp_error = rsp_error_q;

  assign mem_if.req_valid =
      (state_q == WRITEBACK_REQ) ||
      (state_q == REFILL_REQ);

  assign mem_if.req_write =
      (state_q == WRITEBACK_REQ);

  assign mem_if.req_addr =
      (state_q == WRITEBACK_REQ)
      ? (make_line_base(tag_array[req_index][replace_way_q], req_index) +
         addr_t'(wb_cnt_q << BYTE_OFFSET_BITS))
      : (get_line_base(addr_q) +
         addr_t'(refill_cnt_q << BYTE_OFFSET_BITS));

  assign mem_if.req_wdata =
      (state_q == WRITEBACK_REQ)
      ? wb_decoded_data
      : '0;

  assign mem_if.req_wstrb =
      (state_q == WRITEBACK_REQ)
      ? {STRB_WIDTH{1'b1}}
      : '0;

  assign mem_if.rsp_ready = 1'b1;

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
          state_d = RESPOND;
        end else begin
          if (selected_line_dirty) begin
            state_d = WRITEBACK_REQ;
          end else begin
            state_d = REFILL_REQ;
          end
        end
      end

      WRITEBACK_REQ: begin
        if (mem_if.req_valid && mem_if.req_ready) begin
          state_d = WRITEBACK_WAIT;
        end
      end

      WRITEBACK_WAIT: begin
        if (mem_if.rsp_valid) begin
          if (wb_cnt_q == WORDS_PER_LINE-1) begin
            state_d = REFILL_REQ;
          end else begin
            state_d = WRITEBACK_REQ;
          end
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
            state_d = RESPOND;
          end else begin
            state_d = REFILL_REQ;
          end
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

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q             <= IDLE;
      addr_q              <= '0;
      wdata_q             <= '0;
      wstrb_q             <= '0;
      write_q             <= 1'b0;
      rsp_data_q          <= '0;
      rsp_error_q         <= 1'b0;
      ecc_corrected_q     <= 1'b0;
      ecc_uncorrectable_q <= 1'b0;
      refill_cnt_q        <= '0;
      wb_cnt_q            <= '0;
      replace_way_q       <= '0;

      for (int s = 0; s < NUM_SETS; s++) begin
        plru_array[s] <= 1'b0;

        for (int way = 0; way < NUM_WAYS; way++) begin
          valid_array[s][way] <= 1'b0;
          dirty_array[s][way] <= 1'b0;
          tag_array[s][way]   <= '0;

          for (int w = 0; w < WORDS_PER_LINE; w++) begin
            data_array[s][way][w] <= ecc_encode('0);
          end
        end
      end

      for (int w = 0; w < WORDS_PER_LINE; w++) begin
        line_buffer[w] <= '0;
      end

    end else begin
      state_q <= state_d;

      if ((state_q == IDLE) && cpu_if.req_valid && cpu_if.req_ready) begin
        addr_q              <= cpu_if.req_addr;
        wdata_q             <= cpu_if.req_wdata;
        wstrb_q             <= cpu_if.req_wstrb;
        write_q             <= cpu_if.req_write;
        rsp_error_q         <= 1'b0;
        ecc_corrected_q     <= 1'b0;
        ecc_uncorrectable_q <= 1'b0;
        refill_cnt_q        <= '0;
        wb_cnt_q            <= '0;
      end

      if (state_q == CHECK) begin

        if (cache_hit) begin
          if (hit_way == way_t'(0)) begin
            plru_array[req_index] <= 1'b1;
          end else begin
            plru_array[req_index] <= 1'b0;
          end

          ecc_corrected_q     <= hit_corrected;
          ecc_uncorrectable_q <= hit_uncorrectable;

          if (hit_uncorrectable) begin
            rsp_error_q <= 1'b1;
            rsp_data_q  <= hit_decoded_data;
          end else if (write_q) begin
            data_t updated_data;

            updated_data =
              apply_wstrb(hit_decoded_data, wdata_q, wstrb_q);

            data_array[req_index][hit_way][req_word_offset] <=
              ecc_encode(updated_data);

            dirty_array[req_index][hit_way] <= 1'b1;

            rsp_data_q  <= updated_data;
            rsp_error_q <= 1'b0;
          end else begin
            rsp_data_q  <= hit_decoded_data;
            rsp_error_q <= 1'b0;
          end

        end else begin
          replace_way_q <= selected_way_comb;
        end
      end

      if ((state_q == WRITEBACK_WAIT) && mem_if.rsp_valid) begin
        if (mem_if.rsp_error || wb_uncorrectable) begin
          rsp_error_q <= 1'b1;
        end

        if (wb_cnt_q == WORDS_PER_LINE-1) begin
          wb_cnt_q <= '0;
          dirty_array[req_index][replace_way_q] <= 1'b0;
        end else begin
          wb_cnt_q <= wb_cnt_q + 1'b1;
        end
      end

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
              data_array[req_index][replace_way_q][w] <=
                ecc_encode(mem_if.rsp_rdata);
            end else begin
              data_array[req_index][replace_way_q][w] <=
                ecc_encode(line_buffer[w]);
            end
          end

          if (replace_way_q == way_t'(0)) begin
            plru_array[req_index] <= 1'b1;
          end else begin
            plru_array[req_index] <= 1'b0;
          end

          if (write_q) begin
            data_t base_data;
            data_t updated_data;

            if (req_word_offset == refill_cnt_q) begin
              base_data = mem_if.rsp_rdata;
            end else begin
              base_data = line_buffer[req_word_offset];
            end

            updated_data = apply_wstrb(base_data, wdata_q, wstrb_q);

            data_array[req_index][replace_way_q][req_word_offset] <=
              ecc_encode(updated_data);

            dirty_array[req_index][replace_way_q] <= 1'b1;
            rsp_data_q <= updated_data;

          end else begin
            dirty_array[req_index][replace_way_q] <= 1'b0;

            if (req_word_offset == refill_cnt_q) begin
              rsp_data_q <= mem_if.rsp_rdata;
            end else begin
              rsp_data_q <= line_buffer[req_word_offset];
            end
          end

          refill_cnt_q <= '0;

        end else begin
          refill_cnt_q <= refill_cnt_q + 1'b1;
        end
      end

    end
  end

  // ------------------------------------------------------------
  // Fault injection task for verification
  // ------------------------------------------------------------
  // codeword bit mapping:
  // data_array[set][way][word][38]    = overall parity
  // data_array[set][way][word][37:0]  = Hamming code positions 1..38

  task automatic inject_fault(
    input int unsigned set,
    input int unsigned way,
    input int unsigned word,
    input codeword_t   fault_mask
  );
    begin
      data_array[set][way][word] = data_array[set][way][word] ^ fault_mask;
      $display("[FAULT_INJECT] set=%0d way=%0d word=%0d mask=0x%010h",
               set, way, word, fault_mask);
    end
  endtask

endmodule