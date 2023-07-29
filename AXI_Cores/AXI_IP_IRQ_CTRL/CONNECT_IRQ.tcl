proc CONNECT_IRQ {irq_src irq_dest} {
    #connect to global for this irq controller
    global IRQ_COUNT_${irq_dest}
    if { [info exists IRQ_COUNT_${irq_dest}] == 0 } {
	set IRQ_COUNT_${irq_dest} 0	
    }

    upvar 0 IRQ_COUNT_${irq_dest} IRQ_COUNT

    if [llength [get_bd_cells -quiet ${irq_dest}_IRQ]] {
	set dest_name ${irq_dest}_IRQ
    
	set input_port_count [get_property CONFIG.NUM_PORTS [get_bd_cells $dest_name]]
    
	if { ${IRQ_COUNT} >= $input_port_count} {
	    #expand the concact part of the controller
	    set_property CONFIG.NUM_PORTS [expr {$input_port_count + 1}] [get_bd_cells $dest_name]
	}

	connect_bd_net [get_bd_pins ${irq_src}] [get_bd_pins ${dest_name}/In${IRQ_COUNT}]  

	puts "Connecting IRQ: ${irq_src} to ${dest_name}/In${IRQ_COUNT}"

	#expand the number of IRQs connected to this
	set IRQ_COUNT [expr {$IRQ_COUNT + 1}]
    } else {
	connect_bd_net [get_bd_pins ${irq_src}] [get_bd_pins ${irq_dest}]  
	puts "Connecting IRQ: ${irq_src} to ${irq_dest}"
    }
}
