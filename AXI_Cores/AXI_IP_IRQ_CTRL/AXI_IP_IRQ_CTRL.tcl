source -notrace ${BD_PATH}/AXI_Cores/AXI_IP_IRQ_CTRL/CONNECT_IRQ.tcl


proc AXI_IP_IRQ_CTRL {params} {
    # required values
    set_required_values $params {device_name axi_control irq_dest}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    set_optional_values $params [dict create sw_intr_count 0]

    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_intc}] $device_name

    #global value for tracking
    global IRQ_COUNT_${device_name}
    set IRQ_COUNT_${device_name} 0

    #connect to AXI, clk, and reset between slave and mastre
    [AXI_DEV_CONNECT $params]

    connect_bd_net [get_bd_pins ${device_name}/irq] [get_bd_pins ${irq_dest}]
    set IRQ_CONCAT ${device_name}_IRQ
    create_bd_cell -type ip -vlnv  [get_ipdefs -filter {NAME == xlconcat}] ${IRQ_CONCAT}
    connect_bd_net [get_bd_pins ${IRQ_CONCAT}/dout] [get_bd_pins ${device_name}/intr]
    puts "Added Xilinx Interrupt Controller AXI Slave: $device_name"
}
