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

# Default to a release built, override with BUILD=debug
ifeq (,$(BUILD))
BUILD=release
endif

ifneq ($(BUILD),release)
    ifneq ($(BUILD),debug)
        $(error Unrecognized BUILD=$(BUILD), must be 'debug' or 'release')
    endif
endif

GIT_HOME=https://github.com/dlang
TOOLS_DIR=../../tools

INSTALL_DIR=../../install
SYSCONFDIR=/etc
TMP?=/tmp
PGO_DIR=$(abspath pgo)

D = ddmd

C=$D/backend
TK=$D/tk
ROOT=$D/root
EX=examples

GENERATED = ../generated
G = $(GENERATED)/$(OS)/$(BUILD)/$(MODEL)
$(shell mkdir -p $G)

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
  HOST_DMD_VER=2.072.2
  HOST_DMD_ROOT=$(TMP)/.host_dmd-$(HOST_DMD_VER)
  # dmd.2.072.2.osx.zip or dmd.2.072.2.linux.tar.xz
  HOST_DMD_BASENAME=dmd.$(HOST_DMD_VER).$(OS)$(if $(filter $(OS),freebsd),-$(MODEL),)
  # http://downloads.dlang.org/releases/2.x/2.072.2/dmd.2.072.2.linux.tar.xz
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
DFLAGS= -version=MARS -g
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

# Unique extra flags if necessary
DMD_FLAGS  := -I$(ROOT) -Wuninitialized
GLUE_FLAGS := -I$(ROOT) -I$(TK) -I$(C)
BACK_FLAGS := -I$(ROOT) -I$(TK) -I$(C) -I$G -I$D -DDMDV2=1
ROOT_FLAGS := -I$(ROOT)

ifeq ($(OS), osx)
ifeq ($(MODEL), 64)
D_OBJC := 1
endif
endif


FRONT_SRCS=$(addsuffix .d, $(addprefix $D/,access aggregate aliasthis apply argtypes arrayop	\
	arraytypes astcodegen attrib builtin canthrow clone complex cond constfold		\
	cppmangle ctfeexpr dcast dclass declaration delegatize denum dimport	\
	dinifile dinterpret dmacro dmangle dmodule doc dscope dstruct dsymbol	\
	dtemplate dversion escape expression expressionsem func			\
	hdrgen id impcnvtab imphint init initsem inline inlinecost intrange	\
	json lib link mars mtype nogc nspace objc opover optimize parse sapply	\
	sideeffect statement staticassert target typesem traits visitor	\
	typinf utils statement_rewrite_walker statementsem staticcond safe blockexit asttypename printast))

CTFE_SRCS=$(addsuffix .d, $(addprefix $D/ctfe/,bc bc_common bc_c_backend	\
	bc_limits bc_llvm_backend bc_macro bc_printer_backend bc_gccjit_backend	\
	bc_test ctfe_bc))

LEXER_SRCS=$(addsuffix .d, $(addprefix $D/, console entity errors globals id identifier lexer tokens utf))

LEXER_ROOT=$(addsuffix .d, $(addprefix $(ROOT)/, array ctfloat file filename outbuffer port rmem \
	rootobject stringtable hash))

ROOT_SRCS = $(addsuffix .d,$(addprefix $(ROOT)/,aav array ctfloat file \
	filename man outbuffer port response rmem rootobject speller \
	stringtable hash))

PARSER_SRCS=$(addsuffix .d, $(addprefix $D/,parse astbase astbasevisitor transitivevisitor permissivevisitor strictvisitor))

GLUE_OBJS =

ifeq (osx,$(OS))
    FRONT_SRCS += $D/libmach.d $D/scanmach.d
else
    FRONT_SRCS += $D/libelf.d $D/scanelf.d
endif

GLUE_OBJS = 

G_GLUE_OBJS = $(addprefix $G/, $(GLUE_OBJS))

GLUE_SRCS=$(addsuffix .d, $(addprefix $D/,irstate toctype glue gluelayer todt tocsym toir dmsc \
	tocvdebug s2ir toobj e2ir eh iasm))

ifeq ($(D_OBJC),1)
	GLUE_SRCS += $D/objc_glue.d
else
	GLUE_SRCS += $D/objc_glue_stubs.d
endif

DMD_SRCS=$(FRONT_SRCS) $(CTFE_SRCS) $(GLUE_SRCS) $(BACK_HDRS) $(TK_HDRS)

