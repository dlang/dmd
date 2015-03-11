# get OS and MODEL
include osmodel.mak

ifeq (,$(TARGET_CPU))
    $(info No cpu specified, assuming X86)
    TARGET_CPU = X86
endif

ifeq (X86,$(TARGET_CPU))
    TARGET_OBJS = cg87.o cgxmm.o cgsched.o cod1.o cod2.o cod3.o cod4.o ptrntab.o
else
    ifeq (stub,$(TARGET_CPU))
        TARGET_OBJS = platform_stub.o
    else
        $(error Unknown TARGET_CPU: '$(TARGET_CPU)')
    endif
endif

ifeq (osx,$(OS))
    export MACOSX_DEPLOYMENT_TARGET=10.3
endif


# Directory configuration
########################################################################
INSTALL_DIR = ../../install
SYSCONFDIR  = /etc/
# Path prefixes for different source file types
C           = backend
TK          = tk
ROOT        = root


# Misc, applicatons and flags
########################################################################
HOST_CC   = g++
CC        = $(HOST_CC) $(MODEL_FLAG)
LDFLAGS   = -lm -lstdc++ -lpthread
TARGET_OS = $(shell echo $(OS) | tr '[a-z]' '[A-Z]')
MMD       = -MMD -MF $(basename $@).deps
GIT       = git
HOST_DC  ?= dmd


# Default compiler flags
########################################################################
CFLAGS := \
	-fno-exceptions -fno-rtti \
	-D__pascal= \
	-DMARS=1 \
	-DTARGET_$(TARGET_OS)=1 \
	-DDM_TARGET_CPU_$(TARGET_CPU)=1 \
	-DDMDV2=1


# Compiler warning flags
########################################################################
WARNFLAGS := -Wno-deprecated -Wstrict-aliasing

ifeq ($(HOST_CC), clang++)
WARNFLAGS += \
    -Wno-logical-op-parentheses \
    -Wno-dynamic-class-memaccess \
    -Wno-switch
endif

# Enable *additional* warnings when ENABLE_WARNINGS have been
# defined. Can be set in the environment or specified on the make
# command line.
ifdef ENABLE_WARNINGS
WARNFLAGS += \
	-Wall -Wextra \
	-Wno-attributes \
	-Wno-char-subscripts \
	-Wno-deprecated \
	-Wno-empty-body \
	-Wno-format \
	-Wno-missing-braces \
	-Wno-missing-field-initializers \
	-Wno-overloaded-virtual \
	-Wno-parentheses \
	-Wno-reorder \
	-Wno-return-type \
	-Wno-sign-compare \
	-Wno-strict-aliasing \
	-Wno-switch \
	-Wno-type-limits \
	-Wno-unknown-pragmas \
	-Wno-unused-function \
	-Wno-unused-label \
	-Wno-unused-parameter \
	-Wno-unused-value \
	-Wno-unused-variable

# GCC Specific
ifeq ($(HOST_CC), g++)
WARNFLAGS += \
	-Wno-logical-op \
	-Wno-narrowing \
	-Wno-unused-but-set-variable \
	-Wno-uninitialized
endif

# Clang Specific
ifeq ($(HOST_CC), clang++)
WARNFLAGS += \
	-Wno-tautological-constant-out-of-range-compare \
	-Wno-tautological-compare \
	-Wno-constant-logical-operand \
	-Wno-self-assign
endif
endif

CFLAGS += $(WARNFLAGS)


# Compiler debug flags
########################################################################
# Append different flags for debugging, profiling and release. Define
# ENABLE_DEBUG and ENABLE_PROFILING to enable profiling.
ifdef ENABLE_DEBUG
$(info Debugging enabled)
DEBUGFLAGS := -g -g3 -DDEBUG=1 -DUNITTEST
ifdef ENABLE_PROFILING
$(info Profiling enabled)
DEBUGFLAGS += -pg -fprofile-arcs -ftest-coverage
LDFLAGS    += -pg -fprofile-arcs -ftest-coverage
endif
else
# Enable optimization when not debugging
CFLAGS += -O2
endif

CFLAGS += $(DEBUGFLAGS)


# Specific compiler flags
########################################################################
# Add extra flags for each category of source files.
DMD_FLAGS  := -I$(ROOT) -Wuninitialized
GLUE_FLAGS := -I$(ROOT) -I$(TK) -I$(C)
BACK_FLAGS := -I$(ROOT) -I$(TK) -I$(C) -I.
ROOT_FLAGS := -I$(ROOT)


