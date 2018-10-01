#_ win32.mak
#
# Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
# written by Walter Bright
# http://www.digitalmars.com
# Distributed under the Boost Software License, Version 1.0.
# http://www.boost.org/LICENSE_1_0.txt
# https://github.com/dlang/dmd/blob/master/src/win32.mak
#
# Dependencies:
#
# Digital Mars C++ toolset
#   http://www.digitalmars.com/download/freecompiler.html
#
# win32.mak (this file) - requires Digital Mars Make ($DM_HOME\dm\bin\make.exe)
#   http://www.digitalmars.com/ctg/make.html
#
# $(CC) - requires Digital Mars C++ Compiler ($DM_HOME\dm\bin\dmc.exe)
#   http://www.digitalmars.com/ctg/sc.html
#
# detab, tolf, install targets - require the D Language Tools (detab.exe, tolf.exe)
#   https://github.com/dlang/tools.
#
# zip target - requires Info-ZIP or equivalent (zip32.exe)
#   http://www.info-zip.org/Zip.html#Downloads
#
# Configuration:
#
# The easiest and recommended way to configure this makefile is to add
# $DM_HOME\dm\bin to your PATH environment to automatically find make and dmc.
# Set HOST_DC to point to your installed D compiler.
#
# Custom CFLAGS may be set in the User configuration section, along with custom
# LFLAGS.  The difference between CFLAGS and OPT is that CFLAGS primarily
# applies to front-end files, while OPT applies to essentially all C++ sources.
#
# Targets:
#
# defaulttarget - debug dmd
# release       - release dmd (with clean)
# trace         - release dmd with tracing options enabled
# clean         - delete all generated files except target binary
# install       - copy build targets to install directory
# install-clean - delete all files in the install directory
# zip           - create ZIP archive of source code
# scp		- copy source files to another directory
#
# dmd           - release dmd (legacy target)
# debdmd        - debug dmd
# reldmd        - release dmd
# detab         - replace hard tabs with spaces
# tolf          - convert to Unix line endings

############################### Configuration ################################

# fixed model for win32.mak, overridden by win64.mak
MODEL=32
BUILD=release
OS=windows

##### Directories

# DMC directory
DMCROOT=$(DM_HOME)\dm
# DMD source directories
D=dmd
C=$D\backend
TK=$D\tk
ROOT=$D\root

# Include directories
INCLUDE=$(ROOT)
# Install directory
INSTALL=..\install
# Where scp command copies to
SCPDIR=..\backup

# Generated files directory
GEN = ..\generated
G = $(GEN)\$(OS)\$(BUILD)\$(MODEL)

##### Tools

GIT_HOME=https://github.com/dlang
TOOLS_DIR=..\..\tools

# C++ compiler
CC=dmc
# D compiler (set with env variable)
#HOST_DC=dmd
# Make program
MAKE=make
# Librarian
LIB=lib
# Delete file(s)
DEL=del
# Make directory
MD=mkdir
# Remove directory
RD=rmdir
# File copy
CP=cp
# De-tabify
DETAB=detab
# Convert line endings to Unix
TOLF=tolf
# Zip
ZIP=zip32
# Copy to another directory
SCP=$(CP)
# PVS-Studio command line executable
PVS="c:\Program Files (x86)\PVS-Studio\x64\PVS-Studio"
# 64-bit MS assembler
ML=ml64

##### User configuration switches

# Target name
TARGET=$G\dmd
TARGETEXE=$(TARGET).exe
# Custom compile flags
CFLAGS=
# Custom compile flags for all modules
OPT=
# Debug flags
DEBUG=-gl -D -DUNITTEST
# Linker flags (prefix with -L)
LFLAGS=
# Librarian flags
BFLAGS=
# D Optimizer flags
DOPT=
# D Model flags
DMODEL=-m$(MODEL)
# D Debug flags
DDEBUG=-debug -g -unittest

##### Implementation variables (do not modify)

