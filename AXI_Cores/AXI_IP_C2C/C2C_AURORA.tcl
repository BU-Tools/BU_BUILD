#primary_serdes == 1 means this is the primary serdes, if not 1, then it is the name of the primary_serdes
proc C2C_AURORA {params} {

    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {primary_serdes init_clk refclk_freq}

    set_optional_values $params {speed 5}
    set_optional_values $params {singleend_refclk False}

    if {$primary_serdes == 1} {
	puts "Creating ${device_name} as a primary serdes\n"
    } else {
	puts "Creating ${device_name} using ${primary_serdes} as the primary serdes\n"
    }

    #set names
    set C2C ${device_name}
    set C2C_PHY ${C2C}_PHY    

    #create chip-2-chip aurora     
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == aurora_64b66b }] ${C2C_PHY}        
    set_property CONFIG.C_INIT_CLK.VALUE_SRC PROPAGATED   [get_bd_cells ${C2C_PHY}]  
    set_property CONFIG.C_AURORA_LANES       {1}          [get_bd_cells ${C2C_PHY}]
    set_property CONFIG.C_LINE_RATE          $speed          [get_bd_cells ${C2C_PHY}]
    set_property CONFIG.C_REFCLK_FREQUENCY   ${refclk_freq}    [get_bd_cells ${C2C_PHY}]  
    set_property CONFIG.interface_mode       {Streaming}  [get_bd_cells ${C2C_PHY}]
    if {$primary_serdes == 1} {
	set_property CONFIG.SupportLevel     {1}          [get_bd_cells ${C2C_PHY}]
    } else {
	set_property CONFIG.SupportLevel     {0}          [get_bd_cells ${C2C_PHY}]
    }
    set_property CONFIG.SINGLEEND_INITCLK    {true}       [get_bd_cells ${C2C_PHY}]  
    set_property CONFIG.C_USE_CHIPSCOPE      {true}       [get_bd_cells ${C2C_PHY}]
    set_property CONFIG.drp_mode             {NATIVE}     [get_bd_cells ${C2C_PHY}]
    set_property CONFIG.TransceiverControl   {true}       [get_bd_cells ${C2C_PHY}]
   
    set_property CONFIG.SINGLEEND_GTREFCLK   [expr {${singleend_refclk}} ] [get_bd_cells ${C2C_PHY}]

    #expose the DRP interface
    make_bd_intf_pins_external  -name ${C2C_PHY}_DRP                       [get_bd_intf_pins ${C2C_PHY}/*DRP*]
   
    #expose the Aurora core signals to top    
    if {$primary_serdes == 1} {
	#these are only if the serdes is the primary one

	if { [expr {${singleend_refclk}} ] } {
	    make_bd_pins_external       -name ${C2C_PHY}_refclk               [get_bd_pins ${C2C_PHY}/REFCLK1_in]    
	} else {
	    make_bd_intf_pins_external  -name ${C2C_PHY}_refclk               [get_bd_intf_pins ${C2C_PHY}/GT_DIFF_REFCLK1]    
            make_bd_pins_external       -name ${C2C_PHY}_gt_refclk1_out       [get_bd_pins [list ${C2C_PHY}/gt_refclk1_out ${C2C_PHY}/refclk1_in]]
	}

    }								          
    make_bd_intf_pins_external      -name ${C2C_PHY}_Rx                   [get_bd_intf_pins ${C2C_PHY}/GT_SERIAL_RX]       
    make_bd_intf_pins_external      -name ${C2C_PHY}_Tx                   [get_bd_intf_pins ${C2C_PHY}/GT_SERIAL_TX]
    make_bd_pins_external           -name ${C2C_PHY}_power_down           [get_bd_pins ${C2C_PHY}/power_down]       
    make_bd_pins_external           -name ${C2C_PHY}_gt_pll_lock          [get_bd_pins ${C2C_PHY}/gt_pll_lock]
    make_bd_pins_external           -name ${C2C_PHY}_hard_err             [get_bd_pins ${C2C_PHY}/hard_err]
    make_bd_pins_external           -name ${C2C_PHY}_soft_err             [get_bd_pins ${C2C_PHY}/soft_err]
    make_bd_pins_external           -name ${C2C_PHY}_lane_up              [get_bd_pins ${C2C_PHY}/lane_up]
    make_bd_pins_external           -name ${C2C_PHY}_mmcm_not_locked_out  [get_bd_pins ${C2C_PHY}/mmcm_not_locked_out]       
    make_bd_pins_external           -name ${C2C_PHY}_link_reset_out       [get_bd_pins ${C2C_PHY}/link_reset_out]
    make_bd_pins_external           -name ${C2C_PHY}_channel_up    [get_bd_pins ${C2C_PHY}/channel_up]

    if { [string first u [get_part] ] == -1 && [string first U [get_part] ] == -1 } {   
	#7-series debug name
	make_bd_intf_pins_external  -name ${C2C_PHY}_DEBUG                [get_bd_intf_pins ${C2C_PHY}/TRANSCEIVER_DEBUG0]
    } else {
	#USP debug name
	make_bd_intf_pins_external  -name ${C2C_PHY}_DEBUG                [get_bd_intf_pins ${C2C_PHY}/TRANSCEIVER_DEBUG]
    }

    
    
    #connect C2C core with the C2C-mode Auroroa core   
    connect_bd_intf_net [get_bd_intf_pins ${C2C}/AXIS_TX] [get_bd_intf_pins ${C2C_PHY}/USER_DATA_S_AXIS_TX]        
    connect_bd_intf_net [get_bd_intf_pins ${C2C_PHY}/USER_DATA_M_AXIS_RX]   [get_bd_intf_pins ${C2C}/AXIS_RX]        
    connect_bd_net      [get_bd_pins      ${C2C_PHY}/channel_up]            [get_bd_pins ${C2C}/axi_c2c_aurora_channel_up]     
    connect_bd_net      [get_bd_pins      ${C2C}/aurora_pma_init_out]       [get_bd_pins ${C2C_PHY}/pma_init]        
    connect_bd_net      [get_bd_pins      ${C2C}/aurora_reset_pb]           [get_bd_pins ${C2C_PHY}/reset_pb]        
    if {$primary_serdes == 1} {						    
	connect_bd_net  [get_bd_pins      ${C2C_PHY}/user_clk_out]          [get_bd_pins ${C2C}/axi_c2c_phy_clk]
	connect_bd_net  [get_bd_pins      ${C2C_PHY}/mmcm_not_locked_out]   [get_bd_pins ${C2C}/aurora_mmcm_not_locked]        
    } else {
	connect_bd_net  [get_bd_pins ${primary_serdes}/user_clk_out]        [get_bd_pins ${C2C_PHY}/user_clk]
	connect_bd_net  [get_bd_pins ${primary_serdes}/user_clk_out]        [get_bd_pins ${C2C}/axi_c2c_phy_clk]
	connect_bd_net  [get_bd_pins ${primary_serdes}/mmcm_not_locked_out] [get_bd_pins ${C2C}/aurora_mmcm_not_locked]        
    }
    
    #connect external clock to init clocks      
    connect_bd_net [get_bd_ports ${init_clk}]   [get_bd_pins ${C2C_PHY}/init_clk]       
    connect_bd_net [get_bd_ports ${init_clk}]   [get_bd_pins ${C2C}/aurora_init_clk]    

    #drp port fixed to init clk in USP
    if { [string first u [get_part] ] == -1 && [string first U [get_part] ] == -1 } {
	#connect drp clock explicitly in 7-series
	connect_bd_net [get_bd_ports ${init_clk}]   [get_bd_pins ${C2C_PHY}/drp_clk_in]
	#output the qpll lock in 7series since it isn't in the debug group
	make_bd_pins_external       -name ${C2C_PHY}_gt_qplllock                 [get_bd_pins ${C2C_PHY}/gt_qplllock]
    }

    if {$primary_serdes == 1} {
	#provide a clk output of the C2C_PHY user clock 
	create_bd_port -dir O -type clk ${C2C_PHY}_CLK
        connect_bd_net [get_bd_ports ${C2C_PHY}_CLK] [get_bd_pins ${C2C_PHY}/user_clk_out]	
    } else {
	#connect up clocking resource to primary C2C_PHY
	connect_bd_net [get_bd_pins     [get_bd_pins [list ${primary_serdes}/gt_refclk1_out ${primary_serdes}/refclk1_in]] ]            [get_bd_pins ${C2C_PHY}/refclk1_in]


	#connect up qpll signals between the cores
	set qpllclks [get_bd_pins ${primary_serdes}/gt_qpllclk_quad*_out]
	foreach qpllclk ${qpllclks} {
	    #remove the prefix and the "_out" at the end
	    set qpllclk_part [string range ${qpllclk} [string length ${primary_serdes}]+1 [string length ${qpllclk}]-5]
	    connect_bd_net [get_bd_pins ${primary_serdes}${qpllclk_part}_out]      [get_bd_pins ${C2C_PHY}${qpllclk_part}_in]
	}
	set qpllrefclks [get_bd_pins ${primary_serdes}/gt_qpllrefclk_quad*_out]
	foreach qpllrefclk ${qpllrefclks} {
	    set qpllrefclk_part [string range ${qpllrefclk} [string length ${primary_serdes}]+1 [string length ${qpllrefclk}]-5]
	    connect_bd_net [get_bd_pins ${primary_serdes}${qpllrefclk_part}_out]      [get_bd_pins ${C2C_PHY}${qpllrefclk_part}_in]
	}
		
	connect_bd_net [get_bd_pins     ${primary_serdes}/sync_clk_out]              [get_bd_pins ${C2C_PHY}/sync_clk]
    }

    #enable eyescans by default
    global post_synth_commands
    if { \
	     [expr [string first xczu [get_parts -of_objects [get_projects] ] ] >= 0 ] || \
	     [expr [string first xcku [get_parts -of_objects [get_projects] ] ] >= 0 ] || \
	     [expr [string first xcvu [get_parts -of_objects [get_projects] ] ] >= 0 ]} {
	lappend post_synth_commands [format "set_property ES_EYE_SCAN_EN True \[get_cells -hierarchical -regexp .*%s/.*CHANNEL_PRIM_INST\]" ${C2C_PHY}]
    } else {
	lappend post_synth_commands [format "set_property ES_EYE_SCAN_EN True \[get_cells -hierarchical -regexp .*%s/.*gtx_inst/gt.*\]" ${C2C_PHY}]
    }
    puts $post_synth_commands
}
