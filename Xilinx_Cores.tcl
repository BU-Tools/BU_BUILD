source -notrace ${BD_PATH}/axi_helpers.tcl
source -notrace ${BD_PATH}/HDL_gen_helpers.tcl

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
proc BuildILA {params} {
    global build_name
    global apollo_root_path
    global autogen_path

    set_required_values $params {device_name}
    set_required_values $params {probes} False
    set_optional_values $params [dict create EN_STRG_QUAL 1  ADV_TRIGGER false ALL_PROBE_SAME_MU_CNT 2 ENABLE_ILA_AXI_MON false MONITOR_TYPE Native ]

    #build the core
    BuildCore $device_name ila


    #start a list of properties
    dict create property_list {}

    #add parameters
    dict append property_list CONFIG.C_EN_STRG_QUAL          $EN_STRG_QUAL
    dict append property_list CONFIG.C_ADV_TRIGGER           $ADV_TRIGGER
    dict append property_list CONFIG.ALL_PROBE_SAME_MU_CNT   $ALL_PROBE_SAME_MU_CNT
    dict append property_list CONFIG.C_ENABLE_ILA_AXI_MON    $ENABLE_ILA_AXI_MON
    dict append property_list CONFIG.C_MONITOR_TYPE          $MONITOR_TYPE

    #====================================
    #Parse the probes.
    #====================================
    #set the count of probes
    set probe_count 0
    #build each probe
    dict for {probe probe_info} $probes {
	#set the probe count to the max in the list
	if { $probe > $probe_count } {	    
	    set probe_count $probe
	}
	dict for {key value} $probe_info {
	    if {$key == "TYPE"} {
                # type is 0: data & trigger, 1 data only, 2 trigger only
		dict append property_list CONFIG.C_PROBE${probe}_TYPE $value
	    } elseif {$key == "WIDTH"} {		
		dict append property_list CONFIG.C_PROBE${probe}_WIDTH $value
	    } elseif {$key == "MU_CNT"} {		
		dict append property_list CONFIG.C_PROBE${probe}_MU_CNT $value
	    }
	}
    }
    #probes start from 0, so add 1
    set probe_count [expr $probe_count + 1]

    dict append property_list CONFIG.C_NUM_OF_PROBES $probe_count
    
    #apply all the properties to the IP Core
    set_property -dict $property_list [get_ips ${device_name}]
    generate_target -force {all} [get_ips ${device_name}]
    synth_ip [get_ips ${device_name}]
    
}