# Compile flags
CFLAGS=-I$(INCLUDE) $(OPT) $(CFLAGS) $(DEBUG) -cpp -DTARGET_WINDOS=1 -DDM_TARGET_CPU_X86=1
# Compile flags for modules with backend/toolkit dependencies
MFLAGS=-I$C;$(TK) $(OPT) -DMARS -cpp $(DEBUG) -e -wx -DTARGET_WINDOS=1 -DDM_TARGET_CPU_X86=1
# D compile flags
DFLAGS=$(DOPT) $(DMODEL) $(DDEBUG) -wi -version=MARS

# Recursive make
DMDMAKE=$(MAKE) -fwin32.mak C=$C TK=$(TK) ROOT=$(ROOT) MAKE="$(MAKE)" HOST_DC="$(HOST_DC)" MODEL=$(MODEL) CC="$(CC)" LIB="$(LIB)" OBJ_MSVC="$(OBJ_MSVC)"

############################### Rule Variables ###############################

# D front end
FRONT_SRCS=$D/access.d $D/aggregate.d $D/aliasthis.d $D/apply.d $D/argtypes.d $D/arrayop.d	\
	$D/arraytypes.d $D/astcodegen.d $D/attrib.d $D/builtin.d $D/canthrow.d $D/cli.d $D/clone.d $D/compiler.d $D/complex.d	\
	$D/cond.d $D/constfold.d $D/cppmangle.d $D/cppmanglewin.d $D/ctfeexpr.d $D/ctorflow.d $D/dcast.d $D/dclass.d		\
	$D/declaration.d $D/delegatize.d $D/denum.d $D/dimport.d $D/dinifile.d $D/dinterpret.d	\
	$D/dmacro.d $D/dmangle.d $D/dmodule.d $D/doc.d $D/dscope.d $D/dstruct.d $D/dsymbol.d $D/dsymbolsem.d		\
	$D/lambdacomp.d $D/dtemplate.d $D/dversion.d $D/escape.d			\
	$D/expression.d $D/expressionsem.d $D/func.d $D/hdrgen.d $D/id.d $D/imphint.d	\
	$D/impcnvtab.d $D/init.d $D/initsem.d $D/inline.d $D/inlinecost.d $D/intrange.d $D/json.d $D/lib.d $D/link.d	\
	$D/mars.d $D/mtype.d $D/nogc.d $D/nspace.d $D/objc.d $D/opover.d $D/optimize.d $D/parse.d	\
	$D/sapply.d $D/sideeffect.d $D/statement.d $D/staticassert.d $D/target.d	\
	$D/safe.d $D/blockexit.d $D/permissivevisitor.d $D/transitivevisitor.d $D/parsetimevisitor.d $D/printast.d $D/typesem.d \
	$D/traits.d $D/utils.d $D/visitor.d $D/libomf.d $D/scanomf.d $D/templateparamsem.d $D/typinf.d \
	$D/libmscoff.d $D/scanmscoff.d $D/statement_rewrite_walker.d $D/statementsem.d $D/staticcond.d \
	$D/semantic2.d $D/semantic3.d

LEXER_SRCS=$D/console.d $D/entity.d $D/errors.d $D/globals.d $D/id.d $D/identifier.d \
	$D/lexer.d $D/tokens.d $D/utf.d

LEXER_ROOT=$(ROOT)/array.d $(ROOT)/ctfloat.d $(ROOT)/file.d $(ROOT)/filename.d \
	$(ROOT)/outbuffer.d $(ROOT)/port.d $(ROOT)/rmem.d $(ROOT)/rootobject.d \
	$(ROOT)/stringtable.d $(ROOT)/hash.d

PARSER_SRCS=$D/astbase.d $D/parsetimevisitor.d $D/parse.d $D/transitivevisitor.d $D/permissivevisitor.d $D/strictvisitor.d $D/utils.d

