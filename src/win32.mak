#_ win32.mak
#
# Copyright (c) 1999-2016 by Digital Mars
# All Rights Reserved
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
# install target - requires Phobos (.\phobos.lib)
#   https://github.com/dlang/phobos
#
# zip target - requires Info-ZIP or equivalent (zip32.exe)
#   http://www.info-zip.org/Zip.html#Downloads
#
# Configuration:
#
# The easiest and recommended way to configure this makefile is to set DM_HOME
# in your environment to the location where DMC is installed (the parent of
# \dm and/or \dmd).  By default, the install target will place the build
# targets under $DM_HOME\dmd2.
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
D=ddmd
C=$D\backend
TK=$D\tk
ROOT=$D\root

# Include directories
INCLUDE=$(ROOT);$(DMCROOT)\include
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
	$D/arraytypes.d $D/astcodegen.d $D/attrib.d $D/builtin.d $D/canthrow.d $D/clone.d $D/complex.d		\
	$D/cond.d $D/constfold.d $D/cppmangle.d $D/ctfeexpr.d $D/dcast.d $D/dclass.d		\
	$D/declaration.d $D/delegatize.d $D/denum.d $D/dimport.d $D/dinifile.d $D/dinterpret.d	\
	$D/dmacro.d $D/dmangle.d $D/dmodule.d $D/doc.d $D/dscope.d $D/dstruct.d $D/dsymbol.d		\
	$D/dtemplate.d $D/dversion.d $D/escape.d			\
	$D/expression.d $D/expressionsem.d $D/func.d $D/hdrgen.d $D/id.d $D/imphint.d	\
	$D/impcnvtab.d $D/init.d $D/initsem.d $D/inline.d $D/inlinecost.d $D/intrange.d $D/json.d $D/lib.d $D/link.d	\
	$D/mars.d $D/mtype.d $D/nogc.d $D/nspace.d $D/objc.d $D/opover.d $D/optimize.d $D/parse.d	\
	$D/sapply.d $D/sideeffect.d $D/statement.d $D/staticassert.d $D/target.d	\
	$D/safe.d $D/blockexit.d $D/asttypename.d $D/printast.d $D/typesem.d \
	$D/traits.d $D/utils.d $D/visitor.d $D/libomf.d $D/scanomf.d $D/typinf.d \
	$D/libmscoff.d $D/scanmscoff.d $D/statement_rewrite_walker.d $D/statementsem.d $D/staticcond.d

CTFE_SRCS=$D/ctfe/bc.d $D/ctfe/bc_common.d $D/ctfe/bc_c_backend.d		\
	$D/ctfe/bc_limits.d $D/ctfe/bc_llvm_backend.d $D/ctfe/bc_macro.d	\
	$D/ctfe/bc_printer_backend.d $D/ctfe/bc_recorder.d $D/ctfe/bc_test.d	\
	$D/ctfe/ctfe_bc.d

LEXER_SRCS=$D/console.d $D/entity.d $D/errors.d $D/globals.d $D/id.d $D/identifier.d \
	$D/lexer.d $D/tokens.d $D/utf.d

LEXER_ROOT=$(ROOT)/array.d $(ROOT)/ctfloat.d $(ROOT)/file.d $(ROOT)/filename.d \
	$(ROOT)/outbuffer.d $(ROOT)/port.d $(ROOT)/rmem.d $(ROOT)/rootobject.d \
	$(ROOT)/stringtable.d $(ROOT)/hash.d

PARSER_SRCS=$D/astbase.d $D/astbasevisitor.d $D/parse.d $D/transitivevisitor.d $D/permissivevisitor.d $D/strictvisitor.d

GLUE_SRCS=$D/irstate.d $D/toctype.d $D/glue.d $D/gluelayer.d $D/todt.d $D/tocsym.d $D/toir.d $D/dmsc.d \
	$D/tocvdebug.d $D/s2ir.d $D/toobj.d $D/e2ir.d $D/objc_glue_stubs.d $D/eh.d $D/iasm.d

BACK_HDRS=$C/bcomplex.d $C/cc.d $C/cdef.d $C/cgcv.d $C/code.d $C/cv4.d $C/dt.d $C/el.d $C/global.d \
	$C/obj.d $C/oper.d $C/outbuf.d $C/rtlsym.d $C/code_x86.d $C/iasm.d \
	$C/ty.d $C/type.d $C/exh.d $C/mach.d $C/md5.d $C/mscoff.d $C/dwarf.d $C/dwarf2.d $C/xmm.d

TK_HDRS= $(TK)/dlist.d

STRING_IMPORT_FILES= $G\VERSION ../res/default_ddoc_theme.ddoc

