source -notrace ${BD_PATH}/axi_helpers.tcl

proc get_part {} {
    return [get_parts -of_objects [get_projects]]
    }

proc set_default {dict key default} {
    if {[dict exists $dict $key]} {
        return [dict get $dict $key ]
    } else {
        return $default
    }
}

proc AXI_IP_AXI_MONITOR {params} {


    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {core_clk core_rstn}

    # these parameters are special, since they expect lists rather than dicts
    set mon_axi [dict get $params mon_axi]
    set mon_axi_clk [dict get $params mon_axi_clk]
    set mon_axi_rstn [dict get $params mon_axi_rstn]

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 4K} remote_slave 0]

    set mon_slots 0
    #check for an axi bus size mismatch
    if {[llength mon_axi] != [llength mon_clk] || [llength mon_axi] != [llength mon_rstn]} then {
        error "master size mismatch"
    }
    set mon_slots [llength $mon_axi]
    
    #create device
    set NAME ${device_name}
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_perf_mon}] ${NAME}
    set_property CONFIG.C_ENABLE_EVENT_COUNT {1}          [get_bd_cells ${NAME}]
    set_property CONFIG.C_NUM_MONITOR_SLOTS  ${mon_slots} [get_bd_cells ${NAME}]
    set_property CONFIG.ENABLE_EXT_TRIGGERS  {0}          [get_bd_cells ${NAME}]
    set_property CONFIG.C_ENABLE_ADVANCED    {1}          [get_bd_cells ${NAME}]
    set_property CONFIG.C_ENABLE_PROFILE     {0}          [get_bd_cells ${NAME}]
    set_property CONFIG.C_ENABLE_PROFILE     {0}          [get_bd_cells ${NAME}]
    #set the number of counters
    set_property CONFIG.C_NUM_OF_COUNTERS   {10}          [get_bd_cells ${NAME}]

    connect_bd_net [get_bd_pins [format "/%s/core_aclk" ${device_name} ] ] [get_bd_pins ${core_clk}] 
    connect_bd_net [get_bd_pins [format "/%s/core_aresetn" ${device_name} ] ] [get_bd_pins ${core_rstn}] 

    puts "Added Xilinx AXI monitor & AXI Slave: $device_name"
    puts "Monitoring: "
   
    #connect up the busses to be comonitored
    for {set iMon 0} {$iMon < ${mon_slots}} {incr iMon} {

        set slot_AXI [format "/%s/SLOT_%d_AXI" ${device_name} $iMon]
        set slot_clk [format "/%s/slot_%d_axi_aclk" ${device_name} $iMon]
        set slot_rstn [format "/%s/slot_%d_axi_aresetn" ${device_name} $iMon]

        set spy_AXI  [lindex ${mon_axi}      $iMon]
        set spy_clk  [lindex ${mon_axi_clk}  $iMon]
        set spy_rstn [lindex ${mon_axi_rstn} $iMon]

        puts "$iMon:  $spy_AXI"

        # for some reason this sometimes returned "AXI3 AXI3" instead of just AXI3.... so I take the lindex 0
        set_property CONFIG.C_SLOT_${iMon}_AXI_PROTOCOL [lindex [get_property CONFIG.PROTOCOL [get_bd_intf_pins ${spy_AXI}]] 0] [get_bd_cells ${NAME}]

        #connect the AXI bus
        connect_bd_intf_net [get_bd_intf_pins ${slot_AXI}] -boundary_type upper [get_bd_intf_pins ${spy_AXI} ]
        #connet the AXI bus clock
        connect_bd_net [get_bd_pins ${slot_clk}] [get_bd_pins ${spy_clk}]
        #connet the AXI bus resetn
        connect_bd_net [get_bd_pins ${slot_rstn}] [get_bd_pins ${spy_rstn}]

    }

    #connect to AXI, clk, and reset between slave and master
    [AXI_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range $remote_slave]
    puts "Finished Xilinx AXI Monitor: $device_name"
}

proc AXI_IP_I2C {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_iic}] $device_name

    #create external pins
    make_bd_pins_external  -name ${device_name}_scl_i [get_bd_pins $device_name/scl_i]
    make_bd_pins_external  -name ${device_name}_sda_i [get_bd_pins $device_name/sda_i]
    make_bd_pins_external  -name ${device_name}_sda_o [get_bd_pins $device_name/sda_o]
    make_bd_pins_external  -name ${device_name}_scl_o [get_bd_pins $device_name/scl_o]
    make_bd_pins_external  -name ${device_name}_scl_t [get_bd_pins $device_name/scl_t]
    make_bd_pins_external  -name ${device_name}_sda_t [get_bd_pins $device_name/sda_t]
    #connect to AXI, clk, and reset between slave and mastre
    [AXI_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range $remote_slave]

    puts "Added Xilinx I2C AXI Slave: $device_name"
}

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
    [AXI_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range $remote_slave]

    
    #generate ports for the JTAG signals
    make_bd_pins_external       [get_bd_cells $device_name]
    make_bd_intf_pins_external  [get_bd_cells $device_name]

    puts "Added Xilinx XVC AXI Slave: $device_name"
}

