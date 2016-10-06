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

INSTALL_DIR=../../install
SYSCONFDIR=/etc
PGO_DIR=$(abspath pgo)

C=backend
TK=tk
ROOT=root

ifeq (osx,$(OS))
    export MACOSX_DEPLOYMENT_TARGET=10.7
endif

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
ifneq (,$(findstring g++,$(CXX_VERSION))$(findstring gcc,$(CXX_VERSION))$(findstring GCC,$(CXX_VERSION)))
	CXX_KIND=g++
endif
ifneq (,$(findstring clang,$(CXX_VERSION)))
	CXX_KIND=clang++
endif

HOST_DC?=
ifneq (,$(HOST_DC))
  $(warning ========== Use HOST_DMD instead of HOST_DC ========== )
  HOST_DMD=$(HOST_DC)
endif

# Host D compiler for bootstrapping
ifeq (,$(AUTO_BOOTSTRAP))
  # No bootstrap, a $(HOST_DC) installation must be available
  HOST_DMD?=dmd
  HOST_DMD_PATH=$(abspath $(shell which $(HOST_DMD)))
  ifeq (,$(HOST_DMD_PATH))
    $(error '$(HOST_DMD)' not found, get a D compiler or make AUTO_BOOTSTRAP=1)
  endif
  HOST_DMD_RUN:=$(HOST_DMD)
else
  # Auto-bootstrapping, will download dmd automatically
  # Keep var below in sync with other occurrences of that variable, e.g. in circleci.sh
  HOST_DMD_VER=2.068.2
  HOST_DMD_ROOT=/tmp/.host_dmd-$(HOST_DMD_VER)
  # dmd.2.068.2.osx.zip or dmd.2.068.2.linux.tar.xz
  HOST_DMD_BASENAME=dmd.$(HOST_DMD_VER).$(OS)$(if $(filter $(OS),freebsd),-$(MODEL),)
  # http://downloads.dlang.org/releases/2.x/2.068.2/dmd.2.068.2.linux.tar.xz
  HOST_DMD_URL=http://downloads.dlang.org/releases/2.x/$(HOST_DMD_VER)/$(HOST_DMD_BASENAME)
  HOST_DMD=$(HOST_DMD_ROOT)/dmd2/$(OS)/$(if $(filter $(OS),osx),bin,bin$(MODEL))/dmd
  HOST_DMD_PATH=$(HOST_DMD)
  HOST_DMD_RUN=$(HOST_DMD) -conf=$(dir $(HOST_DMD))dmd.conf
endif

# Compiler Warnings
ifdef ENABLE_WARNINGS
WARNINGS := -Wall -Wextra \
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
ifeq ($(CXX_KIND), g++)
WARNINGS += \
	-Wno-logical-op \
	-Wno-narrowing \
	-Wno-unused-but-set-variable \
	-Wno-uninitialized
endif
# Clang Specific
ifeq ($(HOST_CXX_KIND), clang++)
WARNINGS += \
	-Wno-tautological-constant-out-of-range-compare \
	-Wno-tautological-compare \
	-Wno-constant-logical-operand \
	-Wno-self-assign -Wno-self-assign
# -Wno-sometimes-uninitialized
endif
else
# Default Warnings
WARNINGS := -Wno-deprecated -Wstrict-aliasing
# Clang Specific
ifeq ($(CXX_KIND), clang++)
WARNINGS += \
    -Wno-logical-op-parentheses \
    -Wno-dynamic-class-memaccess \
    -Wno-switch
endif
endif

OS_UPCASE := $(shell echo $(OS) | tr '[a-z]' '[A-Z]')

MMD=-MMD -MF $(basename $@).deps

# Default compiler flags for all source files
CXXFLAGS := $(WARNINGS) \
	-fno-exceptions -fno-rtti \
	-D__pascal= -DMARS=1 -DTARGET_$(OS_UPCASE)=1 -DDM_TARGET_CPU_$(TARGET_CPU)=1 \
	$(MODEL_FLAG)
# GCC Specific
ifeq ($(CXX_KIND), g++)
CXXFLAGS += \
    -std=gnu++98
endif
# Default D compiler flags for all source files
DFLAGS= -version=MARS
# Enable D warnings
DFLAGS += -wi

ifneq (,$(DEBUG))
ENABLE_DEBUG := 1
endif
ifneq (,$(RELEASE))
ENABLE_RELEASE := 1
endif

