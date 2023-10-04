source ${BD_PATH}/axi_helpers/connections_clk.tcl

##proc \c AXI_BUS_CONNECT
# Arguments:
#   \param device_name The name of device_name of the "source" AXI interface
#   \param AXIM_PORT_NAME  The name of the "destination" AXI port to connect to. 
#   \param ms_type If the interface of device_name is an axi master "m" or slave "s" (default slave)
#
#This call connects device_name's AXI interface to AXIM_PORT_NAME.
#This is complicated and this code does its best to make this mapping correctly
proc AXI_BUS_CONNECT {device_name AXIM_PORT_NAME {ms_type "s"}} {
    #Xilinx AXI slaves use different names for the AXI connection, this if/else tree will try to find the correct one.
    set MS_TYPE [string toupper ${ms_type}]

    set dest [get_bd_intf_pins -quiet $AXIM_PORT_NAME]
    if { [string trim $dest] == "" } {
	set dest [get_bd_intf_ports  $AXIM_PORT_NAME]
    }
    
    GET_BD_PINS_OR_PORTS src $device_name/${MS_TYPE}_AXI
    if { [string trim $src] == "" } {
        GET_BD_PINS_OR_PORTS src $device_name/${ms_type}_axi
    }
    if { [string trim $src] == "" } {
	GET_BD_PINS_OR_PORTS src $device_name/${ms_type}_axi_lite
    }
    if { [string trim $src] == "" } {
	GET_BD_PINS_OR_PORTS src $device_name/*AXI*LITE*
    }
    if { [string trim $src] == "" } {
        GET_BD_PINS_OR_PORTS src  $device_name/${MS_TYPE}*AXI*
    }
    if { [string trim $src] == "" } {
	GET_BD_PINS_OR_PORTS src  $device_name
    }

    puts "Connecting ${src} to ${dest}"
    connect_bd_intf_net ${src} -boundary_type upper ${dest}
    
}

##proc \c AXI_LITE_BUS_CONNECT
# Arguments: See AXI_BUS_CONNECT()
#
# This function is like AXI_LITE_CONNECT(), but is focused on connecting to specifically axi-lite interfaces.
# Use this when an AXI endpoint has AXI and AXI-Lite interfaces and you are currently connecting the AXI-Lite one.
proc AXI_LITE_BUS_CONNECT {device_name AXIM_PORT_NAME  {ms_type "s"}} {
    #Xilinx AXI slaves use different names for the AXI connection, this if/else tree will try to find the correct one. 
    if [llength [get_bd_intf_pins -quiet $device_name/${ms_type}_AXI_lite]] {
        connect_bd_intf_net [get_bd_intf_pins $device_name/${ms_type}_AXI_lite] -boundary_type upper [get_bd_intf_pins $AXIM_PORT_NAME]
    } else {
        connect_bd_intf_net     [get_bd_intf_pins $device_name/AXI_LITE] -boundary_type upper [get_bd_intf_pins $AXIM_PORT_NAME]
    }
}
