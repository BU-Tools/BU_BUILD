source ${BD_PATH}/utils/buddyallocation/buddy_allocator.tcl
source ${BD_PATH}/utils/pdict.tcl

#proc CheckAllocator {axi_control_name} {    
#    upvar $axi_control_name axi_control
#    pdict $axi_control
#    set_required_values [dict get $axi_control allocator] {starting_address size}
#    set_optional_values [dict get $axi_control allocator] [dict create block_size 4096]
#
#    #check if the buddy allocator has been created, and add it if it hasn't
#    if {![dict exists $axi_control allocator BT] } {
#	dict update axi_control allocator allocator {
#	    dict append allocator BT [CreateBuddyAllocation ${size} ${block_size} ${starting_address}]
#	}
#    }
#    pdict $axi_control
#}


proc SanitizeVivadoSize {value} {
    puts "Sanitizing $value"
    if { [string first K $value] >= 0 } {
	set pos [string first K $value]
	set value [string replace $value $pos $pos *1024]
    }
    if { [string first k $value] >= 0 } {
	set pos [string first k $value]
	set value [string replace $value $pos $pos *1024]
    }
    if { [string first M $value] >= 0 } {
	set pos [string first M $value]
	set value [string replace $value $pos $pos *1024*1024]
    }
    if { [string first m $value] >= 0 } {
	set pos [string first m $value]
	set value [string replace $value $pos $pos *1024*1024]
    }
    set value [expr $value]
    puts "Converted to $value"
    return $value
}

proc CreateAllocator {axi_control_name} {    
    upvar $axi_control_name axi_control

    set_required_values $axi_control {name}
    set_required_values [dict get $axi_control allocator] {starting_address size}
    set_optional_values [dict get $axi_control allocator] [dict create block_size 4096]

    #make sure values are "numbers", not strings.... tcl    
    set block_size [SanitizeVivadoSize $block_size]
    set starting_address [SanitizeVivadoSize $starting_address]
    set size [SanitizeVivadoSize $size]

    #set BT allocator's name
    set local_name ${name}_BT
    global $local_name
    upvar 0 $local_name BT

    #create the new buddy allocation tree
    set BT [CreateBuddyAllocation ${size} ${block_size} ${starting_address}]
    puts "Created BT $local_name"
    pdict $BT
    
    #note the name for the global variable in the control set
    dict update axi_control allocator allocator {
	dict update allocator BT_name BT_name {
	    set BT_name $local_name
	}
    }
}
