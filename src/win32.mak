#_ win32.mak
#
# Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
# All Rights Reserved
# written by Walter Bright
# http://www.digitalmars.com
# Distributed under the Boost Software License, Version 1.0.
# http://www.boost.org/LICENSE_1_0.txt
# https://github.com/D-Programming-Language/dmd/blob/master/src/win32.mak
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
#   https://github.com/D-Programming-Language/tools.
#
# install target - requires Phobos (.\phobos.lib)
#   https://github.com/D-Programming-Language/phobos
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

# fixed model for win32.mak
MODEL=32
BUILD=release
OS=windows

##### Directories

# DMC directory
DMCROOT=$(DM_HOME)\dm
# DMD source directories
C=backend
TK=tk
ROOT=root
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

# C++ compiler
CC=dmc
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

##### User configuration switches

# Target name
TARGET=dmd
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
# D Debug flags
DDEBUG=-debug -g

##### Implementation variables (do not modify)

# Compile flags
CFLAGS=-I$(INCLUDE) $(OPT) $(CFLAGS) $(DEBUG) -cpp -DTARGET_WINDOS=1 -DDM_TARGET_CPU_X86=1
# Compile flags for modules with backend/toolkit dependencies
MFLAGS=-I$C;$(TK) $(OPT) -DMARS -cpp $(DEBUG) -e -wx -DTARGET_WINDOS=1 -DDM_TARGET_CPU_X86=1
# D compile flags
DFLAGS=$(DOPT) $(DDEBUG)
# Recursive make
DMDMAKE=$(MAKE) -fwin32.mak C=$C TK=$(TK) ROOT=$(ROOT) MODEL=$(MODEL) CC="$(CC)" LIB="$(LIB)"

############################### Rule Variables ###############################

# D front end
# mars.obj
FRONTOBJ= denum.obj dstruct.obj dsymbol.obj dimport.obj id.obj \
	staticassert.obj staticcond.obj identifier.obj mtype.obj expression.obj \
	optimize.obj dtemplate.obj lexer.obj declaration.obj dcast.obj \
	init.obj initsem.obj func.obj nogc.obj utf.obj parse.obj statement.obj \
	constfold.obj dversion.obj inifile.obj compiler.obj cppmanglewin.obj \
	dmodule.obj dscope.obj cond.obj inline.obj inlinecost.obj opover.obj \
	entity.obj dclass.obj dmangle.obj attrib.obj impcnvtab.obj \
	link.obj access.obj doc.obj dmacro.obj hdrgen.obj delegatize.obj \
	dinterpret.obj ctfeexpr.obj traits.obj aliasthis.obj \
	builtin.obj clone.obj arrayop.obj \
	json.obj unittests.obj imphint.obj argtypes.obj apply.obj sapply.obj \
	safe.obj sideeffect.obj intrange.obj blockexit.obj canthrow.obj target.obj nspace.obj \
	objc.obj errors.obj escape.obj tokens.obj globals.obj \
	utils.obj expressionsem.obj statementsem.obj templateparamsem.obj typesem.obj

# Glue layer
GLUEOBJ=glue.obj msc.obj s2ir.obj todt.obj e2ir.obj tocsym.obj \
	toobj.obj toctype.obj tocvdebug.obj toir.obj \
	libmscoff.obj scanmscoff.obj irstate.obj typinf.obj \
	libomf.obj scanomf.obj iasm.obj iasmdmd.obj objc_glue_stubs.obj

#GLUEOBJ=gluestub.obj

# D back end
BACKOBJ= go.obj gdag.obj gother.obj gflow.obj gloop.obj var.obj el.obj \
	newman.obj glocal.obj os.obj nteh.obj evalu8.obj cgcs.obj \
	rtlsym.obj cgelem.obj cgen.obj cgreg.obj out.obj \
	blockopt.obj cgobj.obj cg.obj cgcv.obj type.obj dt.obj \
	debug.obj code.obj cg87.obj cgxmm.obj cgsched.obj ee.obj csymbol.obj \
	cgcod.obj cod1.obj cod2.obj cod3.obj cod4.obj cod5.obj outbuf.obj \
	bcomplex.obj ptrntab.obj aa.obj ti_achar.obj md5.obj \
	ti_pvoid.obj mscoffobj.obj pdata.obj cv8.obj backconfig.obj \
	divcoeff.obj dwarf.obj \
	ph2.obj util2.obj eh.obj tk.obj \