# Append different flags for debugging, profiling and release.
ifdef ENABLE_DEBUG
CXXFLAGS += -g -g3 -DDEBUG=1 -DUNITTEST
DFLAGS += -g -debug -unittest
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
DFLAGS  += -cov
endif

# Uniqe extra flags if necessary
DMD_FLAGS  := -I$(ROOT) -Wuninitialized
GLUE_FLAGS := -I$(ROOT) -I$(TK) -I$(C)
BACK_FLAGS := -I$(ROOT) -I$(TK) -I$(C) -I. -DDMDV2=1
ROOT_FLAGS := -I$(ROOT)

ifeq ($(OS), osx)
ifeq ($(MODEL), 64)
D_OBJC := 1
endif
endif


FRONT_SRCS=$(addsuffix .d,access aggregate aliasthis apply argtypes arrayop	\
	arraytypes attrib builtin canthrow clone complex cond constfold		\
	cppmangle ctfeexpr dcast dclass declaration delegatize denum dimport	\
	dinifile dinterpret dmacro dmangle dmodule doc dscope dstruct dsymbol	\
	dtemplate dversion entity errors escape expression func			\
	globals hdrgen id identifier impcnvtab imphint init inline intrange	\
	json lexer lib link mars mtype nogc nspace opover optimize parse sapply	\
	sideeffect statement staticassert target tokens traits utf visitor	\
	typinf utils statementsem safe)

ifeq ($(D_OBJC),1)
	FRONT_SRCS += objc.d
else
	FRONT_SRCS += objc_stubs.d
endif

ROOT_SRCS = $(addsuffix .d,$(addprefix $(ROOT)/,aav array ctfloat file \
	filename man outbuffer port response rmem rootobject speller \
	stringtable))

GLUE_OBJS = s2ir.o e2ir.o toobj.o \
	iasm.o


ifeq ($(D_OBJC),1)
	GLUE_OBJS += objc_glue.o
else
	GLUE_OBJS += objc_glue_stubs.o
endif

ifeq (osx,$(OS))
    FRONT_SRCS += libmach.d scanmach.d
else
    FRONT_SRCS += libelf.d scanelf.d
endif

GLUE_SRCS=$(addsuffix .d, irstate toelfdebug toctype glue gluelayer todt tocsym toir dmsc tocvdebug)

DMD_SRCS=$(FRONT_SRCS) $(GLUE_SRCS) $(BACK_HDRS) $(TK_HDRS)

BACK_OBJS = go.o gdag.o gother.o gflow.o gloop.o gsroa.o var.o el.o \
	glocal.o os.o nteh.o evalu8.o cgcs.o \
	rtlsym.o cgelem.o cgen.o cgreg.o out.o \
	blockopt.o cg.o type.o dt.o \
	debug.o code.o ee.o symbol.o \
	cgcod.o cod5.o outbuf.o compress.o \
	bcomplex.o aa.o ti_achar.o \
	ti_pvoid.o pdata.o cv8.o backconfig.o \
	divcoeff.o dwarf.o dwarfeh.o varstats.o \
	ph2.o util2.o eh.o tk.o strtold.o \
	$(TARGET_OBJS)

ifeq (osx,$(OS))
	BACK_OBJS += machobj.o
else
	BACK_OBJS += elfobj.o
endif

SRC = win32.mak posix.mak osmodel.mak aggregate.h aliasthis.h arraytypes.h	\
	attrib.h complex_t.h cond.h ctfe.h ctfe.h declaration.h dsymbol.h	\
	enum.h errors.h expression.h globals.h hdrgen.h identifier.h idgen.d	\
	import.h init.h intrange.h json.h lexer.h \
	mars.h module.h mtype.h nspace.h objc.h                         \
	scope.h statement.h staticassert.h target.h template.h tokens.h	\
	version.h visitor.h libomf.d scanomf.d libmscoff.d scanmscoff.d         \
	$(DMD_SRCS)

ROOT_SRC = $(addprefix $(ROOT)/, array.h ctfloat.h file.h filename.h \
	longdouble.h newdelete.c object.h outbuffer.h port.h \
	rmem.h root.h stringtable.h)

GLUE_SRC = s2ir.c e2ir.c \
	toobj.c toir.h \
	irstate.h iasm.c \
	toelfdebug.d libelf.d scanelf.d libmach.d scanmach.d \
	tk.c eh.c gluestub.d objc_glue.c objc_glue_stubs.c

