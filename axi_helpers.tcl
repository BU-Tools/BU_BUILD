## \file axi_helpers.tcl
# file \c axi_helpers/function_arguments.tcl
#
# Include for code that simplifies passing dictionaries to functions and setting required and optional dictionary keys
#
# file \c axi_helpers/interconnect.tcl
#
# A collection of code for building AXI interconnects and keeping track of their parameters
#
# file \c axi_helpers/connections.tcl
#
# A collection of code to connect up AXI master and slave interfaces. 
source -notrace ${BD_PATH}/axi_helpers/function_arguments.tcl
source -notrace ${BD_PATH}/axi_helpers/interconnect.tcl
source -notrace ${BD_PATH}/axi_helpers/connections.tcl
