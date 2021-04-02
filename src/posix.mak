# get OS and MODEL
include osmodel.mak

ifeq (,$(TARGET_CPU))
    $(info no cpu specified, assuming X86)
    TARGET_CPU=X86
endif

ifeq (X86,$(TARGET_CPU))
    TARGET_CH = $C/code_x86.h
    TARGET_OBJS = cg87.o cgxmm.o cgsched.o cod1.o cod2.o cod3.o cod4.o ptrntab.o
else
    ifeq (stub,$(TARGET_CPU))
        TARGET_CH = $C/code_stub.h
        TARGET_OBJS = platform_stub.o
    else
        $(error unknown TARGET_CPU: '$(TARGET_CPU)')
    endif
endif

# default to PIC on x86_64, use PIC=1/0 to en-/disable PIC.
# Note that shared libraries and C files are always compiled with PIC.
ifeq ($(PIC),)
    ifeq ($(MODEL),64) # x86_64
        PIC:=1
    else
        PIC:=0
    endif
endif
ifeq ($(PIC),1)
    override PIC:=-fPIC
else
    override PIC:=
endif

INSTALL_DIR=../../install
# can be set to override the default /etc/
SYSCONFDIR=/etc/
PGO_DIR=$(abspath pgo)

C=backend
TK=tk
ROOT=root

GENERATED = ../generated
BUILD=release
G = $(GENERATED)/$(OS)/$(BUILD)/$(MODEL)
$(shell mkdir -p $G)

ifeq (osx,$(OS))
    export MACOSX_DEPLOYMENT_TARGET=10.3
endif
LDFLAGS=-lm -lstdc++ -lpthread

HOST_CXX=c++
# compatibility with old behavior
ifneq ($(HOST_CC),)
  $(warning ===== WARNING: Please use HOST_CXX=$(HOST_CC) instead of HOST_CC=$(HOST_CC). =====)
  HOST_CXX=$(HOST_CC)
endif
CXX=$(HOST_CXX)
AR=ar
GIT=git

# determine whether CXX is gcc or clang based
CXX_VERSION:=$(shell $(CXX) --version)
ifneq (,$(findstring g++,$(CXX_VERSION))$(findstring gcc,$(CXX_VERSION))$(findstring Free Software,$(CXX_VERSION)))
	CXX_KIND=g++
endif
ifneq (,$(findstring clang,$(CXX_VERSION)))
	CXX_KIND=clang++
endif

# Compiler Warnings
ifdef ENABLE_WARNINGS
WARNINGS := -Wall -Wextra \
	-Wwrite-strings \
	-Wno-long-long \
	-Wno-variadic-macros \
	-Wno-overlength-strings
# Frontend specific
DMD_WARNINGS := -Wcast-qual \
	-Wuninitialized
ROOT_WARNINGS := -Wno-sign-compare \
	-Wno-unused-parameter
# Backend specific
GLUE_WARNINGS := $(ROOT_WARNINGS) \
	-Wno-format \
	-Wno-parentheses \
	-Wno-switch \
	-Wno-unused-function \
	-Wno-unused-variable
BACK_WARNINGS := $(GLUE_WARNINGS) \
	-Wno-char-subscripts \
	-Wno-empty-body \
	-Wno-missing-field-initializers \
	-Wno-type-limits \
	-Wno-unused-label \
	-Wno-unused-value \
	-Wno-varargs
# GCC Specific
ifeq ($(CXX_KIND), g++)
BACK_WARNINGS += \
	-Wno-unused-but-set-variable \
	-Wno-implicit-fallthrough \
	-Wno-class-memaccess \
	-Wno-uninitialized
endif
# Clang Specific
ifeq ($(CXX_KIND), clang++)
WARNINGS += \
	-Wno-undefined-var-template \
	-Wno-absolute-value \
	-Wno-missing-braces \
	-Wno-self-assign \
	-Wno-unused-const-variable \
	-Wno-constant-conversion \
	-Wno-overloaded-virtual
endif
else
# Default Warnings
WARNINGS := -Wno-deprecated -Wstrict-aliasing
# Frontend specific
DMD_WARNINGS := -Wuninitialized
ROOT_WARNINGS :=
# Backend specific
GLUE_WARNINGS := $(ROOT_WARNINGS) \
	-Wno-switch
