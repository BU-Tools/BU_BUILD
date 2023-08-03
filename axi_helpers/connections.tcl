source -notrace ${BD_PATH}/dtsi_helpers.tcl


#This function automates the adding of a AXI slave that lives outside of the bd.
#It will create external connections for the AXI bus, AXI clock, and AXI reset_n
#for the external slave and connect them up to the axi interconnect in the bd.
#The arguments are
#  device_name: the name of the axi slave (will be used in the dtsi_chunk file)
#  axi_interconnect_name: name of the bd axi interconnect we will be connecting to
#  axi_master_name: name of the channel on the axi interconnect this slave uses
#  axi_clk: the clock used for this axi slave/master channel
#  axi_reset_n: the reset used for this axi slave/master channel
#  axi_clk_freq: the frequency of the AXI clock used for slave/master

proc AXI_PL_DEV_CONNECT {params} {
    global default_device_tree_additions

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 4K } type AXI4LITE data_width 32 remote_slave 0 manual_load_dtsi 0]

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
    if {$offset == -1} {
        puts "Automatically setting $device_name address"
        assign_bd_address  [get_bd_addr_segs {$device_name/Reg }]
    } else {
        puts "Manually setting $device_name address to $offset $range"
	puts /${device_name}/*
	puts [get_bd_addr_segs /${device_name}/*]
	puts [get_bd_addr_segs ${device_name}/Reg]
        assign_bd_address -verbose -range $range -offset $offset [get_bd_addr_segs ${device_name}/Reg]

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


proc AXI_CLK_CONNECT {device_name axi_clk axi_rstn {ms_type "s"}} {
    #Xilinx AXI slaves use different names for the AXI connection, this if/else tree will try to find the correct one. 
    set MS_TYPE [string toupper ${ms_type}]
    if [llength [get_bd_intf_pins -quiet $device_name/${MS_TYPE}_AXI]] {
        if [llength [get_bd_pins -quiet $device_name/${ms_type}_axi_aclk]] {
            connect_bd_net -quiet     [get_bd_pins $device_name/${ms_type}_axi_aclk]             [get_bd_pins $axi_clk]
            connect_bd_net -quiet     [get_bd_pins $device_name/${ms_type}_axi_aresetn]          [get_bd_pins $axi_rstn]
        } elseif [llength [get_bd_pins -quiet $device_name/${ms_type}_aclk]] {
            connect_bd_net -quiet     [get_bd_pins $device_name/${ms_type}_aclk]             [get_bd_pins $axi_clk]
            connect_bd_net -quiet     [get_bd_pins $device_name/${ms_type}_aresetn]          [get_bd_pins $axi_rstn]
        } elseif [llength [get_bd_pins -quiet $device_name/aclk]] {
            connect_bd_net -quiet     [get_bd_pins $device_name/aclk]             [get_bd_pins $axi_clk]
            connect_bd_net -quiet     [get_bd_pins $device_name/aresetn]          [get_bd_pins $axi_rstn]
        } else {
	    connect_bd_net -quiet     [get_bd_pins $device_name/saxi*aclk]             [get_bd_pins $axi_clk]
	}
    } elseif [llength [get_bd_intf_pins -quiet $device_name/${ms_type}_axi_lite]] {
        connect_bd_net -quiet     [get_bd_pins $device_name/${ms_type}_axi_aclk]             [get_bd_pins $axi_clk]
        connect_bd_net -quiet     [get_bd_pins $device_name/${ms_type}_axi_aresetn]          [get_bd_pins $axi_rstn]
    } elseif [llength [get_bd_pins $device_name/${ms_type}_axi_aclk] ] {
        connect_bd_net -quiet     [get_bd_pins $device_name/${ms_type}_axi_aclk]             [get_bd_pins $axi_clk]
        connect_bd_net -quiet     [get_bd_pins $device_name/${ms_type}_axi_aresetn]          [get_bd_pins $axi_rstn]
    } else {
	connect_bd_net -quiet     [get_bd_pins $device_name/saxi*aclk]             [get_bd_pins $axi_clk]
    }
}
proc AXI_BUS_CONNECT {device_name AXIM_PORT_NAME} {
    #Xilinx AXI slaves use different names for the AXI connection, this if/else tree will try to find the correct one. 
    if [llength [get_bd_intf_pins -quiet $device_name/S_AXI]] {
        connect_bd_intf_net [get_bd_intf_pins $device_name/S_AXI] -boundary_type upper [get_bd_intf_pins $AXIM_PORT_NAME]
    } elseif [llength [get_bd_intf_pins -quiet $device_name/s_axi_lite]] {
        connect_bd_intf_net [get_bd_intf_pins $device_name/s_axi_lite] -boundary_type upper [get_bd_intf_pins $AXIM_PORT_NAME]
    } elseif [llength [get_bd_intf_pins -quiet $device_name/*AXI*LITE*]] {
        connect_bd_intf_net [get_bd_intf_pins $device_name/*AXI*LITE*] -boundary_type upper [get_bd_intf_pins $AXIM_PORT_NAME]
    } else {
	connect_bd_intf_net [get_bd_intf_pins $device_name/S*AXI*] -boundary_type upper [get_bd_intf_pins $AXIM_PORT_NAME]
    }
}
proc AXI_CONNECT {device_name axi_interconnect axi_clk axi_rstn axi_freq {addr_offset -1} {addr_range 64K} {remote_slave 0}} {

    startgroup

    #Create a new master port for this slave
    ADD_MASTER_TO_INTERCONNECT [dict create interconnect $axi_interconnect]
    
    #connect the requested clock to the AXI interconnect clock port
    connect_bd_net [get_bd_pins $axi_clk]   [get_bd_pins ${AXIM_CLK_NAME}]
    connect_bd_net [get_bd_pins $axi_rstn]  [get_bd_pins ${AXIM_RSTN_NAME}]

    #connect the bus
    AXI_BUS_CONNECT $device_name $AXIM_PORT_NAME
    #connect the clocks
    AXI_CLK_CONNECT $device_name $axi_clk $axi_rstn
    
    endgroup
}
proc AXI_SET_ADDR {device_name {addr_offset -1} {addr_range 64K} {force_mem 0}} {


    startgroup
    

    #add addressing
    if {$addr_offset == -1} {
        puts "Automatically setting $device_name address"
        lappend axi_memory_mappings [assign_bd_address -verbose [get_bd_addr_segs {${device_name}/*Reg* }] ]
    } else {
        if {($force_mem == 0) && [llength [get_bd_addr_segs ${device_name}/*Reg*]]} {
            puts "Manually setting $device_name Reg address to $addr_offset $addr_range"
            lappend axi_memory_mappings [assign_bd_address -verbose -range $addr_range -offset $addr_offset [get_bd_addr_segs $device_name/*Reg*]]
	} elseif {($force_mem == 0) && [llength [get_bd_addr_segs ${device_name}/*Control*]]} {
            puts "Manually setting $device_name Control address to $addr_offset $addr_range"
            lappend axi_memory_mappings [assign_bd_address -verbose -range $addr_range -offset $addr_offset [get_bd_addr_segs $device_name/*Control*]]
        } elseif {[llength [get_bd_addr_segs ${device_name}/*Mem*]]} {
            puts "Manually setting $device_name Mem address to $addr_offset $addr_range"
            lappend axi_memory_mappings [assign_bd_address -verbose -range $addr_range -offset $addr_offset [get_bd_addr_segs $device_name/*Mem*]]
        }

    }

    endgroup

}
proc AXI_GEN_DTSI [list device_name [list remote_slave 0] [list manual_load_dtsi 0]  [list dt_data $default_device_tree_additions]] {

    startgroup
    validate_bd_design -quiet

    #Add this to the list of slave we need to make dtsi files for
    if {$remote_slave == 0} {
        #if this is a local Xilinx IP core, most info is done by Vivado
        [AXI_DEV_UIO_DTSI_POST_CHUNK $device_name $dt_data]
    } elseif {$remote_slave == 1} {
        global REMOTE_C2C
	set REMOTE_C2C 1
	#if this is accessed via axi C2C, then we need to write a full dtsi entry
        #this is now a legacy file, 
	[AXI_DEV_UIO_DTSI_CHUNK ${device_name} $dt_data]
	#Now we make dtsi overlay files to be loaded at boot-time
	AXI_DEV_UIO_DTSI_OVERLAY ${device_name} ${manual_load_dtsi} $dt_data
    }
    #else {
    #do not generate a file
    #}
    

    endgroup

}

#This function is a simpler version of AXI_PL_DEV_CONNECT used for axi slaves in the bd.
#proc AXI_DEV_CONNECT {device_name axi_interconnect axi_clk axi_rstn axi_freq {addr_offset -1} {addr_range 64K} {remote_slave 0} {force_mem 0}} {
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

    [AXI_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $offset $range $remote_slave]
    AXI_SET_ADDR $device_name $offset $range $force_mem
    AXI_GEN_DTSI $device_name $remote_slave $manual_load_dtsi $dt_data
}


proc AXI_LITE_CLK_CONNECT {device_name axi_clk axi_rstn {ms_type "s"} } {
    #Xilinx AXI slaves use different names for the AXI connection, this if/else tree will try to find the correct one. 
    set MS_TYPE [string toupper ${ms_type}]
    if [llength [get_bd_intf_pins -quiet $device_name/${MS_TYPE}_AXI_lite]] {
	if [llength [get_bd_pins -quiet $device_name/${ms_type}_axi_lite_aclk]] {
            connect_bd_net      [get_bd_pins $device_name/${ms_type}_axi_lite_aclk]        [get_bd_pins $axi_clk]
            connect_bd_net -quiet     [get_bd_pins -quiet $device_name/${ms_type}_aresetn]     [get_bd_pins $axi_rstn]
	    connect_bd_net -quiet     [get_bd_pins -quiet $device_name/${ms_type}_axi_lite_aresetn]     [get_bd_pins $axi_rstn]
        } elseif       [llength [get_bd_pins -quiet $device_name/${ms_type}_axi_aclk]] {
            connect_bd_net      [get_bd_pins $device_name/${ms_type}_axi_aclk]             [get_bd_pins $axi_clk]
            connect_bd_net      [get_bd_pins $device_name/${ms_type}_axi_aresetn]          [get_bd_pins $axi_rstn]
        } else {	           
            connect_bd_net      [get_bd_pins $device_name/${ms_type}_aclk]                 [get_bd_pins $axi_clk]
            connect_bd_net      [get_bd_pins $device_name/${ms_type}_aresetn]              [get_bd_pins $axi_rstn]
        }
    } else {
        connect_bd_net          [get_bd_pins $device_name/${ms_type}_axi_aclk]             [get_bd_pins $axi_clk]
        connect_bd_net          [get_bd_pins $device_name/${ms_type}_axi_aresetn]          [get_bd_pins $axi_rstn]
    }
}

proc AXI_LITE_BUS_CONNECT {device_name AXIM_PORT_NAME} {
    #Xilinx AXI slaves use different names for the AXI connection, this if/else tree will try to find the correct one. 
    if [llength [get_bd_intf_pins -quiet $device_name/S_AXI_lite]] {
        connect_bd_intf_net [get_bd_intf_pins $device_name/S_AXI_lite] -boundary_type upper [get_bd_intf_pins $AXIM_PORT_NAME]
    } else {
        connect_bd_intf_net     [get_bd_intf_pins $device_name/AXI_LITE] -boundary_type upper [get_bd_intf_pins $AXIM_PORT_NAME]
    }
}

#This function is a simpler version of AXI_PL_DEV_CONNECT used for axi slaves in the bd.
#The arguments are the device name, axi master name+channel and the clk/reset for the
#channel
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


    AXI_SET_ADDR $device_name $offset $range
    AXI_GEN_DTSI $device_name $remote_slave $manual_load_dtsi

    validate_bd_design -quiet


###    #Add this to the list of slave we need to make dtsi files for
###    if {$remote_slave == 0} {
###        #if this is a local Xilinx IP core, most info is done by Vivado
###        [AXI_DEV_UIO_DTSI_POST_CHUNK $device_name]
###    } elseif {$remote_slave == 1} {
###        #if this is accessed via axi C2C, then we need to write a full dtsi entry
###        [AXI_DEV_UIO_DTSI_CHUNK ${device_name}]
###    }
    #else {
    #do not generate a file
    #}
    

    endgroup
}

#proc AXI_CTL_DEV_CONNECT {device_name axi_interconnect axi_clk axi_rstn axi_freq {addr_offset -1} {addr_range 64K} {remote_slave 0}} {
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

    
    AXI_SET_ADDR $device_name $offset $range
    AXI_GEN_DTSI $device_name $remote_slave $manual_load_dtsi

    validate_bd_design -quiet


#####    #Add this to the list of slave we need to make dtsi files for
#####    if {$remote_slave == 0} {
#####        #if this is a local Xilinx IP core, most info is done by Vivado
#####        [AXI_DEV_UIO_DTSI_POST_CHUNK $device_name]
#####    } elseif {$remote_slave == 1} {
#####        #if this is accessed via axi C2C, then we need to write a full dtsi entry
#####        [AXI_DEV_UIO_DTSI_CHUNK ${device_name}]
#####    }
#####    #else {
#####    #do not generate a file
#####    #}
    

    endgroup
}

proc BUILD_JTAG_AXI_MASTER {params} {
    # required values
    set_required_values $params {device_name axi_clk axi_rstn}
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == jtag_axi }] ${device_name}
    connect_bd_net [get_bd_ports ${axi_clk}] [get_bd_pins ${device_name}/aclk]
    connect_bd_net [get_bd_pins  ${device_name}/aresetn] [get_bd_pins ${axi_rstn}]
}


proc BUILD_AXI_DATA_WIDTH {params} {
    # required values
    set_required_values $params {device_name axi_control in_width out_width}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    # optionally add a base address to the offset
    if {[info exists axi_base]} {
         set offset [expr $offset + $axi_base]
    }

    #create the width converter
    create_bd_cell -type ip -vlnv [get_ipdefs -all -filter {NAME == axi_dwidth_converter && UPGRADE_VERSIONS == "" }] $device_name

    set_property CONFIG.SI_DATA_WIDTH.VALUE_SRC USER     [get_bd_cells $device_name] 
    set_property CONFIG.ADDR_WIDTH.VALUE_SRC PROPAGATED  [get_bd_cells $device_name] 
    set_property CONFIG.MI_DATA_WIDTH.VALUE_SRC USER     [get_bd_cells $device_name] 

    #set the converter
    set_property CONFIG.SI_DATA_WIDTH ${in_width}       [get_bd_cells $device_name] 
    set_property CONFIG.MI_DATA_WIDTH ${out_width}       [get_bd_cells $device_name] 

    #connect to AXI, clk, and reset between slave and master
#    [AXI_DEV_CONNECT $device_name $axi_interconnect $axi_clk $axi_rstn $axi_freq $addr_offset $addr_range $remote_slave]
    [AXI_DEV_CONNECT $params]
    puts "Finished Xilinx AXI data width converter: $device_name"

}
