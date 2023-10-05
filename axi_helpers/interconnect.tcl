source -notrace ${BD_PATH}/axi_helpers/device_tree_helpers.tcl



#================================================================================
#Add an AXI master port to the BD from the PL HDL
#================================================================================
#Required values:
#  name:       Name of the interface to make
#  axi_clk:    Name of the clock to use for this interface
#  axi_rstn:   Name of the reset to use for this interface
#  axi_freq:   Frequncy to set for the clk+bus interface
#Optional values:
#  type:       Type of interface (default: AXI4LITE)
#  addr_width: Width of the AXI interface's address bus
#  data_width: Width of the AXI interfaces's data bus
#================================================================================
proc AXI_PL_MASTER_PORT {params} { 

    # required values
    set_required_values $params {name axi_clk axi_rstn axi_freq}

    # optional values
    set_optional_values $params [dict create type AXI4LITE addr_width 32 data_width 32]


    set axi_clk_inst [get_bd_ports -q $axi_clk]
    if { [llength $axi_clk_inst] == 0 } {
	set axi_clk_inst [get_bd_pins -q $axi_clk]
    }
    puts ${axi_clk}
    puts ${axi_clk_inst}
    
    create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0  ${name}
    set axi_port [get_bd_intf_ports ${name}]
    puts ${axi_port}

    set_property CONFIG.DATA_WIDTH ${data_width} $axi_port
    set_property CONFIG.ADDR_WIDTH ${addr_width} $axi_port
    
    #create clk and reset (-q to skip error if it already exists)
    create_bd_port -q -dir I -type clk $axi_clk
    create_bd_port -q -dir I -type rst $axi_rstn

    #setup clk/reset parameters
    set_property CONFIG.FREQ_HZ          $axi_freq  $axi_port
    set_property CONFIG.FREQ_HZ          $axi_freq  $axi_clk_inst
    set_property CONFIG.ASSOCIATED_RESET $axi_rstn  $axi_clk_inst

    #set bus properties
    set_property CONFIG.PROTOCOL ${type} $axi_port
}

#================================================================================
#Expand an interconnect's number of slave interfaces for connecting to AXI master
#interfaces
#================================================================================
#Required values:
#  interconnect:  Name of the AXI interconnect to expand
#Return values (via upval):
#  AXI_MASTER_BUS:  Name of the AXI slave port created
#  AXI_MASTER_CLK:  Name of the AXI slave port clk
#  AXI_MASTER_RSTN: Name of the AXI slave port reset
#================================================================================
proc EXPAND_AXI_INTERCONNECT {params} {
    global AXI_INTERCONNECT_MASTER_SIZE

    set_required_values $params {interconnect}    
    
    #get the current size
    set current_master_count $AXI_INTERCONNECT_MASTER_SIZE($interconnect)

    #update the size
    #  the interconnect always starts with one master slot, so when current_master_count
    #  is 0, then the update will just keep the CONFIG.NUM_SI at 1
    set new_count [expr $current_master_count + 1]
    set_property CONFIG.NUM_SI $new_count [get_bd_cells $interconnect]
    #update the interconnect master size
    set AXI_INTERCONNECT_MASTER_SIZE($interconnect) $new_count

    set slaveID [format "%02d" ${current_master_count}]
    
    #upval the names
    upvar 1 AXI_MASTER_BUS axi_bus;#tie AXI_MASTER_BUS to $axi_bus
    set axi_bus "${interconnect}/S${slaveID}_AXI"
    upvar 1 AXI_MASTER_CLK axi_clk;
    set axi_clk "${interconnect}/S${slaveID}_ACLK"
    upvar 1 AXI_MASTER_RSTN axi_rstn;
    set axi_rstn "${interconnect}/S${slaveID}_ARESETN"

    puts "Added new slave interface for master on $interconnect (size ${new_count})"
    puts "    BUS:  $axi_bus"
    puts "    CLK:  $axi_clk"
    puts "    RSTN: $axi_rstn"

    #set to minimize area mode to remove id_widths
    set_property CONFIG.STRATEGY {1} [get_bd_cells $interconnect]

}


