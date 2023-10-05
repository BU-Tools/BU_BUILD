source ${BD_PATH}/utils/buddyallocation/buddy_allocator.tcl
source ${BD_PATH}/utils/pdict.tcl

## proc \c SanitizeVivadoSize
# Arguments:
#   \param value Value containing Vivado style sizes
#   \return The sanitized value ready to be used as an integer
#
# Vivado uses K & M to simplify labeling memory ranges.
# This is incompatible with use as a number, so this function removes the K/M character and replaces them with the appropriate scaling factor.
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

## proc \c CreateAllocator
# Arguments:
#   \param axi_control_name Name of the axi_control dictionary in the caller's namespace
#
# This function takes a axi_control dictionary, passed by name, and initializes its buddy allocator.
#
# The axi_control dictionary requires the following entries
#
# -> name[str][required]: name of the global axi_control dictionary
#
# -> allocator[dict][required]:
#
# ----> starting_address[number][required]: The address where this allocator will start allocating
#
# ----> size[number][required]: The size of the address range after the starting_address
#
# ----> block_size[number][optional]: The size of the smallest allocation to make (default value of 4096)
#
# This will create a global allocator named ${name}_BT
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
