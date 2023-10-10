## proc \c IP_SYS_RESET
# Arguments:
#   \param params a dictionary of parameters for this core
#     - \b device_name Name of this sys resetter
#     - \b external_reset_n name of the external reset to start the reset cycle
#     - \b slowest_clk The slowest clock synchronous to the reset
#     - \b aux_reset name of an auxiliary reset
#     - \b aux-Reset_n name of an inverted auxiliary reset
#
# This will generate an axi resetter core that will output bus,interconnect, and peripheral rset signals
# These are available in the BD and sent out of the BD
proc IP_SYS_RESET {params} {
    # required values
    set_required_values $params {device_name external_reset_n slowest_clk}

    # optional values
    set_optional_values $params {aux_reset "NULL"}
    set_optional_values $params {aux_reset_n "NULL"}

    #createIP
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == proc_sys_reset}] $device_name

    #connect external reset
    set_property -dict [list CONFIG.C_AUX_RST_WIDTH {1} CONFIG.C_AUX_RESET_HIGH {0}] [get_bd_cells $device_name]
    connect_bd_net [get_bd_pins ${external_reset_n}] [get_bd_pins ${device_name}/ext_reset_in]
    #connect clock
    connect_bd_net [get_bd_pins ${slowest_clk}] [get_bd_pins ${device_name}/slowest_sync_clk]

    #aux_reset
    if {${aux_reset} != "NULL"} {
	set_property -dict [list CONFIG.C_AUX_RST_WIDTH {1} CONFIG.C_AUX_RESET_HIGH {1}] [get_bd_cells $device_name]
	connect_bd_net [get_bd_pins ${aux_reset}] [get_bd_pins ${device_name}/aux_reset_in]
    }
    #aux_reset_n (an error will result if you set both)
    if {${aux_reset_n} != "NULL"} {
	set_property -dict [list CONFIG.C_AUX_RST_WIDTH {1} CONFIG.C_AUX_RESET_HIGH {0}] [get_bd_cells $device_name]
	connect_bd_net [get_bd_pins ${aux_reset_n}] [get_bd_pins ${device_name}/aux_reset_in]
    }

    #Bus reset inverter
    set bus_rst_name ${device_name}_BUS_RST_N
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == util_vector_logic}] ${bus_rst_name}
    set_property -dict [list \
			    CONFIG.C_SIZE      {1}   \
			    CONFIG.C_OPERATION {not} \
			    CONFIG.LOGO_FILE   {data/sym_notgate.png}] \
	[get_bd_cells ${bus_rst_name}]
    #connect up the inverter to the bus_reset signal
    connect_bd_net [get_bd_pins ${device_name}/bus_struct_reset] [get_bd_pins ${bus_rst_name}/Op1]


    #make resets external
    #bus_rst_n
    make_bd_pins_external       -name ${device_name}_bus_rst_n       [get_bd_pins ${bus_rst_name}/Res]
    #interconnect reset
    make_bd_pins_external       -name ${device_name}_intcn_rst_n     [get_bd_pins ${device_name}/interconnect_aresetn]
    #peripheral reset
    make_bd_pins_external       -name ${device_name}_rst_n           [get_bd_pins ${device_name}/peripheral_aresetn]
    
}
