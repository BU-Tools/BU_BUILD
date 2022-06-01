package require yaml

proc BuildHAL {hal_yaml_file} {
    puts ${hal_yaml_file}
    
#    set quad_common_template   [dict get [yaml::yaml2dict -file ${hal_yaml_file}] "COMMON_SETS"]
    set quad_channel_template  [dict get [yaml::yaml2dict -file ${hal_yaml_file}] "CHANNEL_SETS"]
    set quads                  [dict get [yaml::yaml2dict -file ${hal_yaml_file}] "QUADS"]

    
    foreach key [dict keys ${quads}] {	
	set quad_properties [dict get ${quads} ${key}]

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
	    if [dict exists ${quad_channel_template} ${channel_type}] {
		# this is based on a template
		set parameters [dict merge \
				    $parameters \
				    [dict get ${quad_channel_template} ${channel_type}]]
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


	    #Build the MGT core
	    puts $parameters
	    BuildMGTCores $parameters
	}
    }
       
    
}
