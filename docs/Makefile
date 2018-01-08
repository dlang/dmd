MAN_PAGE=man/man1/dmd.1
DMD=dmd
DMD_ROOT=..
G=$(DMD_ROOT)/generated

################################################################################
# Main targets
################################################################################

build: $(MAN_PAGE)

preview:
	man -l $(MAN_PAGE)

################################################################################
# Actual compilation commands
################################################################################

$(MAN_PAGE): $G/gen_man
	$< > $@

$G/gen_man: gen_man.d $(DMD_ROOT)/src/dmd/cli.d
	$(DMD) -I$(DMD_ROOT)/src -of$@ $^
