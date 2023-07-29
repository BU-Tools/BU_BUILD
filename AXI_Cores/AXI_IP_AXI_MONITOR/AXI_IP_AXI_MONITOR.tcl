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
    [AXI_DEV_CONNECT $params]
    puts "Finished Xilinx AXI Monitor: $device_name"
}
