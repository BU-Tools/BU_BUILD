#################################################################################
## Write a record into outfile passed
#################################################################################
proc WritePackage {outfile name data} {
    if { [dict size $data] > 0 } {
	puts $outfile "type $name is record"
	dict for {key value} $data {
	    puts $outfile [format "  %-30s : %s;" $key [lindex $value 0] ]
	}
	puts $outfile "end record $name;"
	puts $outfile "type ${name}_array_t is array (integer range <>) of $name;"
    }
}
#################################################################################
## Write a record into outfile passed 2
#################################################################################
proc StartPackage {outfile name} {
    puts $outfile "--This file was auto-generated."
    puts $outfile "--Modifications might be lost."
    puts $outfile "library IEEE;"
    puts $outfile "use IEEE.std_logic_1164.all;"
    puts $outfile "\n\n\n"
    puts $outfile "package ${name}_PKG is"
}
proc EndPackage {outfile name} {
    puts $outfile "end package ${name}_PKG;"

}
proc WritePackageRecord {outfile name data} {
    set new_record ""
    if { [llength $data] > 0 } {
	puts $outfile "type ${name}_t is record"
	foreach entry $data {
	    set alias [dict get $entry "alias"]
	    set MSB   [dict get $entry "MSB"]
	    set LSB   [dict get $entry "LSB"]
	    puts $outfile [format \
			       "  %-30s : std_logic_vector(%d downto %d);" \
			       [string toupper $alias] \
			       $MSB \
			       $LSB \
			      ]
	}
	puts $outfile "end record ${name}_t;"
	puts $outfile "type ${name}_array_t is array (integer range <>) of ${name}_t;"
	set new_record "${name}_t"
    }
    return ${new_record}
}
proc WritePackage2 {outfile name data} {
    
    if { [llength $data] > 0 } {
	puts $outfile "--This file was auto-generated."
	puts $outfile "--Modifications might be lost."
	puts $outfile "library IEEE;"
	puts $outfile "use IEEE.std_logic_1164.all;"
	puts $outfile "\n\n\n"
	puts $outfile "package ${name}_PKG is"
	puts $outfile "type ${name}_t is record"
	foreach entry $data {
#	    puts  $entry
	    set alias [dict get $entry "alias"]
	    set MSB   [dict get $entry "MSB"]
	    set LSB   [dict get $entry "LSB"]
	    puts $outfile [format \
			       "  %-30s : std_logic_vector(%d downto %d);" \
			       [string toupper $alias] \
			       $MSB \
			       $LSB \
			      ]
	}
	puts $outfile "end record ${name}_t;"
	puts $outfile "type ${name}_array_t is array (integer range <>) of ${name}_t;"
	puts $outfile "end package ${name}_PKG;"
    }
}

#################################################################################
## Generate a uHAL XML node for a register
#################################################################################
proc XMLentry {name addr MSB LSB direction} {
    #set name and address
    set upper_name [string toupper $name]
    set node_line [format "  <node id=\"$upper_name\" address=\"0x%08X\"" $addr]
    
    #build the mask from MSB and LSB ranges
    set node_mask 0
    for {set bit $LSB} {$bit <= $MSB} {incr bit} {
	set node_mask [expr (2**$bit) + $node_mask]
    }
    set node_mask [format 0x%08X $node_mask]
    set node_line "$node_line mask=\"$node_mask\""

    #set read/write
    if {$direction == "output"} {
	set node_line "$node_line permission=\"r\""
    } else {
	set node_line "$node_line permission=\"rw\""
    }
    #end xml entry
    set node_line "$node_line />\n"
    return $node_line
}
#################################################################################
## Generate an XML file for a set of registers
#################################################################################
proc BuildXMLAddressTable {outfile name data} {
    if { [llength $data] > 0 } {
	puts $outfile "<node id=\"${name}\">"
	set addr 0
	foreach entry $data {
	    set alias [dict get $entry "alias"]
	    set MSB   [dict get $entry "MSB"]
	    set LSB   [dict get $entry "LSB"]
	    set dir   [dict get $entry "dir"]
	    puts $outfile [XMLentry $alias $addr $MSB $LSB $dir]
	    set addr [expr $addr + 1]
	}
	puts $outfile "</node>"
    }
    
}

