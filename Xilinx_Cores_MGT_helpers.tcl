source -notrace ${BD_PATH}/HDL_gen_helpers.tcl

#################################################################################
## Build Xilinx MGT IP Package info part of MGT_info
#################################################################################
# args:
#   base_name:  name of this package (group of records)
#   file_path:  output path for generated files
#   records:    inital dictionary of records
# return: package_info
#          - name : name of the package
#          - filename : name of the file with the package
#          - xml_files (dict)
#            - name : xmlfile_path
#          - records (dict):  dictionary of all the records
#            - common_input (dict): dictionary of info about this group of registers
#              - name : record name
#              - xml_file: (dict)
#                  - name
#                  - path
#              - regs (list of dicts)   : list of registers for the common registers into the IP core
#                - dictionary:
#                  - name: real name of register (in core)
#                  - alias: simplified name
#                  - dir: in vs out
#                  - MSB: msb bit position
#                  - LSB: lsb bit position (really always 0, but for future use)
#            - common_output (list of dicts)  : list of registers
#            - userdata_intput (list of dicts): list of registers for the user (data) into the IP core
#            - userdata_output (list of dicts): list of registers
#            - clocks_input (list of dicts)   : list of registers
#            - clocks_output (list of dicts)  : list of registers
#            - channel_intput (list of dics)
#            - channel_output

proc BuildMGTPackageInfo {base_name file_path records} {
    
    #start by setting the package name and output path
    set package_info [dict create "name" "${base_name}_PKG"]
    dict append package_info "filename" "${file_path}/${base_name}_PKG.vhd"	
    
    #create this pkg file
    file mkdir $file_path	
    set outfile [open [dict get $package_info "filename"] w]

    #============================================================================
    #write the packages
    #============================================================================
    StartPackage ${outfile} ${base_name}	
    foreach record_type "common_input common_output \
       		       clocks_input clocks_output \
		       channel_input channel_output \
		       userdata_input userdata_output" {	    

	#create a VHDL record for this record type
	set record_name [WritePackageRecord \
			    ${outfile} \
			    "${base_name}_${record_type}" \
			    [dict get $records $record_type "regs"]\
			   ]
	if { $record_name != ""} {
	    dict with records {
		dict append ${record_type} "name" ${record_name}
	    }
	}	    
    }
    EndPackage ${outfile} ${base_name}
    close $outfile
    read_vhdl "${file_path}/${base_name}_PKG.vhd"	    	    


    #============================================================================
    #create XML files for these registers for address table automation
    #============================================================================
    #create an xml file for this device
    puts "Creating XML for ${base_name}"
    foreach module "common channel" {	    
	#create this xml file
	set file_base "${base_name}_${module}"
	set outfile [open "${file_path}/${file_base}.xml" w]
	puts "  Building: ${file_path}/${file_base}.xml"
	#note the name of this package for the wrapper
	if { ![dict exists $package_info "xml_files"] } {
	    dict append package_info "xml_files" ""
	}
	dict with package_info {
	    dict append "xml_files" ${file_base} "${file_path}/${file_base}.xml"
	}
	set regs [list]
	foreach dir "input output" {		
	    if { [dict exists $records "${module}_${dir}"] } {
		if { [llength [dict get $records "${module}_${dir}"] ] > 0 } {		    
		    set regs [list {*}$regs {*}[dict get $records "${module}_${dir}" "regs"]]
		}
	    }
	}
	BuildXMLAddressTable ${outfile} ${file_base} ${regs}
	close $outfile
    }
    
    dict append package_info "records" $records
    return $package_info
}

