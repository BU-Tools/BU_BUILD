source -notrace ${BD_PATH}/Cores/IP_CORE_MGT/HDL_gen_helpers.tcl
source -notrace ${BD_PATH}/Cores/IP_CORE_MGT/MGT_helpers.tcl

# return: mgt_info (old registers) (dictionary)
#           - channel_count (list): This specific call's channel count
#           - package_info (dict):
#             - name : name of the package
#             - filename : name of the file with the package
#             - records (dict):  dictionary of all the records
#               - common_input (dict): dictionary of info about this group of registers
#                 - name : record name
#                 - count : number of things of this type in IPCore
#                 - regs (list of dicts)   : list of registers for the common registers into the IP core
#                   - dictionary:
#                     - name: real name of register (in core)
#                     - alias: simplified name
#                     - dir: in vs out
#                     - MSB: msb bit position
#                     - LSB: lsb bit position (really always 0, but for future use)
#               - common_output (list of dicts)  : list of registers
#               - userdata_intput (list of dicts): list of registers for the user (data) into the IP core
#               - userdata_output (list of dicts): list of registers
#               - clocks_input (list of dicts)   : list of registers
#               - clocks_output (list of dicts)  : list of registers
#               - channel_intput (list of dicts)
#               - channel_output
proc IP_CORE_MGT {params} {
    global build_name
    global apollo_root_path
    global autogen_path

    #IPcore name
    set_required_values $params {device_name}

    #async clock for core
    set_required_values $params {freerun_frequency}

    #Parameters for the MGT core
    #False means return a full dict instead of a broken up dict
    set_required_values $params {clocking} False
    set_required_values $params {protocol} False
    set_required_values $params {links} False
    set_required_values $params {GT_TYPE}
    set_required_values $params {interface} False

#    set_optional_values $params [dict create userdata [list]]
    
    #optional configuration of what is in the IP core vs the example design
    set_optional_values $params [dict create core {LOCATE_TX_USER_CLOCKING CORE LOCATE_RX_USER_CLOCKING CORE LOCATE_RESET_CONTROLLER CORE LOCATE_COMMON EXAMPLE_DESIGN}]

    #dictionary of interface packages.  If this takes on the default value then we will build the packages and return them. 
#    set_optional_values $params [dict create interface [dict create "base_name" ""] ]

    dict create GT_TYPEs {\
			      "UNKNOWN" "\"0000\"" \
			      "GTH"     "\"0001\"" \
			      "GTX"     "\"0010\"" \
			      "GTY"     "\"0011\"" \
			  }
    
    
    #build the core
    if { $GT_TYPE == "GTX"} {
	BuildCore $device_name gtwizard
    } elseif { $GT_TYPE == "GTY"} {
	BuildCore $device_name gtwizard_ultrascale
    } elseif { $GT_TYPE == "GTH"} {
	BuildCore $device_name gtwizard_ultrascale
    } else {
	error "Unknown Xilinx transceiver type ${GT_TYPE}"
    }

    
    #####################################
    #start a list of properties
    #####################################
    dict create property_list {}

    #####################################
    #simple properties
    dict append property_list CONFIG.GT_TYPE $GT_TYPE
    dict append property_list CONFIG.FREERUN_FREQUENCY $freerun_frequency
    dict append property_list CONFIG.LOCATE_TX_USER_CLOCKING $LOCATE_TX_USER_CLOCKING
    dict append property_list CONFIG.LOCATE_RX_USER_CLOCKING $LOCATE_RX_USER_CLOCKING
    dict append property_list CONFIG.LOCATE_RESET_CONTROLLER $LOCATE_RESET_CONTROLLER
    dict append property_list CONFIG.LOCATE_COMMON $LOCATE_COMMON

    #####################################
    #add optional ports to the device
    set optional_ports [list cplllock_out eyescanreset_in eyescantrigger_in \
			    eyescandataerror_out dmonitorout_out pcsrsvdin_in \
			    rxbufstatus_out rxprbserr_out rxresetdone_out \
			    rxbufreset_in rxcdrhold_in rxdfelpmreset_in rxlpmen_in \
			    rxpcsreset_in rxpmareset_in rxprbscntreset_in \
			    rxprbssel_in rxrate_in txbufstatus_out txresetdone_out \
			    txinhibit_in txpcsreset_in txpmareset_in txpolarity_in \
			    txpostcursor_in txprbsforceerr_in txprecursor_in \
			    txprbssel_in txdiffctrl_in drpaddr_in drpclk_in \
			    drpdi_in drpen_in drprst_in drpwe_in drpdo_out \
			    drprdy_out rxctrl2_out txctrl2_in loopback_in]    
    if {[dict exists $params optional]} {
	set additional_optional_ports [dict get $params optional]
	set optional_ports [concat $optional_ports $additional_optional_ports]
	puts "Adding optional values: $additional_optional_ports"
    } else {
	puts "no additional optional values"
    }
    dict append property_list CONFIG.ENABLE_OPTIONAL_PORTS $optional_ports


    #####################################
    #clocking
    foreach {dict_key dict_value} $clocking {
	foreach {key value} $dict_value {
	    dict append property_list CONFIG.${dict_key}_${key} $value
	}
    }
    #####################################
    #protocol
    foreach {dict_key dict_value} $protocol {
	foreach {key value} $dict_value {
	    dict append property_list CONFIG.${dict_key}_${key} $value
	}
    }
    #####################################
    #links
    set enabled_links {}
    dict create rx_clocks {}
    dict create tx_clocks {}
    foreach {dict_key dict_value} $links {
	lappend enabled_links $dict_key 
	foreach {key value} $dict_value {
	    if {$key == "RX"} {
		dict append rx_clocks $dict_key $value
	    } elseif {$key == "TX"} {
		dict append tx_clocks $dict_key $value
	    }
	}
    }
    dict append property_list CONFIG.CHANNEL_ENABLE $enabled_links
    dict append property_list CONFIG.TX_REFCLK_SOURCE $tx_clocks
    dict append property_list CONFIG.RX_REFCLK_SOURCE $rx_clocks

    #####################################
    #apply all the properties to the IP Core
    #####################################
    set_property -dict $property_list [get_ips ${device_name}]
    generate_target -force {all} [get_ips ${device_name}]
    synth_ip [get_ips ${device_name}]

    #####################################
    #create a wrapper 
    #####################################

    #check that the rx and tx count match (this may need to be altered)
    set tx_count [dict size $tx_clocks]
    set rx_count [dict size $rx_clocks]
    if {$tx_count != $rx_count} {
	error "tx_count and rx_count don't match"
    }

    #####################################
    #parsing netlist from verilog file
    puts  "wrapper start"    
    #Read in the example verilog file to generate a netlist
    set example_verilog_filename [get_files -filter "PARENT_COMPOSITE_FILE == ${xci_file}" "*/synth/${device_name}.v"]
    set data [ParseVerilogComponent ${example_verilog_filename}]
    puts  "file processed"

    #####################################
    #create a dictionary of registers broken up into six catagories
    set records [dict create    \
		     "common_input"    [dict create  "count" 1 "regs" [list] ]  \
		     "common_output"   [dict create  "count" 1 "regs" [list] ]  \
		     "userdata_input"  [dict create  "count" $tx_count "regs" [list] ]  \
		     "userdata_output" [dict create  "count" $tx_count "regs" [list] ]  \
		     "clocks_input"    [dict create  "count" 1 "regs" [list] ]  \
		     "clocks_output"   [dict create  "count" 1 "regs" [list] ]  \
		     "channel_input"   [dict create  "count" $tx_count "regs" [list] ]  \
		     "channel_output"  [dict create  "count" $tx_count "regs" [list \
								 [ dict create \
								       "name" "TXRX_TYPE" \
								       "alias" "TXRX_TYPE" \
								       "dir" "output" \
								       "MSB" 3 \
								       "LSB" 0 \
								       "value" ${GT_TYPE}] \
								]\
					   ]\
		     ]
    #sort our registers into the six catagories above.
    SortMGTregsIntoPackages ${data} records $rx_count [dict get $params "clkdata"] [dict get $params "userdata"]
    
    set base_name [dict get $interface "base_name"]    
    #start the final MGT_Info data structure
    set MGT_info [dict create                            \
		      "channel_count"   $tx_count \
		      "rx_clocks"  $rx_clocks \
		      "tx_clocks"  $tx_clocks \
		     ]
    
    #####################################
    #build packages file for this
    puts "Building packages"
    if { [dict exists $interface "package_info"]} {
	#we already have this package, check that there isn't anything missing
	#check that this registers matches the generate registers for common/channel in/out
	dict append MGT_info "package_info" [dict get $interface "package_info"]
    } else {
	#build this package
	set file_path "${apollo_root_path}/${autogen_path}/HAL/${base_name}/"
	set package_info [BuildMGTPackageInfo $base_name $file_path $records]
	dict append MGT_info "package_info" $package_info
    }
    
#    set component_info {}
#    dict append channel_out TXRX_TYPE {"std_logic_vector(3 downto 0)" 4}

    dict append MGT_info "mgt_type" $GT_TYPE

    #####################################
    #write the warpper       
    set wrapper_filename "${apollo_root_path}/${autogen_path}/cores/${device_name}/${device_name}_wrapper.vhd"
    BuildMGTWrapperVHDL $device_name $wrapper_filename $MGT_info
    read_vhdl ${wrapper_filename}
    
##    for {set i $tx_count} {$i > 0} {incr i -1} {
##	puts -nonewline $wrapper_file "channel_out($i).TXRX_TYPE <= "
##	puts -nonewline $wrapper_file [dict get $GT_TYPEs $GT_TYPE]
##	puts $wrapper_file ";"
##    }
    return $MGT_info
}