BACK_WARNINGS := $(GLUE_WARNINGS) \
	-Wno-unused-value \
	-Wno-varargs
# Clang Specific
ifeq ($(CXX_KIND), clang++)
WARNINGS += \
	-Wno-undefined-var-template \
	-Wno-absolute-value
GLUE_WARNINGS += \
	-Wno-logical-op-parentheses
BACK_WARNINGS += \
	-Wno-logical-op-parentheses \
	-Wno-constant-conversion
endif
endif

# Treat warnings as errors
ifdef ENABLE_WERROR
WARNINGS += -Werror
endif

OS_UPCASE := $(shell echo $(OS) | tr '[a-z]' '[A-Z]')

MMD=-MMD -MF $(basename $@).deps

# Default compiler flags for all source files
CXXFLAGS := $(WARNINGS) \
	-fno-exceptions -fno-rtti \
	-D__pascal= -DMARS=1 -DTARGET_$(OS_UPCASE)=1 -DDM_TARGET_CPU_$(TARGET_CPU)=1 \
	$(MODEL_FLAG) $(PIC)
# GCC Specific
ifeq ($(CXX_KIND), g++)
CXXFLAGS += \
	-std=c++11
endif
# Clang Specific
ifeq ($(CXX_KIND), clang++)
CXXFLAGS += \
	-xc++ -std=c++11
endif
# Default D compiler flags for all source files
DFLAGS := -version=MARS $(PIC)
# Enable D warnings
DFLAGS += -w -de

ifneq (,$(DEBUG))
ENABLE_DEBUG := 1
endif
ifneq (,$(RELEASE))
ENABLE_RELEASE := 1
endif

# Append different flags for debugging, profiling and release.
ifdef ENABLE_DEBUG
CXXFLAGS += -g -g3 -DDEBUG=1 -DUNITTEST
DFLAGS += -g -debug
endif
ifdef ENABLE_RELEASE
CXXFLAGS += -O2
DFLAGS += -O -release -inline
endif
ifdef ENABLE_PROFILING
CXXFLAGS  += -pg -fprofile-arcs -ftest-coverage
endif
ifdef ENABLE_PGO_GENERATE
CXXFLAGS  += -fprofile-generate=${PGO_DIR}
endif
ifdef ENABLE_PGO_USE
CXXFLAGS  += -fprofile-use=${PGO_DIR} -freorder-blocks-and-partition
endif
ifdef ENABLE_LTO
CXXFLAGS  += -flto
endif
ifdef ENABLE_UNITTEST
DFLAGS  += -unittest -cov
endif
ifdef ENABLE_PROFILE
DFLAGS  += -profile
endif
ifdef ENABLE_COVERAGE
DFLAGS  += -cov -L-lgcov
CXXFLAGS += --coverage
endif
ifdef ENABLE_SANITIZERS
CXXFLAGS += -fsanitize=${ENABLE_SANITIZERS}

ifeq ($(HOST_DMD_KIND), dmd)
HOST_CXX += -fsanitize=${ENABLE_SANITIZERS}
endif
ifneq (,$(findstring gdc,$(HOST_DMD_KIND))$(findstring ldc,$(HOST_DMD_KIND)))
DFLAGS += -fsanitize=${ENABLE_SANITIZERS}
endif

endif

# Unique extra flags if necessary
DMD_FLAGS  := -I$(ROOT) $(DMD_WARNINGS)
GLUE_FLAGS := -I$(ROOT) -I$(TK) -I$(C) $(GLUE_WARNINGS)
BACK_FLAGS := -I$(ROOT) -I$(TK) -I$(C) -I. -DDMDV2=1 $(BACK_WARNINGS)
ROOT_FLAGS := -I$(ROOT) $(ROOT_WARNINGS)

# GCC Specific
ifeq ($(CXX_KIND), g++)
BACK_FLAGS += \
	-std=gnu++11
endif

ifeq ($(OS), osx)
ifeq ($(MODEL), 64)
D_OBJC := 1
endif
endif

