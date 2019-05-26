DMD=dmd
DMD_ROOT=..
GENERATED=$(DMD_ROOT)/generated
G=$(DMD_ROOT)/generated/docs
DMD_MAN_PAGE=man/man1/dmd.1
OTHER_MAN_PAGES=$(addprefix man/, \
	$(addprefix man1/, dumpobj.1 obj2asm.1) \
	man5/dmd.conf.5 \
)

include ../src/osmodel.mak

BUILD=release
G_BIN=$(GENERATED)/$(OS)/$(BUILD)/$(MODEL)

# Removes inclusion of all dynamic content and timestamps
export DIFFABLE

################################################################################
# Main targets
################################################################################

build: $(addprefix $G/, $(DMD_MAN_PAGE) $(OTHER_MAN_PAGES))

preview: $G/$(DMD_MAN_PAGE)
	man -l $G/$(DMD_MAN_PAGE)

################################################################################
# Actual compilation commands
################################################################################

$G/$(DMD_MAN_PAGE): $(G_BIN)/gen_man
	@mkdir -p $(dir $@)
	$< > $@

$(G_BIN)/gen_man: gen_man.d $(DMD_ROOT)/src/dmd/cli.d
	@mkdir -p $(dir $@)
	$(DMD) -I$(DMD_ROOT)/src -of$@ $^

$G/%: %
	@mkdir -p $(dir $@)
	cp $< $@
