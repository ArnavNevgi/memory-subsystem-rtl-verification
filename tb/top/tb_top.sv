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

  two_way_cache u_cache (
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
    output data_t data
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

      data = cpu_bus.rsp_rdata;

      if (cpu_bus.rsp_error) begin
        $display("[FAIL] Cache read error addr=0x%08h", addr);
        fail_count++;
      end else begin
        $display("[INFO] Cache read complete  addr=0x%08h data=0x%08h", addr, data);
      end

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

  initial begin
    pass_count = 0;
    fail_count = 0;

    init_signals();

    wait (rst_n == 1'b1);
    repeat (2) @(posedge clk);

    $display("==================================================");
    $display("Phase 3 Test: 2-Way Set-Associative Cache");
    $display("==================================================");

    // ----------------------------------------------------------
    // Preload backing memory.
    //
    // For NUM_SETS=16 and LINE_BYTES=16:
    // 0x0000_0040, 0x0000_0140, and 0x0000_0240
    // map to the same set index but have different tags.
    // ----------------------------------------------------------

    // Line A: base address 0x0000_0040, word index 16
    u_backing_memory.mem[16] = 32'hA0A0_0000;
    u_backing_memory.mem[17] = 32'hA0A0_0004;
    u_backing_memory.mem[18] = 32'hA0A0_0008;
    u_backing_memory.mem[19] = 32'hA0A0_000C;

    // Line B: base address 0x0000_0140, word index 80
    u_backing_memory.mem[80] = 32'hB0B0_0000;
    u_backing_memory.mem[81] = 32'hB0B0_0004;
    u_backing_memory.mem[82] = 32'hB0B0_0008;
    u_backing_memory.mem[83] = 32'hB0B0_000C;

    // Line C: base address 0x0000_0240, word index 144
    u_backing_memory.mem[144] = 32'hC0C0_0000;
    u_backing_memory.mem[145] = 32'hC0C0_0004;
    u_backing_memory.mem[146] = 32'hC0C0_0008;
    u_backing_memory.mem[147] = 32'hC0C0_000C;

    // Extra line for write miss/write hit testing.
    u_backing_memory.mem[32] = 32'h1111_0000;  // address 0x0000_0080
    u_backing_memory.mem[33] = 32'h1111_0004;  // address 0x0000_0084
    u_backing_memory.mem[34] = 32'h1111_0008;  // address 0x0000_0088
    u_backing_memory.mem[35] = 32'h1111_000C;  // address 0x0000_008C

    // ----------------------------------------------------------
    // Test 1: Fill way 0 with Line A.
    // First access to A should miss and refill.
    // ----------------------------------------------------------

    cache_read(32'h0000_0040, read_data);
    check_equal("Line A read miss fill", read_data, 32'hA0A0_0000);

    // ----------------------------------------------------------
    // Test 2: Hit in existing way for Line A.
    // Address 0x44 is same line, different word.
    // ----------------------------------------------------------

    cache_read(32'h0000_0044, read_data);
    check_equal("Line A same-line read hit", read_data, 32'hA0A0_0004);

    // ----------------------------------------------------------
    // Test 3: Fill other way with Line B.
    // Same set index as A, different tag.
    // In a direct-mapped cache this would evict A.
    // In 2-way cache, A and B should coexist.
    // ----------------------------------------------------------

    cache_read(32'h0000_0140, read_data);
    check_equal("Line B same-index miss fills second way", read_data, 32'hB0B0_0000);

    // ----------------------------------------------------------
    // Test 4: Confirm Line A still hits after Line B is loaded.
    // This proves 2-way associativity.
    // ----------------------------------------------------------

    cache_read(32'h0000_0048, read_data);
    check_equal("Line A still present after Line B fill", read_data, 32'hA0A0_0008);

    // ----------------------------------------------------------
    // Test 5: Confirm Line B also hits.
    // ----------------------------------------------------------

    cache_read(32'h0000_0144, read_data);
    check_equal("Line B read hit in other way", read_data, 32'hB0B0_0004);

    // ----------------------------------------------------------
    // Test 6: Pseudo-LRU replacement behavior.
    //
    // Previous access was Line B, so Line A should become LRU.
    // Access Line C, which maps to same set. It should replace A.
    // ----------------------------------------------------------

    cache_read(32'h0000_0240, read_data);
    check_equal("Line C conflict miss replaces pseudo-LRU way", read_data, 32'hC0C0_0000);

    // ----------------------------------------------------------
    // Test 7: Line C should now hit.
    // ----------------------------------------------------------

    cache_read(32'h0000_0244, read_data);
    check_equal("Line C read hit after replacement", read_data, 32'hC0C0_0004);

    // ----------------------------------------------------------
    // Test 8: Write miss with write-allocate.
    // ----------------------------------------------------------

    cache_write(32'h0000_0080, 32'hDEAD_BEEF, 4'hF);
    cache_read (32'h0000_0080, read_data);
    check_equal("Write miss then read hit", read_data, 32'hDEAD_BEEF);

    // ----------------------------------------------------------
    // Test 9: Write hit with byte strobe.
    // Initial value is DEAD_BEEF. Update lower byte to 0xAA.
    // Expected DEAD_BEAA.
    // ----------------------------------------------------------

    cache_write(32'h0000_0080, 32'h0000_00AA, 4'b0001);
    cache_read (32'h0000_0080, read_data);
    check_equal("Write hit byte strobe update", read_data, 32'hDEAD_BEAA);

    // ----------------------------------------------------------
    // Final summary
    // ----------------------------------------------------------

    $display("==================================================");
    $display("Phase 3 Summary");
    $display("PASS count = %0d", pass_count);
    $display("FAIL count = %0d", fail_count);
    $display("==================================================");

    if (fail_count == 0) begin
      $display("[PHASE 3 PASS] 2-way set-associative cache with pseudo-LRU verified.");
    end else begin
      $display("[PHASE 3 FAIL] Some checks failed.");
    end

    #20;
    $finish;
  end

endmodule