DMD_OBJS = \
	access.o attrib.o \
	dcast.o \
	dclass.o \
	constfold.o cond.o \
	declaration.o dsymbol.o \
	denum.o expression.o expressionsem.o func.o nogc.o \
	id.o \
	identifier.o impcnvtab.o dimport.o inifile.o init.o initsem.o inline.o inlinecost.o \
	lexer.o link.o dmangle.o mars.o dmodule.o mtype.o \
	compiler.o cppmangle.o opover.o optimize.o \
	parse.o dscope.o statement.o \
	dstruct.o dtemplate.o \
	dversion.o utf.o staticassert.o staticcond.o \
	entity.o doc.o dmacro.o \
	hdrgen.o delegatize.o dinterpret.o traits.o \
	builtin.o ctfeexpr.o clone.o aliasthis.o \
	arrayop.o json.o unittests.o \
	imphint.o argtypes.o apply.o sapply.o safe.o sideeffect.o \
	intrange.o blockexit.o canthrow.o target.o nspace.o objc.o errors.o \
	escape.o tokens.o globals.o \
	utils.o chkformat.o \
	dsymbolsem.o semantic2.o semantic3.o statementsem.o templateparamsem.o typesem.o

ROOT_OBJS = \
	rmem.o port.o man.o stringtable.o response.o \
	aav.o speller.o outbuffer.o rootobject.o \
	filename.o file.o checkedint.o \
	newdelete.o ctfloat.o

GLUE_OBJS = \
	glue.o msc.o s2ir.o todt.o e2ir.o tocsym.o \
	toobj.o toctype.o toelfdebug.o toir.o \
	irstate.o typinf.o iasm.o iasmdmd.o iasmgcc.o


ifeq ($(D_OBJC),1)
	GLUE_OBJS += objc_glue.o
else
	GLUE_OBJS += objc_glue_stubs.o
endif

ifeq (osx,$(OS))
    GLUE_OBJS += libmach.o scanmach.o
else
    GLUE_OBJS += libelf.o scanelf.o
endif

#GLUE_OBJS=gluestub.o

BACK_OBJS = go.o gdag.o gother.o gflow.o gloop.o var.o el.o \
	glocal.o os.o nteh.o evalu8.o cgcs.o \
	rtlsym.o cgelem.o cgen.o cgreg.o out.o \
	blockopt.o cg.o type.o dt.o \
	debug.o code.o ee.o symbol.o \
	cgcod.o cod5.o outbuf.o \
	bcomplex.o aa.o ti_achar.o \
	ti_pvoid.o pdata.o cv8.o backconfig.o \
	divcoeff.o dwarf.o dwarfeh.o \
	ph2.o util2.o eh.o tk.o strtold.o \
	$(TARGET_OBJS)

ifeq (osx,$(OS))
	BACK_OBJS += machobj.o
else
	BACK_OBJS += elfobj.o
endif

SRC = win32.mak posix.mak osmodel.mak \
	mars.c denum.c dstruct.c dsymbol.c dimport.c idgen.c impcnvgen.c \
	identifier.c mtype.c expression.c expressionsem.c optimize.c template.h \
	dtemplate.c lexer.c declaration.c dcast.c cond.h cond.c link.c \
	aggregate.h parse.c statement.c constfold.c version.h dversion.c \
	inifile.c dmodule.c dscope.c init.h init.c initsem.c attrib.h \
	attrib.c opover.c dclass.c dmangle.c func.c nogc.c inline.c inlinecost.c \
	access.c complex_t.h \
	identifier.h parse.h \
	scope.h enum.h import.h mars.h module.h mtype.h dsymbol.h \
	declaration.h lexer.h expression.h statement.h \
	utf.h utf.c staticassert.h staticassert.c staticcond.c \
	entity.c \
	doc.h doc.c macro.h dmacro.c hdrgen.h hdrgen.c arraytypes.h \
	delegatize.c dinterpret.c traits.c cppmangle.c \
	builtin.c clone.c lib.h arrayop.c \
	aliasthis.h aliasthis.c json.h json.c unittests.c imphint.c \
	argtypes.c apply.c sapply.c safe.c sideeffect.c \
	intrange.h intrange.c blockexit.c canthrow.c target.c target.h \
	scanmscoff.c scanomf.c ctfe.h ctfeexpr.c \
	ctfe.h ctfeexpr.c visitor.h nspace.h nspace.c errors.h errors.c \
	escape.c tokens.h tokens.c globals.h globals.c objc.c objc.h \
	utils.c chkformat.c \
	dsymbolsem.c semantic2.c semantic3.c statementsem.c templateparamsem.c typesem.c

