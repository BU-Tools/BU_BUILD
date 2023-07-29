proc AXI_IP_CDMA {params} {
    global AXI_INTERCONNECT_MASTER_SIZE
    # required values
    set_required_values $params {device_name axi_control irq_port zynq_axi zynq_clk}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    #createIP
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_cdma}] $device_name

    set_property CONFIG.C_M_AXI_MAX_BURST_LEN {256}  [get_bd_cells $device_name]
    set_property CONFIG.C_INCLUDE_SF {1}             [get_bd_cells $device_name]
    set_property CONFIG.C_INCLUDE_SG {0}             [get_bd_cells $device_name]

    #connect up the master connection
    set CDMAMaster "$device_name/M_AXI"
    set CDMAClk    "$device_name/m_axi_aclk"
    set CDMARstn   "$device_name/m_axi_rstn"

    #connect CDMA master to a slave interface
    if { [llength [array names AXI_INTERCONNECT_MASTER_SIZE -exact $zynq_axi ] ] > 0} {
	#parent is an interconnect
	EXPAND_AXI_INTERCONNECT [dict create interconnect $zynq_axi]
	connect_bd_net -q [get_bd_pins  $zynq_clk ] [get_bd_pins $AXI_MASTER_CLK]
	connect_bd_net -q [get_bd_ports $zynq_clk ] [get_bd_pins $AXI_MASTER_CLK]
	connect_bd_net -q [get_bd_pins  $axi_rstn ] [get_bd_pins $AXI_MASTER_RSTN]
	connect_bd_net -q [get_bd_ports $axi_rstn ] [get_bd_pins $AXI_MASTER_RSTN]
	connect_bd_intf_net [get_bd_intf_pins $AXI_MASTER_BUS] -boundary_type upper \
	    [get_bd_intf_pins $CDMAMaster]		
    } else {
	connect_bd_intf_net [get_bd_intf_pins $zynq_axi] -boundary_type upper [get_bd_intf_pins $CDMAMaster]		
    }

    connect_bd_net -quiet [get_bd_pins $CDMAClk] [get_bd_pins $zynq_clk]
    connect_bd_net -quiet [get_bd_pins $CDMAClk] [get_bd_pins $axi_clk]
    connect_bd_net -quiet [get_bd_pins $zynq_clk] [get_bd_pins $axi_clk]

    
    #connect up AXI_LITE interfacee
    AXI_LITE_DEV_CONNECT $params

    #connect interrupt
    CONNECT_IRQ ${device_name}/cdma_introut ${irq_port}
    puts "finished CDMA"
}
