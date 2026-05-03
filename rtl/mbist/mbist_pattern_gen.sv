module mbist_pattern_gen #(
  parameter int DATA_WIDTH = 32
)(
  input  logic [2:0] phase_i,

  output logic                  read_en_o,
  output logic                  write_en_o,
  output logic [DATA_WIDTH-1:0] expected_data_o,
  output logic [DATA_WIDTH-1:0] write_data_o,
  output logic                  count_down_o
);

  always_comb begin
    read_en_o        = 1'b0;
    write_en_o       = 1'b0;
    expected_data_o  = '0;
    write_data_o     = '0;
    count_down_o     = 1'b0;

    case (phase_i)

      // 1. ↑ write 0
      3'd0: begin
        read_en_o    = 1'b0;
        write_en_o   = 1'b1;
        write_data_o = '0;
        count_down_o = 1'b0;
      end

      // 2. ↑ read 0, write 1
      3'd1: begin
        read_en_o       = 1'b1;
        write_en_o      = 1'b1;
        expected_data_o = '0;
        write_data_o    = {DATA_WIDTH{1'b1}};
        count_down_o    = 1'b0;
      end

      // 3. ↑ read 1, write 0
      3'd2: begin
        read_en_o       = 1'b1;
        write_en_o      = 1'b1;
        expected_data_o = {DATA_WIDTH{1'b1}};
        write_data_o    = '0;
        count_down_o    = 1'b0;
      end

      // 4. ↓ read 0, write 1
      3'd3: begin
        read_en_o       = 1'b1;
        write_en_o      = 1'b1;
        expected_data_o = '0;
        write_data_o    = {DATA_WIDTH{1'b1}};
        count_down_o    = 1'b1;
      end

      // 5. ↓ read 1, write 0
      3'd4: begin
        read_en_o       = 1'b1;
        write_en_o      = 1'b1;
        expected_data_o = {DATA_WIDTH{1'b1}};
        write_data_o    = '0;
        count_down_o    = 1'b1;
      end

      // 6. ↑ read 0
      3'd5: begin
        read_en_o       = 1'b1;
        write_en_o      = 1'b0;
        expected_data_o = '0;
        write_data_o    = '0;
        count_down_o    = 1'b0;
      end

      default: begin
        read_en_o        = 1'b0;
        write_en_o       = 1'b0;
        expected_data_o  = '0;
        write_data_o     = '0;
        count_down_o     = 1'b0;
      end

    endcase
  end

endmodule