# Root package
ROOTOBJS= man.obj port.obj checkedint.obj \
	stringtable.obj response.obj speller.obj aav.obj outbuffer.obj \
	rootobject.obj filename.obj file.obj \
	rmem.obj newdelete.obj ctfloat.obj

# D front end
SRCS= mars.c denum.c dstruct.c dsymbol.c dimport.c idgen.c impcnvgen.c utf.h \
	utf.c entity.c identifier.c mtype.c expression.c optimize.c \
	template.h dtemplate.c lexer.c declaration.c dcast.c \
	cond.h cond.c link.c aggregate.h staticassert.h parse.c statement.c \
	constfold.c version.h dversion.c inifile.c staticassert.c staticcond.c \
	dmodule.c dscope.c init.h init.c initsem.c attrib.h attrib.c opover.c \
	dclass.c dmangle.c func.c nogc.c inline.c inlinecost.c access.c complex_t.h \
	compiler.c cppmanglewin.c identifier.h parse.h scope.h enum.h import.h \
	mars.h module.h mtype.h dsymbol.h \
	declaration.h lexer.h expression.h statement.h doc.h doc.c \
	macro.h dmacro.c hdrgen.h hdrgen.c arraytypes.h \
	delegatize.c dinterpret.c ctfeexpr.c traits.c builtin.c \
	clone.c lib.h arrayop.c nspace.h nspace.c objc.c errors.h errors.c escape.c \
	aliasthis.h aliasthis.c json.h json.c unittests.c imphint.c argtypes.c \
	apply.c sapply.c safe.c sideeffect.c ctfe.h \
	intrange.h intrange.c blockexit.c canthrow.c target.c target.h visitor.h \
	tokens.h tokens.c globals.h globals.c objc.h objc.c \
	utils.c expressionsem.c statementsem.c templateparamsem.c typesem.c

# Glue layer
GLUESRC= glue.c msc.c s2ir.c todt.c e2ir.c tocsym.c \
	toobj.c toctype.c tocvdebug.c toir.h toir.c \
	libmscoff.c scanmscoff.c irstate.h irstate.c typinf.c iasm.c iasmdmd.c \
	toelfdebug.c libomf.c scanomf.c libelf.c scanelf.c libmach.c scanmach.c \
	tk.c eh.c gluestub.c objc_glue_stubs.c objc_glue.c

# D back end
BACKSRC= $C\cdef.h $C\cc.h $C\oper.h $C\ty.h $C\optabgen.c \
	$C\global.h $C\code.h $C\code_x86.h $C/code_stub.h $C/platform_stub.c \
	$C\type.h $C\dt.h $C\cgcv.h \
	$C\el.h $C\iasm.h $C\rtlsym.h \
	$C\bcomplex.c $C\blockopt.c $C\cg.c $C\cg87.c $C\cgxmm.c \
	$C\cgcod.c $C\cgcs.c $C\cgcv.c $C\cgelem.c $C\cgen.c $C\cgobj.c \
	$C\cgreg.c $C\var.c \
	$C\cgsched.c $C\cod1.c $C\cod2.c $C\cod3.c $C\cod4.c $C\cod5.c \
	$C\code.c $C\symbol.c $C\debug.c $C\dt.c $C\ee.c $C\el.c \
	$C\evalu8.c $C\go.c $C\gflow.c $C\gdag.c \
	$C\gother.c $C\glocal.c $C\gloop.c $C\newman.c \
	$C\nteh.c $C\os.c $C\out.c $C\outbuf.c $C\ptrntab.c $C\rtlsym.c \
	$C\type.c $C\melf.h $C\mach.h $C\mscoff.h $C\bcomplex.h \
	$C\outbuf.h $C\token.h $C\tassert.h \
	$C\elfobj.c $C\cv4.h $C\dwarf2.h $C\exh.h $C\go.h \
	$C\dwarf.c $C\dwarf.h $C\machobj.c \
	$C\strtold.c $C\aa.h $C\aa.c $C\tinfo.h $C\ti_achar.c \
	$C\md5.h $C\md5.c $C\ti_pvoid.c $C\xmm.h $C\ph2.c $C\util2.c \
	$C\mscoffobj.c $C\obj.h $C\pdata.c $C\cv8.c $C\backconfig.c \
	$C\divcoeff.c $C\dwarfeh.c \
	$C\backend.txt

