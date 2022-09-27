proc GenRefclkName {quad relative_clk} {
    set clk_offset [string range $relative_clk 4 5]
    set clk_base   [string range $relative_clk 0 3]
    if { [string length $clk_offset] > 0 } {
	set clk_name [expr $quad + $clk_offset]
    } else {
	set clk_name $quad
    }
    set clk_name "${clk_name}_${clk_base}"
    return $clk_name
}

proc GenRefclkPKG {clock_map filename} {
    set outFile [open $filename w]    
    puts -nonewline ${outFile} "library IEEE;\n"
    puts -nonewline ${outFile} "use IEEE.std_logic_1164.all;\n\n"
    puts -nonewline ${outFile} "package HAL_PKG is\n"

    puts -nonewline ${outFile} "type HAL_refclks_t is record\n"    
    dict for {clk_name count} $clock_map {
	puts -nonewline ${outFile} [format "  %20s : std_logic;\n" "refclk_${clk_name}_P"]
	puts -nonewline ${outFile} [format "  %20s : std_logic;\n" "refclk_${clk_name}_N"]
    }
    puts -nonewline ${outFile} "end record HAL_refclks_t;\n"
    puts -nonewline ${outFile} "end package HAL_PKG;\n"
    close $outFile
    return $filename
}
