`timescale 1ns/1ps

`include "cache_coverage.sv"

module tb_top;

  import cache_pkg::*;

  logic clk;
  logic rst_n;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  cache_if cpu_bus (
    .clk   (clk),
    .rst_n (rst_n)
  );

  cache_if mem_bus (
    .clk   (clk),
    .rst_n (rst_n)
  );

  two_way_wb_ecc_cache u_cache (
    .clk    (clk),
    .rst_n  (rst_n),
    .cpu_if (cpu_bus),
    .mem_if (mem_bus)
  );

  backing_memory #(
    .RESP_LATENCY(2)
  ) u_backing_memory (
    .clk    (clk),
    .rst_n  (rst_n),
    .mem_if (mem_bus)
  );

  cache_assertions u_cache_assertions (
    .clk           (clk),
    .rst_n         (rst_n),

    .cpu_req_valid (cpu_bus.req_valid),
    .cpu_req_ready (cpu_bus.req_ready),
    .cpu_req_write (cpu_bus.req_write),
    .cpu_req_addr  (cpu_bus.req_addr),
    .cpu_req_wdata (cpu_bus.req_wdata),
    .cpu_req_wstrb (cpu_bus.req_wstrb),

    .cpu_rsp_valid (cpu_bus.rsp_valid),
    .cpu_rsp_ready (cpu_bus.rsp_ready),
    .cpu_rsp_rdata (cpu_bus.rsp_rdata),
    .cpu_rsp_error (cpu_bus.rsp_error),

    .mem_req_valid (mem_bus.req_valid),
    .mem_req_ready (mem_bus.req_ready),
    .mem_req_write (mem_bus.req_write),
    .mem_req_addr  (mem_bus.req_addr),
    .mem_req_wdata (mem_bus.req_wdata),
    .mem_req_wstrb (mem_bus.req_wstrb),

    .mem_rsp_valid (mem_bus.rsp_valid),
    .mem_rsp_ready (mem_bus.rsp_ready),
    .mem_rsp_rdata (mem_bus.rsp_rdata),
    .mem_rsp_error (mem_bus.rsp_error)
  );

  int unsigned pass_count;
  int unsigned fail_count;
  int unsigned random_count;

  data_t read_data;
  logic  read_error;

  data_t ref_mem [0:cache_pkg::MEM_WORDS-1];

  cache_coverage cov;

  function automatic data_t apply_wstrb_ref(
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

  function automatic int unsigned word_index(input addr_t addr);
    return addr[($clog2(cache_pkg::MEM_WORDS)+1):2];
  endfunction

  task automatic init_signals();
    cpu_bus.req_valid = 1'b0;
    cpu_bus.req_write = 1'b0;
    cpu_bus.req_addr  = '0;
    cpu_bus.req_wdata = '0;
    cpu_bus.req_wstrb = '0;
    cpu_bus.rsp_ready = 1'b1;
  endtask

  task automatic init_reference_memory();
    begin
      for (int i = 0; i < cache_pkg::MEM_WORDS; i++) begin
        ref_mem[i] = 32'h1000_0000 + i;
        u_backing_memory.mem[i] = ref_mem[i];
      end
    end
  endtask

  task automatic cache_write(
    input addr_t addr,
    input data_t data,
    input strb_t strb
  );
    begin
      @(posedge clk);

      cpu_bus.req_valid <= 1'b1;
      cpu_bus.req_write <= 1'b1;
      cpu_bus.req_addr  <= addr;
      cpu_bus.req_wdata <= data;
      cpu_bus.req_wstrb <= strb;

      do begin
        @(posedge clk);
      end while (!cpu_bus.req_ready);

      cpu_bus.req_valid <= 1'b0;
      cpu_bus.req_write <= 1'b0;
      cpu_bus.req_addr  <= '0;
      cpu_bus.req_wdata <= '0;
      cpu_bus.req_wstrb <= '0;

      do begin
        @(posedge clk);
      end while (!cpu_bus.rsp_valid);

      if (cpu_bus.rsp_error) begin
        $display("[FAIL] Cache write error addr=0x%08h", addr);
        fail_count++;
      end

      cov.sample(
        1'b1,
        addr,
        strb,
        cpu_bus.rsp_error,
        u_cache.cache_hit,
        u_cache.way0_hit,
        u_cache.way1_hit,
        u_cache.ecc_corrected_q,
        u_cache.ecc_uncorrectable_q
      );

      @(posedge clk);
    end
  endtask

  task automatic cache_read(
    input  addr_t addr,
    output data_t data,
    output logic  error
  );
    begin
      @(posedge clk);

      cpu_bus.req_valid <= 1'b1;
      cpu_bus.req_write <= 1'b0;
      cpu_bus.req_addr  <= addr;
      cpu_bus.req_wdata <= '0;
      cpu_bus.req_wstrb <= '0;

      do begin
        @(posedge clk);
      end while (!cpu_bus.req_ready);

      cpu_bus.req_valid <= 1'b0;
      cpu_bus.req_write <= 1'b0;
      cpu_bus.req_addr  <= '0;
      cpu_bus.req_wdata <= '0;
      cpu_bus.req_wstrb <= '0;

      do begin
        @(posedge clk);
      end while (!cpu_bus.rsp_valid);

      data  = cpu_bus.rsp_rdata;
      error = cpu_bus.rsp_error;

      cov.sample(
        1'b0,
        addr,
        4'h0,
        cpu_bus.rsp_error,
        u_cache.cache_hit,
        u_cache.way0_hit,
        u_cache.way1_hit,
        u_cache.ecc_corrected_q,
        u_cache.ecc_uncorrectable_q
      );

      @(posedge clk);
    end
  endtask

  task automatic check_equal(
    input string name,
    input data_t actual,
    input data_t expected
  );
    begin
      if (actual === expected) begin
        $display("[PASS] %s actual=0x%08h expected=0x%08h", name, actual, expected);
        pass_count++;
      end else begin
        $display("[FAIL] %s actual=0x%08h expected=0x%08h", name, actual, expected);
        fail_count++;
      end
    end
  endtask

  task automatic check_bit(
    input string name,
    input logic actual,
    input logic expected
  );
    begin
      if (actual === expected) begin
        $display("[PASS] %s actual=%0b expected=%0b", name, actual, expected);
        pass_count++;
      end else begin
        $display("[FAIL] %s actual=%0b expected=%0b", name, actual, expected);
        fail_count++;
      end
    end
  endtask

  task automatic scoreboard_write(
    input addr_t addr,
    input data_t data,
    input strb_t strb
  );
    int unsigned idx;
    begin
      idx = word_index(addr);
      ref_mem[idx] = apply_wstrb_ref(ref_mem[idx], data, strb);
    end
  endtask

  task automatic scoreboard_check_read(
    input addr_t addr,
    input data_t actual,
    input logic  error
  );
    int unsigned idx;
    begin
      idx = word_index(addr);

      if (error) begin
        $display("[FAIL] Unexpected read error addr=0x%08h", addr);
        fail_count++;
      end else if (actual !== ref_mem[idx]) begin
        $display("[FAIL] Scoreboard mismatch addr=0x%08h actual=0x%08h expected=0x%08h",
                 addr, actual, ref_mem[idx]);
        fail_count++;
      end else begin
        $display("[PASS] Scoreboard read addr=0x%08h data=0x%08h", addr, actual);
        pass_count++;
      end
    end
  endtask

  task automatic directed_tests();
    begin
      $display("--------------------------------------------------");
      $display("Phase 7 Directed Tests");
      $display("--------------------------------------------------");

      cache_read(32'h0000_0040, read_data, read_error);
      scoreboard_check_read(32'h0000_0040, read_data, read_error);

      cache_read(32'h0000_0044, read_data, read_error);
      scoreboard_check_read(32'h0000_0044, read_data, read_error);

      cache_write(32'h0000_0040, 32'hDEAD_BEEF, 4'hF);
      scoreboard_write(32'h0000_0040, 32'hDEAD_BEEF, 4'hF);

      cache_read(32'h0000_0040, read_data, read_error);
      scoreboard_check_read(32'h0000_0040, read_data, read_error);

      cache_write(32'h0000_0040, 32'h0000_00AA, 4'h1);
      scoreboard_write(32'h0000_0040, 32'h0000_00AA, 4'h1);

      cache_read(32'h0000_0040, read_data, read_error);
      scoreboard_check_read(32'h0000_0040, read_data, read_error);

      // Same-index lines to exercise both ways and PLRU.
      cache_read(32'h0000_0140, read_data, read_error);
      scoreboard_check_read(32'h0000_0140, read_data, read_error);

      cache_read(32'h0000_0240, read_data, read_error);
      scoreboard_check_read(32'h0000_0240, read_data, read_error);
    end
  endtask

  task automatic ecc_fault_tests();
    begin
      $display("--------------------------------------------------");
      $display("Phase 7 ECC Fault Tests");
      $display("--------------------------------------------------");

      // Load a known line into set 4, likely way 0 or way 1 depending on PLRU.
      // Use a fresh address region to avoid ambiguity.
      cache_read(32'h0000_0080, read_data, read_error);
      scoreboard_check_read(32'h0000_0080, read_data, read_error);

      // Address 0x80 maps to set index 8. First fill usually selects way 0.
      u_cache.inject_fault(8, 0, 0, 39'h0000_0000_004);

      cache_read(32'h0000_0080, read_data, read_error);
      check_equal("ECC single-bit corrected read", read_data, ref_mem[word_index(32'h0000_0080)]);
      check_bit  ("ECC single-bit corrected response error", read_error, 1'b0);
      check_bit  ("ECC corrected flag observed", u_cache.ecc_corrected_q, 1'b1);

      // Clean rewrite before double-bit fault.
      cache_write(32'h0000_0080, ref_mem[word_index(32'h0000_0080)], 4'hF);

      u_cache.inject_fault(8, 0, 0, 39'h0000_0000_014);

      cache_read(32'h0000_0080, read_data, read_error);
      check_bit("ECC double-bit response error observed", read_error, 1'b1);
      check_bit("ECC double-bit uncorrectable flag observed", u_cache.ecc_uncorrectable_q, 1'b1);

      // Restore the injected double-bit fault so randomized testing starts
      // from a clean cache state. Without scrubbing/repair logic, the corrupted
      // physical codeword remains stored after detection.
      u_cache.inject_fault(8, 0, 0, 39'h0000_0000_014);
    end
  endtask

  task automatic random_tests(input int unsigned num_ops);
    addr_t addr;
    data_t data;
    strb_t strb;
    int unsigned idx;
    int unsigned op;
    begin
      $display("--------------------------------------------------");
      $display("Phase 7 Random Tests: %0d operations", num_ops);
      $display("--------------------------------------------------");

      for (int n = 0; n < num_ops; n++) begin
        idx  = $urandom_range(0, 255);
        addr = addr_t'(idx << 2);
        op   = $urandom_range(0, 1);

        if (op == 0) begin
          cache_read(addr, read_data, read_error);
          scoreboard_check_read(addr, read_data, read_error);
        end else begin
          data = $urandom();
          case ($urandom_range(0, 4))
            0: strb = 4'hF;
            1: strb = 4'h1;
            2: strb = 4'h8;
            3: strb = 4'h3;
            default: strb = 4'hC;
          endcase

          cache_write(addr, data, strb);
          scoreboard_write(addr, data, strb);
        end

        random_count++;
      end
    end
  endtask

  task automatic coverage_closure_tests();
  begin
    $display("--------------------------------------------------");
    $display("Phase 7 Coverage Closure Tests");
    $display("--------------------------------------------------");

    // ----------------------------------------------------------
    // Force read miss then read hit
    // ----------------------------------------------------------
    cache_read(32'h0000_0300, read_data, read_error);
    scoreboard_check_read(32'h0000_0300, read_data, read_error);

    cache_read(32'h0000_0300, read_data, read_error);
    scoreboard_check_read(32'h0000_0300, read_data, read_error);

    // ----------------------------------------------------------
    // Force write miss then write hit
    // ----------------------------------------------------------
    cache_write(32'h0000_0340, 32'hABCD_1234, 4'hF);
    scoreboard_write(32'h0000_0340, 32'hABCD_1234, 4'hF);

    cache_write(32'h0000_0340, 32'h0000_00EF, 4'h1);
    scoreboard_write(32'h0000_0340, 32'h0000_00EF, 4'h1);

    cache_read(32'h0000_0340, read_data, read_error);
    scoreboard_check_read(32'h0000_0340, read_data, read_error);

    // ----------------------------------------------------------
    // Force way 0 / way 1 coexistence and hits.
    // These addresses map to the same set but different tags.
    // ----------------------------------------------------------
    cache_read(32'h0000_00C0, read_data, read_error);
    scoreboard_check_read(32'h0000_00C0, read_data, read_error);

    cache_read(32'h0000_01C0, read_data, read_error);
    scoreboard_check_read(32'h0000_01C0, read_data, read_error);

    cache_read(32'h0000_00C0, read_data, read_error);
    scoreboard_check_read(32'h0000_00C0, read_data, read_error);

    cache_read(32'h0000_01C0, read_data, read_error);
    scoreboard_check_read(32'h0000_01C0, read_data, read_error);

    // ----------------------------------------------------------
    // Force remaining write strobe bins.
    // ----------------------------------------------------------
    cache_write(32'h0000_0380, 32'h1111_2222, 4'h8);
    scoreboard_write(32'h0000_0380, 32'h1111_2222, 4'h8);

    cache_write(32'h0000_0384, 32'h3333_4444, 4'h3);
    scoreboard_write(32'h0000_0384, 32'h3333_4444, 4'h3);

    cache_write(32'h0000_0388, 32'h5555_6666, 4'hC);
    scoreboard_write(32'h0000_0388, 32'h5555_6666, 4'hC);

    cache_read(32'h0000_0380, read_data, read_error);
    scoreboard_check_read(32'h0000_0380, read_data, read_error);

    cache_read(32'h0000_0384, read_data, read_error);
    scoreboard_check_read(32'h0000_0384, read_data, read_error);

    cache_read(32'h0000_0388, read_data, read_error);
    scoreboard_check_read(32'h0000_0388, read_data, read_error);
  end
endtask

  initial begin
    pass_count   = 0;
    fail_count   = 0;
    random_count = 0;

    cov = new();

    init_signals();

    wait (rst_n == 1'b1);
    repeat (2) @(posedge clk);

    init_reference_memory();

    $display("==================================================");
    $display("Phase 7 Test: Assertions, Coverage, Scoreboard, Random");
    $display("==================================================");

    directed_tests();
    ecc_fault_tests();
    coverage_closure_tests();
    random_tests(500);

    $display("==================================================");
    $display("Phase 7 Summary");
    $display("PASS count      = %0d", pass_count);
    $display("FAIL count      = %0d", fail_count);
    $display("Random ops      = %0d", random_count);
    $display("Coverage        = %0.2f%%", cov.get_coverage());
    $display("==================================================");

    if (fail_count == 0) begin
      $display("[PHASE 7 PASS] Assertions, scoreboard, coverage, and random tests verified.");
    end else begin
      $display("[PHASE 7 FAIL] Some checks failed.");
    end

    #20;
    $finish;
  end

endmodule