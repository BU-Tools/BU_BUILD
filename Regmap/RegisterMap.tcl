proc GenerateRegMapPKGUse {name outfile} {    
    puts $outfile "use work.${name}_CTRL.all;"
}

proc GenerateRegMapInstance { name axi_index outfile} {
    puts $outfile "${name}_map_1: entity work.${name}_map"
    puts $outfile "  generic map ("
    puts $outfile "    ALLOCATED_MEMORY_RANGE => HAL_${name}_MEMORY_RANGE)"
    puts $outfile "  port map ("
    puts $outfile "    clk_axi         => clk_axi,"
    puts $outfile "    reset_axi_n     => reset_axi_n,"
    puts $outfile "    slave_readMOSI  => readMOSI(${axi_index}),"
    puts $outfile "    slave_readMISO  => readMISO(${axi_index}),"
    puts $outfile "    slave_writeMOSI => writeMOSI(${axi_index}),"
    puts $outfile "    slave_writeMISO => writeMISO(${axi_index}),"
    puts $outfile "    Mon             => Mon_${name},"
    puts $outfile "    Ctrl            => Ctrl_${name});"
    
}

proc GenerateRegMap {params} {
    global build_name
    global apollo_root_path
    global autogen_path
    global env

    #config all the arguments
    set_required_values $params {device_name}
    set_required_values $params {xml_path}
    set_required_values $params {out_path}

    set_optional_values $params [dict create \
				     simple False \
				     verbose False \
				     debug False \
				     mapTemplate "templates/axi_generic/template_map.vhd" \
				    ]

    #Handle path and env issues that arrise when calling python from tcl
    #path
    set current_dir [pwd]
    set prog build_vhdl_packages    
    set prog_path ${apollo_root_path}/regmap_helper
    cd $prog_path
    #env
    set python_home ""
    set python_path ""
    if { [info exists env(PYTHONPATH)] } {
	set python_home $env(PYTHONPATH)
	unset env(PYTHONPATH)
    }
    if { [info exists env(PYTHONHOME)] } {
	set python_path $env(PYTHONHOME)
	unset env(PYTHONHOME)
    }
    

    #generate the command we need to call
    set command [list ${prog}.py \
		     --simple $simple \
		     --verbose $verbose \
		     --debug $debug \
		     --mapTemplate $mapTemplate \
		     --outpath $out_path \
		     --xmlpath $xml_path \
		     $device_name ]
    set ret [exec {*}$command]

    set regmapsize 0
    foreach line $ret {
	if { [string first "RegmapSize" $line ] >= 0} {
	    set split_line [split $line ":"]
	    if { [llength $split_line] >= 3 } {
		regmapsize = [lindex $split_line 3]
	    }
	}
    }
    
    
    #restore path
    cd $current_dir

    #restor env
    if { [string length $python_home] > 0 } {	
	set env(PYTHONHOME) $python_home
    }
    if { [string length $python_home] > 0 } {
	set env(PYTHONPATH) $python_path
    }

    
    set pkgFile "${out_path}/${device_name}_PKG.vhd"
    set mapFile "${out_path}/${device_name}_map.vhd"

    puts $pkgFile
    puts $mapFile

    return [list $pkgFile $mapFile $regmapsize]
}
		   
