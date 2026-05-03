`timescale 1ns/1ps

module tb_top;

  localparam int ADDR_WIDTH = 8;
  localparam int DATA_WIDTH = 32;
  localparam int NUM_WORDS  = 64;

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

  logic bist_start;
  logic bist_busy;
  logic bist_done;
  logic bist_pass;
  logic bist_fail;

  logic [ADDR_WIDTH-1:0] fail_addr;
  logic [DATA_WIDTH-1:0] fail_expected;
  logic [DATA_WIDTH-1:0] fail_observed;

  logic                  mbist_mem_we;
  logic [ADDR_WIDTH-1:0] mbist_mem_addr;
  logic [DATA_WIDTH-1:0] mbist_mem_wdata;
  logic [DATA_WIDTH-1:0] mbist_mem_rdata;

  logic normal_access_blocked;

  logic                  normal_en;
  logic                  normal_we;
  logic [ADDR_WIDTH-1:0] normal_addr;
  logic [DATA_WIDTH-1:0] normal_wdata;
  logic [DATA_WIDTH-1:0] normal_rdata;
  logic                  normal_ready;

  logic                  fault_enable;
  logic [ADDR_WIDTH-1:0] fault_addr;
  logic [DATA_WIDTH-1:0] fault_mask;

  int unsigned pass_count;
  int unsigned fail_count;

  mbist_controller #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_WORDS (NUM_WORDS)
  ) u_mbist_controller (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .bist_start_i            (bist_start),
    .bist_busy_o             (bist_busy),
    .bist_done_o             (bist_done),
    .bist_pass_o             (bist_pass),
    .bist_fail_o             (bist_fail),
    .fail_addr_o             (fail_addr),
    .fail_expected_o         (fail_expected),
    .fail_observed_o         (fail_observed),
    .mem_we_o                (mbist_mem_we),
    .mem_addr_o              (mbist_mem_addr),
    .mem_wdata_o             (mbist_mem_wdata),
    .mem_rdata_i             (mbist_mem_rdata),
    .normal_access_blocked_o (normal_access_blocked)
  );

  mbist_memory_array #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_WORDS (NUM_WORDS)
  ) u_mbist_memory_array (
    .clk             (clk),
    .rst_n           (rst_n),
    .bist_active_i   (bist_busy),
    .bist_we_i       (mbist_mem_we),
    .bist_addr_i     (mbist_mem_addr),
    .bist_wdata_i    (mbist_mem_wdata),
    .bist_rdata_o    (mbist_mem_rdata),
    .normal_en_i     (normal_en),
    .normal_we_i     (normal_we),
    .normal_addr_i   (normal_addr),
    .normal_wdata_i  (normal_wdata),
    .normal_rdata_o  (normal_rdata),
    .normal_ready_o  (normal_ready),
    .fault_enable_i  (fault_enable),
    .fault_addr_i    (fault_addr),
    .fault_mask_i    (fault_mask)
  );

  task automatic init_signals();
    begin
      bist_start  = 1'b0;
      normal_en   = 1'b0;
      normal_we   = 1'b0;
      normal_addr = '0;
      normal_wdata = '0;

      fault_enable = 1'b0;
      fault_addr   = '0;
      fault_mask   = '0;
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

  task automatic check_data(
    input string name,
    input logic [DATA_WIDTH-1:0] actual,
    input logic [DATA_WIDTH-1:0] expected
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

  task automatic check_addr(
    input string name,
    input logic [ADDR_WIDTH-1:0] actual,
    input logic [ADDR_WIDTH-1:0] expected
  );
    begin
      if (actual === expected) begin
        $display("[PASS] %s actual=0x%02h expected=0x%02h", name, actual, expected);
        pass_count++;
      end else begin
        $display("[FAIL] %s actual=0x%02h expected=0x%02h", name, actual, expected);
        fail_count++;
      end
    end
  endtask

task automatic start_bist_and_wait();
  begin
    // Ensure previous BIST completion has returned to IDLE.
    bist_start <= 1'b0;

    // Wait until status is clear / controller is idle enough to accept a new start.
    wait (bist_busy == 1'b0);
    repeat (3) @(posedge clk);

    @(posedge clk);
    bist_start <= 1'b1;

    @(posedge clk);
    bist_start <= 1'b0;

    // Wait for BIST to actually start.
    wait (bist_busy == 1'b1);

    // Then wait for completion.
    wait (bist_done == 1'b1);
    @(posedge clk);
  end
endtask

  initial begin
    pass_count = 0;
    fail_count = 0;

    init_signals();

    wait (rst_n == 1'b1);
    repeat (2) @(posedge clk);

    $display("==================================================");
    $display("Phase 6 Test: MBIST Controller with March C-");
    $display("==================================================");

    // ----------------------------------------------------------
    // Test 1: Clean MBIST pass
    // ----------------------------------------------------------

    fault_enable = 1'b0;
    start_bist_and_wait();

    check_bit("Clean MBIST done", bist_done, 1'b1);
    check_bit("Clean MBIST pass", bist_pass, 1'b1);
    check_bit("Clean MBIST fail", bist_fail, 1'b0);

    // ----------------------------------------------------------
    // Test 2: Normal access blocked during BIST
    // ----------------------------------------------------------

    @(posedge clk);
    bist_start <= 1'b1;

    @(posedge clk);
    bist_start <= 1'b0;

    repeat (5) @(posedge clk);

    normal_en    <= 1'b1;
    normal_we    <= 1'b1;
    normal_addr  <= 8'h05;
    normal_wdata <= 32'hDEAD_BEEF;

    @(posedge clk);

    check_bit("Normal access blocked during BIST", normal_access_blocked, 1'b1);
    check_bit("Normal memory port not ready during BIST", normal_ready, 1'b0);

    normal_en <= 1'b0;
    normal_we <= 1'b0;

    wait (bist_done == 1'b1);
    @(posedge clk);

    check_bit("Second clean MBIST done", bist_done, 1'b1);
    check_bit("Second clean MBIST pass", bist_pass, 1'b1);
    check_bit("Second clean MBIST fail", bist_fail, 1'b0);

    // ----------------------------------------------------------
    // Test 3: Inject read fault and verify fail capture.
    //
    // Fault model:
    // - Memory stores correct data.
    // - Read at fault_addr returns corrupted data.
    // - MBIST should detect mismatch during March read.
    // ----------------------------------------------------------

    fault_enable = 1'b1;
    fault_addr   = 8'h0A;
    fault_mask   = 32'h0000_0001;

    repeat (5) @(posedge clk);

    start_bist_and_wait();

    check_bit ("Fault MBIST done", bist_done, 1'b1);
    check_bit ("Fault MBIST pass", bist_pass, 1'b0);
    check_bit ("Fault MBIST fail", bist_fail, 1'b1);
    check_addr("Fault address captured", fail_addr, 8'h0A);
    check_data("Fail expected data captured", fail_expected, 32'h0000_0000);
    check_data("Fail observed data captured", fail_observed, 32'h0000_0001);

    // ----------------------------------------------------------
    // Final summary
    // ----------------------------------------------------------

    $display("==================================================");
    $display("Phase 6 Summary");
    $display("PASS count = %0d", pass_count);
    $display("FAIL count = %0d", fail_count);
    $display("==================================================");

    if (fail_count == 0) begin
      $display("[PHASE 6 PASS] MBIST March C- controller verified.");
    end else begin
      $display("[PHASE 6 FAIL] Some checks failed.");
    end

    #20;
    $finish;
  end

endmodule