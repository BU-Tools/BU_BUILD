source -notrace ${BD_PATH}/axi_helpers.tcl



proc WritePackage {outfile name data} {
    puts $outfile "type $name is record"
    dict for {key value} $data {
	puts $outfile [format "  %-30s : %s;" $key [lindex $value 0] ]
    }
    puts $outfile "end record $name;"
    puts $outfile "type ${name}_array_t is array (integer range <>) of $name;"
}
proc BuildMGTCores {params} {
    global build_name
    global apollo_root_path
    global autogen_path

    set_required_values $params {freerun_frequency}
    set_required_values $params {device_name}
    #False means return a full dict instead of a broken up dict
    set_required_values $params {clocking} False
    set_required_values $params {protocol} False
    set_required_values $params {links} False
    set_required_values $params {GT_TYPE}

    set_optional_values $params [dict create core {LOCATE_TX_USER_CLOCKING CORE LOCATE_RX_USER_CLOCKING CORE}]

    dict create GT_TYPEs {}
    dict append GT_TYPEs "UNKNOWN" "\"0000\""
    dict append GT_TYPEs "GTH" "\"0001\""
    dict append GT_TYPEs "GTX" "\"0010\""
    dict append GT_TYPEs "GTY" "\"0011\""

    #####################################
    #create IP            
    #####################################
    set output_path ${apollo_root_path}/${autogen_path}/cores/    
#    file delete -force -- ${output_path}/${device_name}
    file mkdir ${output_path}


    #delete if it already exists
    if { [get_ips -quiet $device_name] == $device_name } {
	export_ip_user_files -of_objects  [get_files ${device_name}.xci] -no_script -reset -force -quiet
	remove_files  ${device_name}.xci
    }
    #create
    create_ip -vlnv [get_ipdefs -filter {NAME == gtwizard_ultrascale}] -module_name ${device_name} -dir ${output_path}
    set xci_file [get_files ${device_name}.xci]
	

    #start a list of properties
    dict create property_list {}

    #simple properties
    dict append property_list CONFIG.GT_TYPE $GT_TYPE
    dict append property_list CONFIG.FREERUN_FREQUENCY $freerun_frequency
    dict append property_list CONFIG.LOCATE_TX_USER_CLOCKING $LOCATE_TX_USER_CLOCKING
    dict append property_list CONFIG.LOCATE_RX_USER_CLOCKING $LOCATE_RX_USER_CLOCKING

    #add optional ports to the device
    dict append property_list CONFIG.ENABLE_OPTIONAL_PORTS {cplllock_out eyescanreset_in eyescantrigger_in eyescandataerror_out dmonitorout_out pcsrsvdin_in rxbufstatus_out rxprbserr_out rxresetdone_out rxbufreset_in rxcdrhold_in rxdfelpmreset_in rxlpmen_in rxpcsreset_in rxpmareset_in rxprbscntreset_in rxprbssel_in rxrate_in txbufstatus_out txresetdone_out txinhibit_in txpcsreset_in txpmareset_in txpolarity_in txpostcursor_in txprbsforceerr_in txprecursor_in txprbssel_in txdiffctrl_in drpaddr_in drpclk_in drpdi_in drpen_in drprst_in drpwe_in drpdo_out drprdy_out rxctrl2_out txctrl2_in}

    #clocking
    foreach {dict_key dict_value} $clocking {
	foreach {key value} $dict_value {
	    dict append property_list CONFIG.${dict_key}_${key} $value
	}
    }
    #protocol
    foreach {dict_key dict_value} $protocol {
	foreach {key value} $dict_value {
	    dict append property_list CONFIG.${dict_key}_${key} $value
	}
    }
    #links
    set enabled_links {}
    dict create rx_clocks {}
    dict create tx_clocks {}
    foreach {dict_key dict_value} $links {
	lappend enabled_links $dict_key 
	foreach {key value} $dict_value {
	    if {$key == "RX"} {
		dict append rx_clocks $dict_key $value
	    } elseif {$key == "TX"} {
		dict append tx_clocks $dict_key $value
	    }
	}
    }
    dict append property_list CONFIG.CHANNEL_ENABLE $enabled_links
    dict append property_list CONFIG.TX_REFCLK_SOURCE $tx_clocks
    dict append property_list CONFIG.RX_REFCLK_SOURCE $rx_clocks
    
    #apply all the properties to the IP Core
    set_property -dict $property_list [get_ips ${device_name}]
    generate_target -force {instantiation_template synthesis} [get_ips ${device_name}]
    synth_ip [get_ips ${device_name}]
    

    #####################################
    #create a wrapper 
    #####################################
    set tx_count [dict size $tx_clocks]
    set rx_count [dict size $rx_clocks]

    if {$tx_count != $rx_count} {
	error "tx_count and rx_count don't match"
    }

    set example_verilog_filename [get_files -filter "PARENT_COMPOSITE_FILE == ${xci_file}" "*/synth/${device_name}.v"]
    set example_verilog_file [open ${example_verilog_filename} r]
    set file_data [read ${example_verilog_file}]
    set data [split ${file_data} "\n"]
    close $example_verilog_file
    dict create common_in  {}
    dict create common_out {}
    dict create channel_in  {}
    dict create channel_out {}
    set component_info {}
    dict append channel_out TXRX_TYPE {"std_logic_vector(3 downto 0)" 4}

    foreach line $data {
	if {[regexp { *(output|input) *wire *\[([0-9]*) *: *([0-9]*)\] *([a-zA-Z_0-9]*);} ${line}  full_match direction MSB LSB name] == 1} {

	    #build a list of IOs for the vhdl component
	    set component_line "$name : "
	    if {$direction == "output"} {
		append component_line "out "
	    } elseif {$direction == "input"} {
		append component_line "in  "
	    }
	    append component_line "std_logic_vector($MSB downto $LSB)"
	    lappend component_info $component_line


	    #this has passed a regex for a verilog wire line, so we need to process it. 
	    #unless it is a userdata signal, since we want to split that up by channel
	    if { [string range $name 0 5] == "gtwiz_" && [string first "userdata" $name] == -1} {
		#see if this is a vector or a signal
		set type ""
		if {$MSB == 0} {
		    set type "std_logic"			
		} else {
		    set type "std_logic_vector($MSB downto 0)"
		}
		set bitsize [expr ($MSB - $LSB)+1]
		#this is a common signal, so just use it
		if {$direction == "output"} {
		    dict append common_out $name [list $type $bitsize]
		} elseif {$direction == "input"} {
		    dict append common_in  $name [list $type $bitsize]
		} else {
		    error "Invalid in/out type $line"
		}
	    } else {
		#this isn't a common signal, so we need to figure out how to split it up
		if {$LSB != 0} {
		    error "Somehow this wire doesn't start at bit 0"
		}
		if { [expr {($MSB + 1) % $tx_count}] != 0 } {
		    error "Signal $name doens't divide properly by tx_count"
		} else {
		    #determine the type for this variable
		    set bitsize [expr {($MSB + 1) / $tx_count}]
		    set type ""
		    if {$bitsize == 1} {
			set type "std_logic"			
		    } else {
			set type "std_logic_vector($bitsize -1 downto 0)"
		    }
		    #save the line
		    if {$direction == "output"} {
			dict append channel_out $name [list $type $bitsize]
		    } elseif {$direction == "input"} {
			dict append channel_in  $name [list $type $bitsize]
		    } else {
			error "Invalid in/out type $line"
		    }				    
		}
		

	    }
	    
	}
    }
    
    #write the packages for this wrapper
    set package_filename "${apollo_root_path}/${autogen_path}/cores/${device_name}/${device_name}_pkg.vhd"
    set package_file [open ${package_filename} w]
    puts $package_file "----------------------------------------------------------------------------------"
    puts $package_file "--"
    puts $package_file "----------------------------------------------------------------------------------"
    puts $package_file ""
    puts $package_file "library ieee;"
    puts $package_file "use ieee.std_logic_1164.all;"
    puts $package_file ""
    puts $package_file "package ${device_name}_PKG is"
 
    WritePackage $package_file "${device_name}_CommonIn"   $common_in
    WritePackage $package_file "${device_name}_CommonOut"  $common_out
    WritePackage $package_file "${device_name}_ChannelIn"  $channel_in
    WritePackage $package_file "${device_name}_ChannelOut" $channel_out
    
    puts $package_file "end package ${device_name}_PKG;"
    close $package_file
    read_vhdl ${package_filename}

    #write the warpper
    set wrapper_filename "${apollo_root_path}/${autogen_path}/cores/${device_name}/${device_name}_wrapper.vhd"
    set wrapper_file [open ${wrapper_filename} w]
    puts $wrapper_file "library ieee;"
    puts $wrapper_file "use ieee.std_logic_1164.all;\n"
    puts $wrapper_file "use work.${device_name}_PKG.all;\n"
    puts $wrapper_file "entity ${device_name}_wrapper is\n"
    puts $wrapper_file "  port ("
    puts $wrapper_file "    common_in   : in  ${device_name}_CommonIn;"
    puts $wrapper_file "    common_out  : out ${device_name}_CommonOut;"
    puts $wrapper_file "    channel_in  : in  ${device_name}_ChannelIn_array_t($tx_count downto 1);"
    puts $wrapper_file "    channel_out : out ${device_name}_ChannelOut_array_t($tx_count downto 1));"
    puts $wrapper_file "end entity ${device_name}_wrapper;\n"
    puts $wrapper_file "architecture behavioral of ${device_name}_wrapper is"
    #component declaration for verilog interface
    
    puts $wrapper_file "component ${device_name}"
    puts $wrapper_file "  port("
    for {set i 0} {$i < [expr [llength $component_info]-1]} {incr i } {
	puts -nonewline $wrapper_file [lindex $component_info $i]
	puts $wrapper_file ";"
    }
    puts -nonewline $wrapper_file [lindex $component_info [expr [llength $component_info]-1] ]
    puts $wrapper_file "  );"
    puts $wrapper_file "END COMPONENT;"


    puts $wrapper_file "begin"
    puts $wrapper_file "${device_name}_inst : entity work.${device_name}"
    puts $wrapper_file "  port map ("
    #helps keep the final comma missing 
    set needsComma " "
    foreach {key value} $common_in {
	puts -nonewline $wrapper_file  "$needsComma \n    $key (0) => Common_In.$key"
	set needsComma ","
    }
    foreach {key value} $common_out {
	puts -nonewline $wrapper_file  "$needsComma \n    $key (0) => Common_Out.$key"
	set needsComma ","
    }
    foreach {key value} $channel_in {
	puts $wrapper_file  "$needsComma \n    $key => std_logic_vector'("
	for {set i $tx_count} {$i > 1} {incr i -1} {
	    puts $wrapper_file "             Channel_In($i).$key  &"
	}
	puts -nonewline $wrapper_file "              Channel_In(1).$key)"
	set needsComma ","
    }
    foreach {key value } $channel_out {
	if {$key != "TXRX_TYPE"} {
	    set value_size [lindex $value 1]
	    for {set i 0} {$i < $tx_count} {incr i} {
		if { $value_size == 1 } {
		    puts $wrapper_file  "$needsComma \n    $key ($i) => Channel_Out($i + 1).$key"
		} else {
		    puts $wrapper_file  "$needsComma \n    $key (($value_size*($i+1))-1 downto ($value_size*$i)) => Channel_Out($i + 1).$key"
		}
	    }
	    set needsComma ","
	}
    }
    puts $wrapper_file ");"

    
    for {set i $tx_count} {$i > 0} {incr i -1} {
	puts -nonewline $wrapper_file "channel_out($i).TXRX_TYPE <= "
	puts -nonewline $wrapper_file [dict get $GT_TYPEs $GT_TYPE]
	puts $wrapper_file ";"
    }
    puts $wrapper_file "end architecture behavioral;"
    close $wrapper_file
    read_vhdl ${wrapper_filename}

}