# Source object files
########################################################################
# In alphabetical order ... Sadly $(wildcard *.c) cannot be used since
# the source directories contains unused files, or is a mix of files not
# used on all OS/ARCH. A possible adjustment would be to clean-up and
# move Linux/Mac specific files to src_linux, src_mac and win32-files to
# src_win32, etc for example.
DMD_OBJS := \
	access.o aliasthis.o apply.o argtypes.o	arrayop.o attrib.o \
	builtin.o canthrow.o cast.o class.o clone.o cond.o constfold.o \
	cppmangle.o ctfeexpr.o declaration.o delegatize.o doc.o dsymbol.o \
	entity.o enum.o errors.o escape.o expression.o func.o globals.o \
	hdrgen.o id.o identifier.o impcnvtab.o imphint.o import.o \
	inifile.o init.o inline.o interpret.o intrange.o json.o lexer.o \
	link.o macro.o mangle.o mars.o module.o mtype.o nogc.o nspace.o \
	opover.o optimize.o parse.o sapply.o scope.o sideeffect.o \
	statement.o staticassert.o struct.o target.o template.o tokens.o \
	traits.o unittests.o utf.o version.o

ROOT_OBJS := \
	aav.o async.o checkedint.o file.o filename.o man.o object.o \
	outbuffer.o port.o response.o rmem.o speller.o stringtable.o

GLUE_OBJS := \
	e2ir.o glue.o iasm.o irstate.o msc.o s2ir.o tocsym.o toctype.o \
	todt.o toelfdebug.o toir.o toobj.o typinf.o

BACK_OBJS := \
	aa.o backconfig.o bcomplex.o blockopt.o cg.o cgcod.o cgcs.o cgelem.o \
	cgen.o cgreg.o cod5.o code.o cv8.o debug.o divcoeff.o dt.o dwarf.o \
	ee.o eh.o el.o evalu8.o gdag.o gflow.o glocal.o gloop.o go.o gother.o \
	nteh.o os.o out.o outbuf.o pdata.o ph2.o rtlsym.o strtold.o symbol.o \
	ti_achar.o ti_pvoid.o tk.o type.o util2.o var.o \
	$(TARGET_OBJS)

# Adjustments depending on OS
ifeq (osx,$(OS))
    GLUE_OBJS += libmach.o scanmach.o
    BACK_OBJS += machobj.o
else
    GLUE_OBJS += libelf.o scanelf.o
    BACK_OBJS += elfobj.o
endif


# Target dependencies
########################################################################
all: dmd

$(DMD_OBJS) $(GLUE_OBJS): idgen impcnvgen
$(BACK_OBJS): optabgen

frontend.a: $(DMD_OBJS)
root.a: $(ROOT_OBJS)
glue.a: $(GLUE_OBJS)
backend.a: $(BACK_OBJS)

dmd: frontend.a root.a glue.a backend.a
	@echo "  (LINK)  $@"
	$(HOST_CC) -o dmd $(MODEL_FLAG) frontend.a root.a glue.a backend.a $(LDFLAGS)

clean: clean-optabgen clean-idgen clean-impcnvgen
	rm -f dmd \
	$(DMD_OBJS) $(ROOT_OBJS) $(GLUE_OBJS) $(BACK_OBJS) \
	verstr.h core *.deps *.gcda *.gcno *.gcov *.cov *.a *.o

# Just include all deps-file, the compiler fixes this for us.
-include $(wildcard *.deps)


# Generating targets
########################################################################

######## generate a default dmd.conf
define DEFAULT_DMD_CONF
[Environment32]
DFLAGS=-I%@P%/../../druntime/import -I%@P%/../../phobos -L-L%@P%/../../phobos/generated/$(OS)/release/32$(if $(filter $(OS),osx),, -L--export-dynamic)

[Environment64]
DFLAGS=-I%@P%/../../druntime/import -I%@P%/../../phobos -L-L%@P%/../../phobos/generated/$(OS)/release/64$(if $(filter $(OS),osx),, -L--export-dynamic)
endef

export DEFAULT_DMD_CONF

dmd.conf:
	[ -f $@ ] || echo "$$DEFAULT_DMD_CONF" > $@

######## optabgen generates some source
optabgen_output = debtab.c optab.c cdxxx.c elxxx.c fltables.c tytab.c
$(optabgen_output) : optabgen
optabgen: $C/optabgen.c $C/cc.h $C/oper.h
	@echo "  Build and run $@ ..."
	$(CC) $(CFLAGS) -I$(TK) $< -o $@
	./$@
clean-optabgen:
	-rm -f optabgen $(optabgen_output)

######## idgen generates some source
idgen_output = id.h id.c
$(idgen_output) : idgen
idgen : idgen.d
	@echo "  Build and run $@ ..."
	$(HOST_DC) -run idgen
clean-idgen:
	-rm -f idgen $(idgen_output)

