source -notrace ${BD_PATH}/axi_helpers/device_tree_helpers.tcl
source -notrace ${BD_PATH}/utils/vivado.tcl
source ${BD_PATH}/utils/Allocator.tcl

source ${BD_PATH}/axi_helpers/connections_clk.tcl
source ${BD_PATH}/axi_helpers/connections_addressing.tcl
source ${BD_PATH}/axi_helpers/connections_lowlevel.tcl


## proc \c AXI_PL_DEV_CONNECT
#Arguments:
#  \param params dictionary filled with the following (usually set via a global control_set in the config file)
#  - \b device_name the name of the axi slave (will be used in the dtsi_chunk file)
#  - \b axi_control dictionary of the following
#    - \b axi_interconnect the axi interconnect we will be connecting to
#    - \b axi_clk the clock used for this axi slave/master channel
#    - \b axi_reset_n the reset used for this axi slave/master channel
#    - \b axi_clk_freq the frequency of the AXI clock used for slave/master
#    - \b allocator dictionary of the fo llowing
#      - \b BT_name Name of the global variable for the allocator used by this control set
#  - \b addr dictionary of the addressing info for this endpoint
#    - \b offset Address (in bytes) to use for this AXI endpoint (-1 for automatic addressing)
#    - \b range in bytes of this endpoint.   (-1 for default 4K value)
#  - \b type Type of axi connection to use (default is AXI4LITE)
#  - \b data_width The width of this axi connection (default 32)
#  - \b remote_slave Tell the automation to build the dtsi file for creating a dtbo file for runtime-loading (0 or 1)
#  - \b manual_load_dtsi Tell the automation to put this endpoints dtsi info in another directory so it isn't used by default (0 or 1) (Use this for remote UARTS that aren't always loaded to prevent linux crashes)
#This function automates the adding of a AXI slave that lives outside of the bd.
#It will create external connections for the AXI bus, AXI clock, and AXI reset_n
#for the external slave and connect them up to the axi interconnect in the bd.
#
#This will also generate the addressing and dtsi info needed for using the endpoint in linux
proc AXI_PL_DEV_CONNECT {params} {
    global default_device_tree_additions

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 4K} type AXI4LITE data_width 32 remote_slave 0 manual_load_dtsi 0]

    #optional device tree additions
    set_optional_values $params [dict create dt_data $default_device_tree_additions]

    # optionally add a base address to the offset
    if {[info exists axi_base]} {
         set offset [expr $offset + $axi_base]
    }

    #create axi port names
    set AXIS_PORT_NAME $device_name
    append AXI_PORT_NAME "_AXIS"    

    global AXI_ADDR_WIDTH
    
    startgroup
    
    #Create a new master port for this slave
    ADD_MASTER_TO_INTERCONNECT [dict create interconnect $axi_interconnect]


    make_bd_intf_pins_external -name ${AXIS_PORT_NAME} [get_bd_intf_pins  $AXIM_PORT_NAME]


    set_property CONFIG.DATA_WIDTH $data_width [get_bd_intf_ports $AXIS_PORT_NAME]
    #set the AXI address widths

    if {[info exists AXI_ADDR_WIDTH]} {
        set_property CONFIG.ADDR_WIDTH ${AXI_ADDR_WIDTH} [get_bd_intf_ports $AXIS_PORT_NAME]
        puts "Using $AXI_ADDR_WIDTH-bit AXI address"
    } else {
        set_property CONFIG.ADDR_WIDTH 32 [get_bd_intf_ports $AXIS_PORT_NAME]
        puts "Using 32-bit AXI address"
    }
    
    #create clk and reset (-q to skip error if it already exists)
    if ![llength [get_bd_ports -quiet $axi_clk]] {
        create_bd_port -quiet -dir I -type clk $axi_clk
    }
    if ![llength [get_bd_ports -quiet $axi_rstn]] {
        create_bd_port -quiet -dir I -type rst $axi_rstn
    }


    #connect AXI clk/reest ports to AXI interconnect master and setup parameters
    if [llength [get_bd_ports -quiet $axi_clk]] {
        connect_bd_net -quiet [get_bd_ports $axi_clk]      [get_bd_pins $AXIM_CLK_NAME]
    } else {
        connect_bd_net -quiet [get_bd_pins $axi_clk]      [get_bd_pins $AXIM_CLK_NAME]
    }

    if [llength [get_bd_ports -quiet $axi_rstn]] {
        connect_bd_net -quiet [get_bd_ports $axi_rstn]     [get_bd_pins $AXIM_RSTN_NAME]
    } else {
        connect_bd_net -quiet [get_bd_pins $axi_rstn]     [get_bd_pins $AXIM_RSTN_NAME]
    }

    #set bus properties
    set_property CONFIG.FREQ_HZ          $axi_freq  [get_bd_intf_ports ${AXIS_PORT_NAME}]
    set_property CONFIG.PROTOCOL         ${type}    [get_bd_intf_ports $AXIS_PORT_NAME]
    set_property CONFIG.ASSOCIATED_RESET $axi_rstn  [get_bd_intf_ports ${AXIS_PORT_NAME}]
    if [llength [get_bd_ports -quiet $axi_clk]] {
        set_property CONFIG.ASSOCIATED_BUSIF  $device_name [get_bd_ports $axi_clk]
    } else {
        set_property CONFIG.ASSOCIATED_BUSIF  $device_name [get_bd_pins $axi_clk]
    }

    
    #add addressing        
    if { [dict exists $params axi_control allocator BT_name]} {
	set BT_name [dict get $params axi_control allocator BT_name]
	global $BT_name
	upvar 0 $BT_name BT

	if {$offset == -1} {
	    #automatically find an address
	    #need to update range from vivado nomenclature to sane
	    set range [SanitizeVivadoSize $range]
	    
	    #get block returns a range and an updated BT
	    set ret [GetBlock $BT $range]
	    #get the range (element 0)
	    set new_addr [lindex $ret 0]
	    #get the new BT (element 1)
	    set BT [lindex $ret 1]
	    if {$new_addr == -1} {
		set error_string "failed to allocate automatic address"
		error ${error_string}
	    } else {
		assign_bd_address -verbose -range $range -offset $new_addr [get_bd_addr_segs ${device_name}/Reg]
		puts "Automatically setting $device_name address to $new_addr $range"
	    }	    
	} else {
	    #we have a set address
	    set starting_address $offset
	    set ending_address [expr $offset + [SanitizeVivadoSize $range] - 1]

	    set ret [GetBlockAtAddress $BT $starting_address $ending_address]
	    #get the range (element 0)
	    set new_addr [lindex $ret 0]
	    #get the new BT (element 1)
	    set BT [lindex $ret 1]
	    if {$new_addr == -1} {
		set error_string "failed to allocate ${offset} with range ${range}."
		error ${error_string}
	    } else {
		assign_bd_address -verbose -range $range -offset $new_addr [get_bd_addr_segs ${device_name}/Reg]
		puts "Manually setting $device_name address to $offset $range"
	    }
	    
	}

	pdict $BT	
    }

    
    endgroup
    validate_bd_design -quiet

    #now that the design is validated, generate the DTSI_CHUNK file
    if {$offset == -1} {
	AXI_DEV_UIO_DTSI_CHUNK $device_name $dt_data
    } else {
	AXI_DEV_UIO_DTSI_CHUNK $device_name $dt_data
    }

    #generate dtsi file for DTBO generation if the is a remote slave
    if {$remote_slave == 1} {
        AXI_DEV_UIO_DTSI_OVERLAY ${device_name} ${manual_load_dtsi} $dt_data
    }
}