#================================================================================
#add a new master interface to $interconnect to use for a new slave
#================================================================================
#Required values:
#  interconnect:    Name of the AXI interconnect to expand
#Return values (via upval):
#  AXIM_NAME:  Name of the AXI interconnect
#  AXIM_PORT_NAME:  Name of the AXI master port created
#  AXIM_CLK_NAME:   Name of the AXI master port clk
#  AXIM_RSTN_NAME:  Name of the AXI master port reset
#================================================================================
proc ADD_MASTER_TO_INTERCONNECT {params} {
    global AXI_INTERCONNECT_SIZE

    set_required_values $params {interconnect}    

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
    #set to minimize area mode to remove id_widths
    set_property CONFIG.STRATEGY {1} [get_bd_cells $interconnect]

}

#================================================================================
#Global varibles for interconnect sizes
#================================================================================
#array of the count of master interfaces (for AXI endpoints) for each interconnect
[clear_global AXI_INTERCONNECT_SIZE]
array set AXI_INTERCONNECT_SIZE {}
#array of the count of slave interfaces (for interconnect masters) for each interconnect
[clear_global AXI_INTERCONNECT_SIZE]
array set AXI_INTERCONNECT_MASTER_SIZE {}
#================================================================================
#Build a new AXI interconnect
#================================================================================
#Arguments
#  name:  interconnect name
#  clk:   interconnect clk
#  rstn:  interconnect reset_n
#  axi_masters:      list of AXI master interfaces to create and connect
#                    interconnect AXI slave ports
#  axi_master_clks:  list of slave port clocks
#  axi_master_rstns: list of slave port resets
#================================================================================
proc BUILD_AXI_INTERCONNECT {name clk rstn axi_masters axi_master_clks axi_master_rstns} {

    global AXI_INTERCONNECT_SIZE
    global AXI_INTERCONNECT_MASTER_SIZE
    
    #create an axi interconnect
    global $name
    upvar 0 $name AXI_INTERCONNECT_NAME
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
    set AXI_INTERCONNECT_MASTER_SIZE($AXI_INTERCONNECT_NAME) 0; #initialize the size of the interconnect to 0 eventhough it alwasy starts with 1    
    #connect this interconnect clock and reset signals (do quiet incase the type of the signal is different)
    connect_bd_net -q [get_bd_pins  $clk]   [get_bd_pins $AXI_INTERCONNECT_NAME/ACLK]
    connect_bd_net -q [get_bd_ports $clk]   [get_bd_pins $AXI_INTERCONNECT_NAME/ACLK]
    connect_bd_net -q [get_bd_pins  $rstn]  [get_bd_pins $AXI_INTERCONNECT_NAME/ARESETN]
    connect_bd_net -q [get_bd_ports $rstn]  [get_bd_pins $AXI_INTERCONNECT_NAME/ARESETN]

    #set to minimize area mode to remove id_widths
    set_property CONFIG.STRATEGY {1} [get_bd_cells $AXI_INTERCONNECT_NAME]
    
    #create a slave interface for each AXI_BUS master
    set AXI_MASTER_COUNT [llength $axi_masters]
    
    
    #Loop over all master interfaces requested and connect them to slave interfaces.
    for {set iSlave 0} {$iSlave < ${AXI_MASTER_COUNT}} {incr iSlave} {
	startgroup
	#create a params list for EXPAND_AXI_INTERCONNECT
#	EXPAND_AXI_INTERCONNECT [dict create interconnect $AXI_INTERCONNECT_NAME]

	#get the current name
        set slaveM [lindex $axi_masters      ${iSlave}]
        set slaveC [lindex $axi_master_clks  ${iSlave}]
        set slaveR [lindex $axi_master_rstns ${iSlave}]

	
	CONNECT_AXI_MASTER_TO_INTERCONNECT [dict create interconnect $AXI_INTERCONNECT_NAME axi_master $slaveM axi_clk ${slaveC} axi_rstn ${slaveR}]

	
#        # Connect the interconnect's slave and master clocks to the processor system's axi master clock (FCLK_CLK0)
#        connect_bd_net -q [get_bd_pins  $slaveC] [get_bd_pins $AXI_MASTER_CLK]
#	connect_bd_net -q [get_bd_ports $slaveC] [get_bd_pins $AXI_MASTER_CLK]
#
#        # Connect resets
#        connect_bd_net -q [get_bd_pins  $slaveR] [get_bd_pins $AXI_MASTER_RSTN]
#	connect_bd_net -q [get_bd_ports $slaveR] [get_bd_pins $AXI_MASTER_RSTN]
#
#        #connect up this interconnect's slave interface to the master $iSlave driving it
#        connect_bd_intf_net [get_bd_intf_pins $slaveM] \
#	    -boundary_type upper                       \
#	    [get_bd_intf_pins $AXI_MASTER_BUS]
#        endgroup	
    }


    
    #zero the number of slaves connected to this interconnect
    set AXI_INTERCONNECT_SIZE($AXI_INTERCONNECT_NAME) 0
    set_property CONFIG.NUM_MI {1}  [get_bd_cells $AXI_INTERCONNECT_NAME]

    #set to minimize area mode to remove id_widths
    set_property CONFIG.STRATEGY {1} [get_bd_cells $AXI_INTERCONNECT_NAME]

    endgroup
}


