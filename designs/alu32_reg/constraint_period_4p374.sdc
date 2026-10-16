create_clock -name clk -period 4.374 [get_ports clk]
set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] [get_ports clk]]
set_input_delay 0.0 -clock clk $non_clock_inputs
set_output_delay 0.0 -clock clk [all_outputs]
