## proc \c yaml_to_bd
# Arguments:
#   \param yaml_file A yaml file to load and parse for AXI_ENDPOINTS, CORES, or AXI_CONTROL_SETS
#
# This call loads a yaml file and parses it.
# It first loads any control_sets into the global namespace from the AXI_CONTROL_SETS tag.
# Then it looks for a CORE tag and loads any non-AXI IPCores listed there.
# Then it finally processes the AXI_SLAVES tag for any raw TCL commands or BD library TCL commands
proc yaml_to_bd {yaml_file} {
    global build_name
    global apollo_root_path
    global autogen_path
    global BD_PATH
    
    yaml_to_control_sets [subst $yaml_file]
    set my_huddle [yaml::yaml2huddle -file [subst $yaml_file]]

    if [catch {set cores_huddle [huddle get $my_huddle "CORES"]}] {	
	puts "No IP Cores found"
    } else {
	puts "Adding IP Cores"
	huddle_to_bd $cores_huddle ""
    }
    if [catch {set slaves_huddle [huddle get $my_huddle "AXI_SLAVES"]}] {	
	puts "No slaves found"
    } else {
	puts "Adding slaves"
	huddle_to_bd $slaves_huddle ""
    }
}


## proc \c huddle_to_bd
# Arguments:
#   \param huddle The current huddle to be parsed
#   \param parent The name of the parent of this huddle
#
# This function parses the "AXI_SLAVES" nodes of a config.yaml file
# It first checks if there is a TCL_CALL or INCLUDE_FILE key to this huddle.
#
# If it finds TCL_CALL, it processes it either as a direct TCL command, or a BD Library command with the remaining entries as arguments.
#
# If it finds INCLUDE_FILE, it will take the associated value as a yaml file to open and process
#
# Any other name is just searched through for a TCL_CALL or INCLUDE_FILE directive.
# It is convention that SUB_SLAVE is used to force TCL_CALL or INCLUDE_FILE directives to come AFTER processing the current TCL_CALL.
proc huddle_to_bd {huddle parent} {    
    foreach key [huddle keys $huddle] {
        if { 0 == [string compare "TCL_CALL" $key] } {
	    if { "string" == [huddle type $huddle $key] } {
		set command [huddle strip [huddle get $huddle $key]]
		puts "\n\n\n"
		puts "================================================================================"
		puts "Executing command from YAML: $command "
		eval $command
	    } else {
		set tcl_call_huddle [huddle get $huddle $key]
		puts $tcl_call_huddle
		
		set command "[huddle gets $tcl_call_huddle command]"
		set pairs [dict create]
		
		# set a default device name based on the node..
		# it will be overwritten later if you set device name explicitly
		dict append pairs device_name $parent
		
		foreach pairkey [huddle keys $tcl_call_huddle] {
		    if { 0 != [string compare "command" $pairkey]} {
			dict set pairs $pairkey [subst [huddle gets $tcl_call_huddle $pairkey]]
		    }}
		puts "\n\n\n"
		puts "================================================================================"
		puts "Executing command from YAML: $command \[dict create $pairs\]"
		eval $command {$pairs}
	    }	
        }
	if { 0 == [string compare "INCLUDE_FILE" $key] } {
	    #this is an include directive, load the file and move forward
	    set include_huddle [subst [huddle gets $huddle $key]]
	    puts "loading sub-YAML file: $include_huddle"
	    yaml_to_bd $include_huddle            
	}
	if { 0 == [string compare "dict" [huddle type [huddle get $huddle $key]]]} {
            huddle_to_bd [huddle get $huddle $key] $key
        }
    }
}


## proc \c yaml_to_control_sets
# Arguments:
#   \param yaml_file A yaml file to load and parse for AXI_CONTROL_SETS
#
# This function loads yaml files searching for AXI_CONTROL_SETS.
#
# Each control set consists of
#
# -> axi_interconnect: Name of the axi interconnect this control set will connect endpoints to
#
# -> axi_clk: Name of the clock to use for that connection
#
# -> axi_rstn:  Name of the reset used for that connection
#
# -> axi_freq:  frequency of the axi_clk
#
# -> axi_offset: Offset to add to allocation requests.  (Don't use this in new BDs)
#
# -> allocator: This is the info for the axi address allocation for endpoints in this interconnect
#
# ----> starting_address: Address this allocator will start from
#
# ----> size: The range of memory after the starting_address
#
# ----> block_size: The minimum allocation size for the allocator to allocate.  Smaller allocations requests are rounded up to this value.
#
proc yaml_to_control_sets {yaml_file} {
    global build_name
    global apollo_root_path
    global autogen_path
    global BD_PATH

    if { [dict exists [yaml::yaml2dict -file [subst $yaml_file]] "AXI_CONTROL_SETS"] } {
	set dict [dict get [yaml::yaml2dict -file [subst $yaml_file]] "AXI_CONTROL_SETS"]
	puts $dict
	puts "Adding AXI Control Sets"
	foreach key [dict keys $dict] {
	    puts $key
	    if { 0 == [string compare "INCLUDE_FILE" $key] } {
		#this is an include directive, load the file and move forward
		set subfile [dict get $dict $key]
		puts "loading sub-YAML file: $subfile"
		yaml_to_control_sets $subfile           
	    } else {
		#assume this is a control set
		global $key
		upvar 0 $key x ;# tie the calling value to variable x
		set x [dict get $dict $key]
		#add name so we know which control reg we are using (HUDDLE hides this later)
		dict append x name $key
		puts "========================================"
		puts "========================================"
		puts "Adding control $key"		
		if { [dict exists $x allocator] } {
		    ####################
		    #add the allocator to this object
		    ####################
		    CreateAllocator x
		    puts "Allocator"
		    puts "========================================"		    
		    pdict x
		} else {
		    puts "No allocator"
		}
		puts "========================================"
	    }
	}
    }
}
