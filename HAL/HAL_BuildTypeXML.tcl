package require yaml
source ${BD_PATH}/utils/pdict.tcl
source ${BD_PATH}/Regmap/RegisterMap.tcl
source ${BD_PATH}/Cores/Xilinx_Cores.tcl
source ${BD_PATH}/HAL/HAL_helpers.tcl


#build the XML address table for the type of MGT
#Arguments:
#  file_path:        path used to write the xml file
#  type_name:        The name of this type (used in filename)
#  channel_count:    Count of the number of total channels of this type
#  common_count:     Count of the number of total common blocks of this type
#  common_xml_file:  XML file to use as a module for the common blocks
#  channel_xml_file: XML file to use as a module for the channel
#  transceiver_xml:  XML file to use as a module for the DRP interfaces
proc BuildTypeXML {file_path type_name channel_count common_count common_xml_file channel_xml_file transceiver_xml} {
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
	set old_address $address
	set address [expr int(ceil(${address}/0x100)) * 0x100]
	if {$address <= $old_address} {
	    set address [expr ${address} + 0x100]
	}
    }

    
    #process the channels for this type
    foreach quad_channel_count $channel_count {
	#add each channels module
	for {set iChan 0} {$iChan < $quad_channel_count} {incr iChan} {
	    puts $out_file [format \
				"  <node id=\"%s\"   address=\"0x%08X\" fwinfo=\"type=array\" module=\"file://%s\"/>\n" \
				"CHANNEL_${iChan}" \
				$address \
				"${type_name}/${channel_xml_file}.xml" ]	    
	    set address [expr ${address} + 0x100]
	}
    }

    #round the address up to an even multiple of the channel size
    if { [expr ${address} % 0x400] != 0} {
	set old_address $address
	set address [expr int(ceil(${address}/0x400)) * 0x400]
	if {$address <= $old_address} {
	    set address [expr ${address} + 0x400]
	}
    }
   
    #process the DRPs for this type
    foreach quad_channel_count $channel_count {
	#add each channels module
	for {set iChan 0} {$iChan < $quad_channel_count} {incr iChan} {
	    puts $out_file [format \
				"  <node id=\"%s\"   address=\"0x%08X\" fwinfo=\"type=array;mem16_0x400\" module=\"file://%s\"/>\n" \
				"DRP_${iChan}" \
				$address \
				$transceiver_xml ]	    
	    set address [expr ${address} + 0x400]
	}
    }

    



    
    puts $out_file "</node>"
    close $out_file
}
