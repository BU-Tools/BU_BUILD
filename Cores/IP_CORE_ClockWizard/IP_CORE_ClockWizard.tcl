## proc \c IP_CORE_ClockWizard
# Arguments:
#   \param params a dictionary of parameters for this core
#   - \b device_name Name for this IP Core
#   - \b in_clk_type Type of input clock (Differential_clock_capable_pin or others in Xilinx doc)
#   - \b in_clk_freq_MHZ Frequency of input clock in MHz
#   - \b out_clks A dictionary of output clocks to make
#     - \b N : \b freq A list of numbered entries 1-N for each output with an associated frequency
#   - \b config_options a dictionary of additional parameters to set
#     - \b PARAM_NAME : \b PARAM_VALUE pairs of parameters and values to set them to
#
# This creates a Xilinx ClockWizard IP core with an input clock and N output clocks
# The input clock's name, with frequency XX.ABCD will be named device_name_XX_ABCD_Mhz.
# The output clock's name, with freqncy YY.ABCD will be named clk_YY_ABCD_MHZ
# ABCD can be as long as Vivado allows
proc IP_CORE_ClockWizard {params} {
    global build_name
    global apollo_root_path
    global autogen_path

    set_required_values $params {device_name}
    set_required_values $params {in_clk_type}
    set_required_values $params {in_clk_freq_MHZ}
    set_required_values $params {out_clks} False

    
    #build the core
    BuildCore $device_name clk_wiz


    #start a list of properties
    dict create property_list {}

    #add parameters
    dict append property_list CONFIG.PRIM_SOURCE             ${in_clk_type}
    dict append property_list CONFIG.PRIM_IN_FREQ            ${in_clk_freq_MHZ}
    dict append property_list CONFIG.PRIMARY_PORT            ${device_name}_[string map {"." "_"} ${in_clk_freq_MHZ}]MHz

    #====================================
    #Parse the output clocks
    #====================================
    #set the count of clks
    set clk_count 0
    #build each clk
    dict for {clk settings} $out_clks {
	#set the probe count to the max in the list
	if { $clk > $clk_count } {	    
	    set clk_count $clk
	}
	if {$clk == 0} {
	    error "clk == 0 is not allowed, numbering starts at 1"
	}
	
	if { ! [is_dict $settings] } {
	    #set out clock name (settings as it is the only value)
	    dict append property_list CONFIG.CLK_OUT${clk}_PORT clk_[string map {"." "_"} ${settings}]MHz
	    #set out clock frequency
	    dict append property_list CONFIG.CLKOUT${clk}_REQUESTED_OUT_FREQ ${settings}
	} else {
	    #this is a dictionary, so parse things differently

	    #get the frequency
	    if { [dict exists $settings "freq" ] } {
		#set out clock name
		set clk_freq [dict get $settings "freq"]
		dict append property_list CONFIG.CLK_OUT${clk}_PORT clk_[string map {"." "_"} ${clk_freq}]MHz
		dict append property_list CONFIG.CLKOUT${clk}_REQUESTED_OUT_FREQ ${clk_freq}
	    } else {
		error "clk $clk is missing the frequency"
	    }

	    #get any options
	    if { [dict exists $settings "options" ] } {
		dict for {option value} [dict get $settings "options"] {
		    dict append property_list CONFIG.CLKOUT${clk}_${option} $value
		}
	    }
	}	

	#set the clock to be used (clk 1 is assumed used)
	if {$clk > 1} {
	    dict append property_list CONFIG.CLKOUT${clk}_USED true
	}
    }

    dict append property_list CONFIG.NUM_OUT_CLKS $clk_count

    #====================================
    #Parse the config options
    #====================================
    if { [dict exists $params config_options] } {
	dict for {param value} [dict get $params config_options] {
	    puts "Clock Wizard: $param $value"
	    dict append property_list CONFIG.${param} ${value}
	}
    }

    puts "propery list: $property_list"
    
    #apply all the properties to the IP Core
    set_property -dict $property_list [get_ips ${device_name}]
    generate_target -force {all} [get_ips ${device_name}]
    synth_ip [get_ips ${device_name}]
    
}
