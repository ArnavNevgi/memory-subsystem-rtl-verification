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

  two_way_wb_cache u_cache (
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
    $display("Phase 4 Test: Write-Back Cache and Dirty Eviction");
    $display("==================================================");

    // ----------------------------------------------------------
    // Address mapping note:
    //
    // For NUM_SETS=16 and LINE_BYTES=16:
    // 0x0000_0040, 0x0000_0140, 0x0000_0240
    // map to the same set index with different tags.
    // ----------------------------------------------------------

    // Line A: base 0x0000_0040, word index 16
    u_backing_memory.mem[16] = 32'hAAAA_0000;
    u_backing_memory.mem[17] = 32'hAAAA_0004;
    u_backing_memory.mem[18] = 32'hAAAA_0008;
    u_backing_memory.mem[19] = 32'hAAAA_000C;

    // Line B: base 0x0000_0140, word index 80
    u_backing_memory.mem[80] = 32'hBBBB_0000;
    u_backing_memory.mem[81] = 32'hBBBB_0004;
    u_backing_memory.mem[82] = 32'hBBBB_0008;
    u_backing_memory.mem[83] = 32'hBBBB_000C;

    // Line C: base 0x0000_0240, word index 144
    u_backing_memory.mem[144] = 32'hCCCC_0000;
    u_backing_memory.mem[145] = 32'hCCCC_0004;
    u_backing_memory.mem[146] = 32'hCCCC_0008;
    u_backing_memory.mem[147] = 32'hCCCC_000C;

    // Clean eviction test lines.
    u_backing_memory.mem[32]  = 32'h1111_0000;  // 0x0000_0080
    u_backing_memory.mem[96]  = 32'h2222_0000;  // 0x0000_0180
    u_backing_memory.mem[160] = 32'h3333_0000;  // 0x0000_0280

    // ----------------------------------------------------------
    // Test 1: Write miss should allocate line and mark it dirty.
    // It should NOT immediately update backing memory.
    // ----------------------------------------------------------

    cache_write(32'h0000_0040, 32'hDEAD_BEEF, 4'hF);
    check_equal("Write-back: memory not updated immediately",
                u_backing_memory.mem[16],
                32'hAAAA_0000);

    cache_read(32'h0000_0040, read_data);
    check_equal("Write miss allocated dirty line in cache",
                read_data,
                32'hDEAD_BEEF);

    // ----------------------------------------------------------
    // Test 2: Fill second way with another dirty line.
    // ----------------------------------------------------------

    cache_write(32'h0000_0140, 32'hCAFE_BABE, 4'hF);
    cache_read (32'h0000_0140, read_data);
    check_equal("Second dirty line allocated in other way",
                read_data,
                32'hCAFE_BABE);

    // ----------------------------------------------------------
    // Test 3: Conflict miss with Line C.
    // PLRU should select a dirty victim.
    // Dirty victim must be written back before refill.
    // Based on access order, Line A is expected to be evicted.
    // ----------------------------------------------------------

    cache_read(32'h0000_0240, read_data);
    check_equal("Conflict miss loads Line C",
                read_data,
                32'hCCCC_0000);

    check_equal("Dirty eviction wrote Line A word 0 back to memory",
                u_backing_memory.mem[16],
                32'hDEAD_BEEF);

    // ----------------------------------------------------------
    // Test 4: Reading Line A again should refill updated data
    // from backing memory.
    // ----------------------------------------------------------

    cache_read(32'h0000_0040, read_data);
    check_equal("Evicted dirty Line A refills with updated data",
                read_data,
                32'hDEAD_BEEF);

    // ----------------------------------------------------------
    // Test 5: Write hit should update cache and dirty bit.
    // Backing memory should remain unchanged until eviction.
    // ----------------------------------------------------------

    cache_write(32'h0000_0040, 32'h0000_00AA, 4'b0001);
    cache_read (32'h0000_0040, read_data);
    check_equal("Write hit byte strobe updates cached data",
                read_data,
                32'hDEAD_BEAA);

    check_equal("Write hit does not immediately update backing memory",
                u_backing_memory.mem[16],
                32'hDEAD_BEEF);

    // ----------------------------------------------------------
    // Test 6: Clean eviction path.
    // Read-only lines should be clean. Replacing a clean line
    // should not require a dirty write-back.
    // This test mainly verifies functionality remains correct.
    // ----------------------------------------------------------

    cache_read(32'h0000_0080, read_data);
    check_equal("Clean Line D read miss fill",
                read_data,
                32'h1111_0000);

    cache_read(32'h0000_0180, read_data);
    check_equal("Clean Line E fills second way",
                read_data,
                32'h2222_0000);

    cache_read(32'h0000_0280, read_data);
    check_equal("Clean conflict miss loads Line F",
                read_data,
                32'h3333_0000);

    check_equal("Clean eviction did not modify original memory line",
                u_backing_memory.mem[32],
                32'h1111_0000);

    // ----------------------------------------------------------
    // Final summary
    // ----------------------------------------------------------

    $display("==================================================");
    $display("Phase 4 Summary");
    $display("PASS count = %0d", pass_count);
    $display("FAIL count = %0d", fail_count);
    $display("==================================================");

    if (fail_count == 0) begin
      $display("[PHASE 4 PASS] Write-back cache and dirty eviction verified.");
    end else begin
      $display("[PHASE 4 FAIL] Some checks failed.");
    end

    #20;
    $finish;
  end

endmodule