ROOT_SRC = $(ROOT)/root.h \
	$(ROOT)/array.h \
	$(ROOT)/rmem.h $(ROOT)/rmem.c $(ROOT)/port.h $(ROOT)/port.c \
	$(ROOT)/man.c $(ROOT)/newdelete.c \
	$(ROOT)/checkedint.h $(ROOT)/checkedint.c \
	$(ROOT)/stringtable.h $(ROOT)/stringtable.c \
	$(ROOT)/response.c \
	$(ROOT)/aav.h $(ROOT)/aav.c \
	$(ROOT)/longdouble.h $(ROOT)/longdouble.c \
	$(ROOT)/speller.h $(ROOT)/speller.c \
	$(ROOT)/outbuffer.h $(ROOT)/outbuffer.c \
	$(ROOT)/object.h $(ROOT)/rootobject.c \
	$(ROOT)/filename.h $(ROOT)/filename.c \
	$(ROOT)/file.h $(ROOT)/file.c \
	$(ROOT)/ctfloat.h $(ROOT)/ctfloat.c \
	$(ROOT)/hash.h

GLUE_SRC = glue.c msc.c s2ir.c todt.c e2ir.c tocsym.c \
	toobj.c toctype.c tocvdebug.c toir.h toir.c \
	libmscoff.c scanmscoff.c irstate.h irstate.c typinf.c iasm.c \
	toelfdebug.c libomf.c scanomf.c libelf.c scanelf.c libmach.c scanmach.c \
	tk.c eh.c gluestub.c objc_glue.c objc_glue_stubs.c

BACK_SRC = \
	$C/cdef.h $C/cc.h $C/oper.h $C/ty.h $C/optabgen.c \
	$C/global.h $C/code.h $C/type.h $C/dt.h $C/cgcv.h \
	$C/el.h $C/iasm.h $C/rtlsym.h \
	$C/bcomplex.c $C/blockopt.c $C/cg.c $C/cg87.c $C/cgxmm.c \
	$C/cgcod.c $C/cgcs.c $C/cgcv.c $C/cgelem.c $C/cgen.c $C/cgobj.c \
	$C/cgreg.c $C/var.c $C/strtold.c \
	$C/cgsched.c $C/cod1.c $C/cod2.c $C/cod3.c $C/cod4.c $C/cod5.c \
	$C/code.c $C/symbol.c $C/debug.c $C/dt.c $C/ee.c $C/el.c \
	$C/evalu8.c $C/go.c $C/gflow.c $C/gdag.c \
	$C/gother.c $C/glocal.c $C/gloop.c $C/newman.c \
	$C/nteh.c $C/os.c $C/out.c $C/outbuf.c $C/ptrntab.c $C/rtlsym.c \
	$C/type.c $C/melf.h $C/mach.h $C/mscoff.h $C/bcomplex.h \
	$C/outbuf.h $C/token.h $C/tassert.h \
	$C/elfobj.c $C/cv4.h $C/dwarf2.h $C/exh.h $C/go.h \
	$C/dwarf.c $C/dwarf.h $C/aa.h $C/aa.c $C/tinfo.h $C/ti_achar.c \
	$C/ti_pvoid.c $C/platform_stub.c $C/code_x86.h $C/code_stub.h \
	$C/machobj.c $C/mscoffobj.c \
	$C/xmm.h $C/obj.h $C/pdata.c $C/cv8.c $C/backconfig.c $C/divcoeff.c \
	$C/md5.c $C/md5.h \
	$C/ph2.c $C/util2.c $C/dwarfeh.c \
	$(TARGET_CH)

TK_SRC = \
	$(TK)/filespec.h $(TK)/mem.h $(TK)/list.h $(TK)/vec.h \
	$(TK)/filespec.c $(TK)/mem.c $(TK)/vec.c $(TK)/list.c

DEPS = $(patsubst %.o,%.deps,$(DMD_OBJS) $(ROOT_OBJS) $(GLUE_OBJS) $(BACK_OBJS))

all: dmd

auto-tester-build: dmd
.PHONY: auto-tester-build

frontend.a: $(DMD_OBJS)
	$(AR) rcs frontend.a $(DMD_OBJS)

root.a: $(ROOT_OBJS)
	$(AR) rcs root.a $(ROOT_OBJS)

glue.a: $(GLUE_OBJS)
	$(AR) rcs glue.a $(GLUE_OBJS)