proc AXI_IP_LOCAL_XVC {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    #Create a xilinx axi debug bridge
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == debug_bridge}] $device_name
    #configure the debug bridge to be 
    set_property CONFIG.C_DEBUG_MODE {2}     [get_bd_cells $device_name]
    set_property CONFIG.C_BSCAN_MUX {2}      [get_bd_cells $device_name]
    set_property CONFIG.C_XVC_HW_ID {0x0001} [get_bd_cells $device_name]

    
    #test
    set_property CONFIG.C_NUM_BS_MASTER {1} [get_bd_cells $device_name]

    
    #connect to AXI, clk, and reset between slave and mastre
    [AXI_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range $remote_slave]


    #test
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == debug_bridge }] debug_bridge_0
    connect_bd_intf_net [get_bd_intf_pins ${device_name}/m0_bscan] [get_bd_intf_pins debug_bridge_0/S_BSCAN]
    connect_bd_net [get_bd_pins debug_bridge_0/clk] [get_bd_pins $axi_clk]

    puts "Added Xilinx Local XVC AXI Slave: $device_name"
    
}

proc AXI_IP_UART {params} {


    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {baud_rate irq_port}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    #Create a xilinx UART
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_uartlite }] $device_name
    #configure the debug bridge to be
    set_property CONFIG.C_BAUDRATE $baud_rate [get_bd_cells $device_name]

    #connect to AXI, clk, and reset between slave and mastre
    [AXI_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range -1]

    
    #generate ports for the JTAG signals
    make_bd_intf_pins_external  -name ${device_name} [get_bd_intf_pins $device_name/UART]

    #connect interrupt
    connect_bd_net [get_bd_pins ${device_name}/interrupt] [get_bd_pins ${irq_port}]

    
    puts "Added Xilinx UART AXI Slave: $device_name"
}

#primary_serdes == 1 means this is the primary serdes, if not 1, then it is the name of the primary_serdes
proc C2C_AURORA {params} {

    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {primary_serdes init_clk refclk_freq}

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
    #set_property CONFIG.C_AURORA_LANES       {2}          [get_bd_cells ${C2C_PHY}]  
    set_property CONFIG.C_LINE_RATE          {5}          [get_bd_cells ${C2C_PHY}]
#    set_property CONFIG.C_LINE_RATE          {10}          [get_bd_cells ${C2C_PHY}]  
    set_property CONFIG.C_REFCLK_FREQUENCY   ${refclk_freq}    [get_bd_cells ${C2C_PHY}]  
    set_property CONFIG.interface_mode       {Streaming}  [get_bd_cells ${C2C_PHY}]
    if {$primary_serdes == 1} {
	set_property CONFIG.SupportLevel     {1}          [get_bd_cells ${C2C_PHY}]
    } else {
	set_property CONFIG.SupportLevel     {0}          [get_bd_cells ${C2C_PHY}]
    }
    set_property CONFIG.SINGLEEND_INITCLK    {true}       [get_bd_cells ${C2C_PHY}]  
    set_property CONFIG.C_USE_CHIPSCOPE      {true}       [get_bd_cells ${C2C_PHY}]
    set_property CONFIG.drp_mode             {AXI4_LITE}  [get_bd_cells ${C2C_PHY}]
    set_property CONFIG.TransceiverControl   {false}      [get_bd_cells ${C2C_PHY}]  
    set_property CONFIG.TransceiverControl   {true}       [get_bd_cells ${C2C_PHY}]
   
    
   
    #connect to interconnect (init clock)
    set C2C_ARST     ${C2C_PHY}_AXI_LITE_RESET_INVERTER
    create_bd_cell   -type ip -vlnv [get_ipdefs -filter {NAME == util_vector_logic }] ${C2C_ARST}
    set_property     -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells ${C2C_ARST}]
    connect_bd_net   [get_bd_pins ${C2C}/aurora_reset_pb] [get_bd_pins ${C2C_ARST}/Op1]
    set sid          [AXI_CONNECT ${C2C_PHY} $axi_interconnect $init_clk ${C2C_ARST}/Res $axi_freq]
    AXI_SET_ADDR     ${C2C_PHY}    


    
    #expose the Aurora core signals to top    
    if {$primary_serdes == 1} {
	#these are only if the serdes is the primary one
	make_bd_intf_pins_external  -name ${C2C_PHY}_refclk               [get_bd_intf_pins ${C2C_PHY}/GT_DIFF_REFCLK1]    
	make_bd_pins_external       -name ${C2C_PHY}_gt_refclk1_out       [get_bd_pins ${C2C_PHY}/gt_refclk1_out]
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
    }

    if {$primary_serdes == 1} {
	#provide a clk output of the C2C_PHY user clock 
	create_bd_port -dir O -type clk ${C2C_PHY}_CLK
        connect_bd_net [get_bd_ports ${C2C_PHY}_CLK] [get_bd_pins ${C2C_PHY}/user_clk_out]	
    } else {
	#connect up clocking resource to primary C2C_PHY
	connect_bd_net [get_bd_pins     ${primary_serdes}/gt_refclk1_out]            [get_bd_pins ${C2C_PHY}/refclk1_in]
	if { [string first u [get_part] ] == -1 && [string first U [get_part] ] == -1 } {
	    #only in 7-series
  	    connect_bd_net [get_bd_pins ${primary_serdes}/gt_qpllclk_quad3_out]      [get_bd_pins ${C2C_PHY}/gt_qpllclk_quad3_in]
	    connect_bd_net [get_bd_pins ${primary_serdes}/gt_qpllrefclk_quad3_out]   [get_bd_pins ${C2C_PHY}/gt_qpllrefclk_quad3_in]
	}
	connect_bd_net [get_bd_pins     ${primary_serdes}/sync_clk_out]              [get_bd_pins ${C2C_PHY}/sync_clk]
    }

    #    validate_bd_design
    AXI_GEN_DTSI ${C2C_PHY} $axi_interconnect $sid
    
