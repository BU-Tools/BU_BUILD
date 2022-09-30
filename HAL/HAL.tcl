package require yaml
source ${BD_PATH}/utils/pdict.tcl
source ${BD_PATH}/Regmap/RegisterMap.tcl
source ${BD_PATH}/Cores/Xilinx_Cores.tcl
source ${BD_PATH}/HAL/HAL_helpers.tcl

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
#                              mgt_info: [dict] (from Xilinx_Cores.tcl, IP_CORE_MGT)


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
    set template_channel_map [dict create]; #map of tempates to channels	
    foreach channelID [dict keys ${channels}] {
	puts "  Channel: $channelID"
	set current_channel [dict get ${channels} ${channelID}]
	#the default is that this channel is manually configured
	#and each manual configuration is considered unique even
	#if they are the same in the end.  To allow the system to
	#treat them as the same, use a template
	set template_name ${channelID}
	if [dict exists ${current_channel} "TEMPLATE"] {
	    #This channel references a template, so let's use that
	    set template_name [dict get ${current_channel} "TEMPLATE"]
	}
	
	
	
	#update the map that counts number of templates used
	if [dict exists ${template_channel_map} ${template_name}] {
	    set existing_template_list [dict get ${template_channel_map} ${template_name}]
	    lappend existing_template_list ${channelID}
	    dict set \
		template_channel_map \
		${template_name} ${existing_template_list}
	} else {
	    set new_template_list [list ${channelID}]
	    dict set \
		template_channel_map \
		${template_name} ${new_template_list}
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
	    set results [IP_CORE_MGT $parameters]
	    
	    dict update ip_template_info ${channel_type} temp_value {
		#add this ip core's name for this quad + template to the list
		dict lappend temp_value "ip_cores" ${ip_name}
		#asdf
		dict update temp_value "toplevel_regs" toplevel_regs { dict append toplevel_regs $ip_name  [dict get $results "toplevel_regs"]}
		#add this ip core's channel count to the list
		dict lappend temp_value "core_channel_count" [dict get $results "channel_count"]
		dict update temp_value "rx_clocks" rx_clocks { dict append rx_clocks $ip_name [dict create $quad_ID [dict get $results "rx_clocks"]]}
		dict update temp_value "tx_clocks" tx_clocks { dict append tx_clocks $ip_name [dict create $quad_ID [dict get $results "tx_clocks"]]}
		
	    }
	} else {
	    puts "Template ${channel_type} doesn't exists, creating it\n\n\n\n"
	    set parameters [dict set parameters "interface" [dict create "base_name" $channel_type]]
	    #Build the MGT core
	    puts "IP_CORE_MGT $parameters"
	    set results [IP_CORE_MGT $parameters]
	    #create an entry in the ip_template_info dictionary for this template.
	    #it will include these registers that were created (as this is the first for $template)
	    #it will also include (ip_cores) this ip core's name for this quad + template
	    #it will also include (core_channel_count) the number of channels in this quad+template
	    dict set ip_template_info ${channel_type} \
		[dict create \
		     "registers" ${results} \
		     "toplevel_regs" [dict create $ip_name [dict get $results "toplevel_regs"]] \
		     "ip_cores" [list ${ip_name}] \
		     "core_channel_count" [list [dict get $results "channel_count"]] \
		     "rx_clocks" [dict create $ip_name [dict create $quad_ID [dict get $results "rx_clocks"]]] \
		     "tx_clocks" [dict create $ip_name [dict create $quad_ID [dict get $results "tx_clocks"]]]\ 

		]
	    puts "newly created: $ip_template_info"
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
    for {set quad_common_count 0} {$quad_common_count < $common_count} {incr quad_common_count} {
	#add each channels module
	puts $out_file [format \
			    "  <node id=\"%s\"   address=\"0x%08X\" fwinfo=\"type=array\" module=\"file://%s\"/>\n" \
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
				"  <node id=\"%s\"   address=\"0x%08X\" fwinfo=\"type=array\" module=\"file://%s\"/>\n" \
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
    set MSB   [dict get $register "MSB"]
    set LSB   [dict get $register "LSB"]

    set vec_convert ""
    if { [expr $MSB - $LSB] == 0 } {
	set vec_convert "(0)"
    }
    if { [string first ${dir} "_input"] > 0 } {
	set left_name  [format "%s(%d).%s%s" \
			    "${channel_type}_${record_type}" \
			    ${index} \
			    ${alias} \
			    ${vec_convert} \
			    ]
	set right_name [format "%s.%s(%d).%s" \
			    "Ctrl_${channel_type}" \
			    [string map {"_input" "" } ${record_type} ] \
			    ${index} \
			    ${alias} ]
    } else {
	set right_name  [format "%s(%d).%s%s" \
			     "${channel_type}_${record_type}" \
			     ${index} \
			     ${alias} \
			     ${vec_convert} \
			     ]
	set left_name [format "%s.%s(%d).%s" \
			   "Mon_${channel_type}" \
			   [string map {"_output" "" } ${record_type} ] \
			   ${index} \
			   ${alias} ]
    }
    puts -nonewline ${outfile} [format "   %-70s <= %s;\n" $left_name $right_name]
}

#connect up the register signals from a record
proc ConnectUpMGTRegMap {outfile channel_type record_types ip_registers start_index end_index} {
    #loop over all of the dictionaries in the ip_registers dictionary
    foreach record_type $record_types {
	if { [dict exists $ip_registers $record_type] } {
	    set type_registers [dict get $ip_registers $record_type "regs"]

	    #Loop over index
	    for {set loop_index $start_index} {$loop_index <= $end_index} {incr loop_index} {
		foreach register $type_registers {
		    ConnectUpMGTReg $outfile $channel_type $record_type $loop_index $register
		}	
	    }
	}
	
    }
}





#This function is the primary call to build a HAL (hardware abstraction layer) hdl file
#  (and associated IPCores and decoders) for the MGT links on the FPGA
proc BuildHAL {params} {    
    #Global build names
    global build_name
    global apollo_root_path
    global autogen_path

    puts "Param values: $params"
    
    set_required_values $params "hal_yaml_file" False
    set_required_values $params "axi_control"
    
    #TODO: do a test for modification time between config yaml file and output products,
    # so we can skip this step if it has already been run.
      
    puts "Building HAL from config file: ${hal_yaml_file}"
    
#    set quad_common_template   [dict get [yaml::yaml2dict -file ${hal_yaml_file}] "COMMON_SETS"]
    set quad_channel_templates [dict get [yaml::yaml2dict -file ${hal_yaml_file}] "CHANNEL_SETS"]
    set quads                  [dict get [yaml::yaml2dict -file ${hal_yaml_file}] "QUADS"]
    puts "Quads:"
    puts "  $quads"
    
    set ip_template_info [dict create]

    
    #process all the requested channels and build the IP cores for all the quads requested
    #build vhdl packages for their interfaces
    foreach quad ${quads} {
	HAL_process_quad $quad_channel_templates $quad ip_template_info
    }

    #figure out how many physical clocks we need to capture
    set clock_map [dict create]
    dict for {channel_type ip_info} $ip_template_info {
	foreach clock_type "rx_clocks tx_clocks" {	    
	    set clocks [dict get $ip_info $clock_type]
	    dict for {ip ip_list} $clocks {;#{quad ip_clks} $clocks
		dict for {quad clk_list} $ip_list {;#{ip clk_list} $ip_clks
		    dict for {chan relative_clk} $clk_list {
			#			set clk_name [GenRefclkName $quad $relative_clk $clk_list]
			set clk_name [GenRefclkName $quad $relative_clk]
			dict incr clock_map $clk_name
		    }
		}
	    }
	}	
    }

    ####################################
    #build a package for the HAL to interface with top
    #will include packages for clocks and serdes in and out
    ####################################
    set HAL_PKG_filename "${apollo_root_path}/${autogen_path}/HAL/HAL_PKG.vhd"
    GenRefclkPKG $clock_map [dict get $ip_info "toplevel_regs"] $HAL_PKG_filename
    puts "Adding $HAL_PKG_filename"
    read_vhdl $HAL_PKG_filename    
    
    
    #figure out how many ip core types we have and how many channels of each type
    set type_count [dict size $ip_template_info]
    set type_channel_counts [dict create]
    set type_common_counts [dict create]
    dict for {channel_type ip_info} $ip_template_info {
	set registers [dict get $ip_info "registers"]
	dict set type_channel_counts $channel_type [ladd [dict get $ip_info "core_channel_count" ] ]
	dict set type_common_counts $channel_type [llength [dict get $ip_info "core_channel_count" ] ]
    }

    
    #build the final (top level) xml files for each channel_type
    dict for {channel_type ip_info} $ip_template_info {
	set registers [dict get $ip_info "registers"]
	#find all the command and channel xml files
	dict for {xml_name xml_file} [dict get $registers "package_info" "xml_files"] {
	    if {[string first "common" $xml_name ] > 0} {
		set xml_file_common $xml_name
	    }
	    if {[string first "channel" $xml_name ] > 0} {
		set xml_file_channel $xml_name
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
    set regmap_pkgs [list]
    set regmap_sizes [dict create]
    dict for {channel_type ip_info} $ip_template_info {
	set reg_params [dict create \
			    device_name ${channel_type} \
			    xml_path "${apollo_root_path}/${autogen_path}/HAL/${channel_type}_top.xml" \
			    out_path "${apollo_root_path}/${autogen_path}/HAL/${channel_type}/wrapper/${channel_type}/" \
			    simple True \
			    verbose True \
			   ]
	set generated_map_data [GenerateRegMap ${reg_params}]
	read_vhdl [lindex $generated_map_data 0]; #PKG file
	read_vhdl [lindex $generated_map_data 1]; #MAP file
	dict append regmap_sizes $channel_type  [lindex $generated_map_data 2]
	lappend regmap_pkgs ${channel_type}_Ctrl
    }




    #Start generating the HAL vhdl file
    set HAL_file [open "${apollo_root_path}/${autogen_path}/HAL/HAL.vhd" w]    
    puts -nonewline ${HAL_file} "library ieee;\n"
    puts -nonewline ${HAL_file} "use ieee.std_logic_1164.all;\n\n"
    puts -nonewline ${HAL_file} "use work.axiRegPkg.all;\n"
    #add the clocks package
    puts -nonewline ${HAL_file} "use work.hal_pkg.all;\n\n\n"


    #Add all the packages we will need for the IP Core wrappers   
    dict for {channel_type ip_info} $ip_template_info {
	set package_name [dict get $ip_info "registers" "package_info" "name"]
	puts -nonewline ${HAL_file} "use work.${package_name}.all;\n"
    }
    #Add all the packages we will need for the regmap decoders
    foreach regmap_pkg $regmap_pkgs {
	puts -nonewline ${HAL_file} "use work.${regmap_pkg}.all;\n"
    }

    puts -nonewline ${HAL_file} "Library UNISIM;\n"
    puts -nonewline ${HAL_file} "use UNISIM.vcomponents.all;\n\n\n"

    #############################################################################
    # Add entity declaration
    #############################################################################
    puts -nonewline ${HAL_file} "entity HAL is\n"
    #generics for decoder size checking
    puts -nonewline ${HAL_file} "  generic (\n"
    set line_ending ""
    dict for {channel_type ip_info} $ip_template_info {
	puts -nonewline ${HAL_file} [format "%s%40s : integer" \
					 $line_ending \
					 "${channel_type}_MEMORY_RANGE"
				    ]
	set line_ending ";\n"	
    }
    puts -nonewline ${HAL_file} ");\n"
    #normal ports
    puts -nonewline ${HAL_file} "  port (\n"
    puts -nonewline ${HAL_file} "                                 clk_axi : in  std_logic;\n"
    puts -nonewline ${HAL_file} "                             reset_axi_n : in  std_logic;\n"
    puts -nonewline ${HAL_file} "                                readMOSI : in  AXIreadMOSI_array_t (${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                                readMISO : out AXIreadMISO_array_t (${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                               writeMOSI : in  AXIwriteMOSI_array_t(${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                               writeMISO : out AXIwriteMISO_array_t(${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                             HAL_refclks : in  HAL_refclks_t;\n"
    puts -nonewline ${HAL_file} "                        HAL_serdes_input : in  HAL_serdes_input_t;\n"
    puts -nonewline ${HAL_file} "                       HAL_serdes_output : out HAL_serdes_output_t;\n"
    
    set AXI_array_index 0
    
    #finish entity port map
    set line_ending ""
    dict for {channel_type ip_info} $ip_template_info {
	set records [dict get $ip_info "registers" "package_info" "records"]
	foreach record_name [dict keys $records] {
	    if {[string first "userdata" ${record_name}] == 0 } {
		#only route out userdata, other packages are internal/via axi
		set dir "in "
		if { [string first "_output" $record_name] >= 0 } {
		    set dir "out"
		}
		puts -nonewline ${HAL_file} [format "%s%40s : %3s %s_array_t(% 3d-1 downto 0)" \
						 $line_ending \
						 "${channel_type}_${record_name}" \
						 $dir \
						 ${channel_type}_${record_name} \
						 [dict get $type_channel_counts $channel_type] \
						]
		set line_ending ";\n"
	    }
	}
    }
    puts -nonewline ${HAL_file} ");\n"
    puts -nonewline ${HAL_file} "end entity HAL;\n\n\n"

    #############################################################################
    # Architecture
    #############################################################################
    puts -nonewline ${HAL_file} "architecture behavioral of HAL is\n"

    #write the local signals needed to route ip core packages

    #Add refclk signals
    dict for {clk_name count} $clock_map {
	puts ${HAL_file} [format \
			      "  signal %40s : std_logic;" \
			      "refclk_${clk_name}"]
	puts ${HAL_file} [format \
			      "  signal %40s : std_logic;" \
			      "refclk_${clk_name}_2"]
    }
    puts ${HAL_file} "" ; #new line
    
    #Add wrapper signals
    dict for {channel_type ip_info} $ip_template_info {
	set registers [dict get $ip_info "registers"]
	#loop over package_files (not there should on be on entry for the package name)
	set package_name [dict get $ip_info "registers" "package_info" "name"]
	dict for {record_name record_data} [dict get ${registers} "package_info" "records"] {
	    if {[string first "userdata" ${record_name}] < 0} {		
		#we don't need local copies of userdata signals
		puts -nonewline ${HAL_file} [format "  signal %40s : %s(%s-1 downto 0);\n" \
						 "${channel_type}_${record_name}" \
						 "${channel_type}_${record_name}_array_t"\
						 [dict get $type_channel_counts $channel_type] ]
	    }
	}
	puts -nonewline ${HAL_file} "\n\n"
    }
    #Add regmap signals
    dict for {channel_type ip_info} $ip_template_info {
	foreach reg_map_record {"Ctrl" "Mon"} {
	    puts -nonewline ${HAL_file} [format "  signal %40s : %s;\n" \
					     "${reg_map_record}_${channel_type}" \
					     "${channel_type}_${reg_map_record}_t"]
	}
    }

    #############################################################################
    # VHDL Begin
    #############################################################################
    
    #Generate all the ip cores, grouped by type
    puts -nonewline ${HAL_file} "begin\n"

    #capture refclks
    dict for {clk_name count} $clock_map {
	#should be generalized to include US FPGAs
	puts  ${HAL_file} "  ibufds_${clk_name} : ibufds_gte4"
	puts  ${HAL_file} "    generic map ("
	puts  ${HAL_file} "      REFCLK_EN_TX_PATH  => '0',"
	puts  ${HAL_file} "      REFCLK_HROW_CK_SEL => \"00\","
	puts  ${HAL_file} "      REFCLK_ICNTL_RX    => \"00\")"
	puts  ${HAL_file} "    port map ("
	puts  ${HAL_file} "      O     => refclk_${clk_name},"
	puts  ${HAL_file} "      ODIV2 => refclk_${clk_name}_2,"
	puts  ${HAL_file} "      CEB   => '0',"
	puts  ${HAL_file} "      I     => HAL_refclks.refclk_${clk_name}_P,"
	puts  ${HAL_file} "      IB    => HAL_refclks.refclk_${clk_name}_N"
	puts  ${HAL_file} "      );"
	puts  ${HAL_file} "      \n"

    }

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
	set current_single_index 0
	set current_multi_index 0
	
	for {set iCore 0} {$iCore < [dict get $type_common_counts $channel_type]} {incr iCore} {

	    
	    #check that the range for this ipcore in the array of packages makes sense 
	    if {$current_single_index >= ${max_offset} } {
		error "When building IP core $ip_core the channel offset ($current_single_index) was larger than the max channel offset ($max_offset)"		
	    }
	    #generate the IP Core instance
	    set old_current_single_index $current_single_index
	    set old_current_multi_index $current_multi_index
	    GenerateMGTInstance \
		${HAL_file} \
		[lindex [dict get $ip_info "ip_cores"] $iCore] \
		${channel_type} \
		[dict get $registers "package_info" "records"] \
		[dict get [dict get $ip_info "toplevel_regs"] \
		     [lindex [dict get $ip_info "ip_cores"] $iCore] ] \
		"current_single_index" \
		"current_multi_index"

	    #connect up clocks
	    foreach register [dict get $registers "package_info" "records" "clocks_input" "regs"] {
		#find the appropriate clock dict for this ipcore
		set current_clks [dict get $ip_info "rx_clocks" [lindex [dict get $ip_info "ip_cores"] $iCore]]
		
		
		for {set iChanClk [dict get $register "LSB"]} {$iChanClk <= [dict get $register "MSB"]} {incr iChanClk} {
		    #		    set refclk_name [GenRefclkName [lindex $current_clks 0] [lindex [lindex $current_clks 1] 1]]
		    set refclk_name [GenRefclkName [lindex $current_clks 0] [lindex [lindex $current_clks 1] [expr 2*$iChanClk + 1]]]
		    puts ${HAL_file} [format "    %s_clocks_input(%d).%s(%d) <= refclk_%s;\n" \
					  $channel_type \
					  $old_current_single_index \
					  [dict get $register "alias"] \
					  $iChanClk \
					  $refclk_name \
					 ]
		}
	    }

	    
	    #connect up all the common per-quad register signals
	    ConnectUpMGTRegMap \
		${HAL_file} $channel_type \
		"common_input common_output" \
		[dict get $registers "package_info" "records"] \
		$old_current_single_index \
		$old_current_single_index
	    #connect up all the perchannel register signals
	    ConnectUpMGTRegMap \
		${HAL_file} $channel_type \
		"channel_input channel_output" \
		[dict get $registers "package_info" "records"] \
		$old_current_multi_index \
		[expr $current_multi_index -1]
	    
	    
	    #move to the next group of signals
	}
	puts -nonewline ${HAL_file} "\n\n"
	
    }

    puts -nonewline ${HAL_file} "end architecture behavioral;\n"
    
       	
    close $HAL_file
    read_vhdl "${apollo_root_path}/${autogen_path}/HAL/HAL.vhd"


    #add AXI PL connections for the decoders
    dict for {channel_type ip_info} $ip_template_info {
	
	set mapsize [expr 2**([dict get $regmap_sizes $channel_type] - 10)]; #-10 for 2**10 == 1k
	if { $mapsize > 1024 } {
	    set mapsize [expr $mapsize >> 10]"M"
	} else {
	    set mapsize ${mapsize}"M"
	}
	AXI_PL_DEV_CONNECT [dict create \
				"device_name" $channel_type \
				"axi_control" [dict create  \
						   "axi_interconnect" $axi_interconnect \
						   "axi_clk" $axi_clk \
						   "axi_rstn" $axi_rstn \
						   "axi_freq" $axi_freq \
						  ]\
				"addr"        [dict create "offset" "-1" "range" $mapsize]
			    ]
    }
}
