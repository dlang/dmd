OS:=
uname_S:=$(shell uname -s)
ifeq (Darwin,$(uname_S))
        OS:=OSX
endif
ifeq (Linux,$(uname_S))
	OS:=LINUX
endif
ifeq (FreeBSD,$(uname_S))
	OS:=FREEBSD
endif
ifeq (OpenBSD,$(uname_S))
	OS:=OPENBSD
endif
ifeq (Solaris,$(uname_S))
	OS:=SOLARIS
endif
ifeq (SunOS,$(uname_S))
	OS:=SOLARIS
endif
ifeq (,$(OS))
	$(error Unrecognized or unsupported OS for uname: $(uname_S))
endif

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

GENERATED_ROOT=../generated
GENERATED_DIR=$(GENERATED_ROOT)/$(OS)$(MODEL)
INSTALL_DIR=../../install/$(OS)$(MODEL)

C=backend
TK=tk
ROOT=root

# Use make MODEL=32 or MODEL=64 to force the architecture
ifeq ($(MODEL),)
	uname_M:=$(shell uname -m)
	ifeq ($(uname_M),x86_64)
	MODEL=64
	else
		ifeq ($(uname_M),i686)
			MODEL:=32
		else
            $(error Unrecognized model $(uname_M), please define MODEL=32 or MODEL=64)
		endif
	endif
endif
MODEL_FLAG:=-m$(MODEL)

ifeq (OSX,$(OS))
    export MACOSX_DEPLOYMENT_TARGET=10.3
endif
LDFLAGS=-lm -lstdc++ -lpthread

HOST_CC=g++
CC=$(HOST_CC) $(MODEL_FLAG)
GIT=git

#COV=-fprofile-arcs -ftest-coverage

WARNINGS=-Wno-deprecated -Wstrict-aliasing

ifneq (,$(DEBUG))
	GFLAGS:=$(WARNINGS) -D__pascal= -fno-exceptions -g -g3 -DDEBUG=1 -DUNITTEST $(COV)
else
	GFLAGS:=$(WARNINGS) -D__pascal= -fno-exceptions -O2
endif

CFLAGS = $(GFLAGS) -I$(ROOT) -I$(GENERATED_ROOT) -DMARS=1 -DTARGET_$(OS)=1 -DDM_TARGET_CPU_$(TARGET_CPU)=1
MFLAGS = $(GFLAGS) -I$C -I$(TK) -I$(ROOT) -I$(GENERATED_ROOT) -DMARS=1 -DTARGET_$(OS)=1 -DDM_TARGET_CPU_$(TARGET_CPU)=1

CH= $C/cc.h $C/global.h $C/oper.h $C/code.h $C/type.h \
	$C/dt.h $C/cgcv.h $C/el.h $C/obj.h $(TARGET_CH)

DMD_OBJS = $(addprefix $(GENERATED_DIR)/,\
	access.o attrib.o bcomplex.o blockopt.o \
	cast.o code.o cg.o cgcod.o cgcs.o cgelem.o cgen.o \
	cgreg.o class.o cod5.o \
	constfold.o irstate.o cond.o debug.o \
	declaration.o dsymbol.o dt.o dump.o e2ir.o ee.o eh.o el.o \
	dwarf.o enum.o evalu8.o expression.o func.o gdag.o gflow.o \
	glocal.o gloop.o glue.o go.o gother.o iasm.o id.o \
	identifier.o impcnvtab.o import.o inifile.o init.o inline.o \
	lexer.o link.o mangle.o mars.o rmem.o module.o msc.o mtype.o \
	nteh.o cppmangle.o opover.o optimize.o os.o out.o outbuf.o \
	parse.o ph2.o root.o rtlsym.o s2ir.o scope.o statement.o \
	stringtable.o struct.o csymbol.o template.o tk.o tocsym.o todt.o \
	type.o typinf.o util2.o var.o version.o strtold.o utf.o staticassert.o \
	toobj.o toctype.o toelfdebug.o entity.o doc.o macro.o \
	hdrgen.o delegatize.o aa.o ti_achar.o toir.o interpret.o traits.o \
	builtin.o ctfeexpr.o clone.o aliasthis.o \
	man.o arrayop.o port.o response.o async.o json.o speller.o aav.o unittests.o \
	imphint.o argtypes.o ti_pvoid.o apply.o sapply.o sideeffect.o \
	intrange.o canthrow.o target.o \
	pdata.o cv8.o backconfig.o divcoeff.o \
	$(TARGET_OBJS))

