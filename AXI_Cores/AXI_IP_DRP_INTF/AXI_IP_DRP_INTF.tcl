source -notrace ${BD_PATH}/AXI_Cores/Helpers/Xilinx_AXI_Endpoints_Helpers.tcl

proc AXI_IP_DRP_INTF {params} {
    # required values
    set_required_values $params {device_name axi_control }
    set_required_values $params {drp_name init_clk drp_rstn}
    
    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    #turn on the DRP inteface on the transceiver
    set_property CONFIG.drp_mode             {AXI4_LITE}  [get_bd_cells ${drp_name}]    
    #connect this to the interconnect
    AXI_CONNECT  ${drp_name} ${axi_interconnect} ${init_clk} ${drp_rstn} ${axi_freq}
    AXI_SET_ADDR ${drp_name} ${offset} ${range} 
    AXI_GEN_DTSI ${drp_name} ${remote_slave}

}
