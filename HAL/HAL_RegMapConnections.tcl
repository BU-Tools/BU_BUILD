package require yaml
source ${BD_PATH}/utils/pdict.tcl
source ${BD_PATH}/Regmap/RegisterMap.tcl
source ${BD_PATH}/Cores/Xilinx_Cores.tcl
source ${BD_PATH}/HAL/HAL_helpers.tcl

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
