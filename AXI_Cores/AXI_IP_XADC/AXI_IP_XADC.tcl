proc AXI_IP_XADC {params} {

    # required values
    set_required_values $params {device_name axi_control}

    # optional values
    set_optional_values $params [dict create addr {offset -1 range 64K} remote_slave 0]

    #create XADC AXI slave 
    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == xadc_wiz }] ${device_name}

    #disable default user temp monitoring
    set_property CONFIG.USER_TEMP_ALARM {false} [get_bd_cells ${device_name}]

    
    #connect to interconnect
    [AXI_DEV_CONNECT $params]

    
    #expose alarms
    make_bd_pins_external   -name ${device_name}_alarm             [get_bd_pins ${device_name}/alarm_out]
    make_bd_pins_external   -name ${device_name}_vccint_alarm      [get_bd_pins ${device_name}/vccint_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccaux_alarm      [get_bd_pins ${device_name}/vccaux_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccpint_alarm     [get_bd_pins ${device_name}/vccpint_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccpaux_alarm     [get_bd_pins ${device_name}/vccpaux_alarm_out]
    make_bd_pins_external   -name ${device_name}_vccddro_alarm     [get_bd_pins ${device_name}/vccddro_alarm_out]
    make_bd_pins_external   -name ${device_name}_overtemp_alarm    [get_bd_pins ${device_name}/ot_alarm_out]

    puts "Added Xilinx XADC AXI Slave: $device_name"

}
