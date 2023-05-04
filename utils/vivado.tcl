proc GET_BD_PINS_OR_PORTS {destination expression} {
    upvar 1 $destination dest
    set dest [get_bd_pins -quiet $expression]
    if { [string trim $dest] == "" } {
	set dest [get_bd_intf_ports -quiet $expression]
    }
    return $dest
}
