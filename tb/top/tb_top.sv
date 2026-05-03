`timescale 1ns/1ps

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

  int unsigned pass_count;
  int unsigned fail_count;

  data_t read_data;
  logic  read_error;

  task automatic init_signals();
    cpu_bus.req_valid = 1'b0;
    cpu_bus.req_write = 1'b0;
    cpu_bus.req_addr  = '0;
    cpu_bus.req_wdata = '0;
    cpu_bus.req_wstrb = '0;
    cpu_bus.rsp_ready = 1'b1;
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
      end else begin
        $display("[INFO] Cache write complete addr=0x%08h data=0x%08h", addr, data);
      end

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

      $display("[INFO] Cache read addr=0x%08h data=0x%08h error=%0b corrected=%0b uncorrectable=%0b",
               addr,
               data,
               error,
               u_cache.ecc_corrected_q,
               u_cache.ecc_uncorrectable_q);

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

  initial begin
    pass_count = 0;
    fail_count = 0;

    init_signals();

    wait (rst_n == 1'b1);
    repeat (2) @(posedge clk);

    $display("==================================================");
    $display("Phase 5 Test: SECDED ECC and Fault Injection");
    $display("==================================================");

    // Address 0x0000_0040 maps to set index 4.
    // First line fill should choose way 0.
    u_backing_memory.mem[16] = 32'hA5A5_1234;
    u_backing_memory.mem[17] = 32'h1111_2222;
    u_backing_memory.mem[18] = 32'h3333_4444;
    u_backing_memory.mem[19] = 32'h5555_6666;

    // Address 0x0000_0140 maps to same set index 4.
    // Second line fill should choose way 1.
    u_backing_memory.mem[80] = 32'hBEEF_CAFE;
    u_backing_memory.mem[81] = 32'h7777_8888;
    u_backing_memory.mem[82] = 32'h9999_AAAA;
    u_backing_memory.mem[83] = 32'hBBBB_CCCC;

    // Address 0x0000_0240 maps to same set index 4.
    // Used after double-error test if needed.
    u_backing_memory.mem[144] = 32'hFACE_1234;
    u_backing_memory.mem[145] = 32'hABCD_0001;
    u_backing_memory.mem[146] = 32'hABCD_0002;
    u_backing_memory.mem[147] = 32'hABCD_0003;

    // ----------------------------------------------------------
    // Test 1: Normal read miss/refill with ECC encoding.
    // ----------------------------------------------------------

    cache_read(32'h0000_0040, read_data, read_error);
    check_equal("ECC clean read data", read_data, 32'hA5A5_1234);
    check_bit  ("ECC clean read error", read_error, 1'b0);
    check_bit  ("ECC clean read corrected flag", u_cache.ecc_corrected_q, 1'b0);
    check_bit  ("ECC clean read uncorrectable flag", u_cache.ecc_uncorrectable_q, 1'b0);

    // ----------------------------------------------------------
    // Test 2: Single-bit data/codeword error.
    // Flip codeword bit 2. This corresponds to Hamming position 3,
    // which is a data position. ECC should correct it.
    // set=4, way=0, word=0 for address 0x0000_0040.
    // ----------------------------------------------------------

    u_cache.inject_fault(4, 0, 0, 39'h0000_0000_004);

    cache_read(32'h0000_0040, read_data, read_error);
    check_equal("Single-bit data error corrected data", read_data, 32'hA5A5_1234);
    check_bit  ("Single-bit data error response error", read_error, 1'b0);
    check_bit  ("Single-bit data error corrected flag", u_cache.ecc_corrected_q, 1'b1);
    check_bit  ("Single-bit data error uncorrectable flag", u_cache.ecc_uncorrectable_q, 1'b0);

    // ----------------------------------------------------------
    // Test 3: Single-bit ECC/parity error.
    // Fill second line into way 1, then flip parity bit 0.
    // Data should still be returned correctly.
    // ----------------------------------------------------------

    cache_read(32'h0000_0140, read_data, read_error);
    check_equal("Second line clean read", read_data, 32'hBEEF_CAFE);

    u_cache.inject_fault(4, 1, 0, 39'h0000_0000_001);

    cache_read(32'h0000_0140, read_data, read_error);
    check_equal("Single-bit ECC bit error data", read_data, 32'hBEEF_CAFE);
    check_bit  ("Single-bit ECC bit error response error", read_error, 1'b0);
    check_bit  ("Single-bit ECC bit corrected flag", u_cache.ecc_corrected_q, 1'b1);
    check_bit  ("Single-bit ECC bit uncorrectable flag", u_cache.ecc_uncorrectable_q, 1'b0);

    // ----------------------------------------------------------
    // Test 4: Double-bit error.
    // First restore Line A by rewriting clean data so the previous
    // single-bit injected fault is removed and ECC is regenerated.
    // Then flip exactly two bits.
    // ----------------------------------------------------------

    cache_write(32'h0000_0040, 32'hA5A5_1234, 4'hF);

    u_cache.inject_fault(4, 0, 0, 39'h0000_0000_014);

    cache_read(32'h0000_0040, read_data, read_error);
    check_bit("Double-bit error response error", read_error, 1'b1);
    check_bit("Double-bit error corrected flag", u_cache.ecc_corrected_q, 1'b0);
    check_bit("Double-bit error uncorrectable flag", u_cache.ecc_uncorrectable_q, 1'b1);

    // ----------------------------------------------------------
    // Test 5: Write hit after ECC-protected access.
    // This verifies writes regenerate ECC.
    // ----------------------------------------------------------

    cache_write(32'h0000_0140, 32'h1234_5678, 4'hF);
    cache_read (32'h0000_0140, read_data, read_error);

    check_equal("Write hit regenerates ECC and returns updated data", read_data, 32'h1234_5678);
    check_bit  ("Write hit ECC read error", read_error, 1'b0);

    // ----------------------------------------------------------
    // Final summary
    // ----------------------------------------------------------

    $display("==================================================");
    $display("Phase 5 Summary");
    $display("PASS count = %0d", pass_count);
    $display("FAIL count = %0d", fail_count);
    $display("==================================================");

    if (fail_count == 0) begin
      $display("[PHASE 5 PASS] SECDED ECC and fault injection verified.");
    end else begin
      $display("[PHASE 5 FAIL] Some checks failed.");
    end

    #20;
    $finish;
  end

endmodule