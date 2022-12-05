package require yaml
source ${BD_PATH}/utils/pdict.tcl
source ${BD_PATH}/Regmap/RegisterMap.tcl
source ${BD_PATH}/Cores/Xilinx_Cores.tcl
source ${BD_PATH}/HAL/HAL_helpers.tcl

proc HAL_wrapperGen { params
		      ip_template_info
		      type_count
		      type_channel_counts
		      type_common_counts
		      regmap_pkgs
		      regmap_sizes
		      clock_map
		  } {
    #Global build names
    global build_name
    global apollo_root_path
    global autogen_path
    global BD_PATH

    set_required_values $params "axi_control"
    set_optional_values $params {"remote_slave" "0" "addr" {"offset" "-1" "range" "-1"}}


    #############################################################################
    #Start generating the HAL vhdl file
    #############################################################################
    set HAL_file [open "${apollo_root_path}/${autogen_path}/HAL/HAL.vhd" w]    
    puts -nonewline ${HAL_file} "library ieee;\n"
    puts -nonewline ${HAL_file} "use ieee.std_logic_1164.all;\n\n"
    puts -nonewline ${HAL_file} "use work.axiRegPkg.all;\n"
    #add the clocks package
    puts -nonewline ${HAL_file} "use work.hal_pkg.all;\n\n\n"


    #Add all the packages we will need for the IP Core wrappers   
    dict for {channel_type ip_info} $ip_template_info {
	set package_name [dict get $ip_info "registers" "package_info" "name"]
	puts -nonewline ${HAL_file} "use work.${package_name}.all;\n"
    }
    #Add all the packages we will need for the regmap decoders
    foreach regmap_pkg $regmap_pkgs {
	puts -nonewline ${HAL_file} "use work.${regmap_pkg}.all;\n"
    }

    puts -nonewline ${HAL_file} "Library UNISIM;\n"
    puts -nonewline ${HAL_file} "use UNISIM.vcomponents.all;\n\n\n"

    #############################################################################
    # Add entity declaration
    #############################################################################
    puts -nonewline ${HAL_file} "entity HAL is\n"
    #generics for decoder size checking (one per type)
    puts -nonewline ${HAL_file} "  generic (\n"
    set line_ending ""
    dict for {channel_type ip_info} $ip_template_info {
	puts -nonewline ${HAL_file} [format "%s%40s : integer" \
					 $line_ending \
					 "${channel_type}_MEMORY_RANGE"
				    ]
	set line_ending ";\n"	
    }
    puts -nonewline ${HAL_file} ");\n"
    #AXI interface ports
    puts -nonewline ${HAL_file} "  port (\n"
    puts -nonewline ${HAL_file} "                                 clk_axi : in  std_logic;\n"
    puts -nonewline ${HAL_file} "                             reset_axi_n : in  std_logic;\n"
    puts -nonewline ${HAL_file} "                                readMOSI : in  AXIreadMOSI_array_t (${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                                readMISO : out AXIreadMISO_array_t (${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                               writeMOSI : in  AXIwriteMOSI_array_t(${type_count} - 1 downto 0);\n"
    puts -nonewline ${HAL_file} "                               writeMISO : out AXIwriteMISO_array_t(${type_count} - 1 downto 0);\n"
    #Top level MGT signal ports
    puts -nonewline ${HAL_file} "                             HAL_refclks : in  HAL_refclks_t;\n"
    puts -nonewline ${HAL_file} "                        HAL_serdes_input : in  HAL_serdes_input_t;\n"
    puts -nonewline ${HAL_file} "                       HAL_serdes_output : out HAL_serdes_output_t;\n"
    
    
    #finish entity port map
    set line_ending ""
    dict for {channel_type ip_info} $ip_template_info {
	set records [dict get $ip_info "registers" "package_info" "records"]
	foreach record_name [dict keys $records] {
	    if { ([string first "userdata" ${record_name}] == 0) ||
		 ([string first "clocks_output" ${record_name}] == 0)} {
		#only route out userdata, other packages are internal/via axi
		set dir "in "
		if { [string first "_output" $record_name] >= 0 } {
		    set dir "out"
		}
		puts -nonewline ${HAL_file} [format "%s%40s : %3s %s_array_t(% 3d-1 downto 0)" \
						 $line_ending \
						 "${channel_type}_${record_name}" \
						 $dir \
						 ${channel_type}_${record_name} \
						 [dict get $type_channel_counts $channel_type] \
						]
		set line_ending ";\n"
	    }
	}
    }
    puts -nonewline ${HAL_file} ");\n"
    puts -nonewline ${HAL_file} "end entity HAL;\n\n\n"

    #############################################################################
    # Architecture
    #############################################################################
    puts -nonewline ${HAL_file} "architecture behavioral of HAL is\n"

    #write the local signals needed to route ip core packages

    #Add refclk signals
    dict for {clk_name count} $clock_map {
	puts ${HAL_file} [format \
			      "  signal %40s : std_logic;" \
			      "refclk_${clk_name}"]
	puts ${HAL_file} [format \
			      "  signal %40s : std_logic;" \
			      "refclk_${clk_name}_2"]
    }
    puts ${HAL_file} "" ; #new line
    
    #Add wrapper signals
    dict for {channel_type ip_info} $ip_template_info {
	set registers [dict get $ip_info "registers"]
	#loop over package_files (not there should on be on entry for the package name)
	set package_name [dict get $ip_info "registers" "package_info" "name"]
	dict for {record_name record_data} [dict get ${registers} "package_info" "records"] {
	    if {([string first "userdata" ${record_name}] < 0) &&
		([string first "clocks_output" ${record_name}] < 0)} {		
		#we don't need local copies of userdata signals
		puts -nonewline ${HAL_file} [format "  signal %40s : %s(%s-1 downto 0);\n" \
						 "${channel_type}_${record_name}" \
						 "${channel_type}_${record_name}_array_t"\
						 [dict get $type_channel_counts $channel_type] ]
	    }
	}
	puts -nonewline ${HAL_file} "\n\n"
    }
    #Add regmap signals
    dict for {channel_type ip_info} $ip_template_info {
	foreach reg_map_record {"Ctrl" "Mon"} {
	    puts -nonewline ${HAL_file} [format "  signal %40s : %s;\n" \
					     "${reg_map_record}_${channel_type}" \
					     "${channel_type}_${reg_map_record}_t"]
	}
    }

    #############################################################################
    # VHDL Begin
    #############################################################################
    
    #Generate all the ip cores, grouped by type
    puts -nonewline ${HAL_file} "begin\n"

    #capture refclks
    dict for {clk_name count} $clock_map {
	#should be generalized to include US FPGAs
	puts  ${HAL_file} "  ibufds_${clk_name} : ibufds_gte4"
	puts  ${HAL_file} "    generic map ("
	puts  ${HAL_file} "      REFCLK_EN_TX_PATH  => '0',"
	puts  ${HAL_file} "      REFCLK_HROW_CK_SEL => \"00\","
	puts  ${HAL_file} "      REFCLK_ICNTL_RX    => \"00\")"
	puts  ${HAL_file} "    port map ("
	puts  ${HAL_file} "      O     => refclk_${clk_name},"
	puts  ${HAL_file} "      ODIV2 => refclk_${clk_name}_2,"
	puts  ${HAL_file} "      CEB   => '0',"
	puts  ${HAL_file} "      I     => HAL_refclks.refclk_${clk_name}_P,"
	puts  ${HAL_file} "      IB    => HAL_refclks.refclk_${clk_name}_N"
	puts  ${HAL_file} "      );"
	puts  ${HAL_file} "      \n"

    }

    #generate the regmap interfaces for this type and all wrappers for this type
    #connect these all up
    set AXI_array_index 0
    dict for {channel_type ip_info} $ip_template_info {
	#per IP starting offset
	set current_offset 0
	set max_offset [dict get $type_channel_counts $channel_type]
	
	set registers [dict get $ip_info "registers"]
	set ip_cores  [dict get $ip_info "ip_cores"]
	puts -nonewline ${HAL_file} "--------------------------------------------------------------------------------\n"
	puts -nonewline ${HAL_file} "--${channel_type}\n"
	puts -nonewline ${HAL_file} "--------------------------------------------------------------------------------\n"
	
	#################################
	#add this types regmap interface
	GenerateRegMapInstance $channel_type ${AXI_array_index} ${HAL_file}
	set AXI_array_index [expr ${AXI_array_index} + 1]
	set current_single_index 0
	set current_multi_index 0

	#loop over all the quad IP cores for this type
	for {set iCore 0} {$iCore < [dict get $type_common_counts $channel_type]} {incr iCore} {

	    
	    #check that the range for this ipcore in the array of packages makes sense 
	    if {$current_single_index >= ${max_offset} } {
		error "When building IP core $ip_core the channel offset ($current_single_index) was larger than the max channel offset ($max_offset)"		
	    }
	    ##############################
	    #generate the IP Core instance
	    set old_current_single_index $current_single_index
	    set old_current_multi_index $current_multi_index
	    GenerateMGTInstance \
		${HAL_file} \
		[lindex [dict get $ip_info "ip_cores"] $iCore] \
		${channel_type} \
		[dict get $registers "package_info" "records"] \
		[dict get [dict get $ip_info "toplevel_regs"] \
		     [lindex [dict get $ip_info "ip_cores"] $iCore] ] \
		"current_single_index" \
		"current_multi_index"

	    ##############################
	    #connect up clocks
	    foreach register [dict get $registers "package_info" "records" "clocks_input" "regs"] {
		#find the appropriate clock dict for this ipcore
		set current_clks [dict get $ip_info "rx_clocks" [lindex [dict get $ip_info "ip_cores"] $iCore]]
		
		
		for {set iChanClk [dict get $register "LSB"]} {$iChanClk <= [dict get $register "MSB"]} {incr iChanClk} {
		    #		    set refclk_name [GenRefclkName [lindex $current_clks 0] [lindex [lindex $current_clks 1] 1]]
		    set refclk_name [GenRefclkName [lindex $current_clks 0] [lindex [lindex $current_clks 1] [expr 2*$iChanClk + 1]]]
		    puts ${HAL_file} [format "    %s_clocks_input(%d).%s(%d) <= refclk_%s;\n" \
					  $channel_type \
					  $old_current_single_index \
					  [dict get $register "alias"] \
					  $iChanClk \
					  $refclk_name \
					 ]
		}
	    }


	    
	    
	    ######################################################
	    #connect up all the common per-quad register signals
	    ConnectUpMGTRegMap \
		${HAL_file} $channel_type \
		"common_input common_output" \
		[dict get $registers "package_info" "records"] \
		$old_current_single_index \
		$old_current_single_index	    

	    ######################################################
	    #connect up all the perchannel register signals
	    ConnectUpMGTRegMap \
		${HAL_file} $channel_type \
		"channel_input channel_output" \
		[dict get $registers "package_info" "records"] \
		$old_current_multi_index \
		[expr $current_multi_index -1] \
		[dict create "regex" {channel\([0-9]*\)} "replace" {\0.config}]

	    ConnectUpMGTRegMap \
		${HAL_file} $channel_type \
		"drp_input drp_output" \
		[dict get $registers "package_info" "records"] \
		$old_current_multi_index \
		[expr $current_multi_index -1] \
		[dict create "regex" {drp(\([0-9]*\))} "replace" {channel\1.drp} ]


	    
	    #move to the next group of signals
	}
	puts -nonewline ${HAL_file} "\n\n"
	
    }
    #####################################################
    #finish hal vhdl file
    puts -nonewline ${HAL_file} "end architecture behavioral;\n"
    
       	
    close $HAL_file
    read_vhdl "${apollo_root_path}/${autogen_path}/HAL/HAL.vhd"


    ###################################################
    #add AXI connections to the interconnect for the decoders
    dict for {channel_type ip_info} $ip_template_info {
	
	set mapsize [expr 2**([dict get $regmap_sizes $channel_type] - 10)]; #-10 for 2**10 == 1k
	puts $mapsize
	if { $mapsize > 1024 } {
	    set mapsize [expr $mapsize >> 10]"M"
	} else {
	    set mapsize ${mapsize}"M"
	}
	

	set params [dict create \
				"device_name" $channel_type \
				"axi_control" [dict create  \
						   "axi_interconnect" $axi_interconnect \
						   "axi_clk" $axi_clk \
						   "axi_rstn" $axi_rstn \
						   "axi_freq" $axi_freq \
						  ]\
				"addr"        [dict create "offset" $offset "range" $range] \
				"remote_slave" $remote_slave \
			    ]

	puts $params
	AXI_PL_DEV_CONNECT $params
    }
}
