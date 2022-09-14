

proc IP_CORE_FIFO {params} {
    global build_name
    global apollo_root_path
    global autogen_path

    set_required_values $params {device_name}
    set_required_values $params {Input} False
    set_required_values $params {Output} False
    set_required_values $params Type

    #build the core
    BuildCore $device_name fifo_generator
	
    #start a list of properties
    dict create property_list {}
    
    #do some more checking
    CheckExists $Input {Width Depth}
    CheckExists $Output {Width Depth}

    #handle input side settings
    dict append property_list CONFIG.Input_Data_Width [dict get $Input Width]
    dict append property_list CONFIG.Input_Depth      [dict get $Input Depth]
    dict append property_list CONFIG.Output_Data_Width [dict get $Output Width]
    dict append property_list CONFIG.Output_Depth      [dict get $Output Depth]
    if { [dict exists $Output Valid_Flag] } {
	dict append property_list CONFIG.Valid_Flag    {true}
    }
    if { [dict exists $Output Fall_Through] } {
	dict append property_list CONFIG.Performance_Options {First_Word_Fall_Through}
    }
    dict append property_list CONFIG.Fifo_Implementation $Type

    #apply all the properties to the IP Core
    set_property -dict $property_list [get_ips ${device_name}]
    generate_target -force {all} [get_ips ${device_name}]
    synth_ip [get_ips ${device_name}]
}