backend.a: $(BACK_OBJS)
	$(AR) rcs backend.a $(BACK_OBJS)

ifdef ENABLE_LTO
dmd: $(DMD_OBJS) $(ROOT_OBJS) $(GLUE_OBJS) $(BACK_OBJS)
	$(CXX) -o dmd $(MODEL_FLAG) $^ $(LDFLAGS)
	cp dmd $G/dmd
else
dmd: frontend.a root.a glue.a backend.a
	$(CXX) -o dmd $(MODEL_FLAG) frontend.a root.a glue.a backend.a $(LDFLAGS)
	cp dmd $G/dmd
endif

clean:
	rm -f $(DMD_OBJS) $(ROOT_OBJS) $(GLUE_OBJS) $(BACK_OBJS) dmd optab.o id.o impcnvgen idgen id.c id.h \
		impcnvtab.d id.d impcnvtab.c optabgen debtab.c optab.c cdxxx.c elxxx.c fltables.c \
		tytab.c verstr.h core \
		*.cov *.deps *.gcda *.gcno *.a \
		$(GENSRC)
	@[ ! -d ${PGO_DIR} ] || echo You should issue manually: rm -rf ${PGO_DIR}
	rm -Rf $(GENERATED)

######## generate a default dmd.conf

define DEFAULT_DMD_CONF
[Environment32]
DFLAGS=-I%@P%/../../druntime/import -I%@P%/../../phobos -L-L%@P%/../../phobos/generated/$(OS)/release/32$(if $(filter $(OS),osx),, -L--export-dynamic)

[Environment64]
DFLAGS=-I%@P%/../../druntime/import -I%@P%/../../phobos -L-L%@P%/../../phobos/generated/$(OS)/release/64$(if $(filter $(OS),osx),, -L--export-dynamic) -fPIC
endef

export DEFAULT_DMD_CONF

dmd.conf:
	[ -f $@ ] || echo "$$DEFAULT_DMD_CONF" > $@

######## optabgen generates some source

optabgen: $C/optabgen.c $C/cc.h $C/oper.h
	$(HOST_CXX) $(CXXFLAGS) $(BACK_WARNINGS) -I$(TK) $< -o optabgen
	./optabgen

optabgen_output = debtab.c optab.c cdxxx.c elxxx.c fltables.c tytab.c
$(optabgen_output) : optabgen

######## idgen generates some source

idgen_output = id.h id.c id.d
$(idgen_output) : idgen

idgen : idgen.c
	$(HOST_CXX) $(CXXFLAGS) idgen.c -o idgen
	./idgen

######### impcnvgen generates some source

impcnvtab_output = impcnvtab.c impcnvtab.d
$(impcnvtab_output) : impcnvgen

impcnvgen : mtype.h impcnvgen.c
	$(HOST_CXX) $(CXXFLAGS) -I$(ROOT) impcnvgen.c -o impcnvgen
	./impcnvgen

#########

# Create (or update) the verstr.h file.
# The file is only updated if the VERSION file changes, or, only when RELEASE=1
# is not used, when the full version string changes (i.e. when the git hash or
# the working tree dirty states changes).
# The full version string have the form VERSION-devel-HASH(-dirty).
# The "-dirty" part is only present when the repository had uncommitted changes
# at the moment it was compiled (only files already tracked by git are taken
# into account, untracked files don't affect the dirty state).
VERSION := $(shell cat ../VERSION)
ifneq (1,$(RELEASE))
VERSION_GIT := $(shell printf "`$(GIT) rev-parse --short HEAD`"; \
       test -n "`$(GIT) status --porcelain -uno`" && printf -- -dirty)
