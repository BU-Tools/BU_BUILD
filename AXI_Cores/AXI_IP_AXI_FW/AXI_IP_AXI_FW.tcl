proc AXI_IP_AXI_FW {params} {

    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {axi_fw_bus}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 4k} remote_slave 0]
    set_optional_values $params [dict create wait_shift 0]

    # $axi_fw_bus is the master of the line we want to put a firewall in
    # Get the slave that the master is currently connected to. 
    set get_slave_cmd "get_bd_intf_pins -of_objects \[get_bd_intf_nets -of_objects \[get_bd_intf_pins ${axi_fw_bus} \]\] -filter {MODE == Slave}"
    set get_slave_cmd_fallback "get_bd_intf_pins -of_objects \[get_bd_intf_nets -of_objects \[get_bd_intf_ports ${axi_fw_bus} \]\] -filter {MODE == Slave}"
    set get_master_cmd "get_bd_intf_pins -of_objects \[get_bd_intf_nets -of_objects \[get_bd_intf_pins ${axi_fw_bus} \]\] -filter {MODE == Master}"
    set get_master_cmd_fallback "get_bd_intf_ports -of_objects \[get_bd_intf_nets -of_objects \[get_bd_intf_ports ${axi_fw_bus} \]\]"

    set slave_interface [eval ${get_slave_cmd}]
    if { [llength $slave_interface] == 0} {
	#Didn't find any results, it is possible this is due to vivado thining this is a port, not a pin
	#retry with port (fallback query)
	set slave_interface [eval ${get_slave_cmd_fallback}]
    }
    set master_interface [eval ${get_master_cmd}]
    if { [llength $master_interface] == 0} {
	#Didn't find any results, it is possible this is due to vivado thining this is a port, not a pin
	#retry with port (fallback query)
	set master_interface [eval ${get_master_cmd_fallback}]
    }

    puts $slave_interface
    puts $master_interface
    
    #delete the net connection
    if { [llength [get_bd_intf_nets -of_objects [get_bd_intf_pins ${axi_fw_bus}]]] != 0 } {
	delete_bd_objs [get_bd_intf_nets -of_objects [get_bd_intf_pins ${axi_fw_bus}]]
    } else {
	delete_bd_objs [get_bd_intf_nets -of_objects [get_bd_intf_ports ${axi_fw_bus}]]
    }
    
    #create the AXI FW IP
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_firewall }] ${device_name}
    
    #connect the master to the new slave on the AXI FW
    connect_bd_intf_net [get_bd_intf_pins $device_name/S_AXI] -boundary_type upper $master_interface
    #connect the AXI fw to the slave
    connect_bd_intf_net ${slave_interface} -boundary_type upper [get_bd_intf_pins $device_name/M_AXI]


    #shift the default wait (0xFFFF) down by wait_shift bits
    #this does not work yet because when this is applied, the primitives have already been selected.
    #I am working on deleting the FDSE pirmitive with a FDRE primitive that will switch the reset value.
    if { $wait_shift > 0} {
	global post_synth_commands
	set lower_bound [expr {15-$wait_shift}]
	for {set bit 15} {$bit > $lower_bound} {incr bit -1} {
	    #build a command to change the bit'th bit of each wait time register's default value for this axi fw
	    set blah [format "foreach cell \[get_cells -hierarchical -regexp .*%s.*WAIT.*_reg\\\\\[%s\\\\\] -filter {REF_NAME == FDSE}\] { puts \${cell} ; puts \[get_property INIT \${cell}\]; set_property INIT 1'b0 \${cell}; puts \[get_property INIT \${cell}\]; puts \"\\\\n\\\\n\\\\n\\\\n\"} " ${device_name} ${bit}]
	    lappend post_synth_commands $blah
	    
	}
    }

    


    
    AXI_CTL_DEV_CONNECT $params
}
