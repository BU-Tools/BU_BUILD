package require yaml
source ${BD_PATH}/utils/pdict.tcl
source ${BD_PATH}/Regmap/RegisterMap.tcl
source ${BD_PATH}/Cores/Xilinx_Cores.tcl
source ${BD_PATH}/HAL/HAL_helpers.tcl
source ${BD_PATH}/HAL/HAL_wrapperGen.tcl

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
source ${BD_PATH}/HAL/HAL_ProcessQuad.tcl

#build the XML address table for the type of MGT
#Arguments:
#  file_path:        path used to write the xml file
#  type_name:        The name of this type (used in filename)
#  channel_count:    Count of the number of total channels of this type
#  common_count:     Count of the number of total common blocks of this type
#  common_xml_file:  XML file to use as a module for the common blocks
#  channel_xml_file: XML file to use as a module for the channel
#  transceiver_xml:  XML file to use as a module for the DRP interfaces
source ${BD_PATH}/HAL/HAL_BuildTypeXML.tcl

#################################################################################
## Register map connections
#################################################################################
#connect up MGT signals to regmap
source ${BD_PATH}/HAL/HAL_RegMapConnections.tcl





#This function is the primary call to build a HAL (hardware abstraction layer) hdl file
#  (and associated IPCores and decoders) for the MGT links on the FPGA
proc BuildHAL {params} {    
    #Global build names
    global build_name
    global apollo_root_path
    global autogen_path
    global BD_PATH
    
    puts "Param values: $params"
    
    set_required_values $params "hal_yaml_file" False

    #TODO: do a test for modification time between config yaml file and output products,
    # so we can skip this step if it has already been run.
      
    puts "Building HAL from config file: ${hal_yaml_file}"
    
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
	#figure out which DRP file we need for this interface
	set mgt_type [dict get $registers "mgt_type"]
	set drp_file_source "${BD_PATH}/Cores/IP_CORE_MGT/xml/DRP_USP_${mgt_type}.xml"
	set drp_file "${apollo_root_path}/${autogen_path}/HAL/${channel_type}/DRP_USP_${mgt_type}.xml"
	file copy $drp_file_source $drp_file
	puts "Copying ${drp_file_source} to ${drp_file}"
	
	BuildTypeXML \
	    "${apollo_root_path}/${autogen_path}/HAL/" \
	    $channel_type \
	    [dict get $type_channel_counts ${channel_type} ] \
	    [dict get $type_common_counts ${channel_type} ] \
	    ${xml_file_common} \
	    ${xml_file_channel} \
	    "${channel_type}/DRP_USP_${mgt_type}.xml"
	    
	
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

    HAL_wrapperGen $params $ip_template_info \
	$type_count $type_channel_counts $type_common_counts \
	$regmap_pkgs $regmap_sizes \
	$clock_map



}
