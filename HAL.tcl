package require yaml
source ${BD_PATH}/utils.tcl
source ${BD_PATH}/RegisterMap.tcl
source ${BD_PATH}/Xilinx_Cores.tcl

#This function builds all the IP cores reqeuested for the configuration of
#one FPGA Quad
#Arguments:
#  quad_channel_templates: dict of parameters for each kind of channel configuration
#  quad: diction of parameters for a specific quad
#  ip_template_info_name: the name of a variable in the calling function to return
#                         the following data into
#                            Channel_type: [list] One entry for each kind of channel in the HAL
#                              ip_cores: [list] the ipcores generated for this channel type
#                              core_channel_count: [list] number of channels in this IP core
#                              registers: [dict]
#                                common,channel,userdata,clocks_input/output: [lists of dictionaries]
#                                  list of dict for info on each register
#                                channel_count: (temp count of channels in current version of this register dict)
#                                
#                                [list of lists of dicts] a list of input/output records
#                                  for this IP that each contain a list of dictionaries that have the
#                                  register infos
#                                
proc HAL_process_quad {quad_channel_templates quad ip_template_info_name} {
    global build_name
    global apollo_root_path
    global autogen_path

    #get a link to the master dictionary of packages
    upvar $ip_template_info_name ip_template_info
    
    #    set quad_properties [dict get ${quads} ${key}]
    set quad_properties ${quad}
    
    #prepare to set up this quad
    set quad_ID    [dict get ${quad_properties}  "ID"]
    set quad_type  [dict get ${quad_properties}  "GT_TYPE"]
    set quad_name  "QUAD_${quad_type}_${quad_ID}"	
    puts "${quad_name}:"

    set channels [dict get ${quad_properties} "CHANNELS"]
    #find the number of channel templates used
    set channel_template_map [dict create]; #map of channels to templates
    set template_channel_map [dict create]; #map of tempates to channels	
    foreach channelID [dict keys ${channels}] {
	set channel [dict get ${channels} ${channelID}]
	#the default is that this channel is manually configured
	#and each manual configuration is considered unique even
	#if they are the same in the end.  To allow the system to
	#treat them as the same, use a template
	set template ${channelID}
	if [dict exists ${channel} "TEMPLATE"] {
	    #This channel references a template, so let's use that
	    set template [dict get ${channel} "TEMPLATE"]
	}
	#set this channel's template
	set channel_template_map [dict set \
				      channel_template_map \
				      ${channelID} ${template}]
	
	
	#update the map that counts number of templates used
	if [dict exists ${template_channel_map} ${template}] {
	    set existingEntry [dict get ${template_channel_map} \
				   ${template}]
	    set existingEntry [lappend existingEntry \
				   ${channelID}]
	    set template_channel_map [dict set \
					  template_channel_map \
					  ${template} ${existingEntry}]
	} else {
	    set newEntry [list ${channelID}]
	    set template_channel_map [dict set \
					  template_channel_map \
					  ${template} ${newEntry}]
	}
	
    }

    
    #build the info for each IPCore
    foreach channel_type [dict keys ${template_channel_map}] {
	#build the name for this IPCore
	set ip_name "${quad_name}_${channel_type}"
	
	#create the parameters set for these channels
	set parameters [dict create "device_name" ${ip_name}]
	if [dict exists ${quad_channel_templates} ${channel_type}] {
	    # this is based on a template
	    set parameters [dict merge \
				$parameters \
				[dict get ${quad_channel_templates} ${channel_type}]]
	}




	#setup the channels with this configuration
	set channel_of_type [dict get ${template_channel_map} ${channel_type}]
	set link_config [dict create]
	foreach channel ${channel_of_type} {
	    set channel_properties [dict get ${quad_properties} "CHANNELS" ${channel}]
	    #make sure this node has RX and TX clocks
	    if {! [dict exists ${channel_properties} "CLK_RX"]} {
		error "Quad ${quad}, Channel ${channel} is missing CLK_RX"
	    }
	    if {! [dict exists ${channel_properties} "CLK_TX"]} {
		error "Quad ${quad}, Channel ${channel} is missing CLK_TX"
	    }
	    #build a dictionary in the correctformat for this link's clocking
	    set link_config [dict set link_config \
				 ${channel} [dict create \
						 "RX" [dict get ${quad_properties} \
							   "CHANNELS" ${channel} CLK_RX] \
						 "TX" [dict get ${quad_properties} \
							   "CHANNELS" ${channel} CLK_TX]] \
				]
	}	    
	set parameters [dict set parameters "links" ${link_config}]


	
	#configure the core parameters based on if there are just CPLLs or if the QPLL is used
	set core_parameters [dict create \
				 "LOCATE_TX_USER_CLOCKING" "CORE" \
				 "LOCATE_RX_USER_CLOCKING" "CORE" \
				]
	if {[string first "QPLL" ${parameters}] == -1} {
	    set core_parameters [dict set core_parameters \
				     "LOCATE_COMMON" "EXAMPLE_DESIGN" ]
	} else {
	    set core_parameters [dict set core_parameters \
				     "LOCATE_COMMON" "CORE" ]
	}	    
	set parameters [dict set parameters "core" \
			    ${core_parameters}]

	if { [dict exists $ip_template_info ${channel_type} ] } {
	    puts "Template ${channel_type} already exists, using it\n\n\n\n"
	    #this template's registers have already been worked out
	    set parameters [dict set parameters "interface" [dict create "base_name" $channel_type \
								 "registers" [dict get $ip_template_info ${channel_type} "registers"] ] ]
	    #build the MGT core without new packages
	    set results [BuildMGTCores $parameters]
	    
	    dict update ip_template_info ${channel_type} temp_value {
		#add this ip core's name for this quad + template to the list
		dict lappend temp_value "ip_cores" ${ip_name}
		#add this ip core's channel count to the list
		dict lappend temp_value "core_channel_count" [dict get $results "channel_count"]
	    }
	} else {
	    puts "Template ${channel_type} doesn't exists, creating it\n\n\n\n"
	    set parameters [dict set parameters "interface" [dict create "base_name" $channel_type]]
	    #Build the MGT core
	    set results [BuildMGTCores $parameters]
	    #create an entry in the ip_template_info dictionary for this template.
	    #it will include these registers that were created (as this is the first for $template)
	    #it will also include (ip_cores) this ip core's name for this quad + template
	    #it will also include (core_channel_count) the number of channels in this quad+template
	    dict set ip_template_info ${channel_type} \
		[dict create \
		     "registers" ${results} \
		     "ip_cores" [list ${ip_name}] \
		     "core_channel_count" [list [dict get $results "channel_count"]]]	    
	}
    }
}