# Toolkit
TKSRCC=	$(TK)\filespec.c $(TK)\mem.c $(TK)\vec.c $(TK)\list.c
TKSRC= $(TK)\filespec.h $(TK)\mem.h $(TK)\list.h $(TK)\vec.h $(TKSRCC)

# Root package
ROOTSRCC=$(ROOT)\rmem.c $(ROOT)\stringtable.c \
	$(ROOT)\man.c $(ROOT)\port.c $(ROOT)\response.c \
	$(ROOT)\speller.c $(ROOT)\aav.c $(ROOT)\longdouble.c \
	$(ROOT)\checkedint.c $(ROOT)\newdelete.c \
	$(ROOT)\outbuffer.c $(ROOT)\rootobject.c $(ROOT)\filename.c $(ROOT)\file.c
ROOTSRC= $(ROOT)\root.h \
	$(ROOT)\rmem.h $(ROOT)\port.h \
	$(ROOT)\stringtable.h \
	$(ROOT)\checkedint.h \
	$(ROOT)\speller.h \
	$(ROOT)\aav.h \
	$(ROOT)\longdouble.h \
	$(ROOT)\outbuffer.h \
	$(ROOT)\object.h \
	$(ROOT)\filename.h \
	$(ROOT)\file.h \
	$(ROOT)\array.h \
	$(ROOT)\ctfloat.h \
	$(ROOT)\hash.h \
	$(ROOTSRCC)
# Removed garbage collector bits (look in history)
#	$(ROOT)\gc\bits.c $(ROOT)\gc\gc.c $(ROOT)\gc\gc.h $(ROOT)\gc\mscbitops.h \
#	$(ROOT)\gc\bits.h $(ROOT)\gc\gccbitops.h $(ROOT)\gc\linux.c $(ROOT)\gc\os.h \
#	$(ROOT)\gc\win32.c

# Header files
TOTALH=id.h
CH= $C\cc.h $C\global.h $C\oper.h $C\code.h $C\code_x86.h $C\type.h $C\dt.h $C\cgcv.h \
	$C\el.h $C\iasm.h $C\obj.h

# Makefiles
MAKEFILES=win32.mak posix.mak osmodel.mak

############################## Release Targets ###############################

defaulttarget: $G debdmd

auto-tester-build: $G dmd

dmd: $G reldmd

release:
	$(DMDMAKE) clean
	$(DMDMAKE) reldmd
	$(DMDMAKE) clean

$G :
	if not exist "$G" mkdir $G

debdmd:
	$(DMDMAKE) "OPT=" "DEBUG=-D -g -DUNITTEST" "DDEBUG=-debug -g" "DOPT=" "LFLAGS=-L/ma/co/la" $(TARGETEXE)

reldmd:
	$(DMDMAKE) "OPT=-o" "DEBUG=" "DDEBUG=" "DOPT=-inline -O" "LFLAGS=-L/delexe/la" $(TARGETEXE)

trace:
	$(DMDMAKE) "OPT=-o" "DEBUG=-gt -Nc" "DDEBUG=-debug -g" "DOPT=" "LFLAGS=-L/ma/co/delexe/la" $(TARGETEXE)