#================================================================================
#Build a interconnect(child) that is a AXI slave of another interconnect(parent)
#================================================================================
#Required values:
#  device_name:  Autoset by the tcl system
#  axi_clk:      The child interconnect's clock
#  axi_rstn:     The child interconnect's reset_n
#  parent:       A tcl list of parents for this interconnect.
#                These can be another interconnect or an explicit master AXI port
#  master_clk:   A tcl list of parent interface's clock
#  master_rstn:  A tcl list of parent interface's resets
#================================================================================
proc BUILD_CHILD_AXI_INTERCONNECT {params} {
    global AXI_INTERCONNECT_SIZE
    
    # required values (False mean's don't break apart dictionaries/lists)
    set_required_values $params {device_name parent master_clk master_rstn axi_clk axi_rstn } False
    
    #verify the length of parnet,master_clk, and master_rstn are the same
    if { [llength $parent] != [llength $master_clk] || \
            [llength $parent] != [llength $master_rstn]} then {
        error "mismatch between parent, master_clk, and master_rstn lengths"
    }

    
    #store the names of the master ports that will control our child interconnect
    set AXIM_PORT_NAMES {} 
    set AXIM_CLK_NAMES  {}
    set AXIM_RSTN_NAMES {}

    # Build a list of parent AXI master ports
    #  add an axi master port to the parent if it is an interconnect
    for {set iParent 0} {$iParent < [llength $parent]} {incr iParent} {
	#check if this parent is another interconnect or an explicit AXI master
	if { [llength [array names AXI_INTERCONNECT_SIZE -exact [lindex $parent $iParent] ] ] > 0} {
	    #parent is an interconnect
	    ADD_MASTER_TO_INTERCONNECT [dict create interconnect [lindex $parent $iParent]]
	    connect_bd_net -q [get_bd_pins  [lindex $master_clk $iParent] ] \
		[get_bd_pins $AXIM_CLK_NAME]
	    connect_bd_net -q [get_bd_ports [lindex $master_clk $iParent] ] \
		[get_bd_pins $AXIM_CLK_NAME]
	    connect_bd_net -q [get_bd_pins  [lindex $master_rstn $iParent] ] \
		[get_bd_pins $AXIM_RSTN_NAME]
	    connect_bd_net -q [get_bd_ports [lindex $master_rstn $iParent] ] \
		[get_bd_pins $AXIM_RSTN_NAME]
	    lappend AXIM_PORT_NAMES $AXIM_PORT_NAME
	    lappend AXIM_CLK_NAMES  $AXIM_CLK_NAME 
	    lappend AXIM_RSTN_NAMES $AXIM_RSTN_NAME
	} else {
	    #parent is a master interface
	    lappend AXIM_PORT_NAMES [lindex $parent $iParent] 
	    lappend AXIM_CLK_NAMES  [lindex $master_clk $iParent] 
	    lappend AXIM_RSTN_NAMES [lindex $master_rstn $iParent]
	}
    }

    #actually build the interconnect
    BUILD_AXI_INTERCONNECT \
        $device_name \
        $axi_clk \
        $axi_rstn \
        $AXIM_PORT_NAMES \
        $AXIM_CLK_NAMES \
        $AXIM_RSTN_NAMES
}