#################################################################################
## Build Xilinx MGT IP wizard cores
#################################################################################
proc BuildMGTCores {params} {
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
    set registers  [dict create \
			"channel_count"   [list $tx_count] \
			"common_input"    {}  \
			"common_output"   {}  \
			"userdata_input"  {}  \
			"userdata_output" {}  \
			"clocks_input"    {}  \
			"clocks_output"   {}  \
			"channel_input"   {}  \
			"channel_output"  [lappend [dict create  \
							"name" "TXRX_TYPE" \
							"alias" "TXRX_TYPE" \
							"dir" "output" \
							"MSB" 3 \
							"LSB" 0] \
					      ] \
		       ]
    #sort our registers into the six catagories above.
    SortMGTregsIntoPackages ${data} registers $rx_count [dict get $params "clkdata"] [dict get $params "userdata"]


    set base_name [dict get $interface "base_name"]
    puts $base_name    
    #####################################
    #build packages file for this
    puts "Building packages"
    if { [dict exists $interface "registers"]} {
	#we already have this package, check that there isn't anything missing
	#check that this registers matches the generate registers for common/channel in/out
	set registers [dict get $interface "registers"]
	set registers [dict set registers "channel_count" [list $tx_count]]
    } else {
	#build this  package
	#No existing register map exists, create it.
	#create this pkg file
	set file_path "${apollo_root_path}/${autogen_path}/HAL/${base_name}/"
	file mkdir $file_path
	set file_base "${base_name}"
	set outfile [open "${file_path}/${file_base}_PKG.vhd" w]
	StartPackage ${outfile} ${file_base}
	#note the name of this package for the wrapper
	dict lappend registers "package_files" [list "full" "${file_base}_PKG"]

	foreach module "common_input common_output clocks_input clocks_output channel_input channel_output userdata_input userdata_output" {	    
	    
	    set regs [dict get $registers $module]
	    #	    WritePackage2 ${outfile} ${file_base} ${regs}	    
	    WritePackageRecord ${outfile} ${file_base} ${regs}
	}
	EndPackage ${outfile} ${file_base}
	close $outfile
	puts "pkg file ${file_path}/${file_base}_PKG.vhd"
	read_vhdl "${file_path}/${file_base}_PKG.vhd"	    	    

	#create an xml file for this device
	#	foreach module "common_input common_output channel_input channel_output" {	    }
	foreach module "common channel" {	    
	    #create this xml file
	    set file_path "${apollo_root_path}/${autogen_path}/HAL/${base_name}/"
	    file mkdir $file_path
	    set file_base "${base_name}_${module}"
	    set outfile [open "${file_path}/${file_base}.xml" w]	    
	    #note the name of this package for the wrapper
	    dict lappend registers "xml_files" [list $module "${file_base}"]
	    set regs [list]
	    foreach dir "input output" {
		if { [dict exists $registers "${module}_${dir}"] } {
		    if { [llength [dict get $registers "${module}_${dir}"] ] > 0 } {
			#lappend regs [dict get $registers "${module}_input"]
			set regs [list {*}$regs {*}[dict get $registers "${module}_${dir}"]]
		    }
		}
	    }
	    BuildXMLAddressTable ${outfile} ${file_base} ${regs}
	    close $outfile
	}
    }
    
#    set component_info {}
#    dict append channel_out TXRX_TYPE {"std_logic_vector(3 downto 0)" 4}


    

    #####################################
    #write the warpper       
    set wrapper_filename "${apollo_root_path}/${autogen_path}/cores/${device_name}/${device_name}_wrapper.vhd"
    set wrapper_file [open ${wrapper_filename} w]
    puts "Wrapper file: ${wrapper_filename}"

    set line_ending ""; #useful for vhdl lists that can't end with the separator character
    puts $wrapper_file "library ieee;"
    puts $wrapper_file "use ieee.std_logic_1164.all;\n"
    foreach module_package [dict get $registers "package_files"] {
	set package_name [lindex $module_package 0]
	set package_file [lindex $module_package 1]
	puts $wrapper_file "use work.${package_file}.all;"	
    }
    puts $wrapper_file "entity ${device_name}_wrapper is\n"
    puts $wrapper_file "  port ("
    set line_ending ""
    foreach module_package [dict get $registers "package_files"] {
	set package_name [lindex $module_package 0]
	set package_file [lindex $module_package 1]
	if { [string first "_input" $package_name] >= 0 } {
	    set dir "in "
	} else {
	    set dir "out"
	}
	if { [string first "channel" ${package_name}] == 0 ||
	     [string first "userdata" ${package_name}] == 0 } {
	    puts -nonewline $wrapper_file "${line_ending}\n    ${package_name}   : $dir  ${base_name}_${package_name}_array_t(${rx_count}-1 downto 0)"
	} else {
	    puts -nonewline $wrapper_file "${line_ending}\n    ${package_name}   : $dir  ${base_name}_${package_name}_t"
	}

	set line_ending ";"
    }
    puts $wrapper_file "    );"
    puts $wrapper_file "end entity ${device_name}_wrapper;\n"
    puts $wrapper_file "architecture behavioral of ${device_name}_wrapper is"



    set component_data ""
    set entity_data ""
    set component_line_ending ""
    set entity_line_ending ""
    foreach module "common_input common_output clocks_input clocks_output channel_input channel_output userdata_input userdata_output" {
	foreach signal [dict get ${registers} ${module}] {
	    #pull needed values from the dictionary
	    set name [dict get $signal "name"]
	    set alias [dict get $signal "alias"]
	    set dir  [dict get $signal "dir"]
	    #update input/output to vhdl in/out
	    if { $dir == "input" } {
		set dir "in "
	    } else {
		set dir "out"
	    }
	    set MSB [dict get $signal "MSB"]
	    set LSB [dict get $signal "LSB"]

	    if { [string first "channel" ${module}] == 0 ||
		 [string first "userdata" ${module}] == 0 } {

		if { $dir == "in "} {
		    #the size of these are per channel,so we need to update MSB and LSB
		    set width [expr (1+ $MSB - $LSB)*$rx_count]		
		    set MSB [expr $LSB + $width - 1]
		    #entity lines
		    append entity_data [format "%s%40s(% 3u downto % 3u) => (" \
					    ${entity_line_ending} \
					    ${name} \
					    ${MSB} \
					    ${LSB} ]
		    set array_ending "\n"
		    #fill out the assignment with "&" of the package member
		    for {set iChannel [expr $rx_count -1]} {$iChannel >= 0} {incr iChannel -1} {
			append entity_data [format "%s%*s %s(% 3d).%s" \
						${array_ending} \
						"60" \
						" " \
						${module} \
						${iChannel} \
						${alias}]
			set array_ending " & \n"
		    }
		    append entity_data  ")"
		} else {
		    set bottom_index 0
		    set width [expr ($MSB - $LSB + 1)]
		    for {set iChannel [expr $rx_count -1]} {$iChannel >= 0} {incr iChannel -1} {			
			append  entity_data [format "%s%40s(% 3u downto % 3u) => %*s %s(% 3u).%s" \
						 ${entity_line_ending} \
						 ${name} \
						 [expr $iChannel * $width ]\
						 [expr (($iChannel + 1) * $width) -1]\
						 "60" \
						 " " \
						 ${module} \
						 ${iChannel} \
						 ${alias}]
			
		    }
		    
		}
		
	    } else {
		
		append entity_data [format "%s%40s(% 3u downto % 3u) => %s.%s" \
					${entity_line_ending} \
					${name} \
					$MSB \
					$LSB \
					${module} \
					${alias} ]
	    }
	    set entity_line_ending ",\n"

	    
	    # ${line_ending} is used because VHDL can't handle the last line in a list having the separation character
	    append component_data [format "%s%40s : %3s std_logic_vector(% 3u downto % 3u)" \
				       ${component_line_ending}\
				       ${name} \
				       ${dir} \
				       $MSB \
				       $LSB ]
	    set component_line_ending ";\n"
	}
    }

    #####################################
    #component declaration for verilog interface    
    puts $wrapper_file "component ${device_name}"
    puts $wrapper_file "  port("
    puts $wrapper_file ${component_data}
    puts $wrapper_file "  );"
    puts $wrapper_file "END COMPONENT;"


    #####################################
    #component declaration for verilog interface    
    puts $wrapper_file "begin"
    puts $wrapper_file "${device_name}_inst : entity work.${device_name}"
    puts $wrapper_file "  port map ("
    puts $wrapper_file ${entity_data}
    puts $wrapper_file ");"    
    puts $wrapper_file "end architecture behavioral;"
    close $wrapper_file
    read_vhdl ${wrapper_filename}
    
##    for {set i $tx_count} {$i > 0} {incr i -1} {
##	puts -nonewline $wrapper_file "channel_out($i).TXRX_TYPE <= "
##	puts -nonewline $wrapper_file [dict get $GT_TYPEs $GT_TYPE]
##	puts $wrapper_file ";"
##    }
    return $registers
}


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
## Build xilinx FIFO IP
#################################################################################
proc BuildFIFO {params} {
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

#################################################################################
## Build xilinx clocking wizard ip
#################################################################################
proc BuildClockWizard {params} {
    global build_name
    global apollo_root_path
    global autogen_path

    set_required_values $params {device_name}
    set_required_values $params {in_clk_type}
    set_required_values $params {in_clk_freq_MHZ}
    set_required_values $params {out_clks} False

    #build the core
    BuildCore $device_name clk_wiz


    #start a list of properties
    dict create property_list {}

    #add parameters
    dict append property_list CONFIG.PRIM_SOURCE             ${in_clk_type}
    dict append property_list CONFIG.PRIM_IN_FREQ            ${in_clk_freq_MHZ}
    dict append property_list CONFIG.PRIMARY_PORT            ${device_name}_[]

    #====================================
    #Parse the output clocks
    #====================================
    #set the count of probes
    set clk_count 0
    #build each probe
    dict for {clk clk_freq} $out_clks {
	#set the probe count to the max in the list
	if { $clk > $clk_count } {	    
	    set clk_count $clk
	}
	if {$clk == 0} {
	    error "clk == 0 is not allowed, numbering starts at 1"
	}

	#set out clock name
	dict append property_list CONFIG.CLK_OUT${clk}_PORT clk_[string map {"." "_"} ${clk_freq}]MHz
	#set out clock frequency
	dict append property_list CONFIG.CLKOUT${clk}_REQUESTED_OUT_FREQ ${clk_freq}

	#set the clock to be used (clk 1 is assumed used)
	if {$clk > 1} {
	    dict append property_list CONFIG.CLKOUT${clk}_USED true
	}
    }

    dict append property_list CONFIG.NUM_OUT_CLKS $clk_count
    
    #apply all the properties to the IP Core
    set_property -dict $property_list [get_ips ${device_name}]
    generate_target -force {all} [get_ips ${device_name}]
    synth_ip [get_ips ${device_name}]
    
}


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