DMD_SRCS=$(FRONT_SRCS) $(CTFE_SRCS) $(GLUE_SRCS) $(BACK_HDRS) $(TK_HDRS)

# Glue layer
GLUEOBJ=

# D back end
GBACKOBJ= $G/go.obj $G/gdag.obj $G/gother.obj $G/gflow.obj $G/gloop.obj $G/var.obj $G/el.obj \
	$G/newman.obj $G/glocal.obj $G/os.obj $G/nteh.obj $G/evalu8.obj $G/cgcs.obj \
	$G/rtlsym.obj $G/cgelem.obj $G/cgen.obj $G/cgreg.obj $G/out.obj \
	$G/blockopt.obj $G/cgobj.obj $G/cg.obj $G/cgcv.obj $G/type.obj $G/dt.obj \
	$G/debug.obj $G/code.obj $G/cg87.obj $G/cgxmm.obj $G/cgsched.obj $G/ee.obj $G/csymbol.obj \
	$G/cgcod.obj $G/cod1.obj $G/cod2.obj $G/cod3.obj $G/cod4.obj $G/cod5.obj $G/outbuf.obj \
	$G/bcomplex.obj $G/ptrntab.obj $G/aa.obj $G/ti_achar.obj $G/md5.obj \
	$G/ti_pvoid.obj $G/mscoffobj.obj $G/pdata.obj $G/cv8.obj $G/backconfig.obj \
	$G/divcoeff.obj $G/dwarf.obj $G/compress.obj $G/varstats.obj \
	$G/ph2.obj $G/util2.obj $G/tk.obj $G/gsroa.obj \

# Root package
ROOT_SRCS=$(ROOT)/aav.d $(ROOT)/array.d $(ROOT)/ctfloat.d $(ROOT)/file.d \
	$(ROOT)/filename.d $(ROOT)/man.d $(ROOT)/outbuffer.d $(ROOT)/port.d \
	$(ROOT)/response.d $(ROOT)/rmem.d $(ROOT)/rootobject.d \
	$(ROOT)/speller.d $(ROOT)/stringtable.d $(ROOT)/hash.d

# D front end
SRCS = $D/aggregate.h $D/aliasthis.h $D/arraytypes.h	\
	$D/attrib.h $D/complex_t.h $D/cond.h $D/ctfe.h $D/ctfe.h $D/declaration.h $D/dsymbol.h	\
	$D/enum.h $D/errors.h $D/expression.h $D/globals.h $D/hdrgen.h $D/identifier.h $D/idgen.d	\
	$D/import.h $D/init.h $D/intrange.h $D/json.h	\
	$D/mars.h $D/module.h $D/mtype.h $D/nspace.h $D/objc.h                         \
	$D/scope.h $D/statement.h $D/staticassert.h $D/target.h $D/template.h $D/tokens.h	\
	$D/version.h $D/visitor.h $D/objc.d $(DMD_SRCS)

# Glue layer
GLUESRC= \
	$D/libelf.d $D/scanelf.d $D/libmach.d $D/scanmach.d \
	$D/objc_glue.d \
	$(GLUE_SRCS)

# D back end
BACKSRC= $C\cdef.h $C\cc.h $C\oper.h $C\ty.h $C\optabgen.c \
	$C\global.h $C\code.h $C\code_x86.h $C/code_stub.h $C/platform_stub.c \
	$C\type.h $C\dt.h $C\cgcv.h \
	$C\el.h $C\iasm.h $C\rtlsym.h \
	$C\bcomplex.c $C\blockopt.c $C\cg.c $C\cg87.c $C\cgxmm.c \
	$C\cgcod.c $C\cgcs.c $C\cgcv.c $C\cgelem.c $C\cgen.c $C\cgobj.c \
	$C\compress.c $C\cgreg.c $C\var.c \
	$C\cgsched.c $C\cod1.c $C\cod2.c $C\cod3.c $C\cod4.c $C\cod5.c \
	$C\code.c $C\symbol.c $C\debug.c $C\dt.c $C\ee.c $C\el.c \
	$C\evalu8.c $C\go.c $C\gflow.c $C\gdag.c \
	$C\gother.c $C\glocal.c $C\gloop.c $C\gsroa.c $C\newman.c \
	$C\nteh.c $C\os.c $C\out.c $C\outbuf.c $C\ptrntab.c $C\rtlsym.c \
	$C\type.c $C\melf.h $C\mach.h $C\mscoff.h $C\bcomplex.h \
	$C\outbuf.h $C\token.h $C\tassert.h \
	$C\elfobj.c $C\cv4.h $C\dwarf2.h $C\exh.h $C\go.h \
	$C\dwarf.c $C\dwarf.h $C\machobj.c \
	$C\strtold.c $C\aa.h $C\aa.c $C\tinfo.h $C\ti_achar.c \
	$C\md5.h $C\md5.c $C\ti_pvoid.c $C\xmm.h $C\ph2.c $C\util2.c \
	$C\mscoffobj.c $C\obj.h $C\pdata.c $C\cv8.c $C\backconfig.c \
	$C\divcoeff.c $C\dwarfeh.c $C\varstats.c $C\varstats.h \
	$C\backend.txt