ifeq (OSX,$(OS))
    DMD_OBJS += $(addprefix $(GENERATED_DIR)/,libmach.o scanmach.o machobj.o)
else
    DMD_OBJS += $(addprefix $(GENERATED_DIR)/,libelf.o scanelf.o elfobj.o)
endif

all: $(GENERATED_DIR)/dmd

$(GENERATED_DIR)/dmd: $(DMD_OBJS) $(GENERATED_DIR)/.directory
	$(HOST_CC) -o $(GENERATED_DIR)/dmd $(MODEL_FLAG) $(COV) $(DMD_OBJS) $(LDFLAGS)

%/.directory :
	mkdir -p $*
	touch $@

clean:
	rm -rf $(GENERATED_ROOT)
	rm -f verstr.h core *.cov *.gcda *.gcno

######## optabgen generates some source

$(GENERATED_DIR)/optabgen: $C/optabgen.c $C/cc.h $C/oper.h $(GENERATED_DIR)/.directory
	$(CC) $(MFLAGS) $< -o $@
	cd $(GENERATED_ROOT) && $@

optabgen_output = $(addprefix $(GENERATED_ROOT)/,debtab.c optab.c cdxxx.c elxxx.c fltables.c tytab.c)
$(optabgen_output) : $(GENERATED_DIR)/optabgen $(GENERATED_DIR)/.directory

######## q generates some source

idgen_output = $(addprefix $(GENERATED_ROOT)/,id.h id.c)
$(idgen_output) : $(GENERATED_DIR)/idgen $(GENERATED_DIR)/.directory

$(GENERATED_DIR)/idgen : idgen.c $(GENERATED_DIR)/.directory
	$(CC) idgen.c -o $@
	cd $(GENERATED_ROOT) && $@

######### impcnvgen generates some source

impcnvtab_output =  $(GENERATED_ROOT)/impcnvtab.c
$(impcnvtab_output) : $(GENERATED_DIR)/impcnvgen

$(GENERATED_DIR)/impcnvgen : mtype.h impcnvgen.c $(GENERATED_DIR)/.directory
	$(CC) $(CFLAGS) impcnvgen.c -o $@
	cd $(GENERATED_ROOT) && $@

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

$(DMD_OBJS) : $(idgen_output) $(optabgen_output) $(impcnvgen_output)

$(GENERATED_DIR)/aa.o: $C/aa.c $C/aa.h $C/tinfo.h 
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/aav.o: $(ROOT)/aav.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/access.o: access.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/aliasthis.o: aliasthis.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/apply.o: apply.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/argtypes.o: argtypes.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/arrayop.o: arrayop.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/async.o: $(ROOT)/async.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/attrib.o: attrib.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/backconfig.o: $C/backconfig.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/bcomplex.o: $C/bcomplex.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/blockopt.o: $C/blockopt.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/builtin.o: builtin.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/canthrow.o: canthrow.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/cast.o: cast.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/cg.o: $C/cg.c $(GENERATED_ROOT)/fltables.c
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/cg87.o: $C/cg87.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cgcod.o: $C/cgcod.c $(GENERATED_ROOT)/cdxxx.c
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/cgcs.o: $C/cgcs.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cgcv.o: $C/cgcv.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cgelem.o: $C/cgelem.c $C/rtlsym.h $(GENERATED_ROOT)/elxxx.c
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/cgen.o: $C/cgen.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cgobj.o: $C/cgobj.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cgreg.o: $C/cgreg.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cgsched.o: $C/cgsched.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cgxmm.o: $C/cgxmm.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/class.o: class.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/clone.o: clone.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/cod1.o: $C/cod1.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cod2.o: $C/cod2.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cod3.o: $C/cod3.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cod4.o: $C/cod4.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/cod5.o: $C/cod5.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/code.o: $C/code.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/constfold.o: constfold.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/ctfeexpr.o: ctfeexpr.c ctfe.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/irstate.o: irstate.c irstate.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/csymbol.o: $C/symbol.c
	$(CC) -c $(MFLAGS) $< -o $@