## proc \c AXI_DEV_CONNECT
#Arguments:
#  \param params dictionary filled with the following (usually set via a global control_set in the config file)
#  - \b device_name the name of the axi slave (will be used in the dtsi_chunk file)
#  - \b axi_control dictionary of the following
#    - \b axi_interconnect the axi interconnect we will be connecting to
#    - \b axi_clk the clock used for this axi slave/master channel
#    - \b axi_reset_n the reset used for this axi slave/master channel
#    - \b axi_clk_freq the frequency of the AXI clock used for slave/master
#    - \b allocator dictionary of the fo llowing
#      - \b BT_name Name of the global variable for the allocator used by this control set
#  - \b addr dictionary of the addressing info for this endpoint
#    - \b offset Address (in bytes) to use for this AXI endpoint (-1 for automatic addressing)
#    - \b range in bytes of this endpoint.   (-1 for default 4K value)
#  - \b type Type of axi connection to use (default is AXI4LITE)
#  - \b data_width The width of this axi connection (default 32)
#  - \b remote_slave Tell the automation to build the dtsi file for creating a dtbo file for runtime-loading (0 or 1)
#  - \b manual_load_dtsi Tell the automation to put this endpoints dtsi info in another directory so it isn't used by default (0 or 1) (Use this for remote UARTS that aren't always loaded to prevent linux crashes)
#  - \b force_mem Tell the automation to connect this enpoint using its MEM interface instead of a REG interface
#
#This function is a simpler version of AXI_PL_DEV_CONNECT used for axi slaves in the bd.
proc AXI_DEV_CONNECT {params} {
    global default_device_tree_additions
    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 4K} type AXI4LITE remote_slave 0 force_mem 0 manual_load_dtsi 0 ]

    #optional device tree additions
    set_optional_values $params [dict create dt_data $default_device_tree_additions]

    # optionally add a base address to the offset
    if {[info exists axi_base]} {
         set offset [expr $offset + $axi_base]
    }

    #Create a new master port for this slave
    ADD_MASTER_TO_INTERCONNECT [dict create interconnect $axi_interconnect]
    
    #connect the requested clock to the AXI interconnect clock port
    connect_bd_net [get_bd_pins $axi_clk]   [get_bd_pins ${AXIM_CLK_NAME}]
    connect_bd_net [get_bd_pins $axi_rstn]  [get_bd_pins ${AXIM_RSTN_NAME}]

    #connect the bus
    AXI_BUS_CONNECT $device_name $AXIM_PORT_NAME
    #connect the clocks
    AXI_CLK_CONNECT $device_name $axi_clk $axi_rstn

    
    AXI_SET_ADDR $device_name [dict get $params axi_control] $offset $range $force_mem
    AXI_GEN_DTSI $device_name $remote_slave $manual_load_dtsi $dt_data
}


