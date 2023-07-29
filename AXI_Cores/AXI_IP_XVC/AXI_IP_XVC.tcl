proc AXI_IP_XVC {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    #Create a xilinx axi debug bridge
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == debug_bridge}] $device_name
    #configure the debug bridge to be 
    set_property CONFIG.C_DEBUG_MODE  {3} [get_bd_cells $device_name]
    set_property CONFIG.C_DESIGN_TYPE {0} [get_bd_cells $device_name]

    #connect to AXI, clk, and reset between slave and mastre
    [AXI_DEV_CONNECT $params]

    
    #generate ports for the JTAG signals
    make_bd_pins_external       [get_bd_cells $device_name]
    make_bd_intf_pins_external  [get_bd_cells $device_name]

    puts "Added Xilinx XVC AXI Slave: $device_name"
}