$(GENERATED_DIR)/cond.o: cond.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/cppmangle.o: cppmangle.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/cv8.o: $C/cv8.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/debug.o: $C/debug.c $(GENERATED_ROOT)/debtab.c
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/declaration.o: declaration.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/delegatize.o: delegatize.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/divcoeff.o: $C/divcoeff.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/doc.o: doc.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/dsymbol.o: dsymbol.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/dt.o: $C/dt.c $C/dt.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/dump.o: dump.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/dwarf.o: $C/dwarf.c $C/dwarf.h
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/e2ir.o: e2ir.c $C/rtlsym.h expression.h toir.h $(GENERATED_ROOT)/id.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/ee.o: $C/ee.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/eh.o: eh.c $C/cc.h $C/code.h $C/type.h $C/dt.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/el.o: $C/el.c $C/rtlsym.h $C/el.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/elfobj.o: $C/elfobj.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/entity.o: entity.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/enum.o: enum.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/evalu8.o: $C/evalu8.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/expression.o: expression.c expression.h $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/func.o: func.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/gdag.o: $C/gdag.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/gflow.o: $C/gflow.c
	$(CC) -c $(MFLAGS) $< -o$@

#globals.o: globals.c
#	$(CC) -c $(CFLAGS) $<

$(GENERATED_DIR)/glocal.o: $C/glocal.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/gloop.o: $C/gloop.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/glue.o: glue.c $(CH) $C/rtlsym.h mars.h module.h $(GENERATED_ROOT)/id.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/go.o: $C/go.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/gother.o: $C/gother.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/hdrgen.o: hdrgen.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/iasm.o: iasm.c $(CH) $C/iasm.h $(GENERATED_ROOT)/id.h
	$(CC) -c $(MFLAGS) -I$(ROOT) -fexceptions $< -o$@

$(GENERATED_DIR)/id.o: $(GENERATED_ROOT)/id.c $(GENERATED_ROOT)/id.h identifier.h lexer.h
	$(CC) -c $(CFLAGS) -I. $< -o$@

$(GENERATED_DIR)/identifier.o: identifier.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/impcnvtab.o:  $(GENERATED_ROOT)/impcnvtab.c mtype.h
	$(CC) -c $(CFLAGS) -I$(ROOT) -I. $< -o$@

$(GENERATED_DIR)/imphint.o: imphint.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/import.o: import.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/inifile.o: inifile.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/init.o: init.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/inline.o: inline.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) -I $(GENERATED_ROOT) $< -o$@

$(GENERATED_DIR)/interpret.o: interpret.c ctfe.h $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/intrange.o: intrange.h intrange.c
	$(CC) -c $(CFLAGS) intrange.c -o$@

$(GENERATED_DIR)/json.o: json.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/lexer.o: lexer.c  $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) -I $(GENERATED_ROOT) $< -o$@

$(GENERATED_DIR)/libelf.o: libelf.c $C/melf.h
	$(CC) -c $(CFLAGS) -I$C $< -o$@

$(GENERATED_DIR)/libmach.o: libmach.c $C/mach.h
	$(CC) -c $(CFLAGS) -I$C $< -o$@

$(GENERATED_DIR)/libmscoff.o: libmscoff.c $C/mscoff.h
	$(CC) -c $(CFLAGS) -I$C $< -o$@

$(GENERATED_DIR)/link.o: link.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/machobj.o: $C/machobj.c
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/macro.o: macro.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/man.o: $(ROOT)/man.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/mangle.o: mangle.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) -I $(GENERATED_ROOT) $< -o$@

$(GENERATED_DIR)/mars.o: mars.c verstr.h $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) -I $(GENERATED_ROOT) $< -o$@

$(GENERATED_DIR)/rmem.o: $(ROOT)/rmem.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/module.o: module.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) -I$C -I $(GENERATED_ROOT) $< -o$@

$(GENERATED_DIR)/mscoffobj.o: $C/mscoffobj.c $C/mscoff.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/msc.o: msc.c $(CH) mars.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/mtype.o: mtype.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) -I $(GENERATED_ROOT) $< -o$@

$(GENERATED_DIR)/nteh.o: $C/nteh.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/opover.o: opover.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/optimize.o: optimize.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/os.o: $C/os.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/out.o: $C/out.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/outbuf.o: $C/outbuf.c $C/outbuf.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/parse.o: parse.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/pdata.o: $C/pdata.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/ph2.o: $C/ph2.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/platform_stub.o: $C/platform_stub.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/port.o: $(ROOT)/port.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/ptrntab.o: $C/ptrntab.c $C/iasm.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/response.o: $(ROOT)/response.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/root.o: $(ROOT)/root.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/rtlsym.o: $C/rtlsym.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/sapply.o: sapply.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/s2ir.o: s2ir.c $C/rtlsym.h statement.h $(GENERATED_ROOT)/id.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/scanelf.o: scanelf.c $C/melf.h
	$(CC) -c $(CFLAGS) -I$C $< -o$@

