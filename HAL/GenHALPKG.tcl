proc GenHALPKG {filename type_channel_counts} {
    set outFile [open $filename w]    
    puts -nonewline ${outFile} "library IEEE;\n"
    puts -nonewline ${outFile} "use IEEE.std_logic_1164.all;\n\n"
    puts -nonewline ${outFile} "package HAL_PKG is\n"

    dict for {type count} $type_channel_counts {
	puts -nonewline ${outFile} [format \
					"  constant %20s_CHAN_COUNT : integer := % 3d;\n" \
					$type \
					$count
				       ]
    }
    puts -nonewline ${outFile} "end package HAL_PKG;\n"
    close $outFile
    return $filename
}