GLUE_SRCS=$D/irstate.d $D/toctype.d $D/glue.d $D/gluelayer.d $D/todt.d $D/tocsym.d $D/toir.d $D/dmsc.d \
	$D/tocvdebug.d $D/s2ir.d $D/toobj.d $D/e2ir.d $D/objc_glue.d $D/eh.d $D/iasm.d $D/iasmdmd.d $D/iasmgcc.d

BACK_HDRS=$C/cc.d $C/cdef.d $C/cgcv.d $C/code.d $C/cv4.d $C/dt.d $C/el.d $C/global.d \
	$C/obj.d $C/oper.d $C/outbuf.d $C/rtlsym.d $C/code_x86.d $C/iasm.d \
	$C/ty.d $C/type.d $C/exh.d $C/mach.d $C/mscoff.d $C/dwarf.d $C/dwarf2.d $C/xmm.d \
	$C/dlist.d $C/goh.d $C/memh.d $C/melf.d $C/varstats.di

TK_HDRS=

STRING_IMPORT_FILES= $G\VERSION ../res/default_ddoc_theme.ddoc

DMD_SRCS=$(FRONT_SRCS) $(GLUE_SRCS) $(BACK_HDRS) $(TK_HDRS)

# Glue layer
GLUEOBJ=

# D back end
GBACKOBJ= $G/go.obj $G/gdag.obj $G/gother.obj $G/gflow.obj $G/gloop.obj $G/var.obj $G/elem.obj \
	$G/newman.obj $G/glocal.obj $G/os.obj $G/nteh.obj $G/evalu8.obj $G/fp.obj $G/cgcs.obj \
	$G/drtlsym.obj $G/cgelem.obj $G/cgen.obj $G/cgreg.obj $G/out.obj \
	$G/blockopt.obj $G/cgobj.obj $G/cg.obj $G/dcgcv.obj $G/dtype.obj $G/dt.obj \
	$G/debugprint.obj $G/dcode.obj $G/cg87.obj $G/cgxmm.obj $G/cgsched.obj $G/ee.obj $G/symbol.obj \
	$G/cgcod.obj $G/cod1.obj $G/cod2.obj $G/cod3.obj $G/cod4.obj $G/cod5.obj $G/outbuf.obj \
	$G/bcomplex.obj $G/ptrntab.obj $G/md5.obj \
	$G/mscoffobj.obj $G/pdata.obj $G/cv8.obj $G/backconfig.obj $G/sizecheck.obj \
	$G/divcoeff.obj $G/dwarf.obj $G/compress.obj $G/dvarstats.obj \
	$G/ph2.obj $G/util2.obj $G/tk.obj $G/gsroa.obj $G/dvec.obj \

# Root package
ROOT_SRCS=$(ROOT)/aav.d $(ROOT)/array.d $(ROOT)/ctfloat.d $(ROOT)/file.d \
	$(ROOT)/filename.d $(ROOT)/man.d $(ROOT)/outbuffer.d $(ROOT)/port.d \
	$(ROOT)/response.d $(ROOT)/rmem.d $(ROOT)/rootobject.d \
	$(ROOT)/speller.d $(ROOT)/stringtable.d $(ROOT)/hash.d

# D front end
SRCS = $D/aggregate.h $D/aliasthis.h $D/arraytypes.h	\
	$D/attrib.h $D/compiler.h $D/complex_t.h $D/cond.h $D/ctfe.h $D/ctfe.h $D/declaration.h $D/dsymbol.h	\
	$D/enum.h $D/errors.h $D/expression.h $D/globals.h $D/hdrgen.h $D/identifier.h	\
	$D/id.h $D/import.h $D/init.h $D/json.h	\
	$D/mars.h $D/module.h $D/mtype.h $D/nspace.h $D/objc.h                         \
	$D/scope.h $D/statement.h $D/staticassert.h $D/target.h $D/template.h $D/tokens.h	\
	$D/version.h $D/visitor.h $D/objc.d $(DMD_SRCS)

# Glue layer
GLUESRC= \
	$D/libelf.d $D/scanelf.d $D/libmach.d $D/scanmach.d \
	$(GLUE_SRCS)

