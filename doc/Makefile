.PHONY: doc doc_tcl clean 

VHDL_SEARCH_PATHS = "INPUT=./main_fw.md ../src/ ../proj/zynq_bd/synth/ ../proj/zynq_bd/hdl/ ../configs/ "$(wildcard  ../proj/zynq_bd/ip/*/synth/)


all: doc

clean:
	@echo "Cleaning up"
	@rm -rf ./html_zynq > /dev/null 2>&1
	@rm -rf ./html_tcl > /dev/null 2>&1

doc : doc_tcl

doc_tcl :
	@echo "Generating doxygen for TCL"
	@doxygen ./SM_TCL.cfg