BACK_OBJS = go.o gdag.o gother.o gflow.o gloop.o gsroa.o var.o el.o \
	glocal.o os.o nteh.o evalu8.o cgcs.o \
	rtlsym.o cgelem.o cgen.o cgreg.o out.o \
	blockopt.o cg.o type.o dt.o \
	debug.o code.o ee.o symbol.o \
	cgcod.o cod5.o outbuf.o compress.o \
	bcomplex.o aa.o ti_achar.o \
	ti_pvoid.o pdata.o cv8.o backconfig.o \
	divcoeff.o dwarf.o dwarfeh.o varstats.o \
	ph2.o util2.o tk.o strtold.o md5.o \
	$(TARGET_OBJS)

G_OBJS = $(addprefix $G/, $(BACK_OBJS))
#$(info $$G_OBJS is [${G_OBJS}])

ifeq (osx,$(OS))
	BACK_OBJS += machobj.o
else
	BACK_OBJS += elfobj.o
endif

SRC = $(addprefix $D/, win32.mak posix.mak osmodel.mak aggregate.h aliasthis.h arraytypes.h	\
	attrib.h complex_t.h cond.h ctfe.h ctfe.h declaration.h dsymbol.h	\
	enum.h errors.h expression.h globals.h hdrgen.h identifier.h \
	import.h init.h intrange.h json.h lexer.h \
	mars.h module.h mtype.h nspace.h objc.h                         \
	scope.h statement.h staticassert.h target.h template.h tokens.h	\
	version.h visitor.h libomf.d scanomf.d libmscoff.d scanmscoff.d)         \
	$(DMD_SRCS)

ROOT_SRC = $(addprefix $(ROOT)/, array.h ctfloat.h file.h filename.h \
	longdouble.h newdelete.c object.h outbuffer.h port.h \
	rmem.h root.h stringtable.h)

GLUE_SRC = \
	$(addprefix $D/, \
	toelfdebug.d libelf.d scanelf.d libmach.d scanmach.d \
	tk.c gluestub.d objc_glue.d)

BACK_HDRS=$C/bcomplex.d $C/cc.d $C/cdef.d $C/cgcv.d $C/code.d $C/cv4.d $C/dt.d $C/el.d $C/global.d \
	$C/obj.d $C/oper.d $C/outbuf.d $C/rtlsym.d $C/code_x86.d $C/iasm.d \
	$C/ty.d $C/type.d $C/exh.d $C/mach.d $C/md5.d $C/mscoff.d $C/dwarf.d $C/dwarf2.d $C/xmm.d

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

STRING_IMPORT_FILES = $G/VERSION $G/SYSCONFDIR.imp ../res/default_ddoc_theme.ddoc

DEPS = $(patsubst %.o,%.deps,$(DMD_OBJS) $(GLUE_OBJS) $(BACK_OBJS))

all: dmd

auto-tester-build: dmd checkwhitespace $G/dmd_frontend
.PHONY: auto-tester-build

toolchain-info:
	@echo '==== Toolchain Information ===='
	@echo 'uname -a:' $$(uname -a)
	@echo 'MAKE(${MAKE}):' $$(${MAKE} --version)
	@echo 'SHELL(${SHELL}):' $$(${SHELL} --version || true)
	@echo 'HOST_DMD(${HOST_DMD}):' $$(${HOST_DMD} --version)
	@echo 'HOST_CXX(${HOST_CXX}):' $$(${HOST_CXX} --version)
# Not currently possible to choose what linker HOST_CXX uses via `make LD=ld.gold`.
	@echo ld: $$(ld -v)
	@echo gdb: $$(! command -v gdb &>/dev/null || gdb --version)
	@echo '==== Toolchain Information ===='
	@echo

$G/glue.a: $(G_GLUE_OBJS)
	$(AR) rcs $@ $(G_GLUE_OBJS)

$G/backend.a: $(G_OBJS)
	$(AR) rcs $@ $(G_OBJS)

$G/lexer.a: $(LEXER_SRCS) $(LEXER_ROOT) $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -lib -of$@ $(MODEL_FLAG) -J$G -L-lstdc++ $(DFLAGS) $(LEXER_SRCS) $(LEXER_ROOT)

$G/parser.a: $(PARSER_SRCS) $G/lexer.a $(ROOT_SRCS) $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -lib -of$@ $(MODEL_FLAG) -L-lstdc++ $(DFLAGS) $(PARSER_SRCS) $G/lexer.a $(ROOT_SRCS)