proc BuildTypeXML {file_path type_name channel_count common_count common_xml_file channel_xml_file} {
    global build_name
    global apollo_root_path
    global autogen_path

    set out_file [open "${file_path}/${type_name}_top.xml" w]
    puts $out_file "<node id=\"${type_name}\">\n"
    set address 0

    #process the commons for this type
    for {set quad_common_count 1} {$quad_common_count <= $common_count} {incr quad_common_count} {
	#add each channels module
	puts $out_file [format \
			    "  <node id=\"%s\"   address=\"0x%08X\" fw_info=\"type=array\" module=\"file://%s\"/>\n" \
			    "COMMON_${quad_common_count}" \
			    $address \
			    "${type_name}/${common_xml_file}.xml" ]
	set address [expr ${address} + 0x10]
			    
	    
    }

    #round the address up to an even multiple of the channel size
    if { [expr ${address} % 0x100] != 0} {
	set address [expr int(ceil(${address}/0x100)) * 0x100]
    }

    #process the channels for this type
    foreach quad_channel_count $channel_count {
	#add each channels module
	for {set iChan 0} {$iChan <= $quad_channel_count} {incr iChan} {
	    puts $out_file [format \
				"  <node id=\"%s\"   address=\"0x%08X\" fw_info=\"type=array\" module=\"file://%s\"/>\n" \
				"CHANNEL_${iChan}" \
				$address \
				"${type_name}/${channel_xml_file}.xml" ]	    
	    set address [expr ${address} + 0x100]
	}
    }
    puts $out_file "</node>"
    close $out_file
}

