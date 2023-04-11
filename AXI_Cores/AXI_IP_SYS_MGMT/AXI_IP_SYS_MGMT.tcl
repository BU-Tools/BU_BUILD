proc AXI_IP_SYS_MGMT {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0 enable_i2c_pins 0]
    
    #create system management AXIL lite slave
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == system_management_wiz }] ${device_name}

    #setup clocking
    set_property CONFIG.DCLK_FREQUENCY [expr ${axi_freq}/1000000.0] [get_bd_cells ${device_name}]

    
    #disable default user temp monitoring
    set_property CONFIG.USER_TEMP_ALARM {false}        [get_bd_cells ${device_name}]
    #add i2c interface
    if {$enable_i2c_pins} {
      set_property CONFIG.SERIAL_INTERFACE {Enable_I2C}  [get_bd_cells ${device_name}]
      set_property CONFIG.I2C_ADDRESS_OVERRIDE {false}   [get_bd_cells ${device_name}]
    }
    
    #connect to interconnect
    [AXI_DEV_CONNECT $params]

    
    #expose alarms
    make_bd_pins_external   -name ${device_name}_alarm             [get_bd_pins ${device_name}/alarm_out]
    make_bd_pins_external   -name ${device_name}_vccint_alarm      [get_bd_pins ${device_name}/vccint_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccaux_alarm      [get_bd_pins ${device_name}/vccaux_alarm_out]
    make_bd_pins_external   -name ${device_name}_overtemp_alarm    [get_bd_pins ${device_name}/ot_out]

    #expose i2c interface
    make_bd_pins_external  -name ${device_name}_sda [get_bd_pins ${device_name}/i2c_sda]
    make_bd_pins_external  -name ${device_name}_scl [get_bd_pins ${device_name}/i2c_sclk]
    
    puts "Added Xilinx XADC AXI Slave: $device_name"

}
