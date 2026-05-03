module mbist_controller #(
  parameter int ADDR_WIDTH = 8,
  parameter int DATA_WIDTH = 32,
  parameter int NUM_WORDS  = 64
)(
  input  logic clk,
  input  logic rst_n,

  input  logic bist_start_i,

  output logic bist_busy_o,
  output logic bist_done_o,
  output logic bist_pass_o,
  output logic bist_fail_o,

  output logic [ADDR_WIDTH-1:0] fail_addr_o,
  output logic [DATA_WIDTH-1:0] fail_expected_o,
  output logic [DATA_WIDTH-1:0] fail_observed_o,

  output logic                  mem_we_o,
  output logic [ADDR_WIDTH-1:0] mem_addr_o,
  output logic [DATA_WIDTH-1:0] mem_wdata_o,
  input  logic [DATA_WIDTH-1:0] mem_rdata_i,

  output logic normal_access_blocked_o
);

  typedef enum logic [1:0] {
    IDLE,
    RUN,
    DONE
  } state_t;

  state_t state_q, state_d;

  logic [2:0] phase_q;
  logic [ADDR_WIDTH-1:0] addr_q;

  logic read_en;
  logic write_en;
  logic [DATA_WIDTH-1:0] expected_data;
  logic [DATA_WIDTH-1:0] write_data;
  logic count_down;

  logic last_addr;
  logic fail_set;
  logic clear_status;
  logic done_set;

  mbist_pattern_gen #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_pattern_gen (
    .phase_i         (phase_q),
    .read_en_o       (read_en),
    .write_en_o      (write_en),
    .expected_data_o (expected_data),
    .write_data_o    (write_data),
    .count_down_o    (count_down)
  );

  mbist_status_regs #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_status_regs (
    .clk              (clk),
    .rst_n            (rst_n),
    .clear_i          (clear_status),
    .done_set_i       (done_set),
    .fail_set_i       (fail_set),
    .fail_addr_i      (addr_q),
    .fail_expected_i  (expected_data),
    .fail_observed_i  (mem_rdata_i),
    .bist_done_o      (bist_done_o),
    .bist_pass_o      (bist_pass_o),
    .bist_fail_o      (bist_fail_o),
    .fail_addr_o      (fail_addr_o),
    .fail_expected_o  (fail_expected_o),
    .fail_observed_o  (fail_observed_o)
  );

  assign bist_busy_o = (state_q == RUN);
  assign normal_access_blocked_o = bist_busy_o;

  assign mem_we_o    = (state_q == RUN) && write_en;
  assign mem_addr_o  = addr_q;
  assign mem_wdata_o = write_data;

  assign last_addr =
      count_down
      ? (addr_q == '0)
      : (addr_q == ADDR_WIDTH'(NUM_WORDS-1));

  assign fail_set =
      (state_q == RUN) &&
      read_en &&
      (mem_rdata_i !== expected_data);

  assign clear_status =
      (state_q == IDLE) &&
      bist_start_i;

  assign done_set =
      (state_q == RUN) &&
      (phase_q == 3'd5) &&
      last_addr;

  always_comb begin
    state_d = state_q;

    case (state_q)

      IDLE: begin
        if (bist_start_i) begin
          state_d = RUN;
        end
      end

      RUN: begin
        if ((phase_q == 3'd5) && last_addr) begin
          state_d = DONE;
        end
      end

      DONE: begin
        if (!bist_start_i) begin
          state_d = IDLE;
        end
      end

      default: begin
        state_d = IDLE;
      end

    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= IDLE;
      phase_q <= '0;
      addr_q  <= '0;
    end else begin
      state_q <= state_d;

      if ((state_q == IDLE) && bist_start_i) begin
        phase_q <= 3'd0;
        addr_q  <= '0;
      end else if (state_q == RUN) begin

        if (last_addr) begin
          if (phase_q != 3'd5) begin
            phase_q <= phase_q + 1'b1;

            if ((phase_q + 1'b1) == 3'd3 || (phase_q + 1'b1) == 3'd4) begin
              addr_q <= ADDR_WIDTH'(NUM_WORDS-1);
            end else begin
              addr_q <= '0;
            end
          end
        end else begin
          if (count_down) begin
            addr_q <= addr_q - 1'b1;
          end else begin
            addr_q <= addr_q + 1'b1;
          end
        end

      end
    end
  end

endmodule