# Toolkit
TKSRCC=	$(TK)\filespec.c $(TK)\mem.c $(TK)\vec.c $(TK)\list.c
TKSRC= $(TK)\filespec.h $(TK)\mem.h $(TK)\list.h $(TK)\vec.h \
	$(TKSRCC)

# Root package
ROOTSRCC=$(ROOT)\newdelete.c
ROOTSRCD=$(ROOT)\rmem.d $(ROOT)\stringtable.d $(ROOT)\hash.d $(ROOT)\man.d $(ROOT)\port.d \
	$(ROOT)\response.d $(ROOT)\rootobject.d $(ROOT)\speller.d $(ROOT)\aav.d \
	$(ROOT)\ctfloat.d $(ROOT)\outbuffer.d $(ROOT)\filename.d \
	$(ROOT)\file.d $(ROOT)\array.d
ROOTSRC= $(ROOT)\root.h $(ROOT)\stringtable.h \
	$(ROOT)\longdouble.h $(ROOT)\outbuffer.h $(ROOT)\object.h $(ROOT)\ctfloat.h \
	$(ROOT)\filename.h $(ROOT)\file.h $(ROOT)\array.h $(ROOT)\rmem.h $(ROOTSRCC) \
	$(ROOTSRCD)
# Removed garbage collector bits (look in history)
#	$(ROOT)\gc\bits.c $(ROOT)\gc\gc.c $(ROOT)\gc\gc.h $(ROOT)\gc\mscbitops.h \
#	$(ROOT)\gc\bits.h $(ROOT)\gc\gccbitops.h $(ROOT)\gc\linux.c $(ROOT)\gc\os.h \
#	$(ROOT)\gc\win32.c

# Header files
CH= $C\cc.h $C\global.h $C\oper.h $C\code.h $C\code_x86.h $C\type.h $C\dt.h $C\cgcv.h \
	$C\el.h $C\iasm.h $C\obj.h

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

debdmd:
	$(DMDMAKE) "OPT=" "DEBUG=-D -g -DUNITTEST" "DDEBUG=-debug -g -unittest" "DOPT=" "LFLAGS=-L/ma/co/la" $(TARGETEXE)

reldmd:
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

$(DMDFRONTENDEXE): $(FRONT_SRCS) $(CTFE_SRCS) $D\gluelayer.d $(ROOT_SRCS) $G\newdelete.obj $G\lexer.lib $(STRING_IMPORT_FILES)
	$(HOST_DC) $(DSRC) -of$@ -vtls -J$G -J../res -L/STACK:8388608 $(DFLAGS) $(LFLAGS) $(FRONT_SRCS) $(CTFE_SRCS) $D/gluelayer.d $(ROOT_SRCS) newdelete.obj -version=NoBackend
	copy $(DMDFRONTENDEXE) .

$(TARGETEXE): $(DMD_SRCS) $(ROOT_SRCS) $G\newdelete.obj $(LIBS) $(STRING_IMPORT_FILES)
	$(HOST_DC) $(DSRC) -of$@ -vtls -J$G -J../res -L/STACK:8388608 $(DFLAGS) $(LFLAGS) $(DMD_SRCS) $(ROOT_SRCS) $G\newdelete.obj $(LIBS)
	copy $(TARGETEXE) .

############################ Maintenance Targets #############################

clean:
	$(RD) /s /q $(GEN)
	$(DEL) $D\msgs.h $D\msgs.c
	$(DEL) optabgen.exe parser_test.exe example_avg.exe
	$(DEL) $(TARGETEXE) $(DMDFRONTENDEXE) *.map *.obj

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

$(TOOLS_DIR)\checkwhitespace.d:
	-git clone --depth=1 $(GIT_HOME)/tools $(TOOLS_DIR)

######################################################

..\changelog.html: ..\changelog.dd
	$(HOST_DC) -Df$@ $<

############################## Generated Source ##############################
OPTABGENOUTPUT = $G\elxxx.c $G\cdxxx.c $G\optab.c $G\debtab.c $G\fltables.c $G\tytab.c

