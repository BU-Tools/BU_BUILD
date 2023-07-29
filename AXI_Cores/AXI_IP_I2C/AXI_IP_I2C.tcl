proc AXI_IP_I2C {params} {

    # required values
    set_required_values $params {device_name axi_control}
    set_required_values $params {irq_port}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == axi_iic}] $device_name

    #create external pins
    make_bd_pins_external  -name ${device_name}_scl_i [get_bd_pins $device_name/scl_i]
    make_bd_pins_external  -name ${device_name}_sda_i [get_bd_pins $device_name/sda_i]
    make_bd_pins_external  -name ${device_name}_sda_o [get_bd_pins $device_name/sda_o]
    make_bd_pins_external  -name ${device_name}_scl_o [get_bd_pins $device_name/scl_o]
    make_bd_pins_external  -name ${device_name}_scl_t [get_bd_pins $device_name/scl_t]
    make_bd_pins_external  -name ${device_name}_sda_t [get_bd_pins $device_name/sda_t]
    #connect to AXI, clk, and reset between slave and mastre
    [AXI_DEV_CONNECT $params]

    #connect interrupt
    CONNECT_IRQ ${device_name}/iic2intc_irpt ${irq_port}

    puts "Added Xilinx I2C AXI Slave: $device_name"
}
