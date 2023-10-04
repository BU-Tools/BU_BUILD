source -notrace ${BD_PATH}/axi_helpers/device_tree_helpers.tcl
source -notrace ${BD_PATH}/utils/vivado.tcl
source ${BD_PATH}/utils/Allocator.tcl


##proc \c AXI_CLK_CONNECT
# Arguments:
#   \param device_name The name of the device to connect up clocks and resets to
#   \param axi_clk  The name of the clock to connect to device_name
#   \param axi_rstn The name of the associated reset to connect to device_name
#   \param ms_type If the interface of device_name is an axi master "m" or slave "s" (default slave)
#
#This process connects a device's clock and reset ports.
#This can be complicated by Xilinx's naming conventions, so this function tries to find the correct port to connect to.
#This naming can change if the interface is a master or slave AXI interface, so that is an optional argument with the default of a slave interface.
proc AXI_CLK_CONNECT {device_name axi_clk axi_rstn {ms_type "s"}} {
    #Xilinx AXI slaves use different names for the AXI connection, this if/else tree will try to find the correct one. 
    set MS_TYPE [string toupper ${ms_type}]


    #handle destinations
    GET_BD_PINS_OR_PORTS dest_clk $axi_clk

    GET_BD_PINS_OR_PORTS dest_rstn $axi_rstn


    #handle clock source
    GET_BD_PINS_OR_PORTS src_clk $device_name/${ms_type}_axi_aclk
    if { [string trim $src_clk] == "" } {
        GET_BD_PINS_OR_PORTS src_clk $device_name/${ms_type}_aclk
    }
    if { [string trim $src_clk] == "" } {
	GET_BD_PINS_OR_PORTS src_clk $device_name/aclk
    }
    if { [string trim $src_clk] == "" } {
	GET_BD_PINS_OR_PORTS src_clk $device_name/saxi*aclk
    }
    if { [string trim $src_clk] == "" } {
	GET_BD_PINS_OR_PORTS src_clk $device_name/${ms_type}_axi_aclk
    }

    #handle reset source
    GET_BD_PINS_OR_PORTS src_rstn  $device_name/${ms_type}_axi_aresetn
    if { [string trim $src_rstn] == "" } {
        GET_BD_PINS_OR_PORTS src_rstn $device_name/aresetn
    }
    if { [string trim $src_rstn] == "" } {
	GET_BD_PINS_OR_PORTS src_rstn $device_name/aclk
    }
    if { [string trim $src_rstn] == "" } {
	GET_BD_PINS_OR_PORTS src_rstn $device_name/saxi*aclk
    }
    if { [string trim $src_rstn] == "" } {
	GET_BD_PINS_OR_PORTS src_rstn $device_name/${ms_type}_axi_aclk
    }
    
    connect_bd_net -quiet  $src_clk $dest_clk
    connect_bd_net -quiet  $src_rstn $dest_rstn
}

##proc \c AXI_LITE_CLK_CONNECT
# Arguments: Look at AXI_CLK_CONNECT()
#
# A version of the AXI_CLK_CONNECT() call, but searches different names for the connection of axi-lite clocks
proc AXI_LITE_CLK_CONNECT {device_name axi_clk axi_rstn {ms_type "s"} } {
    #Xilinx AXI slaves use different names for the AXI connection, this if/else tree will try to find the correct one. 
    set MS_TYPE [string toupper ${ms_type}]

    #handle destinations
    GET_BD_PINS_OR_PORTS dest_clk $axi_clk

    GET_BD_PINS_OR_PORTS dest_rstn $axi_rstn

    
    #handle clock source
    GET_BD_PINS_OR_PORTS src_clk $device_name/${MS_TYPE}_axi_lite_aclk
    if { [string trim $src_clk] == "" } {
	GET_BD_PINS_OR_PORTS src_clk $device_name/${MS_TYPE}_AXI_lite
    }
    if { [string trim $src_clk] == "" } {
	GET_BD_PINS_OR_PORTS src_clk $device_name/${MS_TYPE}_axi_aclk
    }
    if { [string trim $src_clk] == "" } {
	GET_BD_PINS_OR_PORTS src_clk $device_name/${MS_TYPE}_aclk
    }
    if { [string trim $src_clk] == "" } {
	GET_BD_PINS_OR_PORTS src_clk $device_name/${MS_TYPE}_axi_aclk
    }

    #handle reset source
    GET_BD_PINS_OR_PORTS src_rstn  $device_name/${MS_TYPE}_axi_aresetn
    if { [string trim $src_rstn] == "" } {
	GET_BD_PINS_OR_PORTS src_rstn $device_name/${MS_TYPE}_axi_lite_aresetn
    }

    puts "Connecting ${src_clk} to ${dest_clk}"    
    connect_bd_net -quiet $src_clk $dest_clk
    puts "Connecting ${src_rstn} to ${dest_rstn}"    
    connect_bd_net -quiet $src_rstn $dest_rstn


}

