module cache_assertions (
  input logic clk,
  input logic rst_n,

  input logic cpu_req_valid,
  input logic cpu_req_ready,
  input logic cpu_req_write,
  input logic [31:0] cpu_req_addr,
  input logic [31:0] cpu_req_wdata,
  input logic [3:0]  cpu_req_wstrb,

  input logic cpu_rsp_valid,
  input logic cpu_rsp_ready,
  input logic [31:0] cpu_rsp_rdata,
  input logic        cpu_rsp_error,

  input logic mem_req_valid,
  input logic mem_req_ready,
  input logic mem_req_write,
  input logic [31:0] mem_req_addr,
  input logic [31:0] mem_req_wdata,
  input logic [3:0]  mem_req_wstrb,

  input logic mem_rsp_valid,
  input logic mem_rsp_ready,
  input logic [31:0] mem_rsp_rdata,
  input logic        mem_rsp_error
);

  // ------------------------------------------------------------
  // CPU request must remain stable while waiting for ready
  // ------------------------------------------------------------

  property cpu_req_stable_until_ready;
    @(posedge clk) disable iff (!rst_n)
      (cpu_req_valid && !cpu_req_ready)
      |=> (cpu_req_valid &&
           $stable(cpu_req_write) &&
           $stable(cpu_req_addr)  &&
           $stable(cpu_req_wdata) &&
           $stable(cpu_req_wstrb));
  endproperty

  assert property (cpu_req_stable_until_ready)
    else $error("[ASSERT_FAIL] CPU request changed before ready");

  // ------------------------------------------------------------
  // CPU response must remain stable while waiting for ready
  // ------------------------------------------------------------

  property cpu_rsp_stable_until_ready;
    @(posedge clk) disable iff (!rst_n)
      (cpu_rsp_valid && !cpu_rsp_ready)
      |=> (cpu_rsp_valid &&
           $stable(cpu_rsp_rdata) &&
           $stable(cpu_rsp_error));
  endproperty

  assert property (cpu_rsp_stable_until_ready)
    else $error("[ASSERT_FAIL] CPU response changed before ready");

  // ------------------------------------------------------------
  // Memory request must remain stable while waiting for ready
  // ------------------------------------------------------------

  property mem_req_stable_until_ready;
    @(posedge clk) disable iff (!rst_n)
      (mem_req_valid && !mem_req_ready)
      |=> (mem_req_valid &&
           $stable(mem_req_write) &&
           $stable(mem_req_addr)  &&
           $stable(mem_req_wdata) &&
           $stable(mem_req_wstrb));
  endproperty

  assert property (mem_req_stable_until_ready)
    else $error("[ASSERT_FAIL] Memory request changed before ready");

  // ------------------------------------------------------------
  // Memory response must remain stable while waiting for ready
  // ------------------------------------------------------------

  property mem_rsp_stable_until_ready;
    @(posedge clk) disable iff (!rst_n)
      (mem_rsp_valid && !mem_rsp_ready)
      |=> (mem_rsp_valid &&
           $stable(mem_rsp_rdata) &&
           $stable(mem_rsp_error));
  endproperty

  assert property (mem_rsp_stable_until_ready)
    else $error("[ASSERT_FAIL] Memory response changed before ready");

  // ------------------------------------------------------------
  // Address alignment check
  // ------------------------------------------------------------

  property cpu_req_word_aligned;
    @(posedge clk) disable iff (!rst_n)
      (cpu_req_valid && cpu_req_ready)
      |-> (cpu_req_addr[1:0] == 2'b00);
  endproperty

  assert property (cpu_req_word_aligned)
    else $error("[ASSERT_FAIL] CPU request address is not word-aligned");

  // ------------------------------------------------------------
  // Write requests should have at least one byte lane enabled
  // ------------------------------------------------------------

  property cpu_write_has_strobe;
    @(posedge clk) disable iff (!rst_n)
      (cpu_req_valid && cpu_req_ready && cpu_req_write)
      |-> (cpu_req_wstrb != 4'b0000);
  endproperty

  assert property (cpu_write_has_strobe)
    else $error("[ASSERT_FAIL] CPU write request has zero write strobe");

  // ------------------------------------------------------------
  // Response should not be X when valid
  // ------------------------------------------------------------

  property cpu_rsp_no_x_when_valid;
    @(posedge clk) disable iff (!rst_n)
      cpu_rsp_valid |-> (!$isunknown(cpu_rsp_rdata) && !$isunknown(cpu_rsp_error));
  endproperty

  assert property (cpu_rsp_no_x_when_valid)
    else $error("[ASSERT_FAIL] CPU response contains X while valid");

endmodule