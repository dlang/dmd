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

##### Tools

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
# D Model flags
DMODEL=
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
DMDMAKE=$(MAKE) -fwin32.mak C=$C TK=$(TK) ROOT=$(ROOT) MAKE="$(MAKE)" HOST_DC="$(HOST_DC)" DMODEL=$(DMODEL) CC="$(CC)" LIB="$(LIB)" OBJ_MSVC="$(OBJ_MSVC)"

############################### Rule Variables ###############################

# D front end
FRONT_SRCS=access.d aggregate.d aliasthis.d apply.d argtypes.d arrayop.d	\
	arraytypes.d attrib.d builtin.d canthrow.d clone.d complex.d		\
	cond.d constfold.d cppmangle.d ctfeexpr.d dcast.d dclass.d		\
	declaration.d delegatize.d denum.d dimport.d dinifile.d dinterpret.d	\
	dmacro.d dmangle.d dmodule.d doc.d dscope.d dstruct.d dsymbol.d		\
	dtemplate.d dversion.d entity.d errors.d escape.d			\
	expression.d func.d globals.d hdrgen.d id.d identifier.d imphint.d	\
	impcnvtab.d init.d inline.d intrange.d json.d lexer.d lib.d link.d	\
	mars.d mtype.d nogc.d nspace.d objc_stubs.d opover.d optimize.d parse.d	\
	sapply.d sideeffect.d statement.d staticassert.d target.d tokens.d	\
	safe.d \
	traits.d utf.d utils.d visitor.d libomf.d scanomf.d typinf.d \
	libmscoff.d scanmscoff.d statementsem.d

GLUE_SRCS=irstate.d toctype.d glue.d gluelayer.d todt.d tocsym.d toir.d dmsc.d

BACK_HDRS=$C/bcomplex.d $C/cc.d $C/cdef.d $C/cgcv.d $C/code.d $C/dt.d $C/el.d $C/global.d \
	$C/obj.d $C/oper.d $C/outbuf.d $C/rtlsym.d \
	$C/ty.d $C/type.d

TK_HDRS= $(TK)/dlist.d

DMD_SRCS=$(FRONT_SRCS) $(GLUE_SRCS) $(BACK_HDRS) $(TK_HDRS)

# Glue layer
GLUEOBJ= s2ir.obj e2ir.obj \
	toobj.obj tocvdebug.obj \
	iasm.obj objc_glue_stubs.obj

# D back end
BACKOBJ= go.obj gdag.obj gother.obj gflow.obj gloop.obj var.obj el.obj \
	newman.obj glocal.obj os.obj nteh.obj evalu8.obj cgcs.obj \
	rtlsym.obj cgelem.obj cgen.obj cgreg.obj out.obj \
	blockopt.obj cgobj.obj cg.obj cgcv.obj type.obj dt.obj \
	debug.obj code.obj cg87.obj cgxmm.obj cgsched.obj ee.obj csymbol.obj \
	cgcod.obj cod1.obj cod2.obj cod3.obj cod4.obj cod5.obj outbuf.obj \
	bcomplex.obj ptrntab.obj aa.obj ti_achar.obj md5.obj \
	ti_pvoid.obj mscoffobj.obj pdata.obj cv8.obj backconfig.obj \
	divcoeff.obj dwarf.obj compress.obj varstats.obj \
	ph2.obj util2.obj eh.obj tk.obj \

# Root package
ROOT_SRCS=$(ROOT)/aav.d $(ROOT)/array.d $(ROOT)/ctfloat.d $(ROOT)/file.d \
	$(ROOT)/filename.d $(ROOT)/man.d $(ROOT)/outbuffer.d $(ROOT)/port.d \
	$(ROOT)/response.d $(ROOT)/rmem.d $(ROOT)/rootobject.d \
	$(ROOT)/speller.d $(ROOT)/stringtable.d

# D front end
SRCS = aggregate.h aliasthis.h arraytypes.h	\
	attrib.h complex_t.h cond.h ctfe.h ctfe.h declaration.h dsymbol.h	\
	enum.h errors.h expression.h globals.h hdrgen.h identifier.h idgen.d	\
	import.h init.h intrange.h json.h lexer.h	\
	mars.h module.h mtype.h nspace.h objc.h                         \
	scope.h statement.h staticassert.h target.h template.h tokens.h	\
	version.h visitor.h objc.d $(DMD_SRCS)

# Glue layer
GLUESRC= s2ir.c e2ir.c \
	toobj.c tocvdebug.c toir.h \
	irstate.h iasm.c \
	toelfdebug.d libelf.d scanelf.d libmach.d scanmach.d \
	tk.c eh.c objc_glue_stubs.c objc_glue.c \
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
	$C\gother.c $C\glocal.c $C\gloop.c $C\newman.c \
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
ROOTSRCD=$(ROOT)\rmem.d $(ROOT)\stringtable.d $(ROOT)\man.d $(ROOT)\port.d \
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

defaulttarget: debdmd

auto-tester-build: dmd checkwhitespace dmd_frontend.exe

dmd: reldmd

