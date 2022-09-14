proc AXI_IP_AXI_FW {params} {

    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {axi_fw_bus}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 4k} remote_slave 0]


    # $axi_fw_bus is the master of the line we want to put a firewall in
    # Get the slave that the master is currently connected to. 
    set get_slave_cmd "get_bd_intf_pins -of_objects \[get_bd_intf_nets -of_objects \[get_bd_intf_pins ${axi_fw_bus} \]\] -filter {MODE == Slave}"
    set get_master_cmd "get_bd_intf_pins -of_objects \[get_bd_intf_nets -of_objects \[get_bd_intf_pins ${axi_fw_bus} \]\] -filter {MODE == Master}"
    set slave_interface [eval ${get_slave_cmd}]
    set master_interface [eval ${get_master_cmd}]

    puts $slave_interface
    puts $master_interface
    
    #delete the net connection
    delete_bd_objs [get_bd_intf_nets -of_objects [get_bd_intf_pins ${axi_fw_bus}]]
    
    #create the AXI FW IP
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_firewall }] ${device_name}
    
    #connect the master to the new slave on the AXI FW
    connect_bd_intf_net [get_bd_intf_pins $device_name/S_AXI] -boundary_type upper [get_bd_intf_pins $master_interface]
    #connect the AXI fw to the slave
    connect_bd_intf_net ${slave_interface} -boundary_type upper [get_bd_intf_pins $device_name/M_AXI]
    
#    [AXI_CTL_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $addr_offset $addr_range $remote_slave]    
    [AXI_CTL_DEV_CONNECT $params]    
#    [AXI_DEV_UIO_DTSI_POST_CHUNK ${device_name}]
}