# D back end
BACKSRC= $C\cdef.h $C\cc.h $C\oper.h $C\ty.h $C\optabgen.d \
	$C\global.h $C\code.h $C\code_x86.h $C/code_stub.h $C/platform_stub.c \
	$C\type.h $C\dt.h $C\cgcv.h \
	$C\el.h \
	$C\bcomplex.d $C\blockopt.d $C\cg.d $C\cg87.d $C\cgxmm.d \
	$C\cgcod.d $C\cgcs.d $C\dcgcv.d $C\cgelem.d $C\cgen.c $C\cgobj.d \
	$C\compress.d $C\cgreg.d $C\var.d \
	$C\cgsched.d $C\cod1.d $C\cod2.d $C\cod3.d $C\cod4.d $C\cod5.d \
	$C\dcode.d $C\symbol.d $C\debugprint.d $C\dt.c $C\ee.d $C\elem.d \
	$C\evalu8.d $C\fp.c $C\go.d $C\gflow.d $C\gdag.d \
	$C\gother.d $C\glocal.d $C\gloop.d $C\gsroa.d $C\newman.d \
	$C\nteh.d $C\os.c $C\out.d $C\outbuf.c $C\ptrntab.d $C\drtlsym.d \
	$C\dtype.d $C\melf.h $C\mach.h $C\mscoff.h $C\bcomplex.h \
	$C\outbuf.h $C\token.h $C\tassert.h \
	$C\elfobj.c $C\cv4.h $C\dwarf2.h $C\exh.h $C\go.h \
	$C\dwarf.c $C\dwarf.h $C\machobj.c $C\aarray.d \
	$C\strtold.c $C\aa.h \
	$C\md5.h $C\md5.d $C\ph2.d $C\util2.d \
	$C\mscoffobj.c $C\obj.h $C\pdata.d $C\cv8.d $C\backconfig.d $C\sizecheck.c \
	$C\divcoeff.d $C\dwarfeh.d $C\dvarstats.d $C\varstats.h \
	$C\dvec.d $C\backend.txt

# Toolkit
TKSRCC=	$(TK)\filespec.c $(TK)\mem.c
TKSRC= $(TK)\filespec.h $(TK)\mem.h $(TK)\list.h $(TK)\vec.h \
	$(TKSRCC)

# Root package
ROOTSRCC=$(ROOT)\newdelete.c
ROOTSRCD=$(ROOT)\rmem.d $(ROOT)\stringtable.d $(ROOT)\hash.d $(ROOT)\man.d $(ROOT)\port.d \
	$(ROOT)\response.d $(ROOT)\rootobject.d $(ROOT)\speller.d $(ROOT)\aav.d \
	$(ROOT)\ctfloat.d $(ROOT)\longdouble.d $(ROOT)\outbuffer.d $(ROOT)\filename.d \
	$(ROOT)\file.d $(ROOT)\array.d
ROOTSRC= $(ROOT)\root.h \
	$(ROOT)\longdouble.h $(ROOT)\outbuffer.h $(ROOT)\object.h $(ROOT)\ctfloat.h \
	$(ROOT)\filename.h $(ROOT)\file.h $(ROOT)\array.h $(ROOT)\rmem.h $(ROOTSRCC) \
	$(ROOTSRCD)
# Removed garbage collector bits (look in history)
#	$(ROOT)\gc\bits.c $(ROOT)\gc\gc.c $(ROOT)\gc\gc.h $(ROOT)\gc\mscbitops.h \
#	$(ROOT)\gc\bits.h $(ROOT)\gc\gccbitops.h $(ROOT)\gc\linux.c $(ROOT)\gc\os.h \
#	$(ROOT)\gc\win32.c

# Header files
CH= $C\cc.h $C\global.h $C\oper.h $C\code.h $C\code_x86.h $C\type.h $C\dt.h $C\cgcv.h \
	$C\el.h $C\obj.h

# Makefiles
MAKEFILES=win32.mak posix.mak osmodel.mak

############################## Release Targets ###############################

