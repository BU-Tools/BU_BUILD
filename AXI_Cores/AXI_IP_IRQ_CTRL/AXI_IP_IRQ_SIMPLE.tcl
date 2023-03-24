proc AXI_IP_IRQ_SIMPLE {params} {
    # required values
    set_required_values $params {device_name irq_dest}

    #to trick Vivado into there being a IRQ_CTRL like thing
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == xlconcat}] $device_name
    set_property -dict [list CONFIG.NUM_PORTS {1} ] [get_bd_cells $device_name]
    

    #global value for tracking
    global IRQ_COUNT_${device_name}
    set IRQ_COUNT_${device_name} 0

    connect_bd_net [get_bd_pins ${device_name}/dout] [get_bd_pins ${irq_dest}]
    set IRQ_CONCAT ${device_name}_IRQ
    create_bd_cell -type ip -vlnv  [get_ipdefs -filter {NAME == xlconcat}] ${IRQ_CONCAT}
    connect_bd_net [get_bd_pins ${IRQ_CONCAT}/dout] [get_bd_pins ${device_name}/in0]
    puts "Added Simple Interrupt passthrough $device_name"
}
