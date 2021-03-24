source -quiet ${apollo_root_path}/bd/dtsi_helpers.tcl

#add a new master interface to $interconnect to use for a new slave
proc ADD_MASTER_TO_INTERCONNECT {interconnect} {


    global AXI_INTERCONNECT_SIZE

    if { [string first axi_interconnect [get_property VLNV [get_bd_cells $interconnect] ] ] != -1} {
	#this is a real axi interconnect, so we need to expand it. 
	set INTERCONNECT_SID $AXI_INTERCONNECT_SIZE($interconnect)
	
	#update the number of slaves (master interfaces)
	set AXI_INTERCONNECT_SIZE($interconnect) [expr {${INTERCONNECT_SID} + 1}]
	set_property CONFIG.NUM_MI $AXI_INTERCONNECT_SIZE($interconnect)  [get_bd_cells $interconnect]
    
	uplevel 1 {set AXIM_NAME } $interconnect
	uplevel 1 {append AXIM_NAME "/M" }
	uplevel 1 {append AXIM_NAME [format "%02d" } $INTERCONNECT_SID {]}
	uplevel 1 {
	    set AXIM_PORT_NAME $AXIM_NAME
	    append AXIM_PORT_NAME "_AXI"
	    set AXIM_CLK_NAME $AXIM_NAME
	    append AXIM_CLK_NAME "_ACLK"
	    set AXIM_RSTN_NAME $AXIM_NAME
	    append AXIM_RSTN_NAME "_ARESETN"
	}
    
	puts "Created slave ${INTERCONNECT_SID} on interconnect (${interconnect})"
    } else {
	#connecting to an existing port, so no internonnect expansion
	uplevel 1 {set AXIM_NAME } $interconnect
	uplevel 1 {append AXIM_NAME "/M" }
	uplevel 1 {
	    set AXIM_PORT_NAME $AXIM_NAME
	    append AXIM_PORT_NAME "_AXI"
	    set AXIM_CLK_NAME $AXIM_NAME
	    append AXIM_CLK_NAME "_ACLK"
	    set AXIM_RSTN_NAME $AXIM_NAME
	    append AXIM_RSTN_NAME "_ARESETN"
	}
	puts "Connected to ${interconnect}"
    }
}

[clear_global AXI_INTERCONNECT_SIZE]
array set AXI_INTERCONNECT_SIZE {}

proc BUILD_AXI_INTERCONNECT {name clk rstn axi_masters axi_master_clks axi_master_rstns} {

    global AXI_INTERCONNECT_SIZE
    
    #create an axi interconnect 
    set AXI_INTERCONNECT_NAME $name

    #assert master_connections and master_clocks are the same size
    if {[llength axi_masters] != [llength axi_master_clks] || \
            [llength axi_masters] != [llength axi_master_rstns]} then {
        error "master size mismatch"
    }
    
    startgroup

    #================================================================================
    #  Create an AXI interconnect
    #================================================================================    
    create_bd_cell -type ip -vlnv [get_ipdefs -all -filter {NAME == axi_interconnect && UPGRADE_VERSIONS == "" }] $AXI_INTERCONNECT_NAME

    #connect this interconnect clock and reset signals (do quiet incase the type of the signal is different)
    connect_bd_net -q [get_bd_pins  $clk]   [get_bd_pins $AXI_INTERCONNECT_NAME/ACLK]
    connect_bd_net -q [get_bd_ports $clk]   [get_bd_pins $AXI_INTERCONNECT_NAME/ACLK]
    connect_bd_net -q [get_bd_pins  $rstn]  [get_bd_pins $AXI_INTERCONNECT_NAME/ARESETN]
    connect_bd_net -q [get_bd_ports $rstn]  [get_bd_pins $AXI_INTERCONNECT_NAME/ARESETN]

    #create a slave interface for each AXI_BUS master
    set AXI_MASTER_COUNT [llength $axi_masters]
    set_property CONFIG.NUM_SI $AXI_MASTER_COUNT  [get_bd_cells $AXI_INTERCONNECT_NAME]

    #Loop over all master interfaces requested and connect them to slave interfaces.
    for {set iSlave 0} {$iSlave < ${AXI_MASTER_COUNT}} {incr iSlave} {
        startgroup
        #build this interface's slave interface label
        set slaveID [format "%02d" ${iSlave}]
        set slaveM [lindex $axi_masters ${iSlave}]
        set slaveC [lindex $axi_master_clks ${iSlave}]
        set slaveR [lindex $axi_master_rstns ${iSlave}]
        puts "Setting up interconnect slave interface for $slaveM"

        # Connect the interconnect's slave and master clocks to the processor system's axi master clock (FCLK_CLK0)
        connect_bd_net [get_bd_pins $slaveC] [get_bd_pins $AXI_INTERCONNECT_NAME/S${slaveID}_ACLK]

        # Connect resets
        connect_bd_net [get_bd_pins $slaveR] [get_bd_pins $AXI_INTERCONNECT_NAME/S${slaveID}_ARESETN]

        #connect up this interconnect's slave interface to the master $iSlave driving it
        connect_bd_intf_net [get_bd_intf_pins $slaveM] -boundary_type upper [get_bd_intf_pins $AXI_INTERCONNECT_NAME/S${slaveID}_AXI]
        endgroup
    }

    #zero the number of slaves connected to this interconnect
    set AXI_INTERCONNECT_SIZE($AXI_INTERCONNECT_NAME) 0
    set_property CONFIG.NUM_MI {1}  [get_bd_cells $AXI_INTERCONNECT_NAME]
    endgroup
}