################################ Libraries ##################################

frontend.lib : $(FRONTOBJ)
	$(LIB) -p512 -n -c frontend.lib $(FRONTOBJ)

glue.lib : $(GLUEOBJ)
	$(LIB) -p512 -n -c glue.lib $(GLUEOBJ)

backend.lib : $(BACKOBJ)
	$(LIB) -p512 -n -c backend.lib $(BACKOBJ)

root.lib : $(ROOTOBJS)
	$(LIB) -p512 -n -c root.lib $(ROOTOBJS)

LIBS= frontend.lib glue.lib backend.lib root.lib

$(TARGETEXE): mars.obj $(LIBS) win32.mak
	$(CC) -o$(TARGETEXE) mars.obj $(LIBS) -cpp -mn -Ar -L/STACK:8388608 $(LFLAGS)
	$(CP) $(TARGETEXE) $(G)\$(TARGETEXE)

############################ Maintenance Targets #############################

clean:
	$(DEL) *.obj *.lib *.map
	$(DEL) msgs.h msgs.c
	$(DEL) elxxx.c cdxxx.c optab.c debtab.c fltables.c tytab.c
	$(DEL) impcnvtab.d impcnvtab.c impcnvgen.exe optabgen.exe
	$(DEL) id.h id.c id.d
	$(DEL) verstr.h
	$(DEL) $(GENSRC)

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
	$(CP) readme.txt            $(INSTALL)\src\dmd\readme.txt
	$(CP) boostlicense.txt      $(INSTALL)\src\dmd\boostlicense.txt
	$(CP) backendlicense.txt    $(INSTALL)\src\dmd\backendlicense.txt

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

############################## Generated Source ##############################

elxxx.c cdxxx.c optab.c debtab.c fltables.c tytab.c : \
	$C\cdef.h $C\cc.h $C\oper.h $C\ty.h $C\optabgen.c
	$(CC) -cpp -ooptabgen.exe $C\optabgen -DMARS -DDM_TARGET_CPU_X86=1 -I$(TK)
	.\optabgen.exe

impcnvtab.c impcnvtab.d : impcnvgen.c
	$(CC) -I$(ROOT) -cpp -DDM_TARGET_CPU_X86=1 impcnvgen
	.\impcnvgen.exe

id.h id.c id.d : idgen.c
	$(CC) -cpp -DDM_TARGET_CPU_X86=1 idgen
	.\idgen.exe

verstr.h : ..\VERSION
	echo "$(..\VERSION)" >verstr.h

############################# Intermediate Rules ############################

# Default rules
.c.obj:
	$(CC) -c $(CFLAGS) $*

.asm.obj:
	$(CC) -c $(CFLAGS) $*

# Generated source
impcnvtab.obj : mtype.h impcnvtab.c
	$(CC) -c -I$(ROOT) -cpp impcnvtab

iasm.obj : $(CH) $(TOTALH) $C\iasm.h iasm.c
	$(CC) -c $(MFLAGS) -I$(ROOT) -Ae iasm

iasmdmd.obj : $(CH) $(TOTALH) $C\iasm.h iasmdmd.c
	$(CC) -c $(MFLAGS) -I$(ROOT) -Ae iasmdmd

# D front/back end
bcomplex.obj : $C\bcomplex.c
	$(CC) -c $(MFLAGS) $C\bcomplex

aa.obj : $C\tinfo.h $C\aa.h $C\aa.c
	$(CC) -c $(MFLAGS) -I. $C\aa

backconfig.obj : $C\backconfig.c
	$(CC) -c $(MFLAGS) $C\backconfig

blockopt.obj : $C\blockopt.c
	$(CC) -c $(MFLAGS) $C\blockopt

cg.obj : $C\cg.c
	$(CC) -c $(MFLAGS) -I. $C\cg

cg87.obj : $C\cg87.c
	$(CC) -c $(MFLAGS) $C\cg87

cgcod.obj : $C\cgcod.c
	$(CC) -c $(MFLAGS) -I. $C\cgcod