defaulttarget: $G debdmd

auto-tester-build: $G dmd checkwhitespace $(DMDFRONTENDEXE)

dmd: $G reldmd

release:
	$(DMDMAKE) clean
	$(DEL) $(TARGETEXE)
	$(DMDMAKE) reldmd
	$(DMDMAKE) clean

$G :
	if not exist "$G" mkdir $G

check-host-dc:
	@cmd /c if "$(HOST_DC)" == "" (echo Error: Environment variable HOST_DC is not set & exit 1)

debdmd: check-host-dc debdmd-make

debdmd-make:
	$(DMDMAKE) "OPT=" "DEBUG=-D -g -DUNITTEST" "DDEBUG=-debug -g -unittest" "DOPT=" "LFLAGS=-L/ma/co/la" $(TARGETEXE)

reldmd: check-host-dc reldmd-make

reldmd-make:
	$(DMDMAKE) "OPT=-o" "DEBUG=" "DDEBUG=" "DOPT=-O -release -inline" "LFLAGS=-L/delexe/la" $(TARGETEXE)

profile:
	$(DMDMAKE) "OPT=-o" "DEBUG=" "DDEBUG=" "DOPT=-O -release -profile" "LFLAGS=-L/delexe/la" $(TARGETEXE)

trace:
	$(DMDMAKE) "OPT=-o" "DEBUG=-gt -Nc" "DDEBUG=-debug -g -unittest" "DOPT=" "LFLAGS=-L/ma/co/delexe/la" $(TARGETEXE)

unittest:
	$(DMDMAKE) "OPT=-o" "DEBUG=" "DDEBUG=-debug -g -unittest -cov" "DOPT=" "LFLAGS=-L/ma/co/delexe/la" $(TARGETEXE)

################################ Libraries ##################################

glue.lib : $(GLUEOBJ)
	$(LIB) -p512 -n -o$@ $G\glue.lib $(GLUEOBJ)

LIBS=$G\backend.lib $G\lexer.lib

$G\backend.lib: $(GBACKOBJ) $(OBJ_MSVC)
	$(LIB) -p512 -n -c $@ $(GBACKOBJ) $(OBJ_MSVC)

$G\lexer.lib: $(LEXER_SRCS) $(ROOT_SRCS) $(STRING_IMPORT_FILES) $G
	$(HOST_DC) -of$@ -vtls -lib -J$G $(DFLAGS) $(LEXER_SRCS) $(ROOT_SRCS)

$G\parser.lib: $(PARSER_SRCS) $G\lexer.lib $G
	$(HOST_DC) -of$@ -vtls -lib $(DFLAGS) $(PARSER_SRCS) $G\lexer.lib

parser_test: $G\parser.lib examples\test_parser.d
	$(HOST_DC) -of$@ -vtls $(DFLAGS) $G\parser.lib examples\test_parser.d examples\impvisitor.d

example_avg: $G\libparser.lib examples\avg.d
	$(HOST_DC) -of$@ -vtls $(DFLAGS) $G\libparser.lib examples\avg.d

DMDFRONTENDEXE = $G\dmd_frontend.exe

$(DMDFRONTENDEXE): $(FRONT_SRCS) $D\gluelayer.d $(ROOT_SRCS) $G\newdelete.obj $G\lexer.lib $(STRING_IMPORT_FILES)
	$(HOST_DC) $(DSRC) -of$@ -vtls -J$G -J../res -L/STACK:8388608 $(DFLAGS) $(LFLAGS) $(FRONT_SRCS) $D/gluelayer.d $(ROOT_SRCS) newdelete.obj -version=NoBackend
	copy $(DMDFRONTENDEXE) .

$(TARGETEXE): $(DMD_SRCS) $(ROOT_SRCS) $G\newdelete.obj $(LIBS) $(STRING_IMPORT_FILES)
	$(HOST_DC) $(DSRC) -of$@ -vtls -J$G -J../res -L/STACK:8388608 $(DFLAGS) $(LFLAGS) $(DMD_SRCS) $(ROOT_SRCS) $G\newdelete.obj $(LIBS)
	copy $(TARGETEXE) .