#================================================================================
#Add an AXI master port to the BD from the PL HDL
#Expand an interconnect
#Connect the two
#================================================================================
#Required values:
#  interconnect: Name of the interconnect we will connect to
#  name:         Name of the interface to make
#  axi_clk:      Name of the clock to use for this interface
#  axi_rstn:     Name of the reset to use for this interface
#  axi_freq:     Frequncy to set for the clk+bus interface
#Optional values:
#  type:       Type of interface (default: AXI4LITE)
#  addr_width: Width of the AXI interface's address bus
#  data_width: Width of the AXI interfaces's data bus
#================================================================================
proc GENERATE_PL_MASTER_FOR_INTERCONNECT {params} { 

    # required values
    set_required_values $params {interconnect device_name axi_clk axi_rstn axi_freq}

    # optional values
    set_optional_values $params [dict create type AXI4LITE addr_width 32 data_width 32]

    dict append params name [dict get $params device_name]
    
    #create a master from the PL
    AXI_PL_MASTER_PORT $params
    
    #Add a master to the interconnect
    EXPAND_AXI_INTERCONNECT $params

    #connect the two    
    AXI_BUS_CONNECT [dict get $params device_name] $AXI_MASTER_BUS "m"
    connect_bd_net [GET_BD_PINS_OR_PORTS throw_away $axi_clk]   [GET_BD_PINS_OR_PORTS throw_away $AXI_MASTER_CLK]
    connect_bd_net [GET_BD_PINS_OR_PORTS throw_away $axi_rstn ] [GET_BD_PINS_OR_PORTS throw_away $AXI_MASTER_RSTN]

    #set to minimize area mode to remove id_widths
    set_property CONFIG.STRATEGY {1} [get_bd_cells $interconnect]
}    


#================================================================================
#Add an CLK input to the BD
#================================================================================
#Required values:
#  name:           Name of the interface to make (will be forced to all caps)
#                  This will have _CLK appended to it. 
#  freq:           Frequncy to set for the clk+bus interface
#optional values:
#  global_signal:  Make this a global signal in the TCL (default false)
#  add_rst_n:      Add a reset_n signal to go along with this clock
#================================================================================
proc ADD_PL_CLK {params} {     
    # required values
    set_required_values $params {name freq}

    # optional values
    set_optional_values $params [dict create global_signal false add_rst_n false]

    
    #create this clock
    set clk_name [string toupper ${name}_clk] 
    set clk_freq [string toupper ${name}_clk_freq]

    
    create_bd_port -q -dir I -type clk $clk_name
    set_property CONFIG.FREQ_HZ $freq  [get_bd_ports $clk_name]

    if { $global_signal } {
	global $clk_name
	upvar 0 $clk_name local_clk_name
	set local_clk_name $clk_name
	global $clk_freq
	upvar 0 $clk_freq local_clk_freq
	set local_clk_freq $freq
	Add_Global_Constant ${clk_freq} integer ${freq}
    }

    
    #check if we are also making a reset
    if { $add_rst_n } {
	set rst_n_name [string toupper ${name}_rstn]
	create_bd_port -q -dir I -type rst $rst_n_name
	set_property CONFIG.ASSOCIATED_RESET $rst_n_name [get_bd_ports $clk_name]
	if { $global_signal } {
	    global $rst_n_name
	    upvar 0 $rst_n_name local_rst_n_name
	    set local_rst_n_name $rst_n_name
	}

    }
}


proc BUILD_JTAG_AXI_MASTER {params} {
    # required values
    set_required_values $params {device_name axi_clk axi_rstn}
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == jtag_axi }] ${device_name}
    connect_bd_net [get_bd_ports ${axi_clk}] [get_bd_pins ${device_name}/aclk]
    connect_bd_net [get_bd_pins  ${device_name}/aresetn] [get_bd_pins ${axi_rstn}]
}
