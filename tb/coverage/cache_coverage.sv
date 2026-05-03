class cache_coverage;

  bit        write;
  bit [31:0] addr;
  bit [3:0]  wstrb;
  bit        rsp_error;
  bit        cache_hit;
  bit        way0_hit;
  bit        way1_hit;
  bit        ecc_corrected;
  bit        ecc_uncorrectable;

  covergroup cg;

    option.per_instance = 1;

    cp_access_type: coverpoint write {
      bins read  = {0};
      bins write = {1};
    }

    cp_addr_region: coverpoint addr[9:4] {
      bins low_region[] = {[0:15]};
      bins mid_region[] = {[16:31]};
      bins high_region[] = {[32:63]};
    }

    cp_wstrb: coverpoint wstrb {
      bins full_word = {4'hF};
      bins lower_byte = {4'h1};
      bins upper_byte = {4'h8};
      bins half_low = {4'h3};
      bins half_high = {4'hC};
      bins other[] = {[1:14]};
    }

    cp_rsp_error: coverpoint rsp_error {
      bins no_error = {0};
      bins error    = {1};
    }

    cp_cache_hit: coverpoint cache_hit {
      bins miss = {0};
      bins hit  = {1};
    }

    cp_way0_hit: coverpoint way0_hit {
      bins no = {0};
      bins yes = {1};
    }

    cp_way1_hit: coverpoint way1_hit {
      bins no = {0};
      bins yes = {1};
    }

    cp_ecc_corrected: coverpoint ecc_corrected {
      bins no = {0};
      bins yes = {1};
    }

    cp_ecc_uncorrectable: coverpoint ecc_uncorrectable {
      bins no = {0};
      bins yes = {1};
    }

    cross_access_hit: cross cp_access_type, cp_cache_hit;
    cross_way_hits: cross cp_way0_hit, cp_way1_hit {
    ignore_bins both_ways_hit = binsof(cp_way0_hit.yes) && binsof(cp_way1_hit.yes);
}
    cross_ecc_status: cross cp_ecc_corrected, cp_ecc_uncorrectable;

  endgroup

  function new();
    cg = new();
  endfunction

  function void sample(
    input bit        write_i,
    input bit [31:0] addr_i,
    input bit [3:0]  wstrb_i,
    input bit        rsp_error_i,
    input bit        cache_hit_i,
    input bit        way0_hit_i,
    input bit        way1_hit_i,
    input bit        ecc_corrected_i,
    input bit        ecc_uncorrectable_i
  );
    write             = write_i;
    addr              = addr_i;
    wstrb             = wstrb_i;
    rsp_error         = rsp_error_i;
    cache_hit         = cache_hit_i;
    way0_hit          = way0_hit_i;
    way1_hit          = way1_hit_i;
    ecc_corrected     = ecc_corrected_i;
    ecc_uncorrectable = ecc_uncorrectable_i;

    cg.sample();
  endfunction

  function real get_coverage();
    return cg.get_coverage();
  endfunction

endclass