cgcs.obj : $C\cgcs.c
	$(CC) -c $(MFLAGS) $C\cgcs

cgcv.obj : $C\cgcv.c
	$(CC) -c $(MFLAGS) $C\cgcv

cgelem.obj : $C\rtlsym.h $C\cgelem.c
	$(CC) -c $(MFLAGS) -I. $C\cgelem

cgen.obj : $C\rtlsym.h $C\cgen.c
	$(CC) -c $(MFLAGS) $C\cgen

cgobj.obj : $C\md5.h $C\cgobj.c
	$(CC) -c $(MFLAGS) $C\cgobj

cgreg.obj : $C\cgreg.c
	$(CC) -c $(MFLAGS) $C\cgreg

cgsched.obj : $C\rtlsym.h $C\cgsched.c
	$(CC) -c $(MFLAGS) $C\cgsched

cgxmm.obj : $C\xmm.h $C\cgxmm.c
	$(CC) -c $(MFLAGS) $C\cgxmm

cod1.obj : $C\rtlsym.h $C\cod1.c
	$(CC) -c $(MFLAGS) $C\cod1

cod2.obj : $C\rtlsym.h $C\cod2.c
	$(CC) -c $(MFLAGS) $C\cod2

cod3.obj : $C\rtlsym.h $C\cod3.c
	$(CC) -c $(MFLAGS) $C\cod3

cod4.obj : $C\cod4.c
	$(CC) -c $(MFLAGS) $C\cod4

cod5.obj : $C\cod5.c
	$(CC) -c $(MFLAGS) $C\cod5

code.obj : $C\code.c
	$(CC) -c $(MFLAGS) $C\code

irstate.obj : irstate.h irstate.c
	$(CC) -c $(MFLAGS) -I$(ROOT) irstate

csymbol.obj : $C\symbol.c
	$(CC) -c $(MFLAGS) $C\symbol -ocsymbol.obj

cv8.obj : $C\cv8.c
	$(CC) -c $(MFLAGS) $C\cv8

debug.obj : $C\debug.c
	$(CC) -c $(MFLAGS) -I. $C\debug

divcoeff.obj : $C\divcoeff.c
	$(CC) -c -cpp -e $(DEBUG) $C\divcoeff

dt.obj : $C\dt.h $C\dt.c
	$(CC) -c $(MFLAGS) $C\dt

dwarf.obj : $C\dwarf.h $C\dwarf.c
	$(CC) -c $(MFLAGS) $C\dwarf

ee.obj : $C\ee.c
	$(CC) -c $(MFLAGS) $C\ee

eh.obj : $C\cc.h $C\code.h $C\type.h $C\dt.h eh.c
	$(CC) -c $(MFLAGS) eh

el.obj : $C\rtlsym.h $C\el.h $C\el.c
	$(CC) -c $(MFLAGS) $C\el

evalu8.obj : $C\evalu8.c
	$(CC) -c $(MFLAGS) $C\evalu8

go.obj : $C\go.c
	$(CC) -c $(MFLAGS) $C\go

gflow.obj : $C\gflow.c
	$(CC) -c $(MFLAGS) $C\gflow

gdag.obj : $C\gdag.c
	$(CC) -c $(MFLAGS) $C\gdag

gother.obj : $C\gother.c
	$(CC) -c $(MFLAGS) $C\gother

glocal.obj : $C\rtlsym.h $C\glocal.c
	$(CC) -c $(MFLAGS) $C\glocal

gloop.obj : $C\gloop.c
	$(CC) -c $(MFLAGS) $C\gloop

glue.obj : $(CH) $(TOTALH) $C\rtlsym.h mars.h module.h glue.c
	$(CC) -c $(MFLAGS) -I$(ROOT) glue

gluestub.obj : $(CH) $(TOTALH) $C\rtlsym.h mars.h module.h gluestub.c
	$(CC) -c $(MFLAGS) -I$(ROOT) gluestub

