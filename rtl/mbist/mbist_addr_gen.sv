module mbist_addr_gen #(
  parameter int ADDR_WIDTH = 8,
  parameter int NUM_WORDS  = 64
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  load_i,
  input  logic                  enable_i,
  input  logic                  count_down_i,

  output logic [ADDR_WIDTH-1:0] addr_o,
  output logic                  last_addr_o
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      addr_o <= '0;
    end else begin
      if (load_i) begin
        if (count_down_i) begin
          addr_o <= ADDR_WIDTH'(NUM_WORDS-1);
        end else begin
          addr_o <= '0;
        end
      end else if (enable_i) begin
        if (count_down_i) begin
          addr_o <= addr_o - 1'b1;
        end else begin
          addr_o <= addr_o + 1'b1;
        end
      end
    end
  end

  assign last_addr_o =
      count_down_i
      ? (addr_o == '0)
      : (addr_o == ADDR_WIDTH'(NUM_WORDS-1));

endmodule