$(GENERATED_DIR)/scanmach.o: scanmach.c $C/mach.h
	$(CC) -c $(CFLAGS) -I$C $< -o$@

$(GENERATED_DIR)/scope.o: scope.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/sideeffect.o: sideeffect.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/speller.o: $(ROOT)/speller.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/statement.o: statement.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/staticassert.o: staticassert.c staticassert.h $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/stringtable.o: $(ROOT)/stringtable.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/strtold.o: $C/strtold.c
	$(CC) -c -I$(ROOT) $< -o$@

$(GENERATED_DIR)/struct.o: struct.c $(GENERATED_ROOT)/id.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/target.o: target.c target.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/template.o: template.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/ti_achar.o: $C/ti_achar.c $C/tinfo.h
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/ti_pvoid.o: $C/ti_pvoid.c $C/tinfo.h
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/tk.o: tk.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/tocsym.o: tocsym.c $(CH) mars.h module.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/toctype.o: toctype.c $(CH) $C/rtlsym.h mars.h module.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/todt.o: todt.c mtype.h expression.h $C/dt.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/toelfdebug.o: toelfdebug.c $(CH) mars.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/toir.o: toir.c $C/rtlsym.h expression.h toir.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/toobj.o: toobj.c $(CH) mars.h module.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/traits.o: traits.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/type.o: $C/type.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/typinf.o: typinf.c $(CH) mars.h module.h mtype.h $(GENERATED_ROOT)/id.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $< -o$@

$(GENERATED_DIR)/util2.o: $C/util2.c
	$(CC) -c $(MFLAGS) $< -o$@

$(GENERATED_DIR)/utf.o: utf.c utf.h
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/unittests.o: unittests.c
	$(CC) -c $(CFLAGS) $< -o$@

$(GENERATED_DIR)/var.o: $C/var.c $(GENERATED_ROOT)/optab.c $(GENERATED_ROOT)/tytab.c
	$(CC) -c $(MFLAGS) -I. $< -o$@

$(GENERATED_DIR)/version.o: version.c
	$(CC) -c $(CFLAGS) $< -o$@

######################################################

install: all
	mkdir -p $(INSTALL_DIR)/bin
	cp $(GENERATED_DIR)/dmd $(INSTALL_DIR)/bin/dmd
	cp dmd.conf.default $(INSTALL_DIR)/bin/dmd.conf
	cp backendlicense.txt $(INSTALL_DIR)/dmd-backendlicense.txt
	cp artistic.txt $(INSTALL_DIR)/dmd-artistic.txt

######################################################

gcov:
	gcov access.c
	gcov aliasthis.c
	gcov apply.c
	gcov arrayop.c
	gcov attrib.c
	gcov builtin.c
	gcov canthrow.c
	gcov cast.c
	gcov class.c
	gcov clone.c
	gcov cond.c
	gcov constfold.c
	gcov declaration.c
	gcov delegatize.c
	gcov doc.c
	gcov dsymbol.c
	gcov dump.c
	gcov e2ir.c
	gcov eh.c
	gcov entity.c
	gcov enum.c
	gcov expression.c
	gcov func.c
	gcov glue.c
	gcov iasm.c
	gcov identifier.c
	gcov imphint.c
	gcov import.c
	gcov inifile.c
	gcov init.c
	gcov inline.c
	gcov interpret.c
	gcov ctfeexpr.c
	gcov irstate.c
	gcov json.c
	gcov lexer.c
ifeq (OSX,$(OS))
	gcov libmach.c
else
	gcov libelf.c
endif
	gcov link.c
	gcov macro.c
	gcov mangle.c
	gcov mars.c
	gcov module.c
	gcov msc.c
	gcov mtype.c
	gcov opover.c
	gcov optimize.c
	gcov parse.c
	gcov scope.c
	gcov sideeffect.c
	gcov statement.c
	gcov staticassert.c
	gcov s2ir.c
	gcov struct.c
	gcov template.c
	gcov tk.c
	gcov tocsym.c
	gcov todt.c
	gcov toobj.c
	gcov toctype.c
	gcov toelfdebug.c
	gcov typinf.c
	gcov utf.c
	gcov version.c
	gcov intrange.c
	gcov target.c

#	gcov hdrgen.c
#	gcov tocvdebug.c

######################################################

# All files under source control are part of the zip distro, except for the
# cppunit stuff.
zip:
	rm -f $(GENERATED_DIR)/dmdsrc.zip
	zip $(GENERATED_DIR)/dmdsrc `git ls-files | grep -v '^cppunit-1.12.1/'`

