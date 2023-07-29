proc IP_CORE_ILA {params} {
    global build_name
    global apollo_root_path
    global autogen_path

    set_required_values $params {device_name}
    set_required_values $params {probes} False
    set_optional_values $params [dict create EN_STRG_QUAL 1  ADV_TRIGGER false ALL_PROBE_SAME_MU_CNT 2 ENABLE_ILA_AXI_MON false MONITOR_TYPE Native ]

    #build the core
    BuildCore $device_name ila


    #start a list of properties
    dict create property_list {}

    #add parameters
    dict append property_list CONFIG.C_EN_STRG_QUAL          $EN_STRG_QUAL
    dict append property_list CONFIG.C_ADV_TRIGGER           $ADV_TRIGGER
    dict append property_list CONFIG.ALL_PROBE_SAME_MU_CNT   $ALL_PROBE_SAME_MU_CNT
    dict append property_list CONFIG.C_ENABLE_ILA_AXI_MON    $ENABLE_ILA_AXI_MON
    dict append property_list CONFIG.C_MONITOR_TYPE          $MONITOR_TYPE

    #====================================
    #Parse the probes.
    #====================================
    #set the count of probes
    set probe_count 0
    #build each probe
    dict for {probe probe_info} $probes {
	#set the probe count to the max in the list
	if { $probe > $probe_count } {	    
	    set probe_count $probe
	}
	dict for {key value} $probe_info {
	    if {$key == "TYPE"} {
                # type is 0: data & trigger, 1 data only, 2 trigger only
		dict append property_list CONFIG.C_PROBE${probe}_TYPE $value
	    } elseif {$key == "WIDTH"} {		
		dict append property_list CONFIG.C_PROBE${probe}_WIDTH $value
	    } elseif {$key == "MU_CNT"} {		
		dict append property_list CONFIG.C_PROBE${probe}_MU_CNT $value
	    }
	}
    }
    #probes start from 0, so add 1
    set probe_count [expr $probe_count + 1]

    dict append property_list CONFIG.C_NUM_OF_PROBES $probe_count
    
    #apply all the properties to the IP Core
    set_property -dict $property_list [get_ips ${device_name}]
    generate_target -force {all} [get_ips ${device_name}]
    synth_ip [get_ips ${device_name}]
    
}

