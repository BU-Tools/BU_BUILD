source -notrace ${BD_PATH}/axi_helpers.tcl

proc AXI_IP_AXI_ILA {params} {

    set_required_values $params {device_name axi_control}
    set_required_values $params {core_clk}

    create_bd_cell -type ip -vlnv [get_ipdefs -filter {NAME == ila}] ${device_name}

    set_property -dict [list 
			CONFIG.C_EN_STRG_QUAL {1}
			CONFIG.C_ADV_TRIGGER {true}
			CONFIG.C_PROBE43_MU_CNT {2}
			CONFIG.C_PROBE42_MU_CNT {2}
			CONFIG.C_PROBE41_MU_CNT {2}
			CONFIG.C_PROBE40_MU_CNT {2}
			CONFIG.C_PROBE39_MU_CNT {2}
			CONFIG.C_PROBE38_MU_CNT {2}
			CONFIG.C_PROBE37_MU_CNT {2}
			CONFIG.C_PROBE36_MU_CNT {2}
			CONFIG.C_PROBE35_MU_CNT {2}
			CONFIG.C_PROBE34_MU_CNT {2}
			CONFIG.C_PROBE33_MU_CNT {2}
			CONFIG.C_PROBE32_MU_CNT {2}
			CONFIG.C_PROBE31_MU_CNT {2}
			CONFIG.C_PROBE30_MU_CNT {2}
			CONFIG.C_PROBE29_MU_CNT {2}
			CONFIG.C_PROBE28_MU_CNT {2}
			CONFIG.C_PROBE27_MU_CNT {2}
			CONFIG.C_PROBE26_MU_CNT {2}
			CONFIG.C_PROBE25_MU_CNT {2}
			CONFIG.C_PROBE24_MU_CNT {2}
			CONFIG.C_PROBE23_MU_CNT {2}
			CONFIG.C_PROBE22_MU_CNT {2}
			CONFIG.C_PROBE21_MU_CNT {2}
			CONFIG.C_PROBE20_MU_CNT {2}
			CONFIG.C_PROBE19_MU_CNT {2}
			CONFIG.C_PROBE18_MU_CNT {2}
			CONFIG.C_PROBE17_MU_CNT {2}
			CONFIG.C_PROBE16_MU_CNT {2}
			CONFIG.C_PROBE15_MU_CNT {2}
			CONFIG.C_PROBE14_MU_CNT {2}
			CONFIG.C_PROBE13_MU_CNT {2}
			CONFIG.C_PROBE12_MU_CNT {2}
			CONFIG.C_PROBE11_MU_CNT {2}
			CONFIG.C_PROBE10_MU_CNT {2}
			CONFIG.C_PROBE9_MU_CNT {2}
			CONFIG.C_PROBE8_MU_CNT {2}
			CONFIG.C_PROBE7_MU_CNT {2}
			CONFIG.C_PROBE6_MU_CNT {2}
			CONFIG.C_PROBE5_MU_CNT {2}
			CONFIG.C_PROBE4_MU_CNT {2}
			CONFIG.C_PROBE3_MU_CNT {2}
			CONFIG.C_PROBE2_MU_CNT {2}
			CONFIG.C_PROBE1_MU_CNT {2}
			CONFIG.C_PROBE0_MU_CNT {2}
			CONFIG.C_TRIGIN_EN {true}
			CONFIG.ALL_PROBE_SAME_MU_CNT {2}] [get_bd_cells ${device_name}]

    make_bd_pins_external  -name ${device_name}_TRIG_IN      [get_bd_intf_pins $device_name/trig_in]
    make_bd_pins_external  -name ${device_name}_TRIG_IN_ACK  [get_bd_intf_pins $device_name/trig_in_ack]
    make_bd_pins_external  -name ${device_name}_core_clk     [get_bd_intf_pins $device_name/clk]
    
    [AXI_DEV_CONNECT $params]
    
    
}

