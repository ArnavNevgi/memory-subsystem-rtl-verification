module mbist_memory_array #(
  parameter int ADDR_WIDTH = 8,
  parameter int DATA_WIDTH = 32,
  parameter int NUM_WORDS  = 64
)(
  input  logic clk,
  input  logic rst_n,

  input  logic                  bist_active_i,
  input  logic                  bist_we_i,
  input  logic [ADDR_WIDTH-1:0] bist_addr_i,
  input  logic [DATA_WIDTH-1:0] bist_wdata_i,
  output logic [DATA_WIDTH-1:0] bist_rdata_o,

  input  logic                  normal_en_i,
  input  logic                  normal_we_i,
  input  logic [ADDR_WIDTH-1:0] normal_addr_i,
  input  logic [DATA_WIDTH-1:0] normal_wdata_i,
  output logic [DATA_WIDTH-1:0] normal_rdata_o,
  output logic                  normal_ready_o,

  input  logic                  fault_enable_i,
  input  logic [ADDR_WIDTH-1:0] fault_addr_i,
  input  logic [DATA_WIDTH-1:0] fault_mask_i
);

  logic [DATA_WIDTH-1:0] mem [0:NUM_WORDS-1];

  assign normal_ready_o = !bist_active_i;

  always_comb begin
    bist_rdata_o = mem[bist_addr_i];

    if (fault_enable_i && (bist_addr_i == fault_addr_i)) begin
      bist_rdata_o = mem[bist_addr_i] ^ fault_mask_i;
    end
  end

  always_comb begin
    normal_rdata_o = mem[normal_addr_i];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_WORDS; i++) begin
        mem[i] <= '0;
      end
    end else begin

      if (bist_active_i) begin
        if (bist_we_i) begin
          mem[bist_addr_i] <= bist_wdata_i;
        end
      end else begin
        if (normal_en_i && normal_we_i) begin
          mem[normal_addr_i] <= normal_wdata_i;
        end
      end

    end
  end

endmodule