parser_test: $G/parser.a $(EX)/test_parser.d $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -of$@ $(MODEL_FLAG) -L-lstdc++ $(DFLAGS) $G/parser.a $(EX)/test_parser.d $(EX)/impvisitor.d

example_avg: $G/parser.a $(EX)/avg.d $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -of$@ $(MODEL_FLAG) -L-lstdc++ $(DFLAGS) $G/parser.a $(EX)/avg.d

$G/dmd_frontend: $(FRONT_SRCS) $(CTFE_SRCS) $D/gluelayer.d $(ROOT_SRCS) $G/newdelete.o $G/lexer.a $(STRING_IMPORT_FILES) $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -of$@ $(MODEL_FLAG) -vtls -J$G -J../res -L-lstdc++ $(DFLAGS) $(filter-out $(STRING_IMPORT_FILES) $(HOST_DMD_PATH),$^) -version=NoBackend

dmd: $G/dmd $G/dmd.conf
	cp $< .

ifdef ENABLE_LTO
$G/dmd: $(DMD_SRCS) $(ROOT_SRCS) $G/newdelete.o $G/lexer.a $(G_GLUE_OBJS) $(G_OBJS) $(STRING_IMPORT_FILES) $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -of$@ $(MODEL_FLAG) -vtls -J$G -J../res -L-lstdc++ $(DFLAGS) $(filter-out $(STRING_IMPORT_FILES) $(HOST_DMD_PATH),$^)
else
$G/dmd: $(DMD_SRCS) $(ROOT_SRCS) $G/newdelete.o $G/backend.a $G/lexer.a $(STRING_IMPORT_FILES) $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -of$@ $(MODEL_FLAG) -vtls -J$G -J../res -L-lstdc++ $(DFLAGS) $(filter-out $(STRING_IMPORT_FILES) $(HOST_DMD_PATH) $(LEXER_ROOT),$^)
endif


clean:
	rm -R $(GENERATED)
	rm -f parser_test parser_test.o example_avg example_avg.o
	rm -f dmd
	rm -f $(addprefix $D/backend/, $(optabgen_output))
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
DFLAGS=-I%@P%/../../../../../druntime/import -I%@P%/../../../../../phobos -L-L%@P%/../../../../../phobos/generated/$(OS)/release/32$(if $(filter $(OS),osx),, -L--export-dynamic)

[Environment64]
DFLAGS=-I%@P%/../../../../../druntime/import -I%@P%/../../../../../phobos -L-L%@P%/../../../../../phobos/generated/$(OS)/release/64$(if $(filter $(OS),osx),, -L--export-dynamic)
endef

export DEFAULT_DMD_CONF

$G/dmd.conf:
	[ -f $@ ] || echo "$$DEFAULT_DMD_CONF" > $@

######## generate a default dmd.conf (for compatibility)
######## REMOVE ME after the ddmd -> dmd transition

define DEFAULT_DMD_CONF_LEGACY
[Environment32]
DFLAGS=-I%@P%/../../druntime/import -I%@P%/../../phobos -L-L%@P%/../../phobos/generated/$(OS)/release/32$(if $(filter $(OS),osx),, -L--export-dynamic)

[Environment64]
DFLAGS=-I%@P%/../../druntime/import -I%@P%/../../phobos -L-L%@P%/../../phobos/generated/$(OS)/release/64$(if $(filter $(OS),osx),, -L--export-dynamic)
endef

export DEFAULT_DMD_CONF_LEGACY

dmd.conf:
	[ -f $@ ] || echo "$$DEFAULT_DMD_CONF_LEGACY" > $@

######## optabgen generates some source
optabgen_output = debtab.c optab.c cdxxx.c elxxx.c fltables.c tytab.c

$G/optabgen: $C/optabgen.c $C/cc.h $C/oper.h
	$(HOST_CXX) $(CXXFLAGS) -I$(TK) $< -o $G/optabgen
	$G/optabgen
	mv $(optabgen_output) $G

optabgen_files = $(addprefix $G/, $(optabgen_output))
$(optabgen_files): optabgen.out
.INTERMEDIATE: optabgen.out
optabgen.out : $G/optabgen

######## VERSION

$(shell ../config.sh "$G" ../VERSION $(SYSCONFDIR))

#########
# Specific dependencies other than the source file for all objects
########################################################################
# If additional flags are needed for a specific file add a _CXXFLAGS as a
# dependency to the object file and assign the appropriate content.

cg.o: $G/fltables.c

cgcod.o: $G/cdxxx.c

cgelem.o: $G/elxxx.c

