## proc \c clean_version
# This function returns the current version of vivado in a MAJ.MIN.PATCH format for use when comparing version numbers
# It will clear out any manually loaded patch info from the version.
proc clean_version {} {
    return [string range [version -short] 0 [expr [expr [string last _ [version -short]] > 0 ? [string last _ [version -short]] : [string length [version -short]] ] -1]]

}