BACK_HDRS=$C/bcomplex.d $C/cc.d $C/cdef.d $C/cgcv.d $C/code.d $C/cv4.d $C/dt.d $C/el.d $C/global.d \
	$C/obj.d $C/oper.d $C/outbuf.d $C/rtlsym.d \
	$C/ty.d $C/type.d

TK_HDRS= $(TK)/dlist.d

BACK_SRC = \
	$C/cdef.h $C/cc.h $C/oper.h $C/ty.h $C/optabgen.c \
	$C/global.h $C/code.h $C/type.h $C/dt.h $C/cgcv.h \
	$C/el.h $C/iasm.h $C/rtlsym.h \
	$C/bcomplex.c $C/blockopt.c $C/cg.c $C/cg87.c $C/cgxmm.c \
	$C/cgcod.c $C/cgcs.c $C/cgcv.c $C/cgelem.c $C/cgen.c $C/cgobj.c \
	$C/compress.c $C/cgreg.c $C/var.c $C/strtold.c \
	$C/cgsched.c $C/cod1.c $C/cod2.c $C/cod3.c $C/cod4.c $C/cod5.c \
	$C/code.c $C/symbol.c $C/debug.c $C/dt.c $C/ee.c $C/el.c \
	$C/evalu8.c $C/go.c $C/gflow.c $C/gdag.c \
	$C/gother.c $C/glocal.c $C/gloop.c $C/gsroa.c $C/newman.c \
	$C/nteh.c $C/os.c $C/out.c $C/outbuf.c $C/ptrntab.c $C/rtlsym.c \
	$C/type.c $C/melf.h $C/mach.h $C/mscoff.h $C/bcomplex.h \
	$C/outbuf.h $C/token.h $C/tassert.h \
	$C/elfobj.c $C/cv4.h $C/dwarf2.h $C/exh.h $C/go.h \
	$C/dwarf.c $C/dwarf.h $C/aa.h $C/aa.c $C/tinfo.h $C/ti_achar.c \
	$C/ti_pvoid.c $C/platform_stub.c $C/code_x86.h $C/code_stub.h \
	$C/machobj.c $C/mscoffobj.c \
	$C/xmm.h $C/obj.h $C/pdata.c $C/cv8.c $C/backconfig.c $C/divcoeff.c \
	$C/varstats.c $C/varstats.h \
	$C/md5.c $C/md5.h \
	$C/ph2.c $C/util2.c $C/dwarfeh.c \
	$(TARGET_CH)

TK_SRC = \
	$(TK)/filespec.h $(TK)/mem.h $(TK)/list.h $(TK)/vec.h \
	$(TK)/filespec.c $(TK)/mem.c $(TK)/vec.c $(TK)/list.c

STRING_IMPORT_FILES = verstr.h SYSCONFDIR.imp ../res/default_ddoc_theme.ddoc

DEPS = $(patsubst %.o,%.deps,$(DMD_OBJS) $(GLUE_OBJS) $(BACK_OBJS))

all: dmd

auto-tester-build: dmd checkwhitespace dmd_frontend
.PHONY: auto-tester-build

glue.a: $(GLUE_OBJS)
	$(AR) rcs glue.a $(GLUE_OBJS)

backend.a: $(BACK_OBJS)
	$(AR) rcs backend.a $(BACK_OBJS)

dmd_frontend: $(FRONT_SRCS) gluelayer.d $(ROOT_SRCS) newdelete.o $(STRING_IMPORT_FILES) $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -of$@ $(MODEL_FLAG) -vtls -J. -J../res -L-lstdc++ $(DFLAGS) $(filter-out $(STRING_IMPORT_FILES) $(HOST_DMD_PATH),$^) -version=NoBackend

ifdef ENABLE_LTO
dmd: $(DMD_SRCS) $(ROOT_SRCS) newdelete.o $(GLUE_OBJS) $(BACK_OBJS) $(STRING_IMPORT_FILES) $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -of$@ $(MODEL_FLAG) -vtls -J. -J../res -L-lstdc++ $(DFLAGS) $(filter-out $(STRING_IMPORT_FILES) $(HOST_DMD_PATH),$^)
else
dmd: $(DMD_SRCS) $(ROOT_SRCS) newdelete.o glue.a backend.a $(STRING_IMPORT_FILES) $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -of$@ $(MODEL_FLAG) -vtls -J. -J../res -L-lstdc++ $(DFLAGS) $(filter-out $(STRING_IMPORT_FILES) $(HOST_DMD_PATH),$^)
endif