######### impcnvgen generates some source
impcnvgen_output = impcnvtab.c
$(impcnvgen_output) : impcnvgen
impcnvgen : impcnvgen.c mtype.h
	@echo "  Build and run $@ ..."
	$(CC) $(CFLAGS) -I$(ROOT) $< -o $@
	./$@
clean-impcnvgen:
	-rm -f impcnvgen $(impcnvgen_output)


# Specific dependencies other than the source file for all objects
########################################################################
# If additional flags are needed for a specific file add a _CFLAGS as a
# dependency to the object file and assign the appropriate
# content. These files are compiled by the implicit targets in the next
# section.

cg.o: fltables.c

cgcod.o: cdxxx.c

cgelem.o: elxxx.c

debug.o: debtab.c

iasm.o: CFLAGS += -fexceptions

inifile.o: CFLAGS += -DSYSCONFDIR='"$(SYSCONFDIR)"'

mars.o: verstr.h

var.o: optab.c tytab.c


# Generic (implicit) rules for all source files
########################################################################
# Search the directory $(C) for .c-files when using implicit pattern
# matching below. The above specific deps slightly adjust the following
# rules for some of the source files.
vpath %.c $(C)

$(DMD_OBJS): %.o: %.c posix.mak
	@echo "  (CC)  DMD_OBJS   $<"
	$(CC) -c $(CFLAGS) $(DMD_FLAGS) $(MMD) $<

$(BACK_OBJS): %.o: %.c posix.mak
	@echo "  (CC)  BACK_OBJS  $<"
	$(CC) -c $(CFLAGS) $(BACK_FLAGS) $(MMD) $<

$(GLUE_OBJS): %.o: %.c posix.mak
	@echo "  (CC)  GLUE_OBJS  $<"
	$(CC) -c $(CFLAGS) $(GLUE_FLAGS) $(MMD) $<

$(ROOT_OBJS): %.o: $(ROOT)/%.c posix.mak
	@echo "  (CC)  ROOT_OBJS  $<"
	$(CC) -c $(CFLAGS) $(ROOT_FLAGS) $(MMD) $<

%.a:
	@echo "  (AR)  Archiving $@"
	ar rcs $@ $?


# Version string in verstr.h
########################################################################
# Create (or update) the verstr.h file.
# The file is only updated if the VERSION file changes, or, only when RELEASE=1
# is not used, when the full version string changes (i.e. when the git hash or
# the working tree dirty states changes).
# The full version string have the form VERSION-devel-HASH(-dirty).
# The "-dirty" part is only present when the repository had uncommitted changes
# at the moment it was compiled (only files already tracked by git are taken
# into account, untracked files don't affect the dirty state).
GIT     := git
VERSION := $(shell cat ../VERSION)
ifneq (1,$(RELEASE))
VERSION_GIT := $(shell printf "`$(GIT) rev-parse --short HEAD`"; \
       test -n "`$(GIT) status --porcelain -uno`" && printf -- -dirty)
VERSION := $(addsuffix -devel$(if $(VERSION_GIT),-$(VERSION_GIT)),$(VERSION))
endif
$(shell test \"$(VERSION)\" != "`cat verstr.h 2> /dev/null`" \
		&& printf \"$(VERSION)\" > verstr.h )


# Install target
########################################################################

install: all
	$(eval bin_dir=$(if $(filter $(OS),osx), bin, bin$(MODEL)))
	mkdir -p $(INSTALL_DIR)/$(OS)/$(bin_dir)
	cp dmd $(INSTALL_DIR)/$(OS)/$(bin_dir)/dmd
	cp ../ini/$(OS)/$(bin_dir)/dmd.conf $(INSTALL_DIR)/$(OS)/$(bin_dir)/dmd.conf
	cp backendlicense.txt $(INSTALL_DIR)/dmd-backendlicense.txt
	cp boostlicense.txt $(INSTALL_DIR)/dmd-boostlicense.txt


# Gcov (coverage testing)
########################################################################
# Run gcov on all available gcno files if gcov is found, then run gcovr
# if that one is found as well.

gcov:
	files=*.gcno; \
	[ $${#files[*]} -gt 0 ] && \
		gcov -md *.gcno || \
		echo "No gcno files, execute test suite"

gcovr: gcov
	@echo "Creating gcov report: gcov-report.html"
	gcovr --html -o gcov-report.html .


# Zip source directory
########################################################################
# Zip's the whole 'src' directory skipping Win build files and some
# other files not required.
zip:
	-rm -f dmdsrc.zip
	zip dmdsrc -r . -x dmd_msc\* vcbuild\* \*.zip \*.o \*.txt verstr.h