debug.o: $G/debtab.c

iasm.o: CXXFLAGS += -fexceptions

var.o: $G/optab.c $G/tytab.c


# Generic rules for all source files
########################################################################
# Search the directory $(C) for .c-files when using implicit pattern
# matching below.
#vpath %.c $(C)

-include $(DEPS)

$(G_OBJS): $G/%.o: $C/%.c posix.mak $(optabgen_files)
	@echo "  (CC)  BACK_OBJS  $<"
	$(CXX) -c -o$@ $(CXXFLAGS) $(BACK_FLAGS) $(MMD) $<

$(G_GLUE_OBJS): $G/%.o: $D/%.c posix.mak $(optabgen_files)
	@echo "  (CC)  GLUE_OBJS  $<"
	$(CXX) -c -o$@ $(CXXFLAGS) $(GLUE_FLAGS) $(MMD) $<

$G/newdelete.o: $G/%.o: $(ROOT)/%.c posix.mak
	@echo "  (CC)  ROOT_OBJS  $<"
	$(CXX) -c -o$@ $(CXXFLAGS) $(ROOT_FLAGS) $(MMD) $<

######################################################

install: all
	$(eval bin_dir=$(if $(filter $(OS),osx), bin, bin$(MODEL)))
	mkdir -p $(INSTALL_DIR)/$(OS)/$(bin_dir)
	cp dmd $(INSTALL_DIR)/$(OS)/$(bin_dir)/dmd
	cp ../ini/$(OS)/$(bin_dir)/dmd.conf $(INSTALL_DIR)/$(OS)/$(bin_dir)/dmd.conf
	cp $D/boostlicense.txt $(INSTALL_DIR)/dmd-boostlicense.txt

######################################################

checkwhitespace: $(HOST_DMD_PATH) $(TOOLS_DIR)/checkwhitespace.d
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -run $(TOOLS_DIR)/checkwhitespace.d $(SRC) $(GLUE_SRC) $(ROOT_SRCS)

$(TOOLS_DIR)/checkwhitespace.d:
	git clone --depth=1 ${GIT_HOME}/tools $(TOOLS_DIR)

######################################################

gcov:
	gcov $(filter %.c,$(SRC) $(GLUE_SRC))

######################################################

zip:
	-rm -f dmdsrc.zip
	zip dmdsrc $(SRC) $(ROOT_SRCS) $(GLUE_SRC) $(BACK_SRC) $(TK_SRC)

######################################################

gitzip:
	git archive --format=zip HEAD > $(ZIPFILE)

######################################################

../changelog.html: ../changelog.dd $(HOST_DMD_PATH)
	CC=$(HOST_CXX) $(HOST_DMD_RUN) -Df$@ $<

################################################################################
# DDoc documentation generation
################################################################################

# BEGIN fallbacks for old variable names
# should be removed after https://github.com/dlang/dlang.org/pull/1581
# has been pulled
DOCSRC=../dlang.org
STDDOC=$(DOCFMT)
DOC_OUTPUT_DIR=$(DOCDIR)
# END fallbacks

# DDoc html generation - this is very similar to the way the documentation for
# Phobos is built
ifneq ($(DOCSRC),)

# list all files for which documentation should be generated
SRC_DOCUMENTABLES = $(ROOT_SRCS) $(DMD_SRCS)

D2HTML=$(foreach p,$1,$(if $(subst package.d,,$(notdir $p)),$(subst /,_,$(subst .d,.html,$p)),$(subst /,_,$(subst /package.d,.html,$p))))
HTMLS=$(addprefix $(DOC_OUTPUT_DIR)/, \
	$(call D2HTML, $(SRC_DOCUMENTABLES)))

# For each module, define a rule e.g.:
# ../web/phobos/ddmd_mars.html : ddmd/mars.d $(STDDOC) ; ...
$(foreach p,$(SRC_DOCUMENTABLES),$(eval \
$(DOC_OUTPUT_DIR)/$(call D2HTML,$p) : $p $(STDDOC) $(HOST_DMD_PATH) ;\
  $(HOST_DMD_RUN) -of- $(MODEL_FLAG) -J$G -J../res -c -Dd$(DOCSRC) -Iddmd\
  $(DFLAGS) project.ddoc $(STDDOC) -Df$$@ $$<))

$(DOC_OUTPUT_DIR) :
	mkdir -p $@

html: $(HTMLS) project.ddoc $D/id.d | $(DOC_OUTPUT_DIR)
endif

######################################################

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
