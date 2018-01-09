include ../common.mak

TESTS:=bug18193

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done:
	@echo Testing $*
	@mkdir -p $(basename $@)
	$(QUIET)$(DMD) -version=Shared -o- -deps=$@ -Isrc -I../../import src/$*

clean:
	rm -rf $(GENERATED)