## proc \c AXI_LITE_DEV_CONNECT
#Arguments:
#  \param params dictionary filled with the following (usually set via a global control_set in the config file)
#
# This is a version of AXI_DEV_CONNECT() that has a restricted list of AXI ports to connect to (axi-lite ports) used for cases when you want to connect to an axi-lite interface instead of the higher priority full axi interface.
proc AXI_LITE_DEV_CONNECT {params} {
    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 4K} type AXI4LITE remote_slave 0 manual_load_dtsi 0]

    # optionally add a base address to the offset
    if {[info exists axi_base]} {
         set offset [expr $offset + $axi_base]
    }

    startgroup

    #Create a new master port for this slave
    ADD_MASTER_TO_INTERCONNECT [dict create interconnect $axi_interconnect]

    #connect the requested clock to the AXI interconnect clock port 
    connect_bd_net [get_bd_pins $axi_clk]   [get_bd_pins ${AXIM_CLK_NAME}]
    connect_bd_net [get_bd_pins $axi_rstn]  [get_bd_pins ${AXIM_RSTN_NAME}]

    AXI_LITE_BUS_CONNECT  $device_name $AXIM_PORT_NAME
    AXI_LITE_CLK_CONNECT  $device_name $axi_clk $axi_rstn


    AXI_SET_ADDR $device_name [dict get $params axi_control] $offset $range
    AXI_GEN_DTSI $device_name $remote_slave $manual_load_dtsi

    validate_bd_design -quiet 

    endgroup
}

