#======================================================
#
# PrimeTime  Scripts (dctcl mode)
#
#======================================================
source synopsys_pt.setup
#======================================================
#  1. Set the Power Analysis Mode
#======================================================

set power_enable_analysis true
set power_analysis_mode time_based
set power_report_leakage_breakdowns true
set power_clock_network_include_register_clock_pin_power false

#======================================================
#  2. Read and link the design
#======================================================

set DESIGN "IOTDF"
current_design $DESIGN

read_verilog "./Netlist/IOTDF_syn.v"
link

#======================================================
#  3. Set transition time / annotate parasitics
#======================================================
set_input_transition .1 [all_inputs]
read_sdc  "/home/rain/IC_contest/iot_data_final2019/icc2019cb/Netlist/IOTDF_syn.sdc"
read_sdf -load_delay net "/home/rain/IC_contest/iot_data_final2019/icc2019cb/Netlist/IOTDF_syn.sdf"

#======================================================
#  4. Read Switching Activity File
#======================================================
read_fsdb -strip_path testfixture/u_$DESIGN ./FSDB/$DESIGN\_F1.fsdb

#======================================================
#  5. Perform power analysis
#======================================================
check_power
update_power

#======================================================
#  6. Generate Power Report
#======================================================
# BUG command 

set_power_analysis_options -waveform_interval 1 -waveform_format out -waveform_output vcd
# vcd.out
report_power >  ./Report/$DESIGN\_POWER
 

exit