#    endgroup      
}

proc AXI_C2C_MASTER {params} {

    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {primary_serdes init_clk refclk_freq}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} addr_lite {lite_offset -1 lite_range 64K}]

    #create AXI(4) firewall IPs to handle a bad C2C link
    set AXI_FW ${device_name}_AXI_FW
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_firewall }] ${AXI_FW}
    #force mapping to the mem interface on this one. 
    [AXI_DEV_CONNECT $AXI_FW $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range]
    [AXI_CTL_DEV_CONNECT $AXI_FW $axi_interconnect $axi_clk $axi_rstn $axi_freq]    

    #create AXI(4LITE) firewall IPs to handle a bad C2C link
    set AXILITE_FW ${device_name}_AXILITE_FW
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_firewall }] ${AXILITE_FW}
    [AXI_DEV_CONNECT $AXILITE_FW $axi_interconnect $axi_clk $axi_rstn $axi_freq $lite_offset $lite_range]
    [AXI_CTL_DEV_CONNECT $AXILITE_FW $axi_interconnect $axi_clk $axi_rstn $axi_freq]

    #create the actual C2C master
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_chip2chip }] $device_name
    set_property CONFIG.C_AXI_STB_WIDTH     {4}     [get_bd_cells $device_name]
    set_property CONFIG.C_AXI_DATA_WIDTH    {32}	[get_bd_cells $device_name]
    set_property CONFIG.C_NUM_OF_IO         {58.0}	[get_bd_cells $device_name]
    set_property CONFIG.C_INTERFACE_MODE    {1}	[get_bd_cells $device_name]
    set_property CONFIG.C_INTERFACE_TYPE    {2}	[get_bd_cells $device_name]
    set_property CONFIG.C_AURORA_WIDTH      {1.0}   [get_bd_cells $device_name]
    set_property CONFIG.C_EN_AXI_LINK_HNDLR {false} [get_bd_cells $device_name]
    set_property CONFIG.C_INCLUDE_AXILITE   {1}     [get_bd_cells $device_name]

    #connect AXI interface to the firewall
    connect_bd_intf_net [get_bd_intf_pins ${device_name}/s_axi] [get_bd_intf_pins ${AXI_FW}/M_AXI]
    connect_bd_net      [get_bd_pins ${device_name}/s_aclk]     [get_bd_pins $axi_clk]
    connect_bd_net      [get_bd_pins ${device_name}/s_aresetn]  [get_bd_pins $axi_rstn]
    AXI_SET_ADDR ${device_name} $offset $range 1
    
    #connect AXI LITE interface to the firewall
    connect_bd_intf_net [get_bd_intf_pins ${device_name}/s_axi_lite] [get_bd_intf_pins ${AXILITE_FW}/M_AXI]
    connect_bd_net      [get_bd_pins ${device_name}/s_axi_lite_aclk] [get_bd_pins $axi_clk]
    AXI_SET_ADDR ${device_name} $lite_offset $lite_range

    make_bd_pins_external       -name ${device_name}_aurora_pma_init_in [get_bd_pins ${device_name}/aurora_pma_init_in]
    #expose debugging signals
    make_bd_pins_external       -name ${device_name}_aurora_do_cc [get_bd_pins ${device_name}/aurora_do_cc]
    make_bd_pins_external       -name ${device_name}_axi_c2c_config_error_out    [get_bd_pins ${device_name}/axi_c2c_config_error_out   ]
    make_bd_pins_external       -name ${device_name}_axi_c2c_link_status_out     [get_bd_pins ${device_name}/axi_c2c_link_status_out    ]
    make_bd_pins_external       -name ${device_name}_axi_c2c_multi_bit_error_out [get_bd_pins ${device_name}/axi_c2c_multi_bit_error_out]
    make_bd_pins_external       -name ${device_name}_axi_c2c_link_error_out      [get_bd_pins ${device_name}/axi_c2c_link_error_out     ]

    
    C2C_AURORA [dict create device_name ${device_name} \
                    axi_control [dict get $params axi_control] \
                     primary_serdes $primary_serdes \
                     init_clk $init_clk \
                     refclk_freq $refclk_freq]
    
    #assign_bd_address [get_bd_addr_segs {$device_name/S_AXI/Mem }]
    puts "Added C2C master: $device_name"
}