imphint.obj : imphint.c
	$(CC) -c $(CFLAGS) $*

mars.obj : $(TOTALH) module.h mars.h mars.c verstr.h
	$(CC) -c $(CFLAGS) $* -Ae

md5.obj : $C\md5.h $C\md5.c
	$(CC) -c $(MFLAGS) $C\md5

dmodule.obj : $(TOTALH) dmodule.c
	$(CC) -c $(CFLAGS) -I$C dmodule.c

msc.obj : $(CH) mars.h msc.c
	$(CC) -c $(MFLAGS) -I$(ROOT) msc

mscoffobj.obj : $C\mscoff.h $C\mscoffobj.c
	$(CC) -c $(MFLAGS) -I.;$(ROOT) $C\mscoffobj

newman.obj : $(CH) $C\newman.c
	$(CC) -c $(MFLAGS) $C\newman

nteh.obj : $C\rtlsym.h $C\nteh.c
	$(CC) -c $(MFLAGS) $C\nteh

os.obj : $C\os.c
	$(CC) -c $(MFLAGS) $C\os

out.obj : $C\out.c
	$(CC) -c $(MFLAGS) $C\out

outbuf.obj : $C\outbuf.h $C\outbuf.c
	$(CC) -c $(MFLAGS) $C\outbuf

pdata.obj : $C\pdata.c
	$(CC) -c $(MFLAGS) $C\pdata

ph2.obj : $C\ph2.c
	$(CC) -c $(MFLAGS) $C\ph2

ptrntab.obj : $C\iasm.h $C\ptrntab.c
	$(CC) -c $(MFLAGS) $C\ptrntab

rtlsym.obj : $C\rtlsym.h $C\rtlsym.c
	$(CC) -c $(MFLAGS) $C\rtlsym

scanmscoff.obj : $(TOTALH) $C\mscoff.h scanmscoff.c
	$(CC) -c $(CFLAGS) -I.;$(ROOT);$C scanmscoff.c

ti_achar.obj : $C\tinfo.h $C\ti_achar.c
	$(CC) -c $(MFLAGS) -I. $C\ti_achar

ti_pvoid.obj : $C\tinfo.h $C\ti_pvoid.c
	$(CC) -c $(MFLAGS) -I. $C\ti_pvoid

toctype.obj : $(CH) $(TOTALH) $C\rtlsym.h mars.h module.h toctype.c
	$(CC) -c $(MFLAGS) -I$(ROOT) toctype

tocvdebug.obj : $(CH) $(TOTALH) $C\rtlsym.h mars.h module.h tocvdebug.c
	$(CC) -c $(MFLAGS) -I$(ROOT) tocvdebug

toobj.obj : $(CH) $(TOTALH) mars.h module.h toobj.c
	$(CC) -c $(MFLAGS) -I$(ROOT) toobj

type.obj : $C\type.c
	$(CC) -c $(MFLAGS) $C\type

typinf.obj : $(CH) $(TOTALH) $C\rtlsym.h mars.h module.h typinf.c
	$(CC) -c $(MFLAGS) -I$(ROOT) typinf

todt.obj : mtype.h expression.h $C\dt.h todt.c
	$(CC) -c -I$(ROOT) $(MFLAGS) todt

s2ir.obj : $C\rtlsym.h statement.h s2ir.c visitor.h
	$(CC) -c -I$(ROOT) $(MFLAGS) s2ir

e2ir.obj : $C\rtlsym.h expression.h toir.h e2ir.c
	$(CC) -c -I$(ROOT) $(MFLAGS) e2ir

toir.obj : $C\rtlsym.h expression.h toir.h toir.c
	$(CC) -c -I$(ROOT) $(MFLAGS) toir

tocsym.obj : $(CH) $(TOTALH) mars.h module.h tocsym.c
	$(CC) -c $(MFLAGS) -I$(ROOT) tocsym

unittests.obj : $(TOTALH) unittests.c
	$(CC) -c $(CFLAGS) $*