#################################################################################
## Register map connections
#################################################################################

#connect up one register signal 
proc ConnectUpMGTReg {outfile channel_type record_type index register} {
    set alias [dict get $register "alias"]
    set dir   [dict get $register "dir"]		       			
    if { [string first ${dir} "_input"] > 0 } {
	set left_name  [format "%s(%d).%s" \
			    "${channel_type}_${record_type}" \
			    ${index} \
			    ${alias} ]
	set right_name [format "%s(%d).%s" \
			    "Ctrl_${channel_type}" \
			    ${index} \
			    ${alias} ]
    } else {
	set right_name  [format "%s(%d).%s" \
			     "${channel_type}_${record_type}" \
			     ${index} \
			     ${alias} ]
	set left_name [format "%s(%d).%s" \
			   "Mon_${channel_type}" \
			   ${index} \
			   ${alias} ]
    }
    puts -nonewline ${outfile} [format "   %-70s <= %s;\n" $left_name $right_name]
}

#connect up the register signals from a record
proc ConnectUpMGTRegMap {outfile channel_type record_types ip_registers start_index end_index} {
    #loop over all of the dictionaries in the ip_registers dictionary
    foreach record_type $record_types {
	set type_registers [dict get $ip_registers $record_type]

	#Loop over index
	for {set loop_index $start_index} {$loop_index <= $end_index} {incr loop_index} {
	    foreach register $type_registers {
		ConnectUpMGTReg $outfile $channel_type $record_type $loop_index $register
	    }	
	}
	
    }
}

proc GenerateMGTInstance {outfile ip_core channel_type package_files start_index end_index} {
    puts -nonewline ${outfile} "  ${ip_core}_inst : entity work.${ip_core}_wrapper\n"
    puts -nonewline ${outfile} "    port map (\n"
    set line_ending ""
    #loop over all the interface packages for this IP core wrapper
    foreach package_file $package_files {
	set package_name [lindex $package_file 0]
	set package_file [lindex $package_file 1]		
	puts -nonewline ${outfile} [format "%s%*s => %s(% 3d downto % 3d)" \
					 $line_ending \
					 "50" \
					 $package_name \
					 "${channel_type}_${package_name}" \
					 $end_index \
					 $start_index \
					]
	set line_ending ";\n"		
    }
    puts -nonewline ${outfile} "    );\n\n\n"
1}   



proc InstantiateMGTGroup {} {
    
}