$(OPTABGENOUTPUT) : \
	$C\cdef.h $C\cc.h $C\oper.h $C\ty.h $C\optabgen.c
	$(CC) -cpp -o$G\optabgen.exe $C\optabgen -DMARS -DDM_TARGET_CPU_X86=1 -I$(TK)
	$G\optabgen.exe
	copy *.c "$G\"
	$(DEL) *.c

$G\VERSION : ..\VERSION $G
	copy ..\VERSION $@

############################# Intermediate Rules ############################

# Default rules
.c.obj:
	$(CC) -c $(CFLAGS) $*

.asm.obj:
	$(CC) -c $(CFLAGS) $*

# D front/back end
$G/bcomplex.obj : $C\bcomplex.c
	$(CC) -c -o$@ $(MFLAGS) $C\bcomplex

$G/aa.obj : $C\tinfo.h $C\aa.h $C\aa.c
	$(CC) -c -o$@ $(MFLAGS) -I$D -I$G $C\aa

$G/backconfig.obj : $C\backconfig.c
	$(CC) -c -o$@ $(MFLAGS) $C\backconfig

$G/blockopt.obj : $C\blockopt.c
	$(CC) -c -o$@ $(MFLAGS) $C\blockopt

$G/cg.obj : $C\cg.c
	$(CC) -c -o$@ $(MFLAGS) -I$D -I$G $C\cg

$G/cg87.obj : $C\cg87.c
	$(CC) -c -o$@ $(MFLAGS) $C\cg87

$G/cgcod.obj : $C\cgcod.c
	$(CC) -c -o$@ $(MFLAGS) -I$D -I$G $C\cgcod

$G/cgcs.obj : $C\cgcs.c
	$(CC) -c -o$@ $(MFLAGS) $C\cgcs

$G/cgcv.obj : $C\cgcv.c
	$(CC) -c -o$@ $(MFLAGS) $C\cgcv

$G/cgelem.obj : $C\rtlsym.h $C\cgelem.c
	$(CC) -c -o$@ $(MFLAGS) -I$D -I$G $C\cgelem

$G/cgen.obj : $C\rtlsym.h $C\cgen.c
	$(CC) -c -o$@ $(MFLAGS) $C\cgen

$G/cgobj.obj : $C\md5.h $C\cgobj.c
	$(CC) -c -o$@ $(MFLAGS) $C\cgobj

$G/cgreg.obj : $C\cgreg.c
	$(CC) -c -o$@ $(MFLAGS) $C\cgreg

$G/cgsched.obj : $C\rtlsym.h $C\cgsched.c
	$(CC) -c -o$@ $(MFLAGS) $C\cgsched

$G/cgxmm.obj : $C\xmm.h $C\cgxmm.c
	$(CC) -c -o$@ $(MFLAGS) $C\cgxmm

$G/cod1.obj : $C\rtlsym.h $C\cod1.c
	$(CC) -c -o$@ $(MFLAGS) $C\cod1

$G/cod2.obj : $C\rtlsym.h $C\cod2.c
	$(CC) -c -o$@ $(MFLAGS) $C\cod2

$G/cod3.obj : $C\rtlsym.h $C\cod3.c
	$(CC) -c -o$@ $(MFLAGS) $C\cod3

$G/cod4.obj : $C\cod4.c
	$(CC) -c -o$@ $(MFLAGS) $C\cod4

$G/cod5.obj : $C\cod5.c
	$(CC) -c -o$@ $(MFLAGS) $C\cod5

$G/code.obj : $C\code.c
	$(CC) -c -o$@ $(MFLAGS) $C\code

$G/compress.obj : $C\compress.c
	$(CC) -c -o$@ $(MFLAGS) $C\compress

$G/csymbol.obj : $C\symbol.c
	$(CC) -c -o$G\csymbol.obj $(MFLAGS) $C\symbol

$G/cv8.obj : $C\cv8.c
	$(CC) -c -o$@ $(MFLAGS) $C\cv8

$G/debug.obj : $C\debug.c
	$(CC) -c -o$@ $(MFLAGS) -I$D -I$G $C\debug

$G/divcoeff.obj : $C\divcoeff.c
	$(CC) -c -o$@ -cpp -e $(DEBUG) $C\divcoeff

$G/dt.obj : $C\dt.h $C\dt.c
	$(CC) -c -o$@ $(MFLAGS) $C\dt

$G/dwarf.obj : $C\dwarf.h $C\dwarf.c
	$(CC) -c -o$@ $(MFLAGS) $C\dwarf

$G/ee.obj : $C\ee.c
	$(CC) -c -o$@ $(MFLAGS) $C\ee

