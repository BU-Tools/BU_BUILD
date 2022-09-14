
proc AXI_IP_BRAM {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    #create XADC AXI slave
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_bram_ctrl }] ${device_name}

    set_property CONFIG.SINGLE_PORT_BRAM {1} [get_bd_cells ${device_name}]

    
    #connect to interconnect
    [AXI_DEV_CONNECT $params]


    #connect this to a blockram
    set BRAM_NAME ${device_name}_RAM
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == blk_mem_gen }] ${BRAM_NAME}
    set_property CONFIG.Memory_Type            {True_Dual_Port_RAM}   [get_bd_cells ${BRAM_NAME}]
    set_property CONFIG.Assume_Synchronous_Clk {false}                [get_bd_cells ${BRAM_NAME}]

    
    #connect BRAM controller to BRAM
    connect_bd_intf_net [get_bd_intf_pins ${device_name}/BRAM_PORTA] [get_bd_intf_pins ${BRAM_NAME}/BRAM_PORTA]

    #make the other port external to the PL
    make_bd_intf_pins_external  [get_bd_intf_pins ${BRAM_NAME}/BRAM_PORTB]

    puts "Added Xilinx blockram: $device_name"
}
