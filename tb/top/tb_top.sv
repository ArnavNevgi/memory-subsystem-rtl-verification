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

  // CPU-side interface
  cache_if cpu_bus (
    .clk   (clk),
    .rst_n (rst_n)
  );

  // Cache-to-memory interface
  cache_if mem_bus (
    .clk   (clk),
    .rst_n (rst_n)
  );

  direct_mapped_cache u_cache (
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
    $display("Phase 2 Test: Direct-Mapped Cache Baseline");
    $display("==================================================");

    // Preload backing memory for read miss tests.
    // backing_memory is word-addressed internally.
    u_backing_memory.mem[16] = 32'h1122_3344;  // address 0x0000_0040
    u_backing_memory.mem[17] = 32'h5566_7788;  // address 0x0000_0044
    u_backing_memory.mem[18] = 32'h99AA_BBCC;  // address 0x0000_0048
    u_backing_memory.mem[19] = 32'hDDEE_FF00;  // address 0x0000_004C

    u_backing_memory.mem[64] = 32'hCAFE_BABE;  // address 0x0000_0100
    u_backing_memory.mem[65] = 32'hFACE_FEED;  // address 0x0000_0104
    u_backing_memory.mem[66] = 32'hABCD_1234;  // address 0x0000_0108
    u_backing_memory.mem[67] = 32'h1357_2468;  // address 0x0000_010C

    // ----------------------------------------------------------
    // Test 1: Write miss with write-allocate
    // Address 0x0000_0000 is not cached yet.
    // Cache should refill line, then write data.
    // ----------------------------------------------------------

    cache_write(32'h0000_0000, 32'hDEAD_BEEF, 4'hF);
    cache_read (32'h0000_0000, read_data);
    check_equal("Write miss then read hit", read_data, 32'hDEAD_BEEF);

    // ----------------------------------------------------------
    // Test 2: Read miss refill from backing memory
    // Address 0x0000_0040 is preloaded in backing memory.
    // ----------------------------------------------------------

    cache_read(32'h0000_0040, read_data);
    check_equal("Read miss refill from backing memory", read_data, 32'h1122_3344);

    // ----------------------------------------------------------
    // Test 3: Read hit from same cache line
    // Address 0x0000_0044 is in the same 16-byte cache line.
    // Should hit after previous refill.
    // ----------------------------------------------------------

    cache_read(32'h0000_0044, read_data);
    check_equal("Read hit within refilled cache line", read_data, 32'h5566_7788);

    // ----------------------------------------------------------
    // Test 4: Write hit with byte strobe
    // Original 0x55667788, update lower byte to 0xAA.
    // Expected 0x556677AA.
    // ----------------------------------------------------------

    cache_write(32'h0000_0044, 32'h0000_00AA, 4'b0001);
    cache_read (32'h0000_0044, read_data);
    check_equal("Write hit byte strobe update", read_data, 32'h5566_77AA);

    // ----------------------------------------------------------
    // Test 5: Same-index conflict replacement
    // 0x0000_0000 and 0x0000_0100 map to same direct-mapped index
    // for NUM_SETS=16 and LINE_BYTES=16.
    // Accessing 0x0100 should replace index 0.
    // ----------------------------------------------------------

    cache_read(32'h0000_0100, read_data);
    check_equal("Conflict miss loads new tag at same index", read_data, 32'hCAFE_BABE);

    // Reading 0x0000_0000 again should cause a miss and refill.
    // Since Phase 2 uses write-through, backing memory should contain DEAD_BEEF.
    cache_read(32'h0000_0000, read_data);
    check_equal("Old line refilled after conflict replacement", read_data, 32'hDEAD_BEEF);

    // ----------------------------------------------------------
    // Final summary
    // ----------------------------------------------------------

    $display("==================================================");
    $display("Phase 2 Summary");
    $display("PASS count = %0d", pass_count);
    $display("FAIL count = %0d", fail_count);
    $display("==================================================");

    if (fail_count == 0) begin
      $display("[PHASE 2 PASS] Direct-mapped cache baseline verified.");
    end else begin
      $display("[PHASE 2 FAIL] Some checks failed.");
    end

    #20;
    $finish;
  end

endmodule