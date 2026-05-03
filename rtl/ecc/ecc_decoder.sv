module ecc_decoder #(
  parameter int DATA_WIDTH = 32,
  parameter int ECC_WIDTH  = 7
)(
  input  logic [DATA_WIDTH-1:0] data_i,
  input  logic [ECC_WIDTH-1:0]  ecc_i,

  output logic [DATA_WIDTH-1:0] data_o,
  output logic                  corrected_o,
  output logic                  uncorrectable_o
);

  function automatic bit is_power_of_two(input int value);
    return (value == 1)  ||
           (value == 2)  ||
           (value == 4)  ||
           (value == 8)  ||
           (value == 16) ||
           (value == 32);
  endfunction

  logic [37:0] code_no_overall;
  logic [37:0] corrected_code;
  logic [5:0]  syndrome;
  logic        overall_error;

  always_comb begin
    int data_idx;
    int parity_pos;

    code_no_overall = '0;
    corrected_code  = '0;
    syndrome        = '0;
    data_o          = '0;

    data_idx = 0;

    for (int pos = 1; pos <= 38; pos++) begin
      if (!is_power_of_two(pos)) begin
        code_no_overall[pos-1] = data_i[data_idx];
        data_idx++;
      end
    end

    code_no_overall[0]  = ecc_i[0];
    code_no_overall[1]  = ecc_i[1];
    code_no_overall[3]  = ecc_i[2];
    code_no_overall[7]  = ecc_i[3];
    code_no_overall[15] = ecc_i[4];
    code_no_overall[31] = ecc_i[5];

    for (int p = 0; p < 6; p++) begin
      parity_pos = 1 << p;

      for (int pos = 1; pos <= 38; pos++) begin
        if ((pos & parity_pos) != 0) begin
          syndrome[p] ^= code_no_overall[pos-1];
        end
      end
    end

    overall_error = (^code_no_overall) ^ ecc_i[6];

    corrected_code  = code_no_overall;
    corrected_o     = 1'b0;
    uncorrectable_o = 1'b0;

    if ((syndrome != 0) && overall_error) begin
      corrected_o = 1'b1;

      if (syndrome <= 38) begin
        corrected_code[syndrome-1] = ~corrected_code[syndrome-1];
      end

    end else if ((syndrome == 0) && overall_error) begin
      corrected_o = 1'b1;

    end else if ((syndrome != 0) && !overall_error) begin
      uncorrectable_o = 1'b1;
    end

    data_idx = 0;

    for (int pos = 1; pos <= 38; pos++) begin
      if (!is_power_of_two(pos)) begin
        data_o[data_idx] = corrected_code[pos-1];
        data_idx++;
      end
    end
  end

endmodule