#################################################################################
##
#################################################################################
proc VerilogIPSignalGrabber {direction MSB LSB name dict_inputs_name dict_outputs_name regs_xml_name reg_count_name} {
    #tie local variables to the ones of the caller (ick, I know.. tcl)
    upvar $dict_inputs_name  dict_inputs
    upvar $dict_outputs_name dict_outputs
    upvar $regs_xml_name regs_xml
    upvar $reg_count_name reg_count

    #see if this is a vector or a signal
    set type ""
    if {$MSB == 0} {
	set type "std_logic"			
    } else {
	set type "std_logic_vector($MSB downto 0)"
    }
    set bitsize [expr ($MSB - $LSB)+1]
    
    #write signals to the appropriate 
    if {$direction == "output"} {
	dict append dict_outputs $name [list $type $bitsize]
	dict append regs_xml dict_outputs [XMLentry $name $reg_count [expr $bitsize -1] 0 $direction]
	set reg_count [expr $reg_count + 1]
	
    } elseif {$direction == "input"} {
	dict append dict_inputs  $name [list $type $bitsize]
	dict append regs_xml dict_inputs [XMLentry $name $reg_count [expr $bitsize -1] 0 $direction]
	set reg_count [expr $reg_count + 1]
    } else {
	error "Invalid in/out type $line"
    }
}

#################################################################################
## ParseVerilogComponent
#################################################################################
proc ParseVerilogComponent {filename} {
    set example_verilog_file [open ${filename} r]
    set data [list]
    puts "Parsing file: ${filename}"

    set parse_regex { *(output|input) *wire *\[([0-9]*) *: *([0-9]*)\] *([a-zA-Z_0-9]*);}

    
    while { [gets $example_verilog_file line] >= 0} {

	set foundMatch [regexp ${parse_regex} $line full_match direction MSB LSB name ]
	if {  ${foundMatch} == 1} {
	    
	    #set an alias for this signal that is clean of Xilinx's _in/_out naming
	    set alias $name

	    if {[regexp {([a-zA-Z_0-9]*)_(in|out)$} ${name} full_match name_alias dir] == 1} {
		set alias ${name_alias}
	    }

	    #add a dictionary for this line's info
	    lappend data [dict create \
			      "name"  $name \
			      "alias" $alias \
			      "dir"   $direction \
			      "MSB"   $MSB \
			      "LSB"   $LSB\
			     ]
	}
    }
    close $example_verilog_file
    return $data
}