############################ Maintenance Targets #############################

clean:
	$(RD) /s /q $(GEN)
	$(DEL) $D\msgs.h $D\msgs.c
	$(DEL) optabgen.exe parser_test.exe example_avg.exe
	$(DEL) $(TARGETEXE) $(DMDFRONTENDEXE) *.map *.obj *.exe

install: detab install-copy

install-copy:
	$(MD) $(INSTALL)\windows\bin
	$(MD) $(INSTALL)\windows\lib
	$(MD) $(INSTALL)\src\dmd\root
	$(MD) $(INSTALL)\src\dmd\tk
	$(MD) $(INSTALL)\src\dmd\backend
	$(CP) $(TARGETEXE)          $(INSTALL)\windows\bin\$(TARGETEXE)
	$(CP) $(SRCS)               $(INSTALL)\src\dmd
	$(CP) $(GLUESRC)            $(INSTALL)\src\dmd
	$(CP) $(ROOTSRC)            $(INSTALL)\src\dmd\root
	$(CP) $(TKSRC)              $(INSTALL)\src\dmd\tk
	$(CP) $(BACKSRC)            $(INSTALL)\src\dmd\backend
	$(CP) $(MAKEFILES)          $(INSTALL)\src\dmd
	$(CP) $D\readme.txt            $(INSTALL)\src\dmd\readme.txt
	$(CP) $D\boostlicense.txt      $(INSTALL)\src\dmd\boostlicense.txt

install-clean:
	$(DEL) /s/q $(INSTALL)\*
	$(RD) /s/q $(INSTALL)

detab:
	$(DETAB) $(SRCS) $(GLUESRC) $(ROOTSRC) $(TKSRC) $(BACKSRC)

tolf:
	$(TOLF) $(SRCS) $(GLUESRC) $(ROOTSRC) $(TKSRC) $(BACKSRC) $(MAKEFILES)

zip: detab tolf $(MAKEFILES)
	$(DEL) dmdsrc.zip
	$(ZIP) dmdsrc $(MAKEFILES)
	$(ZIP) dmdsrc $(SRCS)
	$(ZIP) dmdsrc $(GLUESRC)
	$(ZIP) dmdsrc $(BACKSRC)
	$(ZIP) dmdsrc $(TKSRC)
	$(ZIP) dmdsrc $(ROOTSRC)

scp: detab tolf $(MAKEFILES)
	$(SCP) $(MAKEFILES) $(SCPDIR)/src
	$(SCP) $(SRCS) $(SCPDIR)/src
	$(SCP) $(GLUESRC) $(SCPDIR)/src
	$(SCP) $(BACKSRC) $(SCPDIR)/src/backend
	$(SCP) $(TKSRC) $(SCPDIR)/src/tk
	$(SCP) $(ROOTSRC) $(SCPDIR)/src/root

pvs:
#	$(PVS) --cfg PVS-Studio.cfg --cl-params /I$(ROOT) /Tp canthrow.c --source-file canthrow.c
#	$(PVS) --cfg PVS-Studio.cfg --cl-params /I$(ROOT) /I$C /I$(TK) /Tp scanmscoff.c --source-file scanmscoff.c
	$(PVS) --cfg PVS-Studio.cfg --cl-params /DMARS /DDM_TARGET_CPU_X86 /I$C /I$(TK) /I$(ROOT) /Tp $C\cod3.c --source-file $C\cod3.c
#	$(PVS) --cfg PVS-Studio.cfg --cl-params /I$(ROOT) /Tp $(SRCS) --source-file $(SRCS)
#	$(PVS) --cfg PVS-Studio.cfg --cl-params /I$(ROOT) /Tp $(GLUESRC) --source-file $(GLUESRC)
#	$(PVS) --cfg PVS-Studio.cfg --cl-params /I$(ROOT) /Tp $(ROOTSRCC) --source-file $(ROOTSRCC)
#	$(PVS) --cfg PVS-Studio.cfg --cl-params /I$C;$(TK) /Tp $(BACKSRC) --source-file $(BACKSRC)
#	$(PVS) --cfg PVS-Studio.cfg --cl-params /I$(TK) /Tp $(TKSRCC) --source-file $(TKSRCC)

