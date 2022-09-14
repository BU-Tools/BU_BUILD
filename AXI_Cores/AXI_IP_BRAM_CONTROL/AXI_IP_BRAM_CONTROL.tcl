proc AXI_IP_BRAM_CONTROL {params} {

    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {width}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    # create bd cell
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_bram_ctrl }] ${device_name}

    # convert the address range into a bram controller depth
    set depths [dict create 1k 1024 2k 2048 4k 4096 8k 8192 16k 16384 32k 32768 64k 65536 128k 131072 256k 262144]
    set depth [dict get $depths [string tolower $range]]

    set cell [get_bd_cells $device_name]

    # make connections
    [AXI_DEV_CONNECT $params]

    # set width
    set_property -dict [list CONFIG.MEM_DEPTH $depth CONFIG.READ_WRITE_MODE "READ_WRITE" CONFIG.SINGLE_PORT_BRAM {1} CONFIG.DATA_WIDTH $width] $cell

    # connect to a port
    make_bd_pins_external       -name ${device_name}_port $cell
    make_bd_intf_pins_external  -name ${device_name}_port $cell

    set_property -dict [list CONFIG.READ_WRITE_MODE {READ_WRITE}] [get_bd_intf_ports ${device_name}_port]
}
