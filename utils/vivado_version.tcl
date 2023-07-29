proc clean_version {} {
    return [string range [version -short] 0 [expr [expr [string last _ [version -short]] > 0 ? [string last _ [version -short]] : [string length [version -short]] ] -1]]

}
