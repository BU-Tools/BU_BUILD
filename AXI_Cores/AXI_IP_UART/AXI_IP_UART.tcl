
proc AXI_IP_UART {params} {


    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {baud_rate irq_port}

    # optional values
    # remote_slave -1 means don't generate a dtsi_ file
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave -1 ]

    #Create a xilinx UART
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_uartlite }] $device_name
    #configure the debug bridge to be
    set_property CONFIG.C_BAUDRATE $baud_rate [get_bd_cells $device_name]

    #connect to AXI, clk, and reset between slave and mastre
    [AXI_DEV_CONNECT $params]

    
    #generate ports for the UART
    make_bd_intf_pins_external  -name ${device_name} [get_bd_intf_pins $device_name/UART]

    #connect interrupt
    CONNECT_IRQ ${device_name}/interrupt ${irq_port}

    
    puts "Added Xilinx UART AXI Slave: $device_name"
}