#This function is the primary call to build a HAL (hardware abstraction layer) hdl file
#  (and associated IPCores and decoders) for the MGT links on the FPGA
proc BuildHAL {hal_yaml_file} {    
    #Global build names
    global build_name
    global apollo_root_path
    global autogen_path

    
    #TODO: do a test for modification time between config yaml file and output products,
    # so we can skip this step if it has already been run.
      
    puts "Building HAL from config file: ${hal_yaml_file}"
    
#    set quad_common_template   [dict get [yaml::yaml2dict -file ${hal_yaml_file}] "COMMON_SETS"]
    set quad_channel_templates [dict get [yaml::yaml2dict -file ${hal_yaml_file}] "CHANNEL_SETS"]
    set quads                  [dict get [yaml::yaml2dict -file ${hal_yaml_file}] "QUADS"]
    
    set ip_template_info [dict create]

    
    #process all the requested channels and build the IP cores for all the quads requested
    #build vhdl packages for their interfaces
    foreach quad ${quads} {
	HAL_process_quad $quad_channel_templates $quad ip_template_info       	
    }
    
    #figure out how many ip core types we have and how many channels of each type
    set type_count [dict size $ip_template_info]
    set type_channel_counts [dict create]
    set type_common_counts [dict create]
    dict for {channel_type ip_info} $ip_template_info {
	set registers [dict get $ip_info "registers"]
	dict set type_channel_counts $channel_type [ladd [dict get $ip_info "core_channel_count" ] ]
	dict set type_common_counts $channel_type [llength [dict get $ip_info "core_channel_count" ] ]
    }

    
    #build the final xml files
    dict for {channel_type ip_info} $ip_template_info {
	set registers [dict get $ip_info "registers"]
	#find all the command and channel xml files
	foreach xml_filename [dict get $ip_info "registers" "xml_files"] {
	    if {[string first "common" [lindex $xml_filename 0] ] == 0} {
		set xml_file_common [lindex $xml_filename 1]
	    }
	    if {[string first "channel" [lindex $xml_filename 0] ] == 0} {
		set xml_file_channel [lindex $xml_filename 1]
	    }
	}
	
	BuildTypeXML \
	    "${apollo_root_path}/${autogen_path}/HAL/" \
	    $channel_type \
	    [dict get $type_channel_counts ${channel_type} ] \
	    [dict get $type_common_counts ${channel_type} ] \
	    ${xml_file_common} \
	    ${xml_file_channel}
	
    }


    #run the regmap helper for these cores
    dict for {channel_type ip_info} $ip_template_info {
	set reg_params [dict create \
			    device_name ${channel_type} \
			    xml_path "${apollo_root_path}/${autogen_path}/HAL/${channel_type}_top.xml" \
			    out_path "${apollo_root_path}/${autogen_path}/HAL/${channel_type}/" \
			    simple True \
			    verbose True \
			   ]
	GenerateRegMap ${reg_params}
    }




    #Start generating the HAL vhdl file
    set HAL_file [open "${apollo_root_path}/${autogen_path}/HAL/HAL.vhd" w]    
    puts -nonewline ${HAL_file} "library ieee;\n"
    puts -nonewline ${HAL_file} "use ieee.std_logic_1164.all;\n\n"
    puts -nonewline ${HAL_file} "use work.axiRegPkg.all;\n"


    #Add all the packages we will need    
    dict for {channel_type ip_info} $ip_template_info {
	set registers [dict get $ip_info "registers"]
	foreach package_file [dict get $registers "package_files"] {
	    set package_name [lindex $package_file 0]
	    set package_file [lindex $package_file 1]
	    puts -nonewline ${HAL_file} "use work.${package_file}.all;\n"	
	}
    }


    
    #add basic entity
    puts -nonewline ${HAL_file} "entity HAL is\n"
    puts -nonewline ${HAL_file} "  port (\n"
    puts -nonewline ${HAL_file} "                                 clk_axi : in  std_logic;\n"
    puts -nonewline ${HAL_file} "                             reset_axi_n : in  std_logic;\n"
    puts -nonewline ${HAL_file} "                                readMOSI : in  AXIreadMOSI_array_t (${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                                readMISO : out AXIreadMISO_array_t (${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                               writeMOSI : in  AXIwriteMOSI_array_t(${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                               writeMISO : out AXIwriteMISO_array_t(${type_count} - 1 downto 0);\n"

    set AXI_array_index 0
    
    #finish entity port map
    set line_ending ""
    dict for {channel_type ip_info} $ip_template_info {
	set registers [dict get $ip_info "registers"]
	foreach package_file [dict get $registers "package_files"] {
	    set package_name [lindex $package_file 0]
	    set package_file [lindex $package_file 1]
	    if {[string first "userdata" ${package_name}] == 0 } {
		#only route out userdata, other packages are internal/via axi
		set dir "in "
		if { [string first "_output" $package_name] >= 0 } {
		    set dir "out"
		}
		puts -nonewline ${HAL_file} [format "%s%40s : %3s %s" \
				     $line_ending \
				     "${channel_type}_${package_name}" \
				     $dir \
				     ${package_file}]
		set line_ending ";\n"
	    }
	}
    }
    puts -nonewline ${HAL_file} ");\n"
    puts -nonewline ${HAL_file} "end entity HAL;\n\n\n"
    puts -nonewline ${HAL_file} "architecture behavioral of HAL is\n"

    #write the local signals needed to route ip core packages
    dict for {channel_type ip_info} $ip_template_info {
	set registers [dict get $ip_info "registers"]
	foreach package_file [dict get $registers "package_files"] {	   
	    set package_name [lindex $package_file 0]
	    set package_file [lindex $package_file 1]
	    if {[string first "userdata" ${package_name}] < 0 } {
		#we don't need local copies of userdata signals
		puts -nonewline ${HAL_file} [format "  signal %40s : %s(%s-1 downto 0);\n" \
				     "${channel_type}_${package_name}" \
				     "${channel_type}_${package_name}_array_t"\
				     [dict get $type_channel_counts $channel_type] ]
	    }
	}
	puts -nonewline ${HAL_file} "\n\n"
    }
  
    #Generate all the ip cores, grouped by type
    puts -nonewline ${HAL_file} "begin\n"
    dict for {channel_type ip_info} $ip_template_info {
	#per IP starting offset
	set current_offset 0
	set max_offset [dict get $type_channel_counts $channel_type]
	
	set registers [dict get $ip_info "registers"]
	set ip_cores  [dict get $ip_info "ip_cores"]
	puts -nonewline ${HAL_file} "--------------------------------------------------------------------------------\n"
	puts -nonewline ${HAL_file} "--${channel_type}\n"
	puts -nonewline ${HAL_file} "--------------------------------------------------------------------------------\n"

	GenerateRegMapInstance $channel_type ${AXI_array_index} ${HAL_file}
	set AXI_array_index [expr ${AXI_array_index} + 1]
	
	for {set iCore 0} {$iCore < [dict get $type_common_counts $channel_type]} {incr iCore} {
	    #check that the range for this ipcore in the array of packages makes sense 
	    set ending_offset [expr $current_offset + [lindex [dict get $ip_info "core_channel_count"] $iCore] -1]
	    if {$ending_offset >= ${max_offset} } {
		error "When building IP core $ip_core the channel offset ($ending_offset) was larger than the max channel offset ($max_offset)"		
	    }
	    #generate the IP Core instance
	    puts $registers
	    GenerateMGTInstance \
		${HAL_file} \
		[lindex [dict get $ip_info "ip_cores"] $iCore] \
		${channel_type} \
		[dict get $registers "package_files"] \
		$current_offset \
		$ending_offset
	    

	    #connect up all the common per-quad register signals
	    ConnectUpMGTRegMap \
		${HAL_file} $channel_type \
		"common_input common_output" \
		[dict get $ip_info "registers"] \
		$iCore $iCore
	    #connect up all the perchannel register signals
	    ConnectUpMGTRegMap \
		${HAL_file} $channel_type \
		"channel_input channel_output" \
		[dict get $ip_info "registers"] \
		$current_offset $ending_offset
	    
	    
	    #move to the next group of signals
	    set current_offset [expr $ending_offset + 1]
	}
	puts -nonewline ${HAL_file} "\n  );\n"
	
    }

    puts -nonewline ${HAL_file} "end architecture behavioral;\n"
	
       	
#    puts "HAL HDL begin:\n"
#    puts $HAL_data
    #    puts "HAL HDL end:\n"
    close $HAL_file
#    read_vhdl "${apollo_root_path}/${autogen_path}/HAL/HAL.vhd"

    pdict $ip_template_info
}