release:
	$(DMDMAKE) clean
	$(DMDMAKE) reldmd
	$(DMDMAKE) clean

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
	$(LIB) -p512 -n -c glue.lib $(GLUEOBJ)

backend.lib : $(BACKOBJ) $(OBJ_MSVC)
	$(LIB) -p512 -n -c backend.lib $(BACKOBJ) $(OBJ_MSVC)

LIBS= glue.lib backend.lib

dmd_frontend.exe: $(FRONT_SRCS) gluelayer.d $(ROOT_SRCS) newdelete.obj verstr.h
	$(HOST_DC) $(DSRC) -of$@ -vtls -J. -L/STACK:8388608 $(DFLAGS) $(FRONT_SRCS) gluelayer.d $(ROOT_SRCS) newdelete.obj -version=NoBackend

$(TARGETEXE): $(DMD_SRCS) $(ROOT_SRCS) newdelete.obj $(LIBS) verstr.h
	$(HOST_DC) $(DSRC) -of$@ -vtls -J. -L/STACK:8388608 $(DFLAGS) $(DMD_SRCS) $(ROOT_SRCS) newdelete.obj $(LIBS)

############################ Maintenance Targets #############################

clean:
	$(DEL) *.obj *.lib *.map *.lst
	$(DEL) msgs.h msgs.c
	$(DEL) elxxx.c cdxxx.c optab.c debtab.c fltables.c tytab.c
	$(DEL) id.h id.d
	$(DEL) verstr.h
	$(DEL) optabgen.exe

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

checkwhitespace:
	$(HOST_DC) -run checkwhitespace $(SRCS) $(GLUESRC) $(ROOTSRC)

######################################################

..\changelog.html: ..\changelog.dd
	$(HOST_DC) -Df$@ $<

############################## Generated Source ##############################

elxxx.c cdxxx.c optab.c debtab.c fltables.c tytab.c : \
	$C\cdef.h $C\cc.h $C\oper.h $C\ty.h $C\optabgen.c
	$(CC) -cpp -ooptabgen.exe $C\optabgen -DMARS -DDM_TARGET_CPU_X86=1 -I$(TK)
	.\optabgen.exe

id.h id.d : idgen.d
	$(HOST_DC) -run idgen

verstr.h : ..\VERSION
	echo "$(..\VERSION)" >verstr.h

############################# Intermediate Rules ############################

# Default rules
.c.obj:
	$(CC) -c $(CFLAGS) $*

.asm.obj:
	$(CC) -c $(CFLAGS) $*

iasm.obj : $(CH) $C\iasm.h iasm.c
	$(CC) -c $(MFLAGS) -I$(ROOT) -Ae iasm

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

compress.obj : $C\compress.c
	$(CC) -c $(MFLAGS) $C\compress

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

glue.obj : $(CH) $C\rtlsym.h mars.h module.h glue.c
	$(CC) -c $(MFLAGS) -I$(ROOT) glue

md5.obj : $C\md5.h $C\md5.c
	$(CC) -c $(MFLAGS) $C\md5

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

strtold.obj : $C\strtold.c
	$(CC) -c -cpp $C\strtold

ti_achar.obj : $C\tinfo.h $C\ti_achar.c
	$(CC) -c $(MFLAGS) -I. $C\ti_achar

ti_pvoid.obj : $C\tinfo.h $C\ti_pvoid.c
	$(CC) -c $(MFLAGS) -I. $C\ti_pvoid

tocvdebug.obj : $(CH) $C\rtlsym.h mars.h module.h tocvdebug.c
	$(CC) -c $(MFLAGS) -I$(ROOT) tocvdebug

toobj.obj : $(CH) mars.h module.h toobj.c
	$(CC) -c $(MFLAGS) -I$(ROOT) toobj

type.obj : $C\type.c
	$(CC) -c $(MFLAGS) $C\type

s2ir.obj : $C\rtlsym.h statement.h s2ir.c visitor.h
	$(CC) -c -I$(ROOT) $(MFLAGS) s2ir

e2ir.obj : $C\rtlsym.h expression.h toir.h e2ir.c
	$(CC) -c -I$(ROOT) $(MFLAGS) e2ir

util2.obj : $C\util2.c
	$(CC) -c $(MFLAGS) $C\util2

var.obj : $C\var.c optab.c
	$(CC) -c $(MFLAGS) -I. $C\var

varstats.obj : $C\varstats.c
	$(CC) -c $(MFLAGS) -I. $C\varstats


tk.obj : tk.c
	$(CC) -c $(MFLAGS) tk.c

# Root
newdelete.obj : $(ROOT)\newdelete.c
	$(CC) -c $(CFLAGS) $(ROOT)\newdelete.c

# Win64
longdouble.obj : $(ROOT)\longdouble.c
	$(CC) -c $(CFLAGS) $(ROOT)\longdouble.c

ldfpu.obj : vcbuild\ldfpu.asm
	$(ML) -c -Zi -Foldfpu.obj vcbuild\ldfpu.asm

############################## Generated Rules ###############################

# These rules were generated by makedep, but are not currently maintained

objc_glue_stubs.obj : objc.h objc_glue_stubs.c
