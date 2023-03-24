proc AXI_IP_SYSTEM_ILA {params} {
    # required values
    set_required_values $params {device_name axi_clk axi_rstn}
    set_required_values $params {slots} False

    # optional values
    set_optional_values $params [dict create scatter_gather 0]; #0 off, 1 on

    
    #createIP
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == system_ila}] $device_name

    #scatter gather options
    set_property CONFIG.C_INCLUDE_SG $scatter_gather [get_bd_cells ${device_name}]
    
    set slot_count 0
    dict for {slot info} $slots {
	set current_slot ${slot_count}
	incr slot_count
	set_property CONFIG.C_NUM_MONITOR_SLOTS $slot_count  [get_bd_cells ${device_name}]
	dict with info {
	    #connect the AXI bus to monitor
	    connect_bd_intf_net [get_bd_intf_pins $axi_bus] -boundary_type upper [get_bd_intf_pins ${device_name}/SLOT_${current_slot}_AXI]
	}
    }

    #connect up clocks and resets
    connect_bd_net -quiet [get_bd_pins $axi_clk]                         [get_bd_pins ${device_name}/clk]
    connect_bd_net -quiet [get_bd_pins $axi_rstn]                        [get_bd_pins ${device_name}/resetn]    

	
}
