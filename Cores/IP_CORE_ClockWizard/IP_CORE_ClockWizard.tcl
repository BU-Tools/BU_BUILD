
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
    #set the count of probes
    set clk_count 0
    #build each probe
    dict for {clk clk_freq} $out_clks {
	#set the probe count to the max in the list
	if { $clk > $clk_count } {	    
	    set clk_count $clk
	}
	if {$clk == 0} {
	    error "clk == 0 is not allowed, numbering starts at 1"
	}

	#set out clock name
	dict append property_list CONFIG.CLK_OUT${clk}_PORT clk_[string map {"." "_"} ${clk_freq}]MHz
	#set out clock frequency
	dict append property_list CONFIG.CLKOUT${clk}_REQUESTED_OUT_FREQ ${clk_freq}

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
