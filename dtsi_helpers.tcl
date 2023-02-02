set dtsi_output_path "${apollo_root_path}/kernel/hw"

set axi_memory_mappings_addr  [dict create]
set axi_memory_mappings_range [dict create]

set default_device_tree_additions "        compatible = \"generic-uio\";\n        label = \"\$device_name\";\n        linux,uio-name = \"\$device_name\";\n"

#Find this device and add its AXI address and range to .h and .vhd files
proc BUILD_AXI_ADDR_TABLE {device_name {new_name  ""} } {
    global axi_memory_mappings_addr
    global axi_memory_mappings_range
    set addr_seg [get_bd_addr_segs -quiet *SEG*${device_name}]
    if {[string length ${addr_seg}] == 0} {
	set addr_seg [get_bd_addr_segs -regexp -quiet ".*SEG.*${device_name}_(?:Control|Reg|Mem).*"]
    }
    puts ${addr_seg}
    if {[string length ${addr_seg}] >0} {
	set addr [format %08X [lindex [get_property -quiet OFFSET ${addr_seg}] 0] ]
	set addr_range [format %08X [lindex [get_property -quiet RANGE ${addr_seg}] 0] ]
	set name $device_name
	if {[string length $new_name] > 0} {
	    set name $new_name
	}
	puts "  ${name}:  ${addr}:${addr_range}"
	dict set axi_memory_mappings_addr  ${name} ${addr}      
	dict set axi_memory_mappings_range ${name} ${addr_range}
    }
}

#This function writes a dtsi_post_chunk file to append a XILINX axi slave so it
#  can be used as a UIO device.
#This takes the name of the device (as it appears in the DTSI file generated by xilinx)
#proc AXI_DEV_UIO_DTSI_POST_CHUNK {device_name {dt_data $default_device_tree_additions}} {
proc AXI_DEV_UIO_DTSI_POST_CHUNK [list device_name  [list dt_data $default_device_tree_additions]] {
    global dtsi_output_path
    
    assign_bd_address [get_bd_addr_segs {${device_name}/S_AXI/Reg }]
    puts "AXI_DEV_UIO_DTSI_POST_CHUNK: ${device_name}"

    BUILD_AXI_ADDR_TABLE ${device_name}

    #make sure the output folder exists
    file mkdir ${dtsi_output_path}
    set dtsi_file [open "${dtsi_output_path}/${device_name}.dtsi_post_chunk" w+]
    puts $dtsi_file "  &${device_name}{"

    #add device specific stuff
    set map {}
    lappend map {$device_name} $device_name
    puts  ${dtsi_file} [string map $map  ${dt_data}]

#    puts $dtsi_file "    compatible = \"generic-uio\";"
#    puts $dtsi_file "      label = \"$device_name\";"
#    puts $dtsi_file "      linux,uio-name = \"$device_name\";"
    puts $dtsi_file "  };"
    close $dtsi_file
}

