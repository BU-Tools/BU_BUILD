source -notrace ${BD_PATH}/axi_helpers.tcl

proc CheckExists { source_dict keys } {
    set missing_elements False

    foreach key $keys {
	if {! [dict exists $source_dict $key] } {
	    puts "Missing key $key"
	    set missing_elements True
	}    
    }
    if { $missing_elements == True} {
	error "Dictionary missing required elements"
    }
}


#################################################################################
## Function to simplify the creation of Xilnix IP cores
#################################################################################
proc BuildCore {device_name core_type} {
    global build_name
    global apollo_root_path
    global autogen_path

    set output_path ${apollo_root_path}/${autogen_path}/cores/    
    
    #####################################
    #delete IP if it exists
    #####################################    
    if { [file exists ${output_path}/${device_name}/${device_name}.xci] } {
	file delete -force ${output_path}/${device_name}
    }

    #####################################
    #create IP            
    #####################################    

    file mkdir ${output_path}

    #delete if it already exists
    if { [get_ips -quiet $device_name] == $device_name } {
	export_ip_user_files -of_objects  [get_files ${device_name}.xci] -no_script -reset -force -quiet
	remove_files  ${device_name}.xci
    }
    #create
    puts $core_type
    puts $device_name
    puts $output_path
    create_ip -vlnv [get_ipdefs -filter "NAME == $core_type"] -module_name ${device_name} -dir ${output_path}
    #put xci_file in the scope of the calling function
    upvar 1 xci_file x
    set x [get_files ${device_name}.xci]    
}



#################################################################################
## Xilinx ILA core
#################################################################################
source -notrace ${BD_PATH}/Cores/IP_CORE_ILA/IP_CORE_ILA.tcl

#################################################################################
## Build Xilinx MGT IP wizard cores
#################################################################################
source -notrace ${BD_PATH}/Cores/IP_CORE_MGT/IP_CORE_MGT.tcl


#################################################################################
## Build xilinx FIFO IP
#################################################################################
source -notrace ${BD_PATH}/Cores/IP_CORE_FIFO/IP_CORE_FIFO.tcl

#################################################################################
## Build xilinx clocking wizard ip
#################################################################################
source -notrace ${BD_PATH}/Cores/IP_CORE_ClockWizard/IP_CORE_ClockWizard.tcl

#################################################################################
## Build xilinx sys reset ip
#################################################################################
source -notrace ${BD_PATH}/Cores/IP_CORE_SYS_RESET/IP_CORE_SYS_RESET.tcl

##proc Build_iBERT {params} {
##    global build_name
##    global apollo_root_path
##    global autogen_path
##
##    set_required_values $params {device_name}
##    set_required_values $params {links}
##
##    #build the core
##    BuildCore $device_name in_system_ibert
##
##   #links
##    set_property CONFIG.C_GTS_USED ${links} [get_ips ${device_name}]
##
##    #CONFIG.C_ENABLE_INPUT_PORTS {false}] [get_ips in_system_ibert_0]
##}