VERSION := $(addsuffix -devel$(if $(VERSION_GIT),-$(VERSION_GIT)),$(VERSION))
endif
$(shell test \"$(VERSION)\" != "`cat verstr.h 2> /dev/null`" \
		&& printf \"$(VERSION)\" > verstr.h )

#########

$(DMD_OBJS) $(GLUE_OBJS) : $(idgen_output) $(impcnvgen_output)
$(BACK_OBJS) : $(optabgen_output)


# Specific dependencies other than the source file for all objects
########################################################################
# If additional flags are needed for a specific file add a _CFLAGS as a
# dependency to the object file and assign the appropriate content.

cg.o: fltables.c

cgcod.o: cdxxx.c

cgelem.o: elxxx.c

debug.o: debtab.c

iasm.o: CXXFLAGS += -fexceptions

inifile.o: CXXFLAGS += -DSYSCONFDIR='"$(SYSCONFDIR)"'

mars.o: verstr.h

var.o: optab.c tytab.c


# Generic rules for all source files
########################################################################
# Search the directory $(C) for .c-files when using implicit pattern
# matching below.
vpath %.c $(C)

$(DMD_OBJS): %.o: %.c posix.mak
	@echo "  (CC)  DMD_OBJS   $<"
	$(CXX) -c $(CXXFLAGS) $(DMD_FLAGS) $(MMD) $<

$(BACK_OBJS): %.o: %.c posix.mak
	@echo "  (CC)  BACK_OBJS  $<"
	$(CXX) -c $(CXXFLAGS) $(BACK_FLAGS) $(MMD) $<

$(GLUE_OBJS): %.o: %.c posix.mak
	@echo "  (CC)  GLUE_OBJS  $<"
	$(CXX) -c $(CXXFLAGS) $(GLUE_FLAGS) $(MMD) $<

$(ROOT_OBJS): %.o: $(ROOT)/%.c posix.mak
	@echo "  (CC)  ROOT_OBJS  $<"
	$(CXX) -c $(CXXFLAGS) $(ROOT_FLAGS) $(MMD) $<


-include $(DEPS)

######################################################

install: all
	$(eval bin_dir=$(if $(filter $(OS),osx), bin, bin$(MODEL)))
	mkdir -p $(INSTALL_DIR)/$(OS)/$(bin_dir)
	cp dmd $(INSTALL_DIR)/$(OS)/$(bin_dir)/dmd
	cp ../ini/$(OS)/$(bin_dir)/dmd.conf $(INSTALL_DIR)/$(OS)/$(bin_dir)/dmd.conf
	cp backendlicense.txt $(INSTALL_DIR)/dmd-backendlicense.txt
	cp boostlicense.txt $(INSTALL_DIR)/dmd-boostlicense.txt

######################################################

gcov:
	gcov access.c
	gcov aliasthis.c
	gcov apply.c
	gcov arrayop.c
	gcov attrib.c
	gcov builtin.c
	gcov blockexit.c
	gcov canthrow.c
	gcov dcast.c
	gcov dclass.c
	gcov clone.c
	gcov cond.c
	gcov constfold.c
	gcov declaration.c
	gcov delegatize.c
	gcov doc.c
	gcov dsymbol.c
	gcov e2ir.c
	gcov eh.c
	gcov entity.c
	gcov denum.c
	gcov expression.c
	gcov expressionsem.c
	gcov func.c
	gcov nogc.c
	gcov glue.c
	gcov iasm.c
	gcov identifier.c
	gcov imphint.c
	gcov dimport.c
	gcov inifile.c
	gcov init.c
	gcov initsem.c
	gcov inline.c
	gcov inlinecost.c
	gcov dinterpret.c
	gcov ctfeexpr.c
	gcov irstate.c
	gcov json.c
	gcov lexer.c
ifeq (osx,$(OS))
	gcov libmach.c
else
	gcov libelf.c
endif
	gcov link.c
	gcov dmacro.c
	gcov dmangle.c
	gcov mars.c
	gcov dmodule.c
	gcov msc.c
	gcov mtype.c
	gcov nspace.c
ifeq ($(D_OBJC),1)
	gcov objc.c
	gcov objc_glue.c
else
	gcov objc_glue_stubs.c
endif
	gcov opover.c
	gcov optimize.c
	gcov parse.c
	gcov dscope.c
	gcov safe.c
	gcov sideeffect.c
	gcov statement.c
	gcov staticassert.c
	gcov staticcond.c
	gcov s2ir.c
	gcov dstruct.c
	gcov dtemplate.c
	gcov tk.c
	gcov tocsym.c
	gcov todt.c
	gcov toobj.c
	gcov toctype.c
	gcov toelfdebug.c
	gcov typinf.c
	gcov utf.c
	gcov dversion.c
	gcov intrange.c
	gcov target.c

#	gcov hdrgen.c
#	gcov tocvdebug.c

######################################################

zip:
	-rm -f dmdsrc.zip
	zip dmdsrc $(SRC) $(ROOT_SRC) $(GLUE_SRC) $(BACK_SRC) $(TK_SRC)

#############################

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
