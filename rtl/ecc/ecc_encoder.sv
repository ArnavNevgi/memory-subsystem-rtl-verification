module ecc_encoder #(
  parameter int DATA_WIDTH = 32,
  parameter int ECC_WIDTH  = 7
)(
  input  logic [DATA_WIDTH-1:0] data_i,
  output logic [ECC_WIDTH-1:0]  ecc_o
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

  always_comb begin
    int data_idx;
    int parity_pos;

    code_no_overall = '0;
    data_idx = 0;

    for (int pos = 1; pos <= 38; pos++) begin
      if (!is_power_of_two(pos)) begin
        code_no_overall[pos-1] = data_i[data_idx];
        data_idx++;
      end
    end

    for (int p = 0; p < 6; p++) begin
      parity_pos = 1 << p;
      code_no_overall[parity_pos-1] = 1'b0;

      for (int pos = 1; pos <= 38; pos++) begin
        if ((pos & parity_pos) != 0) begin
          code_no_overall[parity_pos-1] ^= code_no_overall[pos-1];
        end
      end
    end

    ecc_o[5:0] = {
      code_no_overall[31],
      code_no_overall[15],
      code_no_overall[7],
      code_no_overall[3],
      code_no_overall[1],
      code_no_overall[0]
    };

    ecc_o[6] = ^code_no_overall;
  end

endmodule