#################################################################################
## SortMGTregsIntoPackages
#################################################################################
# This function processes a list of registers generated by ParseVerilogComponent
# and organizes them into a dictionary of subgroups (listed below).
# Each subgroup is a list of register dictionaries (listed below)
# reg_output_name (dict):  dictionary of all the organized registers
#  - common_input (dict):  dictionary containing information about this grouping of regs
#    - "to be expanded by others"
#    - regs (list of dicts)   : list of registers for the common registers into the IP core
#      - dictionary:
#        - name: real name of register (in core)
#        - alias: simplified name
#        - dir: in vs out
#        - MSB: msb bit position
#        - LSB: lsb bit position (really always 0, but for future use)
#  - common_output (list of dicts)  : list of registers
#  - userdata_intput (list of dicts): list of registers for the user (data) into the IP core
#  - userdata_output (list of dicts): list of registers
#  - clocks_input (list of dicts)   : list of registers
#  - clocks_output (list of dicts)  : list of registers
#  - channel_intput (list of dics)
#  - channel_output
#proc SortMGTregsIntoPackages_UpdateEntry {registers_name }
proc SortMGTregsIntoPackages { reg_input reg_output_name channel_count clkdata userdata } {
    set drp_rename_map [dict create \
			    "drpaddr" "address" \
			    "drpclk"  "clk" \
			    "drpdi"   "wr_data" \
			    "drpen"   "enable" \
			    "drpwe"   "wr_enable" \
			    "drpdo"   "rd_data" \
			    "drprdy"  "rd_data_valid" \
			    "drprst"  "reset" \
			]

    set skipped [list]
    upvar $reg_output_name registers
    foreach entry ${reg_input} {	
	set name  [dict get ${entry} "name"]
	set alias [dict get ${entry} "alias"]
	set dir   [dict get ${entry} "dir"]
	set MSB   [dict get ${entry} "MSB"]
	set LSB   [dict get ${entry} "LSB"]

	
	# isolate specially requested userdata signals
	set found_signal 0


	if { [regex -nocase {gt[xyh][tr]x[pn]_(out|in)} $name match match_dir  ] > 0} {

	    set found_signal 1
	    lappend skipped ${entry}
	}
	if { ! ${found_signal} } {
	    if {[string first "drp" $name] >= 0} {
		#this is a per channel signal
		#udpate these to divide by the number of channels
		#Adjust width for per channel
		set width [expr  ((1+$MSB - $LSB))]
		if { [expr $width % $channel_count] == 0 } {
		    #update the MSB for a single channel
		    dict set entry "MSB" [expr ${width}/$channel_count -1]
		} else {
		    error "DRP signal $alias isn't a multiple of the channel count ($channel_count)"
		}
		#do a replace of the alias to make it compatible with our standard decoder
		if {[dict exists ${drp_rename_map} $alias]} {
		    dict set entry "alias" [dict get ${drp_rename_map} $alias]
		}
		dict with registers {
		    dict lappend "drp_${dir}" "regs" ${entry}
		}
		set found_signal 1
	    }
	}
	
	if { ! ${found_signal} } {
	    foreach username ${userdata} {	    
		if { [string equal -nocase $alias $username] } {
		    #Adjust width for per channel
		    set width [expr  ((1+$MSB - $LSB))]
		    if { [expr $width % $channel_count] == 0 } {
			#update the MSB for a single channel
			dict set entry "MSB" [expr ${width}/$channel_count -1]
		    }
		    dict with registers {
			dict lappend "userdata_${dir}" "regs" ${entry}
		    }
		    set found_signal 1
		    break
		}
	    }
	}

	if { ! ${found_signal} } {
	    foreach clkname ${clkdata} {	    
		if { [string equal -nocase $alias $clkname] } {
		    #Adjust width for per channel
#		    set width [expr  ((1+$MSB - $LSB))]
#		    if { [expr $width % $channel_count] == 0 } {
#			#update the MSB for a single channel
#			dict set entry "MSB" [expr ${width}/$channel_count -1]
#		    }
		    dict with registers {
			dict lappend "clocks_${dir}" "regs" ${entry}
		    }

		    set found_signal 1
		    break
		}
	    }
	}

	
	#process other signals
	if { ! ${found_signal} } {
	    if {[string first "refclk" $name] >= 0 || \
		    [string first "freerun" $name] >= 0 || \
		    ([string first "qpll" $name] >= 0 && \
			 [string first "clk" $name] >= 0) } {
		#this is a clock signal
		dict with registers {
		    dict lappend "clocks_${dir}" "regs" ${entry}
		}
	    } elseif {[string range $name 0 5] == "gtwiz_" && \
			  [string first "userdata" $name] == -1 || \
			  [string first "qpll" $name] >= 0 } {
		#this is a common signal
		dict with registers {
		    dict lappend "common_${dir}" "regs" ${entry}
		}
	    } else {
		#this is a per channel signal
		#udpate these to divide by the number of channels
		#Adjust width for per channel
		set width [expr  ((1+$MSB - $LSB))]
		if { [expr $width % $channel_count] == 0 } {
		    #update the MSB for a single channel
		    dict set entry "MSB" [expr ${width}/$channel_count -1]
		} else {
		    error "Channel signal $alias isn't a multiple of the channel count ($channel_count)"
		}
		dict with registers {
		    dict lappend "channel_${dir}" "regs" ${entry}
		}
	    }
	}
    }
    return $skipped
}
