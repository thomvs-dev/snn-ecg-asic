# cg3 constraints. Identical to flow/constraint.sdc except the clock uncertainty,
# which is now separate for setup and hold.
# 25 MHz: 2501 cycles per input timer tick is approximately 100 us.
# Fully synchronous interface, including active-high reset: no reset false path.
create_clock -name core_clk -period 40.0 [get_ports clk]
# Setup compares two different clock edges, so it carries source jitter as well
# as skew error: 0.4 ns as before.
# Hold compares the same clock edge at launch and capture, so jitter cancels and
# only skew/modelling error remains: 0.2 ns. The clock is propagated (post-CTS),
# so real skew is already in the path delays. Earlier variants applied 0.4 ns to
# both checks.
set_clock_uncertainty -setup 0.4 [get_clocks core_clk]
set_clock_uncertainty -hold 0.2 [get_clocks core_clk]
set_clock_transition 0.2 [get_clocks core_clk]
set_input_delay -clock core_clk -max 4.0 [get_ports {reset load_valid load_data* start}]
set_input_delay -clock core_clk -min 0.5 [get_ports {reset load_valid load_data* start}]
set_input_transition 0.5 [get_ports {reset load_valid load_data* start}]
set_output_delay -clock core_clk -max 4.0 [all_outputs]
set_output_delay -clock core_clk -min 0.5 [all_outputs]
# Library capacitance unit is pF; 10 fF assumed external load per output.
set_load 0.01 [all_outputs]