proc AXI_IP_XADC {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    #create XADC AXI slave 
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == xadc_wiz }] ${device_name}

    #disable default user temp monitoring
    set_property CONFIG.USER_TEMP_ALARM {false} [get_bd_cells ${device_name}]

    
    #connect to interconnect
    [AXI_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range $remote_slave]

    
    #expose alarms
    make_bd_pins_external   -name ${device_name}_alarm             [get_bd_pins ${device_name}/alarm_out]
    make_bd_pins_external   -name ${device_name}_vccint_alarm      [get_bd_pins ${device_name}/vccint_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccaux_alarm      [get_bd_pins ${device_name}/vccaux_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccpint_alarm     [get_bd_pins ${device_name}/vccpint_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccpaux_alarm     [get_bd_pins ${device_name}/vccpaux_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccddro_alarm     [get_bd_pins ${device_name}/vccddro_alarm_out]
    make_bd_pins_external   -name ${device_name}_overtemp_alarm    [get_bd_pins ${device_name}/ot_alarm_out]

    puts "Added Xilinx XADC AXI Slave: $device_name"

}

proc AXI_IP_SYS_MGMT {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0 enable_i2c_pins 0]
    
    #create system management AXIL lite slave
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == system_management_wiz }] ${device_name}

    #disable default user temp monitoring
    set_property CONFIG.USER_TEMP_ALARM {false}        [get_bd_cells ${device_name}]
    #add i2c interface
    if {$enable_i2c_pins} {
      set_property CONFIG.SERIAL_INTERFACE {Enable_I2C}  [get_bd_cells ${device_name}]
      set_property CONFIG.I2C_ADDRESS_OVERRIDE {false}   [get_bd_cells ${device_name}]
    }
    
    #connect to interconnect
    [AXI_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range $remote_slave]

    
    #expose alarms
    make_bd_pins_external   -name ${device_name}_alarm             [get_bd_pins ${device_name}/alarm_out]
    make_bd_pins_external   -name ${device_name}_vccint_alarm      [get_bd_pins ${device_name}/vccint_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccaux_alarm      [get_bd_pins ${device_name}/vccaux_alarm_out]
    make_bd_pins_external   -name ${device_name}_overtemp_alarm    [get_bd_pins ${device_name}/ot_out]

    #expose i2c interface
    make_bd_pins_external  -name ${device_name}_sda [get_bd_pins ${device_name}/i2c_sda]
    make_bd_pins_external  -name ${device_name}_scl [get_bd_pins ${device_name}/i2c_sclk]
    
    puts "Added Xilinx XADC AXI Slave: $device_name"

}


proc AXI_IP_BRAM {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    #create XADC AXI slave
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_bram_ctrl }] ${device_name}

    set_property CONFIG.SINGLE_PORT_BRAM {1} [get_bd_cells ${device_name}]

    
    #connect to interconnect
    [AXI_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range $remote_slave]


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
