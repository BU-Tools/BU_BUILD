## proc \c Add_Global_Constant
# Arguments:
#   \param name Name to be used in the global VHDL package for this constant
#   \param type The type of this constant (std_logic_1164 VHDL type)
#   \param value Value to set the constant to
#
# This call adds a constant to the global VHDL package and sets its value.
# This will be writen out at the end of the BD build process.
proc Add_Global_Constant {name type value} {
    #connect to global variable for this
    global global_constants
    if { [info exists global_constants] == 0 } {
	set global_constants [dict create ${name} [dict create type ${type} value ${value}]]
    } else {
	dict append global_constants ${name} [dict create type ${type} value ${value}]
    }
   
}

## proc \c Generate_Global_package
# This call generates the final global package file and writes it to disk.
# The contents have been set by calls to Add_Global_constant
proc Generate_Global_package {} {
    global build_name
    global apollo_root_path
    global autogen_path

    #global files set
    set filename "${apollo_root_path}/${autogen_path}/Global_PKG.vhd"
    set outfile [open ${filename} w]
    
    puts $outfile "----------------------------------------------------------------------------------"
    puts $outfile "--"
    puts $outfile "----------------------------------------------------------------------------------"
    puts $outfile ""
    puts $outfile "library ieee;"
    puts $outfile "use ieee.std_logic_1164.all;"
    puts $outfile ""
    puts $outfile "package Global_PKG is"



    global global_constants
    if { [info exists global_constants] == 1 } {
	#output constants
	dict for {parameter value} $global_constants {	    
	    puts $outfile [format "  constant  %-30s : %-10s := %-10s;" $parameter [dict get $value type] [dict get $value value] ]
	}
    }

    puts $outfile "end package Global_PKG;"
    close $outfile
    #load the new VHDL file
    read_vhdl $filename
}
