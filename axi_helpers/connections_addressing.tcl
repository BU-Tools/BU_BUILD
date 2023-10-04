source -notrace ${BD_PATH}/axi_helpers/device_tree_helpers.tcl
source -notrace ${BD_PATH}/utils/vivado.tcl
source ${BD_PATH}/utils/Allocator.tcl

## proc \c AXI_SET_ADDR
#Arguments:
#  \param params dictionary filled with the following (usually set via a global control_set in the config file)
#  - \b device_name the name of the axi slave (will be used in the dtsi_chunk file)
#  - \b axi_control dictionary of the following
#    - \b allocator dictionary of the fo llowing
#      - \b BT_name Name of the global variable for the allocator used by this control set
#  - \b addr dictionary of the addressing info for this endpoint
#    - \b offset Address (in bytes) to use for this AXI endpoint (-1 for automatic addressing)
#    - \b range in bytes of this endpoint.   (-1 for default 4K value)
#  - \b force_mem Tell the automation to connect this enpoint using its MEM interface instead of a REG interface
#
# This function allocates a space for device_name in the range controlled by the axi_control.
# If addr's members are -1, then an automatic value found, otherwise these values are used for the endpoint
proc AXI_SET_ADDR {device_name axi_control {addr_offset -1} {addr_range 64K} {force_mem 0}} {
    startgroup
    #add addressing
    if { [dict exists $axi_control allocator BT_name]} {
	set BT_name [dict get $axi_control allocator BT_name]
	global $BT_name
	upvar 0 $BT_name BT

	if {$addr_range == -1 || $addr_range == "auto"} {
	    if {($force_mem == 0) && [llength [get_bd_addr_segs ${device_name}/*Reg*]]} {
		set addr_range [get_property RANGE [get_bd_addr_segs ${device_name}/*Reg*]]
	    } elseif {($force_mem == 0) && [llength [get_bd_addr_segs ${device_name}/*Control*]]} {
		set addr_range [get_property RANGE [get_bd_addr_segs ${device_name}/*Control*]]
	    } elseif {[llength [get_bd_addr_segs ${device_name}/*Mem*]] } {
		set addr_range [get_property RANGE [get_bd_addr_segs ${device_name}/*Mem*]]
	    }
	}
	set addr_range [SanitizeVivadoSize $addr_range]
	
	if {$addr_offset == -1} {
	    #automatically find an address
	    	     
	    #get block returns a range and an updated BT
	    set ret [GetBlock $BT $addr_range]
	    #get the address (element 0)
	    set new_addr [lindex $ret 0]
	    #get the new BT (element 1)
	    set BT [lindex $ret 1]
	    if {$new_addr == -1} {
		set error_string "failed to allocate automatic address"
		error ${error_string}
	    } else {
		set addr_offset $new_addr
	    }	    
	    puts "Automatically setting $device_name address to $addr_offset : $addr_range"
	} else {
	    #we have a set address
	    set starting_address $addr_offset
	    set ending_address [expr $addr_offset + [SanitizeVivadoSize $addr_range] - 1]

	    set ret [GetBlockAtAddress $BT $starting_address $ending_address]
	    #get the address (element 0)
	    set new_addr [lindex $ret 0]
	    #get the new BT (element 1)
	    set BT [lindex $ret 1]
	    puts "I\'d allocate $addr_range at [format 0x%08X $addr_offset] ( block starting at [format 0x%08X $new_addr] )"
	    if {$new_addr == -1} {
		set error_string "failed to allocate automatic address"
		error ${error_string}
	    } else {
		set addr_offset $new_addr
	    }	    
	}

	#add the assignment to vivado
	if {($force_mem == 0) && [llength [get_bd_addr_segs ${device_name}/*Reg*]]} {
	    lappend axi_memory_mappings [assign_bd_address -verbose -range $addr_range -offset $addr_offset [get_bd_addr_segs $device_name/*Reg*]]
	} elseif {($force_mem == 0) && [llength [get_bd_addr_segs ${device_name}/*Control*]]} {
	    lappend axi_memory_mappings [assign_bd_address -verbose -range $addr_range -offset $addr_offset [get_bd_addr_segs $device_name/*Control*]]
	} elseif {[llength [get_bd_addr_segs ${device_name}/*Mem*]] } {
	    lappend axi_memory_mappings [assign_bd_address -verbose -range $addr_range -offset $addr_offset [get_bd_addr_segs $device_name/*Mem*]]
	} else {
	    set error_string "${device_name} is not of type Reg,Control, or Mem"
	    error $error_string
	}
	
	pdict $BT	
    }


    
    endgroup

}

## proc \c AXI_GEN_DTSI
#Arguments:
# \param device_name  The name of this axi endpoint
# \param remote_slave If this is set to 1, a dtsi_chunk and dtsi overlay file is generated, if 0, a dtsi_post_chunk is created
# \param manual_load_dtsi If this is 1, the output files are put in a separate directory for manual loading instaed of automatic, default is 0
# \param dt_data This is the non-address data to be added to the device tree entries.  By default it loads the device as a generic-uio device.
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