util2.obj : $C\util2.c
	$(CC) -c $(MFLAGS) $C\util2

var.obj : $C\var.c optab.c
	$(CC) -c $(MFLAGS) -I. $C\var


tk.obj : tk.c
	$(CC) -c $(MFLAGS) tk.c

# Root
aav.obj : $(ROOT)\aav.h $(ROOT)\aav.c
	$(CC) -c $(CFLAGS) $(ROOT)\aav.c

checkedint.obj : $(ROOT)\checkedint.h $(ROOT)\checkedint.c
	$(CC) -c $(CFLAGS) $(ROOT)\checkedint.c

dmgcmem.obj : $(ROOT)\dmgcmem.c
	$(CC) -c $(CFLAGS) $(ROOT)\dmgcmem.c

man.obj : $(ROOT)\man.c
	$(CC) -c $(CFLAGS) $(ROOT)\man.c

rmem.obj : $(ROOT)\rmem.c
	$(CC) -c $(CFLAGS) $(ROOT)\rmem.c

newdelete.obj : $(ROOT)\newdelete.c
	$(CC) -c $(CFLAGS) $(ROOT)\newdelete.c

port.obj : $(ROOT)\port.c
	$(CC) -c $(CFLAGS) $(ROOT)\port.c

response.obj : $(ROOT)\response.c
	$(CC) -c $(CFLAGS) $(ROOT)\response.c

speller.obj : $(ROOT)\speller.h $(ROOT)\speller.c
	$(CC) -c $(CFLAGS) $(ROOT)\speller.c

stringtable.obj : $(ROOT)\stringtable.c
	$(CC) -c $(CFLAGS) $(ROOT)\stringtable.c

outbuffer.obj : $(ROOT)\outbuffer.c
	$(CC) -c $(CFLAGS) $(ROOT)\outbuffer.c

rootobject.obj : $(ROOT)\rootobject.c
	$(CC) -c $(CFLAGS) $(ROOT)\rootobject.c

filename.obj : $(ROOT)\filename.c
	$(CC) -c $(CFLAGS) $(ROOT)\filename.c

file.obj : $(ROOT)\file.c
	$(CC) -c $(CFLAGS) $(ROOT)\file.c

ctfloat.obj : $(ROOT)\ctfloat.c
	$(CC) -c $(CFLAGS) $(ROOT)\ctfloat.c

# Root/GC -- Removed (look in history)
#
#bits.obj : $(ROOT)\gc\bits.h $(ROOT)\gc\bits.c
#	$(CC) -c $(CFLAGS) -I$(ROOT)\gc $(ROOT)\gc\bits.c
#
#gc.obj : $(ROOT)\gc\bits.h $(ROOT)\gc\os.h $(ROOT)\gc\gc.h $(ROOT)\gc\gc.c
#	$(CC) -c $(CFLAGS) -I$(ROOT)\gc $(ROOT)\gc\gc.c
#
#win32.obj : $(ROOT)\gc\os.h $(ROOT)\gc\win32.c
#	$(CC) -c $(CFLAGS) -I$(ROOT)\gc $(ROOT)\gc\win32.c

############################## Generated Rules ###############################

# These rules were generated by makedep, but are not currently maintained

