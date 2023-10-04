.PHONY: doc doc_tcl clean 

all: doc

clean:
	@echo "Cleaning up"
	@rm -rf ./html_tcl > /dev/null 2>&1
	@rm doxygen.tar.gz

doc : doc_tcl

doc_tcl :
	@echo "Generating doxygen for TCL"
	@doxygen ./SM_TCL.cfg
	@tar -zcf doxygen.tar.gz html_tcl
