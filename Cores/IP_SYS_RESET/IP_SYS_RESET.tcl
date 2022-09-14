

proc IP_SYS_RESET {params} {
    # required values
    set_required_values $params {device_name external_reset_n slowest_clk}

    # optional values
    set_optional_values $params {aux_reset "NULL"}

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
}