#function to create a DTSI chunk file for a full PL AXI slave.
#proc AXI_DEV_UIO_DTSI_CHUNK {device_name  {dt_data $default_device_tree_additions}} {
proc AXI_DEV_UIO_DTSI_CHUNK [list device_name  [list dt_data $default_device_tree_additions]] {
    global dtsi_output_path

    global REMOTE_C2C
    global REMOTE_C2C_64

    puts "AXI_DEV_UIO_DTSI_CHUNK: ${device_name}"

    BUILD_AXI_ADDR_TABLE ${device_name}

#    set addr [format %X [lindex [get_property OFFSET [get_bd_addr_segs *SEG*${device_name}_*]] 0] ]
#    set addr_range [format %X [lindex [get_property RANGE [get_bd_addr_segs *SEG*${device_name}_*]] 0] ]
    set addr [format %X [lindex [get_property OFFSET [get_bd_addr_segs -regex .*SEG.*${device_name}_(Reg|Control|Mem0).*]] 0] ]
    set addr_range [format %X [lindex [get_property RANGE [get_bd_addr_segs -regex .*SEG.*${device_name}_(Reg|Control|Mem0).*]] 0] ]

    #make sure the output folder exists
    file mkdir ${dtsi_output_path}

    if { [expr [string first xc7z [get_parts -of_objects [get_projects] ] ] >= 0 ] || 
	 [info exists REMOTE_C2C] || 
	 [expr [package vcompare [version -short] 2020.2 ] >=0] } {    
	#build dtsi file for this for later    
	set dtsi_file [open "${dtsi_output_path}/${device_name}.dtsi_chunk" w+]
	
	#handle amba_pl between 7 and USP
	set amba_path "  amba_pl"
	if { [expr [string first xc7z [get_parts -of_objects [get_projects] ] ] == -1 ] } {
	    set amba_path "${amba_path}@0"
	}
	puts $dtsi_file "${amba_path} {" 
	

	puts $dtsi_file "    axiSlave$device_name: $device_name@${addr} {"
#	puts $dtsi_file "      compatible = \"generic-uio\";"
	if { [expr [string length ${addr}] > 8 ] || 
	     [expr [string first xczu [get_parts -of_objects [get_projects] ] ] >= 0 ] ||
	     [info exists REMOTE_C2C_64] 
	 } {
#	    puts $dtsi_file "      		#address-cells = <2>;"
#	    puts $dtsi_file "                   #size-cells = <2>;"

	    set addr_MSB  [string range ${addr} 8 [string length ${addr}]]
	    if { [expr [string length $addr_MSB] == 0 ] } {
		set addr_MSB "0"
	    }
	    set addr_LSB  [string range ${addr} 0 7]

	    set range_MSB [string range ${addr_range} 8 [string length ${addr_range} ] ]
	    if { [expr [string length $range_MSB] == 0 ] } {
		set range_MSB "0"
	    }
	    set range_LSB [string range ${addr_range} 0 7]    

	    puts $dtsi_file "      reg = <0x${addr_MSB} 0x${addr_LSB} 0x${range_MSB} 0x${range_LSB}>;"
	} else {
#	    puts $dtsi_file "      		#address-cells = <1>;"
#	    puts $dtsi_file "                   #size-cells = <1>;"
	    puts $dtsi_file "      reg = <0x${addr} 0x${addr_range}>;"
	}
	#add additional parameters
	set map {}
	lappend map {$device_name} $device_name
	puts  ${dtsi_file} [string map $map  ${dt_data}]

#	puts $dtsi_file "      label = \"$device_name\";"
#	puts $dtsi_file "      linux,uio-name = \"$device_name\";"
	puts $dtsi_file "    };"
	puts $dtsi_file "  };"
	close $dtsi_file
    } else { 
	#build a dtsi_post_chunk file
	AXI_DEV_UIO_DTSI_POST_CHUNK ${device_name}
    }
}

