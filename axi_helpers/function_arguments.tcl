proc set_default {dict key default} {
    if {[dict exists $dict $key]} {
        puts "setting explicit $key"
        return [dict get $dict $key ]
    } else {
        puts "$dict"
        puts "setting default $default for $key"
        return $default
    }
}

proc clear_global {variable} {
    upvar $variable testVar
    if { [info exists testVar] } {
        puts "unsetting"
        unset testVar
    }
}

proc is_dict {value} {
    return [expr {[string is list $value] && ([llength $value]&1) == 0}]
}

proc set_required_values {params required_params {split_dict True}} {
    foreach key $required_params  {
        if {[dict exists $params $key]} {
            set val [dict get $params $key]
            if {$split_dict && [is_dict $val]} {
                # handle dictionary arguments
                #puts [dict size $val]
                foreach subkey [dict keys $val] {
                    upvar 1 $subkey x ;# tie the calling value to variable x
                    set x [subst [dict get $val $subkey]]
		    #puts $x
                }
            } else {
                # handle non-dictionary arguments
                upvar 1 $key x ;# tie the calling value to variable x
                set x $val
            }
        } else {
	    set error_message "Required parameter $key not found in:\n    $params"
	    puts ${error_message}
            error ${error_message}
        }
    }
}

proc set_other_values {params other_params {split_dict True}} {
    if { $split_dict } {
	
	foreach key [dict keys $other_params]  {
	    if { [dict exists $params $key] } {
		set value [dict get $params $key]
		# dictionary type parameters
		if {[is_dict $value]} {		
		    foreach subkey [dict keys $value] {
			upvar 1 $subkey x ;# tie the calling value to variable x
			set x  [dict get $value $subkey]
		    }		
		} else {
		    # non-dictionary type parameters or dictionaries not to be split
		    upvar 1 $key x; # tie the calling value to variable x
		    set x $value
		}
	    }
	}

    } else {	
	if { [dict exists $params $other_params] } {
	    upvar 1 $other_params x ;# tie the calling value to variable x
	    set x [dict get $params $other_params]
	}
    }
}

proc set_optional_values {params optional_params {split_dict True}} {

    foreach key [dict keys $optional_params]  {
        set def_val [dict get $optional_params $key]

        # dictionary type parameters
        if {[is_dict $def_val] } {
	    
            # check if the optional dictionary even exists
            # if not just use the default values
            if {[dict exists $params $key]} {
                set set_dict [dict get $params $key]
            } else {
                set set_dict $def_val
            }

	    foreach subkey [dict keys $def_val] {
		upvar 1 $subkey x ;# tie the calling value to variable x
		set x [set_default $set_dict $subkey [dict get $def_val $subkey]]
	    }

        } else {
            # non-dictionary type parameters
            upvar 1 $key x; # tie the calling value to variable x
            set x [set_default $params $key $def_val]
        }
    }
}


