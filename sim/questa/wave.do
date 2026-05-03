vsim -voptargs=+acc work.tb_top

add wave -r sim:/tb_top/clk
add wave -r sim:/tb_top/rst_n

add wave -r sim:/tb_top/bist_start
add wave -r sim:/tb_top/bist_busy
add wave -r sim:/tb_top/bist_done
add wave -r sim:/tb_top/bist_pass
add wave -r sim:/tb_top/bist_fail

add wave -r sim:/tb_top/fail_addr
add wave -r sim:/tb_top/fail_expected
add wave -r sim:/tb_top/fail_observed

add wave -r sim:/tb_top/mbist_mem_we
add wave -r sim:/tb_top/mbist_mem_addr
add wave -r sim:/tb_top/mbist_mem_wdata
add wave -r sim:/tb_top/mbist_mem_rdata

add wave -r sim:/tb_top/normal_access_blocked
add wave -r sim:/tb_top/normal_ready

add wave -r sim:/tb_top/fault_enable
add wave -r sim:/tb_top/fault_addr
add wave -r sim:/tb_top/fault_mask

add wave -r sim:/tb_top/u_mbist_controller/state_q
add wave -r sim:/tb_top/u_mbist_controller/phase_q
add wave -r sim:/tb_top/u_mbist_controller/addr_q
add wave -r sim:/tb_top/u_mbist_controller/read_en
add wave -r sim:/tb_top/u_mbist_controller/write_en
add wave -r sim:/tb_top/u_mbist_controller/expected_data
add wave -r sim:/tb_top/u_mbist_controller/write_data
add wave -r sim:/tb_top/u_mbist_controller/count_down
add wave -r sim:/tb_top/u_mbist_controller/fail_set

run -all