clean:
	rm -f newdelete.o $(GLUE_OBJS) $(BACK_OBJS) dmd optab.o id.o	\
		idgen $(idgen_output) optabgen $(optabgen_output)	\
		verstr.h SYSCONFDIR.imp core *.cov *.deps *.gcda *.gcno *.a *.lst
	@[ ! -d ${PGO_DIR} ] || echo You should issue manually: rm -rf ${PGO_DIR}

######## Download and install the last dmd buildable without dmd

ifneq (,$(AUTO_BOOTSTRAP))
$(HOST_DMD_PATH):
	mkdir -p ${HOST_DMD_ROOT}
ifneq (,$(shell which xz 2>/dev/null))
	curl -fsSL ${HOST_DMD_URL}.tar.xz | tar -C ${HOST_DMD_ROOT} -Jxf - || rm -rf ${HOST_DMD_ROOT}
else
	TMPFILE=$$(mktemp deleteme.XXXXXXXX) &&	curl -fsSL ${HOST_DMD_URL}.zip > $${TMPFILE}.zip && \
		unzip -qd ${HOST_DMD_ROOT} $${TMPFILE}.zip && rm $${TMPFILE}.zip;
endif
endif

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

optabgen: $C/optabgen.c $C/cc.h $C/oper.h
	$(HOST_CXX) $(CXXFLAGS) -I$(TK) $< -o optabgen
	./optabgen

optabgen_output = debtab.c optab.c cdxxx.c elxxx.c fltables.c tytab.c
$(optabgen_output) : optabgen

######## idgen generates some source

idgen_output = id.h id.d
$(idgen_output) : idgen

idgen: idgen.d $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) $<
	./idgen

#########
# STRING_IMPORT_FILES
#
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
$(shell test $(SYSCONFDIR) != "`cat SYSCONFDIR.imp 2> /dev/null`" \
		&& printf '$(SYSCONFDIR)' > SYSCONFDIR.imp )

#########

$(GLUE_OBJS) : $(idgen_output)
$(BACK_OBJS) : $(optabgen_output)


# Specific dependencies other than the source file for all objects
########################################################################
# If additional flags are needed for a specific file add a _CXXFLAGS as a
# dependency to the object file and assign the appropriate content.

cg.o: fltables.c

cgcod.o: cdxxx.c

cgelem.o: elxxx.c

debug.o: debtab.c

iasm.o: CXXFLAGS += -fexceptions

var.o: optab.c tytab.c


# Generic rules for all source files
########################################################################
# Search the directory $(C) for .c-files when using implicit pattern
# matching below.
vpath %.c $(C)

$(BACK_OBJS): %.o: %.c posix.mak
	@echo "  (CC)  BACK_OBJS  $<"
	$(CXX) -c $(CXXFLAGS) $(BACK_FLAGS) $(MMD) $<

$(GLUE_OBJS): %.o: %.c posix.mak
	@echo "  (CC)  GLUE_OBJS  $<"
	$(CXX) -c $(CXXFLAGS) $(GLUE_FLAGS) $(MMD) $<

newdelete.o: %.o: $(ROOT)/%.c posix.mak
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

checkwhitespace: $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -run checkwhitespace $(SRC) $(GLUE_SRC) $(ROOT_SRCS)

######################################################

gcov:
	gcov $(filter %.c,$(SRC) $(GLUE_SRC))

######################################################

zip:
	-rm -f dmdsrc.zip
	zip dmdsrc $(SRC) $(ROOT_SRCS) $(GLUE_SRC) $(BACK_SRC) $(TK_SRC)

######################################################

../changelog.html: ../changelog.dd $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -Df$@ $<

#############################

ifneq ($(DOCDIR),)
html: $(DOCDIR)/.generated
$(DOCDIR)/.generated: $(DMD_SRCS) $(ROOT_SRCS) $(HOST_DMD_PATH) project.ddoc
	$(HOST_DMD_RUN) -of- $(MODEL_FLAG) -J. -J../res -c -Dd$(DOCDIR)\
	  $(DFLAGS) project.ddoc $(DOCFMT) $(DMD_SRCS) $(ROOT_SRCS)
	touch $@
endif

######################################################

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
