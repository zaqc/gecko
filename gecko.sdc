## Generated SDC file "gecko.sdc"

## Copyright (C) 1991-2014 Altera Corporation
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, Altera MegaCore Function License 
## Agreement, or other applicable license agreement, including, 
## without limitation, that your use is for the sole purpose of 
## programming logic devices manufactured by Altera and sold by 
## Altera or its authorized distributors.  Please refer to the 
## applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus II"
## VERSION "Version 13.1.4 Build 182 03/12/2014 SJ Web Edition"

## DATE    "Tue Aug 13 19:01:11 2024"

##
## DEVICE  "EP4CE6E22I7"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {clk50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk50}]
create_clock -name {esp_clk} -period 1.000 -waveform { 0.000 0.500 } [get_ports {esp_clk}]


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {Main_pll_unit|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 1 -divide_by 2 -master_clock {clk50} [get_pins {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {esp_clk}] -rise_to [get_clocks {esp_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {esp_clk}] -fall_to [get_clocks {esp_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {esp_clk}] -rise_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {esp_clk}] -rise_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.110  
set_clock_uncertainty -rise_from [get_clocks {esp_clk}] -fall_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {esp_clk}] -fall_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.110  
set_clock_uncertainty -fall_from [get_clocks {esp_clk}] -rise_to [get_clocks {esp_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {esp_clk}] -fall_to [get_clocks {esp_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {esp_clk}] -rise_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {esp_clk}] -rise_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.110  
set_clock_uncertainty -fall_from [get_clocks {esp_clk}] -fall_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {esp_clk}] -fall_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.110  
set_clock_uncertainty -rise_from [get_clocks {clk50}] -rise_to [get_clocks {clk50}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk50}] -fall_to [get_clocks {clk50}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk50}] -rise_to [get_clocks {clk50}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk50}] -fall_to [get_clocks {clk50}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {Main_pll_unit|altpll_component|auto_generated|pll1|clk[0]}]  0.020  


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

