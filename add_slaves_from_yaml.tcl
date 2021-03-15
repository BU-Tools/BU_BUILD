# https://github.com/apollo-lhc/sm_zynq_fw/blob/develop/configs/rev2_xczu7ev/slaves.yaml

proc huddle_to_bd {huddle} {
    foreach key [huddle keys $huddle] {
        #puts "$key"
        #puts "Processing node $key"
        if { 0 == [string compare "TCL_CALL" $key] } {
            #puts "Found TCL_CALL"
            set tcl_call_huddle [huddle get $huddle $key]
            set command "[huddle gets $tcl_call_huddle command]"
            set pairs [dict create]
            foreach pairkey [huddle keys $tcl_call_huddle] {
                if { 0 != [string compare "command" $pairkey]} {
                    #puts "  > $pairkey"
                    dict append pairs $pairkey [subst [huddle gets $tcl_call_huddle $pairkey]]
                }}
            puts "Executing command from YAML: $command \[dict create $pairs\]"
            eval $command {$pairs}
        }
        if { 0 == [string compare "dict" [huddle type [huddle get $huddle $key]]]} {
            huddle_to_bd [huddle get $huddle $key]
        }
    }}

proc yaml_to_bd {yaml_file} {
    huddle_to_bd [huddle get [yaml::yaml2huddle -file $yaml_file] "AXI_SLAVES"]
}
