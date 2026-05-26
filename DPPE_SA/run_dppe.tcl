# 1. files to compile
read_verilog -sv ./DPPE_SA/DP2.sv

# 2. Run Synthesis 
synth_design -top DP -part xc7a35tcpg236-1

# 3. gates/FFs report
report_utilization -file utilization_report.txt

# 4. timing report
report_timing_summary -file timing_report.txt

exit