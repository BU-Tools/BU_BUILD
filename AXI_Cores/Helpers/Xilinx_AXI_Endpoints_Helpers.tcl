source -notrace ${BD_PATH}/axi_helpers.tcl

proc get_part {} {
    return [get_parts -of_objects [get_projects]]
    }

proc set_default {dict key default} {
    if {[dict exists $dict $key]} {
        return [dict get $dict $key ]
    } else {
        return $default
    }
}

