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