#other optional ports not selected
#stepdir_in cdrstepsq_in cdrstepsx_in cfgreset_in clkrsvd0_in clkrsvd1_in cpllfreqlock_in cplllockdetclk_in cplllocken_in cpllrefclksel_in cpllreset_in dmonfiforeset_in dmonitorclk_in drpaddr_in drpclk_in drpdi_in drpen_in drprst_in drpwe_in freqos_in gtgrefclk_in gtnorthrefclk0_in gtnorthrefclk1_in gtrefclk1_in gtrsvd_in gtrxresetsel_in gtsouthrefclk0_in gtsouthrefclk1_in gttxresetsel_in incpctrl_in loopback_in pcieeqrxeqadaptdone_in pcierstidle_in pciersttxsyncstart_in pcieuserratedone_in qpll0clk_in qpll0freqlock_in qpll0refclk_in qpll1clk_in qpll1freqlock_in qpll1refclk_in resetovrd_in rxafecfoken_in rxcdrfreqreset_in rxcdrovrden_in rxcdrreset_in rxchbonden_in rxchbondi_in rxchbondlevel_in rxchbondmaster_in rxchbondslave_in rxckcalreset_in rxckcalstart_in rxdfeagcctrl_in rxdfeagchold_in rxdfeagcovrden_in rxdfecfokfcnum_in rxdfecfokfen_in rxdfecfokfpulse_in rxdfecfokhold_in rxdfecfokovren_in rxdfekhhold_in rxdfekhovrden_in rxdfelfhold_in rxdfelfovrden_in rxdfetap2hold_in rxdfetap2ovrden_in rxdfetap3hold_in rxdfetap3ovrden_in rxdfetap4hold_in rxdfetap4ovrden_in rxdfetap5hold_in rxdfetap5ovrden_in rxdfetap6hold_in rxdfetap6ovrden_in rxdfetap7hold_in rxdfetap7ovrden_in rxdfetap8hold_in rxdfetap8ovrden_in rxdfetap9hold_in rxdfetap9ovrden_in rxdfetap10hold_in rxdfetap10ovrden_in rxdfetap11hold_in rxdfetap11ovrden_in rxdfetap12hold_in rxdfetap12ovrden_in rxdfetap13hold_in rxdfetap13ovrden_in rxdfetap14hold_in rxdfetap14ovrden_in rxdfetap15hold_in rxdfetap15ovrden_in rxdfeuthold_in rxdfeutovrden_in rxdfevphold_in rxdfevpovrden_in rxdfexyden_in rxdlybypass_in rxdlyen_in rxdlyovrden_in rxdlysreset_in rxelecidlemode_in rxeqtraining_in rxgearboxslip_in rxlatclk_in rxlpmgchold_in rxlpmgcovrden_in rxlpmhfhold_in rxlpmhfovrden_in rxlpmlfhold_in rxlpmlfklovrden_in rxlpmoshold_in rxlpmosovrden_in rxmonitorsel_in rxoobreset_in rxoscalreset_in rxoshold_in rxosovrden_in rxoutclksel_in rxpd_in rxphalign_in rxphalignen_in rxphdlypd_in rxphdlyreset_in rxphovrden_in rxpllclksel_in rxpolarity_in rxqpien_in rxratemode_in rxslide_in rxslipoutclk_in rxslippma_in rxsyncallin_in rxsyncin_in rxsyncmode_in rxsysclksel_in rxtermination_in sigvalidclk_in tstin_in tx8b10bbypass_in txcominit_in txcomsas_in txcomwake_in txdataextendrsvd_in txdccforcestart_in txdccreset_in txdeemph_in txdetectrx_in txdlybypass_in txdlyen_in txdlyhold_in txdlyovrden_in txdlysreset_in txdlyupdown_in txelecidle_in txheader_in txlatclk_in txlfpstreset_in txlfpsu2lpexit_in txlfpsu3wake_in txmaincursor_in txmargin_in txmuxdcdexhold_in txmuxdcdorwren_in txoneszeros_in txoutclksel_in txpd_in txpdelecidlemode_in txphalign_in txphalignen_in txphdlypd_in txphdlyreset_in txphdlytstclk_in txphinit_in txphovrden_in txpippmen_in txpippmovrden_in txpippmpd_in txpippmsel_in txpippmstepsize_in txpisopd_in txpllclksel_in txqpibiasen_in txqpiweakpup_in txrate_in txratemode_in txsequence_in txswing_in txsyncallin_in txsyncin_in txsyncmode_in txsysclksel_in bufgtce_out bufgtcemask_out bufgtdiv_out bufgtreset_out bufgtrstmask_out cpllfbclklost_out cpllrefclklost_out dmonitoroutclk_out drpdo_out drprdy_out gtrefclkmonitor_out pcierategen3_out pcierateidle_out pcierateqpllpd_out pcierateqpllreset_out pciesynctxsyncdone_out pcieusergen3rdy_out pcieuserphystatusrst_out pcieuserratestart_out pcsrsvdout_out phystatus_out pinrsrvdas_out powerpresent_out resetexception_out rxcdrlock_out rxcdrphdone_out rxchanbondseq_out rxchanisaligned_out rxchanrealign_out rxchbondo_out rxckcaldone_out rxclkcorcnt_out rxcominitdet_out rxcomsasdet_out rxcomwakedet_out rxdata_out rxdataextendrsvd_out rxdatavalid_out rxdlysresetdone_out rxelecidle_out rxheader_out rxheadervalid_out rxlfpstresetdet_out rxlfpsu2lpexitdet_out rxlfpsu3wakedet_out rxmonitorout_out rxosintdone_out rxosintstarted_out rxosintstrobedone_out rxosintstrobestarted_out rxoutclk_out rxoutclkfabric_out rxoutclkpcs_out rxphaligndone_out rxphalignerr_out rxprbslocked_out rxprgdivresetdone_out rxqpisenn_out rxqpisenp_out rxratedone_out rxrecclkout_out rxsliderdy_out rxslipdone_out rxslipoutclkrdy_out rxslippmardy_out rxstartofseq_out rxstatus_out rxsyncdone_out rxsyncout_out rxvalid_out txcomfinish_out txdccdone_out txdlysresetdone_out txoutclk_out txoutclkfabric_out txoutclkpcs_out txphaligndone_out txphinitdone_out txprgdivresetdone_out txqpisenn_out txqpisenp_out txratedone_out txsyncdone_out txsyncout_out}






#BuildMGTCores [dict create device_name TEST freerun_frequency 100 clocking {TX {LINE_RATE 10 PLL_TYPE CPLL REFCLK_FREQUENCY 200} RX {LINE_RATE 10 PLL_TYPE CPLL REFCLK_FREQUENCY 200}} protocol {TX {DATA_ENCODING 8B10B INT_DATA_WIDTH 40} RX {DATA_DECODING 8B10B COMMA_PRESET K28.1 COMMA_P_ENABLE 1 COMMA_M_ENABLE 1 COMMA_P_VAL 1001111100 COMMA_M_VAL 0110000011 COMMA_MASK 1111111111}} core {LOCATE_TX_USER_CLOCKING CORE LOCATE_RX_USER_CLOCKING CORE} links {X0Y0 {RX clk0 TX clk0} X0Y1 {RX clk0 TX clk0} X0Y2 {RX clk1 TX clk1} X0Y3 {RX clk0 TX clk0} X0Y4 {RX clk0-1 TX clk0-1} X0Y5 {RX clk0-1 TX clk0-1} X0Y6 {RX clk0 TX clk0} X0Y7 {RX clk1 TX clk1}}] 