proc BUILD_CHILD_AXI_INTERCONNECT {params} {

    # required values
    set_required_values $params {name axi_clk axi_rstn parent master_clk master_rstn}

    # optional values
    set_optional_values $params [dict create firewall 0]

    #if {firewall != 0} {
    #}

    # FIXME: this is kind of stupid... figure out a better way to do this
    # if you have no slaves connected it just keep generating masters
    set master_id [ADD_MASTER_TO_INTERCONNECT $parent]

    global AXI_INTERCONNECT_SIZE
    set AXI_INTERCONNECT_SIZE($name) 0

    #connect this interconnect clock and reset signals (do quiet incase the type of the signal is different)
    connect_bd_net -q [get_bd_pins  $axi_clk]   [get_bd_pins $parent/M${master_id}_ACLK]
    connect_bd_net -q [get_bd_ports $axi_clk]   [get_bd_pins $parent/M${master_id}_ACLK]
    connect_bd_net -q [get_bd_pins  $axi_rstn]  [get_bd_pins $parent/M${master_id}_ARESETN]
    connect_bd_net -q [get_bd_ports $axi_rstn]  [get_bd_pins $parent/M${master_id}_ARESETN]

    BUILD_AXI_INTERCONNECT \
        $name \
        $axi_clk \
        $axi_rstn \
        [list "$parent/M${master_id}_AXI"] \
        $master_clk \
        $master_rstn
}

proc AXI_PL_MASTER_PORT {base_name axi_clk axi_rstn axi_freq {type AXI4LITE} {axi_width 32}} {
    
    create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0  ${base_name}
    set_property CONFIG.DATA_WIDTH 32 [get_bd_intf_ports ${base_name}]
    set_property CONFIG.ADDR_WIDTH ${axi_width} [get_bd_intf_ports ${base_name}]
    
    #create clk and reset (-q to skip error if it already exists)
    create_bd_port -q -dir I -type clk $axi_clk
    create_bd_port -q -dir I -type rst $axi_rstn

    #setup clk/reset parameters
    set_property CONFIG.FREQ_HZ          $axi_freq  [get_bd_ports $axi_clk]
    set_property CONFIG.ASSOCIATED_RESET $axi_rstn  [get_bd_ports $axi_clk]

    #set bus properties
    set_property CONFIG.PROTOCOL ${type} [get_bd_intf_ports ${base_name}]
}