access.obj : $(TOTALH) enum.h objc.h aggregate.h init.h attrib.h access.c
aliasthis.obj : $(TOTALH) aliasthis.h aliasthis.c
apply.obj : $(TOTALH) apply.c
argtypes.obj : $(TOTALH) mtype.h argtypes.c
arrayop.obj : $(TOTALH) identifier.h declaration.h arrayop.c
attrib.obj : $(TOTALH) dsymbol.h identifier.h declaration.h attrib.h attrib.c
builtin.obj : $(TOTALH) builtin.c
blockexit.obj : $(TOTALH) blockexit.c
canthrow.obj : $(TOTALH) canthrow.c
dcast.obj : $(TOTALH) expression.h mtype.h dcast.c
dclass.obj : $(TOTALH) enum.h dclass.c
clone.obj : $(TOTALH) clone.c
constfold.obj : $(TOTALH) expression.h constfold.c
cond.obj : $(TOTALH) identifier.h declaration.h cond.h cond.c
compiler.obj : $(TOTALH) compiler.c
cppmanglewin.obj : $(TOTALH) mtype.h declaration.h mars.h
declaration.obj : $(TOTALH) identifier.h attrib.h declaration.h declaration.c expression.h
delegatize.obj : $(TOTALH) delegatize.c
doc.obj : $(TOTALH) doc.h doc.c
denum.obj : $(TOTALH) dsymbol.h identifier.h enum.h denum.c
errors.obj : $(TOTALH) errors.h errors.c
escape.obj : $(TOTALH) escape.c
expression.obj : $(TOTALH) expression.h expression.c
func.obj : $(TOTALH) identifier.h attrib.h declaration.h func.c
globals.obj : $(TOTALH) globals.h globals.c
hdrgen.obj : $(TOTALH) hdrgen.h hdrgen.c
id.obj : $(TOTALH) id.h id.c
identifier.obj : $(TOTALH) identifier.h identifier.c
dimport.obj : $(TOTALH) dsymbol.h import.h dimport.c
inifile.obj : $(TOTALH) inifile.c
init.obj : $(TOTALH) init.h init.c
init.obj : $(TOTALH) init.h initsem.c
inline.obj : $(TOTALH) inline.c
inlinecost.obj : $(TOTALH) inlinecost.c
dinterpret.obj : $(TOTALH) dinterpret.c declaration.h expression.h ctfe.h
ctfexpr.obj : $(TOTALH) ctfeexpr.c ctfe.h
intrange.obj : $(TOTALH) intrange.h intrange.c
json.obj : $(TOTALH) json.h json.c
lexer.obj : $(TOTALH) lexer.c
libmscoff.obj : $(TOTALH) lib.h libmscoff.c
libomf.obj : $(TOTALH) lib.h libomf.c
link.obj : $(TOTALH) link.c
dmacro.obj : $(TOTALH) macro.h dmacro.c
dmangle.obj : $(TOTALH) dsymbol.h declaration.h dmangle.c
nspace.obj : $(TOTALH) nspace.c
objc.obj : $(TOTALH) objc.c
objc_glue_stubs.obj : $(TOTALH) objc.h objc_glue_stubs.c
opover.obj : $(TOTALH) expression.h opover.c
optimize.obj : $(TOTALH) expression.h optimize.c
parse.obj : $(TOTALH) attrib.h lexer.h parse.h parse.c
sapply.obj : $(TOTALH) sapply.c
scanomf.obj : $(TOTALH) lib.h scanomf.c
dscope.obj : $(TOTALH) scope.h dscope.c
safe.obj : $(TOTALH) safe.c
sideeffect.obj : $(TOTALH) sideeffect.c
statement.obj : $(TOTALH) statement.h statement.c expression.h
staticassert.obj : $(TOTALH) staticassert.h staticassert.c
staticcond.obj : $(TOTALH) staticassert.h staticcond.c
dstruct.obj : $(TOTALH) identifier.h enum.h dstruct.c
target.obj : $(TOTALH) target.c target.h
tokens.obj : $(TOTALH) tokens.h tokens.c
traits.obj : $(TOTALH) traits.c
dsymbol.obj : $(TOTALH) identifier.h dsymbol.h dsymbol.c
mtype.obj : $(TOTALH) mtype.h mtype.c
utf.obj : utf.h utf.c
dtemplate.obj : $(TOTALH) template.h dtemplate.c
dversion.obj : $(TOTALH) identifier.h dsymbol.h cond.h version.h dversion.c
utils.obj : $(TOTALH) utils.c
expressionsem.obj : $(TOTALH) expressionsem.c
statementsem.obj : $(TOTALH) statementsem.c
templateparamsem.obj : $(TOTALH) templateparamsem.c
typesem.obj : $(TOTALH) typesem.c
