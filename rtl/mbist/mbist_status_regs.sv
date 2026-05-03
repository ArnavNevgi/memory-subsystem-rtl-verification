module mbist_status_regs #(
  parameter int ADDR_WIDTH = 8,
  parameter int DATA_WIDTH = 32
)(
  input  logic clk,
  input  logic rst_n,

  input  logic                  clear_i,
  input  logic                  done_set_i,
  input  logic                  fail_set_i,
  input  logic [ADDR_WIDTH-1:0] fail_addr_i,
  input  logic [DATA_WIDTH-1:0] fail_expected_i,
  input  logic [DATA_WIDTH-1:0] fail_observed_i,

  output logic                  bist_done_o,
  output logic                  bist_pass_o,
  output logic                  bist_fail_o,
  output logic [ADDR_WIDTH-1:0] fail_addr_o,
  output logic [DATA_WIDTH-1:0] fail_expected_o,
  output logic [DATA_WIDTH-1:0] fail_observed_o
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bist_done_o      <= 1'b0;
      bist_pass_o      <= 1'b0;
      bist_fail_o      <= 1'b0;
      fail_addr_o      <= '0;
      fail_expected_o  <= '0;
      fail_observed_o  <= '0;
    end else begin

      if (clear_i) begin
        bist_done_o      <= 1'b0;
        bist_pass_o      <= 1'b0;
        bist_fail_o      <= 1'b0;
        fail_addr_o      <= '0;
        fail_expected_o  <= '0;
        fail_observed_o  <= '0;
      end else begin

        if (fail_set_i && !bist_fail_o) begin
          bist_fail_o      <= 1'b1;
          fail_addr_o      <= fail_addr_i;
          fail_expected_o  <= fail_expected_i;
          fail_observed_o  <= fail_observed_i;
        end

        if (done_set_i) begin
          bist_done_o <= 1'b1;
          bist_pass_o <= !(bist_fail_o || fail_set_i);
        end

      end
    end
  end

endmodule