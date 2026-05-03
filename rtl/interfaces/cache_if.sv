interface cache_if #(
  parameter int ADDR_WIDTH = cache_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = cache_pkg::DATA_WIDTH,
  parameter int STRB_WIDTH = cache_pkg::STRB_WIDTH
)(
  input logic clk,
  input logic rst_n
);

  import cache_pkg::*;

  // ------------------------------------------------------------
  // Request channel
  // ------------------------------------------------------------

  logic                  req_valid;
  logic                  req_ready;
  logic                  req_write;
  logic [ADDR_WIDTH-1:0] req_addr;
  logic [DATA_WIDTH-1:0] req_wdata;
  logic [STRB_WIDTH-1:0] req_wstrb;

  // ------------------------------------------------------------
  // Response channel
  // ------------------------------------------------------------

  logic                  rsp_valid;
  logic                  rsp_ready;
  logic [DATA_WIDTH-1:0] rsp_rdata;
  logic                  rsp_error;

  // ------------------------------------------------------------
  // Master modport: used by CPU/test generator
  // ------------------------------------------------------------

  modport master (
    input  clk,
    input  rst_n,

    output req_valid,
    input  req_ready,
    output req_write,
    output req_addr,
    output req_wdata,
    output req_wstrb,

    input  rsp_valid,
    output rsp_ready,
    input  rsp_rdata,
    input  rsp_error
  );

  // ------------------------------------------------------------
  // Slave modport: used by memory/cache block
  // ------------------------------------------------------------

  modport slave (
    input  clk,
    input  rst_n,

    input  req_valid,
    output req_ready,
    input  req_write,
    input  req_addr,
    input  req_wdata,
    input  req_wstrb,

    output rsp_valid,
    input  rsp_ready,
    output rsp_rdata,
    output rsp_error
  );

endinterface