proc BuildMGTWrapperVHDL {base_name wrapper_filename MGT_info} {
    set channel_count [dict get ${MGT_info} "channel_count"]
    
    set wrapper_file [open ${wrapper_filename} w]
    puts "Building wrapper file: ${wrapper_filename}"

    set line_ending ""; #useful for vhdl lists that can't end with the separator character

    #============================================================================
    #start writing the VHDL file
    #============================================================================
    puts $wrapper_file "library ieee;"
    puts $wrapper_file "use ieee.std_logic_1164.all;\n"

    #add includes for records
    set package_name [dict get $MGT_info "package_info" "name"]
    puts $wrapper_file "use work.${package_name}.all;"	
#    dict for {record_name record_data} [dict get $MGT_info "package_info"] {
##	set record_type [dict get $record_data "name"]
#	puts $wrapper_file "use work.${}.all;"	
#    }

    #========================================================
    #build the entity
    #========================================================
    puts $wrapper_file "entity ${base_name}_wrapper is\n"
    puts $wrapper_file "  port ("
    set line_ending ""
    dict for {record_name record} [dict get $MGT_info "package_info" "records"] {
	#determin record direction
	set dir "out"
	if { [string first "_input" $record_name] >= 0 } {
	    set dir "in "
	}

	set record_type [dict get $record "name"]
	#write port line (channel and userdata are array types, others are normal)
	puts -nonewline $wrapper_file "${line_ending}\n"
	if { [string first "channel" ${record_name}] == 0 ||
	     [string first "userdata" ${record_name}] == 0 } {
	    #change from _t to _array_t
	    set record_type [string map {"_t" "_array_t"} $record_type]
	    append record_type "(${channel_count}-1 downto 0)"
	}
	puts -nonewline $wrapper_file "    ${record_name}   : $dir  ${record_type}"
	set line_ending ";"
    }
    puts $wrapper_file "    );"
    puts $wrapper_file "end entity ${base_name}_wrapper;\n"

    #========================================================
    # build the architecture
    #========================================================
    puts $wrapper_file "architecture behavioral of ${base_name}_wrapper is"

    set component_data ""
    set entity_data ""
    set component_line_ending ""
    set entity_line_ending ""
    puts [dict keys [dict get $MGT_info "package_info" "records"]]
    foreach module "common_input common_output \
    	    	   clocks_input clocks_output \
		   channel_input channel_output \
		   userdata_input userdata_output" {
	foreach signal [dict get ${MGT_info} "package_info" "records" ${module} "regs"] {
	    #pull needed values from the dictionary
	    set name [dict get $signal "name"]
	    set alias [dict get $signal "alias"]
	    set dir  [dict get $signal "dir"]
	    #update input/output to vhdl in/out
	    set dir "out"
	    if { $dir == "input" } {
		set dir "in "
	    }
	    set MSB [dict get $signal "MSB"]
	    set LSB [dict get $signal "LSB"]

	    if { [string first "channel" ${module}] == 0 ||
		 [string first "userdata" ${module}] == 0 } {

		if { $dir == "in "} {
		    #the size of these are per channel,so we need to update MSB and LSB
		    set width [expr (1+ $MSB - $LSB)*$channel_count]		
		    set MSB [expr $LSB + $width - 1]
		    #entity lines
		    append entity_data [format "%s%40s(% 3u downto % 3u) => (" \
					    ${entity_line_ending} \
					    ${name} \
					    ${MSB} \
					    ${LSB} ]
		    set array_ending "\n"
		    #fill out the assignment with "&" of the package member
		    for {set iChannel [expr $channel_count -1]} {$iChannel >= 0} {incr iChannel -1} {
			append entity_data [format "%s%*s %s(% 3d).%s" \
						${array_ending} \
						"60" \
						" " \
						${module} \
						${iChannel} \
						${alias}]
			set array_ending " & \n"
		    }
		    append entity_data  ")"
		} else {
		    set bottom_index 0
		    set width [expr ($MSB - $LSB + 1)]
		    for {set iChannel [expr $channel_count -1]} {$iChannel >= 0} {incr iChannel -1} {			
			append  entity_data [format "%s%40s(% 3u downto % 3u) => %*s %s(% 3u).%s" \
						 ${entity_line_ending} \
						 ${name} \
						 [expr $iChannel * $width ]\
						 [expr (($iChannel + 1) * $width) -1]\
						 "60" \
						 " " \
						 ${module} \
						 ${iChannel} \
						 ${alias}]
			
		    }
		    
		}
		
	    } else {
		
		append entity_data [format "%s%40s(% 3u downto % 3u) => %s.%s" \
					${entity_line_ending} \
					${name} \
					$MSB \
					$LSB \
					${module} \
					${alias} ]
	    }
	    set entity_line_ending ",\n"

	    
	    # ${line_ending} is used because VHDL can't handle the last line in a list having the separation character
	    append component_data [format "%s%40s : %3s std_logic_vector(% 3u downto % 3u)" \
				       ${component_line_ending}\
				       ${name} \
				       ${dir} \
				       $MSB \
				       $LSB ]
	    set component_line_ending ";\n"
	}
    }

    #####################################
    #component declaration for verilog interface    
    puts $wrapper_file "component ${base_name}"
    puts $wrapper_file "  port("
    puts $wrapper_file ${component_data}
    puts $wrapper_file "  );"
    puts $wrapper_file "END COMPONENT;"


    #####################################
    #component declaration for verilog interface    
    puts $wrapper_file "begin"
    puts $wrapper_file "${base_name}_inst : entity work.${base_name}"
    puts $wrapper_file "  port map ("
    puts $wrapper_file ${entity_data}
    puts $wrapper_file ");"    
    puts $wrapper_file "end architecture behavioral;"
    close $wrapper_file
}
