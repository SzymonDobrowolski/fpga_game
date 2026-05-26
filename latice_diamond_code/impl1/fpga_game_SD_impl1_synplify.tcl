#-- Lattice Semiconductor Corporation Ltd.
#-- Synplify OEM project file

#device options
set_option -technology MACHXO2
set_option -part LCMXO2_4000HC
set_option -package TG144C
set_option -speed_grade -5

#compilation/mapping options
set_option -symbolic_fsm_compiler true
set_option -resource_sharing true

#use verilog 2001 standard option
set_option -vlog_std v2001

#map options
set_option -frequency 100
set_option -maxfan 1000
set_option -auto_constrain_io 0
set_option -disable_io_insertion false
set_option -retiming false; set_option -pipe true
set_option -force_gsr false
set_option -compiler_compatible 0
set_option -dup false

set_option -default_enum_encoding default

#simulation options


#timing analysis options



#automatic place and route (vendor) options
set_option -write_apr_constraint 1

#synplifyPro options
set_option -fix_gated_and_generated_clocks 1
set_option -update_models_cp 0
set_option -resolve_multiple_driver 0


set_option -seqshift_no_replicate 0

#-- add_file options
set_option -include_path {C:/Users/Rafal/Desktop/szymon_to_fpga}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/clk_divider.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/ddr.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/delay.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/dev_i2c_phy.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/dev_i2c_phy_bit.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/dev_i2c_phy_scaler.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/hdmi_i2c_cfg.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/pll_75mhz.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/pong_main.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/pong_top.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/rect_painter.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/uart_rx.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/uart_tx.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/vga_sync_gen.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/vo_phy_ddr.v}
add_file -verilog -vlog_std v2001 {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/source/pll_50_to_40Mhz_0_90_180.v}

#-- top module name
set_option -top_module top

#-- set result format/file last
project -result_file {C:/Users/Rafal/Desktop/szymon_to_fpga/impl1/fpga_game_SD_impl1.edi}

#-- error message log file
project -log_file {fpga_game_SD_impl1.srf}

#-- set any command lines input by customer


#-- run Synplify with 'arrange HDL file'
project -run -clean
