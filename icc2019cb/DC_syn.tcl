# Read all Files
source synopsys_dc.setup
read_verilog IOTDF.v
current_design IOTDF
link

# Setting Clock Constraits
source -echo -verbose IOTDF_DC.sdc

# Synthesis all design
compile_ultra

write -format ddc  -hierarchy -output "./Netlist/IOTDF_syn.ddc"
write_sdf ./Netlist/IOTDF_syn.sdf
write_sdc Netlist/IOTDF_syn.sdc
write_file -format verilog -hierarchy -output ./Netlist/IOTDF_syn.v
report_area > ./Report/area.log
report_timing > ./Report/timing.log
report_qor > ./Report/IOTDF_syn.qor

#======================================================
#  Finish and Quit
#======================================================
exit

