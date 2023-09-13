proc AXI_IP_CLOCK_CONVERT {params} {

    # required values
    set_required_values $params {device_name axi_control}
    
    #create the IP
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_clock_converter }] ${device_name}
        
    #connect the bus
    AXI_BUS_CONNECT $device_name $axi_interconnect
    #connect the clocks
    AXI_CLK_CONNECT $device_name $axi_clk $axi_rstn
}