## proc \c AXI_CTL_DEV_CONNECT
#Arguments:
#  \param params dictionary filled with the following (usually set via a global control_set in the config file)
#
# This is a version of AXI_DEV_CONNECT() that has a restricted list of AXI ports to connect to (axi-lite control ports) used for cases when you want to connect to an axi-lite control interface instead of the higher priority full axi interface.
proc AXI_CTL_DEV_CONNECT {params} {
    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 4K} type AXI4LITE remote_slave 0 manual_load_dtsi 0]

    # optionally add a base address to the offset
    if {[info exists axi_base]} {
         set offset [expr $offset + $axi_base]
    }

    startgroup

    #Create a new master port for this slave
    ADD_MASTER_TO_INTERCONNECT [dict create interconnect $axi_interconnect]

    #connect the requested clock to the AXI interconnect clock port 
    connect_bd_net [get_bd_pins $axi_clk]   [get_bd_pins ${AXIM_CLK_NAME}]
    connect_bd_net [get_bd_pins $axi_rstn]  [get_bd_pins ${AXIM_RSTN_NAME}]


    #Xilinx AXI slaves use different names for the AXI connection, this if/else tree will try to find the correct one. 
    connect_bd_intf_net     [get_bd_intf_pins $device_name/S_AXI_CTL] -boundary_type upper [get_bd_intf_pins $AXIM_PORT_NAME]
    connect_bd_net  -quiet  [get_bd_pins $device_name/aclk]             [get_bd_pins $axi_clk]
    connect_bd_net  -quiet  [get_bd_pins $device_name/aresetn]          [get_bd_pins $axi_rstn]

    
    AXI_SET_ADDR $device_name [dict get $params axi_control] $offset $range
    AXI_GEN_DTSI $device_name $remote_slave $manual_load_dtsi

    validate_bd_design -quiet

    endgroup
}

## proc \c CONNECT_AXI_MASTER_TO_INTERCONNECT
#Arguments:
#  \param params dictionary filled with the following (usually set via a global control_set in the config file)
#  - \b interconnect The name of the axi interconnect we will connect to
#  - \b axi_master The axi_master interface that will be connecting to the interconnect
#  - \b axi_clk The clock to use for this axi connection
#  - \b axi_rstn The reset to use for this axi connection
proc CONNECT_AXI_MASTER_TO_INTERCONNECT {params} {
    # required values
    set_required_values $params {interconnect axi_master axi_clk axi_rstn}

    set_optional_values $params [dict create type AXI4]
    startgroup

    #add new spot on interconnect for this master
    EXPAND_AXI_INTERCONNECT $params

    #get source clk
    set src_clk [GET_BD_PINS_OR_PORTS foo $axi_clk]
        
    # connect clocks (foo is just an unused placeholder variable for this function)
    connect_bd_net $src_clk [get_bd_pins $AXI_MASTER_CLK]; #interconnnect
    
    # Connect resets
    connect_bd_net [GET_BD_PINS_OR_PORTS foo $axi_rstn] [get_bd_pins $AXI_MASTER_RSTN]

    
    #connect up this interconnect's slave interface to the master $iSlave driving it
    if {$type == {AXI4}} {
	AXI_BUS_CONNECT $axi_master $AXI_MASTER_BUS  "m"
	connect_bd_net -quiet $src_clk [GET_BD_PINS_OR_PORTS foo ${axi_master}/m_aclk]; #interconnnect
	connect_bd_net -quiet [GET_BD_PINS_OR_PORTS foo $axi_rstn] [get_bd_pins ${axi_master}/m_aresetn]
    } else {
	AXI_LITE_BUS_CONNECT $axi_master $AXI_MASTER_BUS "m"
	connect_bd_net -quiet $src_clk [GET_BD_PINS_OR_PORTS foo ${axi_master}/m_axi_lite_aclk]; #interconnnect
	connect_bd_net -quiet [GET_BD_PINS_OR_PORTS foo $axi_rstn] [get_bd_pins ${axi_master}/m_aresetn]
    }
	

    #set to minimize area mode to remove id_widths
    set_property CONFIG.STRATEGY {1} [get_bd_cells $interconnect]

    endgroup	
}