$G/el.obj : $C\rtlsym.h $C\el.h $C\el.c
	$(CC) -c -o$@ $(MFLAGS) $C\el

$G/evalu8.obj : $C\evalu8.c
	$(CC) -c -o$@ $(MFLAGS) $C\evalu8

$G/go.obj : $C\go.c
	$(CC) -c -o$@ $(MFLAGS) $C\go

$G/gflow.obj : $C\gflow.c
	$(CC) -c -o$@ $(MFLAGS) $C\gflow

$G/gdag.obj : $C\gdag.c
	$(CC) -c -o$@ $(MFLAGS) $C\gdag

$G/gother.obj : $C\gother.c
	$(CC) -c -o$@ $(MFLAGS) $C\gother

$G/glocal.obj : $C\rtlsym.h $C\glocal.c
	$(CC) -c -o$@ $(MFLAGS) $C\glocal

$G/gloop.obj : $C\gloop.c
	$(CC) -c -o$@ $(MFLAGS) $C\gloop

$G/glue.obj : $(CH) $C\rtlsym.h $D\mars.h $D\module.h $D\glue.c
	$(CC) -c -o$@ $(MFLAGS) -I$(ROOT) $D\glue

$G/gsroa.obj : $C\gsroa.c
	$(CC) -c -o$@ $(MFLAGS) $C\gsroa

$G/md5.obj : $C\md5.h $C\md5.c
	$(CC) -c -o$@ $(MFLAGS) $C\md5

$G/mscoffobj.obj : $C\mscoff.h $C\mscoffobj.c
	$(CC) -c -o$@ $(MFLAGS) -I$D;$(ROOT) -I$G $C\mscoffobj

$G/newman.obj : $(CH) $C\newman.c
	$(CC) -c -o$@ $(MFLAGS) $C\newman

$G/nteh.obj : $C\rtlsym.h $C\nteh.c
	$(CC) -c -o$@ $(MFLAGS) $C\nteh

$G/os.obj : $C\os.c
	$(CC) -c -o$@ $(MFLAGS) $C\os

$G/out.obj : $C\out.c
	$(CC) -c -o$@ $(MFLAGS) $C\out

$G/outbuf.obj : $C\outbuf.h $C\outbuf.c
	$(CC) -c -o$@ $(MFLAGS) $C\outbuf

$G/pdata.obj : $C\pdata.c
	$(CC) -c -o$@ $(MFLAGS) $C\pdata

$G/ph2.obj : $C\ph2.c
	$(CC) -c -o$@ $(MFLAGS) $C\ph2

$G/ptrntab.obj : $C\iasm.h $C\ptrntab.c
	$(CC) -c -o$@ $(MFLAGS) $C\ptrntab

$G/rtlsym.obj : $C\rtlsym.h $C\rtlsym.c
	$(CC) -c -o$@ $(MFLAGS) $C\rtlsym

$G/strtold.obj : $C\strtold.c
	$(CC) -c -o$@ -cpp $C\strtold

$G/ti_achar.obj : $C\tinfo.h $C\ti_achar.c
	$(CC) -c -o$@ $(MFLAGS) -I$D $C\ti_achar

$G/ti_pvoid.obj : $C\tinfo.h $C\ti_pvoid.c
	$(CC) -c -o$@ $(MFLAGS) -I$D -I$G $C\ti_pvoid

$G/type.obj : $C\type.c
	$(CC) -c -o$@ $(MFLAGS) $C\type

$G/util2.obj : $C\util2.c
	$(CC) -c -o$@ $(MFLAGS) $C\util2

$G/var.obj : $C\var.c $G\optab.c
	$(CC) -c -o$@ $(MFLAGS) -I$D -I$C -I$G $C\var

$G/varstats.obj : $C\varstats.c
	$(CC) -c -o$@ $(MFLAGS) -I$D -I$G $C\varstats


$G/tk.obj : $C\tk.c
	$(CC) -c -o$@ $(MFLAGS) $C\tk.c

# Root
$G\newdelete.obj : $(ROOT)\newdelete.c
	$(CC) -c -o$@ $(CFLAGS) $(ROOT)\newdelete.c

# Win64
$G\longdouble.obj : $(ROOT)\longdouble.c
	$(CC) -c -o$@ $(CFLAGS) $(ROOT)\longdouble.c

$G\ldfpu.obj : vcbuild\ldfpu.asm
	$(ML) -c -o$@ -Zi -Fo$G\ldfpu.obj vcbuild\ldfpu.asm

############################## Generated Rules ###############################

# These rules were generated by makedep, but are not currently maintained