checkwhitespace: $(TOOLS_DIR)\checkwhitespace.d
	$(HOST_DC) -run $(TOOLS_DIR)\checkwhitespace $(SRCS) $(GLUESRC) $(ROOTSRC) $(TKSRC) $(BACKSRC) $(CH)

# Extra test here, wine attempts to execute git even if file already exists
$(TOOLS_DIR)\checkwhitespace.d:
	if not exist $(TOOLS_DIR)\checkwhitespace.d git clone --depth=1 $(GIT_HOME)/tools $(TOOLS_DIR)

######################################################

..\changelog.html: ..\changelog.dd
	$(HOST_DC) -Df$@ $<

############################## Generated Source ##############################
OPTABGENOUTPUT = $G\elxxx.d $G\cdxxx.d $G\optab.d $G\debtab.d $G\fltables.d $G\tytab.d

$(OPTABGENOUTPUT) : \
	$C\cdef.h $C\cc.h $C\oper.h $C\ty.h $C\optabgen.d
	$(HOST_DC) -of$G\optabgen.exe -betterC $(DFLAGS) -mv=dmd.backend=$C $C\optabgen
	$G\optabgen.exe
	copy *.c "$G\"
	copy cdxxx.d "$G\"
	copy debtab.d "$G\"
	copy elxxx.d "$G\"
	copy fltables.d "$G\"
	copy tytab.d "$G\"
	copy optab.d "$G\"
	$(DEL) *.c
	$(DEL) debtab.d
	$(DEL) elxxx.d
	$(DEL) fltables.d
	$(DEL) cdxxx.d
	$(DEL) tytab.d
	$(DEL) optab.d

$G\VERSION : ..\VERSION $G
	copy ..\VERSION $@

############################# Intermediate Rules ############################

# Default rules
.c.obj:
	$(CC) -c $(CFLAGS) $*

.asm.obj:
	$(CC) -c $(CFLAGS) $*

# D front/back end

$G/backconfig.obj : $C\backconfig.d
	$(HOST_DC) -c -betterC -of$@ $(DFLAGS) -mv=dmd.backend=$C $C\backconfig

$G/bcomplex.obj : $C\bcomplex.d
	$(HOST_DC) -c -betterC -of$@ $(DFLAGS) -mv=dmd.backend=$C $C\bcomplex

$G/blockopt.obj : $C\blockopt.d
	$(HOST_DC) -c -betterC -of$@ $(DFLAGS) -mv=dmd.backend=$C $C\blockopt

$G/cg.obj : $G\fltables.d $C\cg.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -J$G -betterC -mv=dmd.backend=$C $C\cg

$G/cg87.obj : $C\cg87.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cg87

$G/cgcod.obj : $G\cdxxx.d $C\cgcod.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -J$G -betterC -mv=dmd.backend=$C $C\cgcod

$G/cgcs.obj : $C\cgcs.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cgcs

$G/dcgcv.obj : $C\dcgcv.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\dcgcv

$G/cgelem.obj : $G\elxxx.d $C\cgelem.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -J$G -betterC -mv=dmd.backend=$C $C\cgelem

$G/cgen.obj : $C\cgen.c
	$(CC) -c -o$@ $(MFLAGS) $C\cgen

$G/cgobj.obj : $C\md5.d $C\cgobj.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cgobj

$G/cgreg.obj : $C\cgreg.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cgreg

$G/cgsched.obj : $C\cgsched.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cgsched

$G/cgxmm.obj : $C\xmm.d $C\cgxmm.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cgxmm

$G/cod1.obj : $C\cod1.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cod1

$G/cod2.obj : $C\cod2.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cod2

