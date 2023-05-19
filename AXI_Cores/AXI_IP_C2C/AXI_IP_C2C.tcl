source -notrace ${BD_PATH}/AXI_Cores/AXI_IP_C2C/C2C_AURORA.tcl


proc AXI_IP_C2C {params} {

    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {primary_serdes init_clk refclk_freq}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} addr_lite {offset -1 range 64K} irq_port "."]

    set_optional_values $params {c2c_master true}
    set_optional_values $params {singleend_refclk False}
    set_optional_values $params {speed 5}

    #create the actual C2C core
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_chip2chip }] $device_name
    set_property CONFIG.C_AXI_STB_WIDTH     {4}     [get_bd_cells $device_name]
    set_property CONFIG.C_AXI_DATA_WIDTH    {32}    [get_bd_cells $device_name]
    set_property CONFIG.C_NUM_OF_IO         {58.0}  [get_bd_cells $device_name]
    set_property CONFIG.C_INTERFACE_MODE    {0}	    [get_bd_cells $device_name]
    set_property CONFIG.C_INTERFACE_TYPE    {2}	    [get_bd_cells $device_name]
    set_property CONFIG.C_MASTER_FPGA       $c2c_master	    [get_bd_cells $device_name]
    set_property CONFIG.C_INCLUDE_AXILITE   [expr 1 + !$c2c_master]	    [get_bd_cells $device_name]
    set_property CONFIG.C_AURORA_WIDTH      {1.0}   [get_bd_cells $device_name]
    set_property CONFIG.C_EN_AXI_LINK_HNDLR {false} [get_bd_cells $device_name]
    set_property CONFIG.C_M_AXI_WUSER_WIDTH {0}     [get_bd_cells $device_name]
    set_property CONFIG.C_M_AXI_ID_WIDTH {0}        [get_bd_cells $device_name]


    #set type of clock connection based on if this is a c2c master or not
    if {$c2c_master == true} {
	set ms_type "s"
    } else {
	set ms_type "m"
    }


    if {$c2c_master == true} {
	#connect AXI interface interconnect (firewall will cut this and insert itself)
	if { [dict exists $params addr] } {
	    set AXI_params $params
	    dict set AXI_params addr [dict get $params addr]
	    dict set AXI_params remote_slave -1
	    dict set AXI_params force_mem 1
	    AXI_DEV_CONNECT $AXI_params
	    BUILD_AXI_ADDR_TABLE ${device_name}_Mem0 ${device_name}_AXI_BRIDGE
	} else {
	    AXI_CLK_CONNECT $device_name $axi_clk $axi_rstn $ms_type
	}
	
	if { [dict exists $params addr_lite] } {
	    set AXILite_params $params
	    dict set AXILite_params addr [dict get $params addr_lite]
	    dict set AXILite_params remote_slave -1
	    AXI_LITE_DEV_CONNECT $AXILite_params 
	    BUILD_AXI_ADDR_TABLE ${device_name}_Reg ${device_name}_AXI_LITE_BRIDGE
	} else {
	    AXI_LITE_CLK_CONNECT $device_name $axi_clk $axi_rstn $ms_type
	}
    } else {	
	if { [dict exists $params addr] } {
	    dict set AXI_params interconnect $axi_interconnect
	    dict set AXI_params axi_master $device_name
	    dict set AXI_params axi_clk    $axi_clk
	    dict set AXI_params axi_rstn   $axi_rstn
	    CONNECT_AXI_MASTER_TO_INTERCONNECT $AXI_params
	} else {
	    AXI_CLK_CONNECT $device_name $axi_clk $axi_rstn $ms_type
	}
	
	if { [dict exists $params addr_lite] } {
	    set AXILite_params $params	    
	    dict set AXILite_params interconnect $axi_interconnect
	    dict set AXILite_params axi_master $device_name
	    dict set AXILite_params axi_clk    $axi_clk
	    dict set AXILite_params axi_rstn   $axi_rstn
	    dict set AXILite_params type AXI4Lite
	    CONNECT_AXI_MASTER_TO_INTERCONNECT $AXILite_params
	} else {
	    AXI_LITE_CLK_CONNECT $device_name $axi_clk $axi_rstn $ms_type
	}

    }

    make_bd_pins_external       -name ${device_name}_aurora_pma_init_in          [get_bd_pins ${device_name}/aurora_pma_init_in]
    make_bd_pins_external       -name ${device_name}_aurora_reset_pb             [get_bd_pins ${device_name}/aurora_reset_pb]
    #expose debugging signals
    make_bd_pins_external       -name ${device_name}_aurora_do_cc                [get_bd_pins ${device_name}/aurora_do_cc]
    make_bd_pins_external       -name ${device_name}_axi_c2c_config_error_out    [get_bd_pins ${device_name}/axi_c2c_config_error_out   ]
    make_bd_pins_external       -name ${device_name}_axi_c2c_link_status_out     [get_bd_pins ${device_name}/axi_c2c_link_status_out    ]
    make_bd_pins_external       -name ${device_name}_axi_c2c_multi_bit_error_out [get_bd_pins ${device_name}/axi_c2c_multi_bit_error_out]
    make_bd_pins_external       -name ${device_name}_axi_c2c_link_error_out      [get_bd_pins ${device_name}/axi_c2c_link_error_out     ]

    
    C2C_AURORA [dict create device_name ${device_name} \
                    axi_control [dict get $params axi_control] \
                    primary_serdes $primary_serdes \
                    init_clk $init_clk \
                    refclk_freq $refclk_freq \
		    speed $speed \
		    singleend_refclk $singleend_refclk \
		   ]
    

    #connect interrupt
    if { ${irq_port} != "."} {
	CONNECT_IRQ ${device_name}/axi_c2c_s2m_intr_out ${irq_port}
    }
    

    #assign_bd_address [get_bd_addr_segs {$device_name/S_AXI/Mem }]
    puts "Added C2C ip: $device_name"

}