#function to create a DTSI chunk file for a full PL AXI slave.
proc AXI_DEV_UIO_DTSI_OVERLAY [list device_name  manual_load_dtsi [list dt_data $default_device_tree_additions]] {
    global dtsi_output_path

    global REMOTE_C2C
    global REMOTE_C2C_64

    BUILD_AXI_ADDR_TABLE ${device_name}

    set addr_segs [get_bd_addr_segs -regex .*SEG.*${device_name}_(Reg|Control|Mem0).*]
    if { [llength ${addr_segs} ] == 0 } {
	puts "Cannont find address segments for $device_name"
	error "Cannont find address segments for $device_name"
    }
    set addr [format %X [lindex [get_property OFFSET ${addr_segs}] 0] ]
    set addr_range [format %X [lindex [get_property RANGE ${addr_segs}] 0] ]

    #build dtsi file for this for later    
    if { ${manual_load_dtsi} == 0} {
	#make sure the output folder exists
	file mkdir ${dtsi_output_path}
	set dtsi_filename "${dtsi_output_path}/${device_name}.dtsi"
    } else {
	#make sure the output folder exists
	file mkdir ${dtsi_output_path}/manual_load

	set dtsi_filename "${dtsi_output_path}/manual_load/${device_name}.dtsi"
    }
    set dtsi_file [open ${dtsi_filename}  w+]
    
    set amba_path "amba_pl"
    set is64bit false
    #determine if this is 32 or 64 bit encoding
    if { [expr [string length ${addr}] > 8 ] || 
	 [expr [string first xczu [get_parts -of_objects [get_projects] ] ] >= 0 ] ||
	 [info exists REMOTE_C2C_64] 
     } {
	set is64bit true
    }

    puts ${dtsi_file} "/dts-v1/;"
    puts ${dtsi_file} "/plugin/;"
    puts ${dtsi_file} " "
    puts ${dtsi_file} "/ {"
    puts ${dtsi_file} "	fragment@0 {"
    puts ${dtsi_file} "	    target = <&${amba_path}>;"
    puts ${dtsi_file} "	    __overlay__ {"
    
    puts ${dtsi_file} "       axiSlave$device_name: $device_name@${addr} {"
    if { $is64bit } {
	#figure out how to write 64 bit address in 32bit word chunks
	set addr_MSB  [string range ${addr} 8 [string length ${addr}]]
	if { [expr [string length $addr_MSB] == 0 ] } {
	    set addr_MSB "0"
	}
	set addr_LSB  [string range ${addr} 0 7]
	
	set range_MSB [string range ${addr_range} 8 [string length ${addr_range} ] ]
	if { [expr [string length $range_MSB] == 0 ] } {
	    set range_MSB "0"
	}
	set range_LSB [string range ${addr_range} 0 7]    
	
	puts ${dtsi_file} "        reg = <0x${addr_MSB} 0x${addr_LSB} 0x${range_MSB} 0x${range_LSB}>;"
    } else {
	puts ${dtsi_file} "        reg = <0x${addr} 0x${addr_range}>;"
    }

    set map {}
    lappend map {$device_name} $device_name
    #load the dt_data info (by default this is enables generic UIO, but some things like i2c and interrupts override this)
    puts  ${dtsi_file} [string map $map  ${dt_data}]
    puts ${dtsi_file} "      };"
    puts ${dtsi_file} "    };"
    puts ${dtsi_file} "  };"
    puts ${dtsi_file} "};"


    close ${dtsi_file}
}

proc GENERATE_AXI_ADDR_MAP_C {outFileName} {
    global axi_memory_mappings_addr
    global axi_memory_mappings_range
    set outFile [open ${outFileName} w+]
    puts ${outFile} "#ifndef __AXI_ADDR_MAP__" 
    puts ${outFile} "#define __AXI_ADDR_MAP__"

    foreach {slave addr} ${axi_memory_mappings_addr} {
	set line "#define AXI_ADDR_${slave} 0x${addr}" 	
	puts ${outFile} $line
    }
    puts ${outFile} "// ranges"
    foreach {slave range} ${axi_memory_mappings_range} {
	set line "#define AXI_RANGE_${slave} 0x${range}" 	
	puts ${outFile} $line
    }
    puts ${outFile} "#endif" 
    close ${outFile}
}

proc GENERATE_AXI_ADDR_MAP_VHDL {outFileName} {
    global axi_memory_mappings_addr
    global axi_memory_mappings_range
    set outFile [open ${outFileName} w+]
    puts ${outFile} "library ieee;"
    puts ${outFile} "use ieee.std_logic_1164.all;"
    puts ${outFile} "use ieee.numeric_std.all;"
    puts ${outFile} ""
    puts ${outFile} "package AXISlaveAddrPkg is"

    foreach {slave addr} ${axi_memory_mappings_addr} {
	set line "constant AXI_ADDR_${slave} : unsigned(31 downto 0) := x\"${addr}\";" 	
	puts ${outFile} $line
    }
    puts ${outFile} "-- ranges"
    foreach {slave range} ${axi_memory_mappings_range} {
	set line "constant AXI_RANGE_${slave} : unsigned(31 downto 0) :=  x\"${range}\";" 	
	puts ${outFile} $line
    }
    puts ${outFile} "end package AXISlaveAddrPkg;" 
    close ${outFile}
}
