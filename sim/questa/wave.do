vsim -voptargs=+acc work.tb_top

add wave -r sim:/tb_top/clk
add wave -r sim:/tb_top/rst_n

add wave -r sim:/tb_top/cpu_bus/*
add wave -r sim:/tb_top/mem_bus/*

add wave -r sim:/tb_top/u_cache/state_q
add wave -r sim:/tb_top/u_cache/addr_q
add wave -r sim:/tb_top/u_cache/write_q

add wave -r sim:/tb_top/u_cache/req_index
add wave -r sim:/tb_top/u_cache/req_tag
add wave -r sim:/tb_top/u_cache/req_word_offset

add wave -r sim:/tb_top/u_cache/way0_hit
add wave -r sim:/tb_top/u_cache/way1_hit
add wave -r sim:/tb_top/u_cache/cache_hit
add wave -r sim:/tb_top/u_cache/hit_way
add wave -r sim:/tb_top/u_cache/replace_way_q

add wave -r sim:/tb_top/u_cache/ecc_corrected_q
add wave -r sim:/tb_top/u_cache/ecc_uncorrectable_q
add wave -r sim:/tb_top/u_cache/rsp_data_q
add wave -r sim:/tb_top/u_cache/rsp_error_q

add wave -r sim:/tb_top/pass_count
add wave -r sim:/tb_top/fail_count
add wave -r sim:/tb_top/random_count

run -all