$G/cod3.obj : $C\cod3.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cod3

$G/cod4.obj : $C\cod4.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cod4

$G/cod5.obj : $C\cod5.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cod5

$G/dcode.obj : $C\dcode.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\dcode

$G/compress.obj : $C\compress.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\compress

$G/symbol.obj : $C\symbol.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\symbol

$G/cv8.obj : $C\cv8.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\cv8

$G/debugprint.obj : $G\debtab.d $C\debugprint.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -J$G -betterC $C\debugprint

$G/divcoeff.obj : $C\divcoeff.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC $C\divcoeff

$G/dt.obj : $C\dt.h $C\dt.c
	$(CC) -c -o$@ $(MFLAGS) $C\dt

$G/dvec.obj : $C\dvec.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\dvec

$G/dwarf.obj : $C\dwarf.h $C\dwarf.c
	$(CC) -c -o$@ $(MFLAGS) $C\dwarf

$G/ee.obj : $C\ee.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\ee

$G/elem.obj : $C\rtlsym.d $C\el.d $C\elem.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\elem

$G/evalu8.obj : $C\evalu8.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\evalu8

$G/fp.obj : $C\fp.c
	$(CC) -c -o$@ $(MFLAGS) $C\fp

$G/go.obj : $C\go.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\go

$G/gflow.obj : $C\gflow.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\gflow

$G/gdag.obj : $C\gdag.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\gdag

$G/gother.obj : $C\gother.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\gother

$G/glocal.obj : $C\glocal.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\glocal

$G/gloop.obj : $C\gloop.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\gloop

$G/gsroa.obj : $C\gsroa.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\gsroa

$G/md5.obj : $C\md5.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\md5

$G/mscoffobj.obj : $C\mscoff.h $C\mscoffobj.c
	$(CC) -c -o$@ $(MFLAGS) -I$D;$(ROOT) -I$G $C\mscoffobj

$G/newman.obj : $(CH) $C\newman.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\newman

$G/nteh.obj : $C\rtlsym.d $C\nteh.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\nteh

$G/os.obj : $C\os.c
	$(CC) -c -o$@ $(MFLAGS) $C\os

$G/out.obj : $C\out.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\out

$G/outbuf.obj : $C\outbuf.h $C\outbuf.c
	$(CC) -c -o$@ $(MFLAGS) $C\outbuf

$G/pdata.obj : $C\pdata.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\pdata

$G/ph2.obj : $C\ph2.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\ph2

$G/ptrntab.obj : $C\iasm.d $C\ptrntab.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\ptrntab

$G/drtlsym.obj : $C\rtlsym.d $C\drtlsym.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\drtlsym

$G/sizecheck.obj : $C\sizecheck.c
	$(CC) -c -o$@ $(MFLAGS) $C\sizecheck

$G/strtold.obj : $C\strtold.c
	$(CC) -c -o$@ -cpp $C\strtold

$G/dtype.obj : $C\dtype.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\dtype

$G/util2.obj : $C\util2.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\util2

$G/var.obj : $C\var.d $G\optab.d $G\tytab.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -J$G -betterC -mv=dmd.backend=$C $C\var

$G/dvarstats.obj : $C\dvarstats.d
	$(HOST_DC) -c -of$@ $(DFLAGS) -betterC -mv=dmd.backend=$C $C\dvarstats
#	$(CC) -c -o$@ $(MFLAGS) -I$D -I$G $C\varstats


$G/tk.obj : $C\tk.c
	$(CC) -c -o$@ $(MFLAGS) $C\tk.c

# Root
$G\newdelete.obj : $(ROOT)\newdelete.c
	$(CC) -c -o$@ $(CFLAGS) $(ROOT)\newdelete.c

$G/longdouble.obj : $(ROOT)\longdouble.d
	$(HOST_DC) -c -of$@ $(DFLAGS) $(ROOT)\longdouble.d

############################## Generated Rules ###############################

# These rules were generated by makedep, but are not currently maintained
