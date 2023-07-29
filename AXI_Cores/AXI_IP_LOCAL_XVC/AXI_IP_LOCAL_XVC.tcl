

proc AXI_IP_LOCAL_XVC {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 4k} remote_slave 0]

    #Create a xilinx axi debug bridge
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == debug_bridge}] $device_name
    #configure the debug bridge to be 
    set_property CONFIG.C_DEBUG_MODE {2}     [get_bd_cells $device_name]
    set_property CONFIG.C_BSCAN_MUX {2}      [get_bd_cells $device_name]
    set_property CONFIG.C_XVC_HW_ID {0x0001} [get_bd_cells $device_name]

    
    #test
    set_property CONFIG.C_NUM_BS_MASTER {1} [get_bd_cells $device_name]

    
    #connect to AXI, clk, and reset between slave and mastre
    [AXI_DEV_CONNECT $params]


    #test
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == debug_bridge }] debug_bridge_0
    connect_bd_intf_net [get_bd_intf_pins ${device_name}/m0_bscan] [get_bd_intf_pins debug_bridge_0/S_BSCAN]
    connect_bd_net [get_bd_pins debug_bridge_0/clk] [get_bd_pins $axi_clk]

    puts "Added Xilinx Local XVC AXI Slave: $device_name"
    
}
