#_ win32.mak
# Copyright (C) 1999-2011 by Digital Mars, http://www.digitalmars.com
# Written by Walter Bright
# All Rights Reserved
# Build dmd with Digital Mars C++ compiler
#   http://www.digitalmars.com/ctg/sc.html
# This makefile is designed to be used with Digital Mars make.exe
#   http://www.digitalmars.com/ctg/make.html
# which should be in \dm\bin or in \dmd\windows\bin 

D=
DMDSVN=\svnproj\dmd\trunk\src
#DMDSVN=\svnproj\dmd\branches\dmd-1.x\src
SCROOT=$D\dm
INCLUDE=$(SCROOT)\include
CC=\dm\bin\dmc
LIBNT=$(SCROOT)\lib
SNN=$(SCROOT)\lib\snn
DIR=\dmd2
CP=cp

C=backend
TK=tk
ROOT=root

MAKE=make -fwin32.mak C=$C TK=$(TK) ROOT=$(ROOT)

TARGET=dmd
XFLG=
MODEL=n
OPT=
DEBUG=-gl -D -DUNITTEST
#PREC=-H -HItotal.h -HO
PREC=
LFLAGS=

LINKN=$(SCROOT)\bin\link /de

CFLAGS=-I$(ROOT);$(INCLUDE) $(XFLG) $(OPT) $(DEBUG) -cpp
MFLAGS=-I$C;$(TK) -DMARS -cpp $(DEBUG) -e -wx

# Makerules:
.c.obj:
	$(CC) -c $(CFLAGS) $(PREC) $*

.asm.obj:
	$(CC) -c $(CFLAGS) $*

defaulttarget: debdmd

################ RELEASES #########################

release:
	$(MAKE) clean
	$(MAKE) dmd
	$(MAKE) clean

################ NT COMMAND LINE RELEASE #########################

trace:
	$(MAKE) OPT=-o "DEBUG=-gt -Nc" LFLAGS=-L/ma/co/delexe dmd.exe

dmd:
	$(MAKE) OPT=-o "DEBUG=" LFLAGS=-L/delexe dmd.exe
#	$(MAKE) OPT=-o "DEBUG=" LFLAGS=-L/ma/co/delexe dmd.exe

################ NT COMMAND LINE DEBUG #########################

debdmd:
	$(MAKE) OPT= "DEBUG=-D -g -DUNITTEST" LFLAGS=-L/ma/co dmd.exe

#########################################

# D front end

OBJ1= mars.obj enum.obj struct.obj dsymbol.obj import.obj id.obj \
	staticassert.obj identifier.obj mtype.obj expression.obj \
	optimize.obj template.obj lexer.obj declaration.obj cast.obj \
	init.obj func.obj utf.obj unialpha.obj parse.obj statement.obj \
	constfold.obj version.obj inifile.obj typinf.obj \
	module.obj scope.obj dump.obj cond.obj inline.obj opover.obj \
	entity.obj class.obj mangle.obj attrib.obj impcnvtab.obj \
	link.obj access.obj doc.obj macro.obj hdrgen.obj delegatize.obj \
	interpret.obj traits.obj aliasthis.obj intrange.obj \
	builtin.obj clone.obj libomf.obj arrayop.obj irstate.obj \
	glue.obj msc.obj ph.obj tk.obj s2ir.obj todt.obj e2ir.obj tocsym.obj \
	util.obj eh.obj toobj.obj toctype.obj tocvdebug.obj toir.obj \
	json.obj unittests.obj imphint.obj argtypes.obj

# from C/C++ compiler optimizer and back end

OBJ8= go.obj gdag.obj gother.obj gflow.obj gloop.obj var.obj el.obj \
	newman.obj glocal.obj os.obj nteh.obj evalu8.obj cgcs.obj \
	rtlsym.obj html.obj cgelem.obj cgen.obj cgreg.obj out.obj \
	blockopt.obj cgobj.obj cg.obj cgcv.obj type.obj dt.obj \
	debug.obj code.obj cg87.obj cgsched.obj ee.obj csymbol.obj \
	cgcod.obj cod1.obj cod2.obj cod3.obj cod4.obj cod5.obj outbuf.obj \
	bcomplex.obj iasm.obj ptrntab.obj aa.obj ti_achar.obj md5.obj \
	ti_pvoid.obj

# from ROOT

ROOTOBJS= lstring.obj array.obj gnuc.obj man.obj rmem.obj port.obj root.obj \
	stringtable.obj dchar.obj response.obj async.obj speller.obj aav.obj

OBJS= $(OBJ1) $(OBJ8) $(ROOTOBJS)

SRCS= mars.c enum.c struct.c dsymbol.c import.c idgen.c impcnvgen.c utf.h \
	utf.c entity.c identifier.c mtype.c expression.c optimize.c \
	template.h template.c lexer.c declaration.c cast.c \
	cond.h cond.c link.c aggregate.h staticassert.h parse.c statement.c \
	constfold.c version.h version.c inifile.c iasm.c staticassert.c \
	module.c scope.c dump.c init.h init.c attrib.h attrib.c opover.c \
	eh.c toctype.c class.c mangle.c tocsym.c func.c inline.c \
	access.c complex_t.h unialpha.c irstate.h irstate.c glue.c msc.c \
	ph.c tk.c s2ir.c todt.c e2ir.c util.c toobj.c cppmangle.c \
	identifier.h parse.h scope.h enum.h import.h intrange.h \
	typinf.c tocvdebug.c toelfdebug.c mars.h module.h mtype.h dsymbol.h \
	declaration.h lexer.h expression.h statement.h doc.h doc.c \
	macro.h macro.c hdrgen.h hdrgen.c arraytypes.h \
	delegatize.c toir.h toir.c interpret.c traits.c builtin.c \
	clone.c lib.h libomf.c libelf.c libmach.c arrayop.c intrange.c \
	aliasthis.h aliasthis.c json.h json.c unittests.c imphint.c argtypes.c

# From C++ compiler

BACKSRC= $C\cdef.h $C\cc.h $C\oper.h $C\ty.h $C\optabgen.c \
	$C\global.h $C\code.h $C\type.h $C\dt.h $C\cgcv.h \
	$C\el.h $C\iasm.h $C\rtlsym.h $C\html.h \
	$C\bcomplex.c $C\blockopt.c $C\cg.c $C\cg87.c \
	$C\cgcod.c $C\cgcs.c $C\cgcv.c $C\cgelem.c $C\cgen.c $C\cgobj.c \
	$C\cgreg.c $C\var.c \
	$C\cgsched.c $C\cod1.c $C\cod2.c $C\cod3.c $C\cod4.c $C\cod5.c \
	$C\code.c $C\symbol.c $C\debug.c $C\dt.c $C\ee.c $C\el.c \
	$C\evalu8.c $C\go.c $C\gflow.c $C\gdag.c \
	$C\gother.c $C\glocal.c $C\gloop.c $C\html.c $C\newman.c \
	$C\nteh.c $C\os.c $C\out.c $C\outbuf.c $C\ptrntab.c $C\rtlsym.c \
	$C\type.c $C\melf.h $C\mach.h $C\bcomplex.h \
	$C\cdeflnx.h $C\outbuf.h $C\token.h $C\tassert.h \
	$C\elfobj.c $C\cv4.h $C\dwarf2.h $C\exh.h $C\go.h \
	$C\dwarf.c $C\dwarf.h $C\cppman.c $C\machobj.c \
	$C\strtold.c $C\aa.h $C\aa.c $C\tinfo.h $C\ti_achar.c \
	$C\md5.h $C\md5.c $C\ti_pvoid.c \
	$C\backend.txt

# From TK

TKSRC= $(TK)\filespec.h $(TK)\mem.h $(TK)\list.h $(TK)\vec.h \
	$(TK)\filespec.c $(TK)\mem.c $(TK)\vec.c $(TK)\list.c

# From root

ROOTSRC= $(ROOT)\dchar.h $(ROOT)\dchar.c $(ROOT)\lstring.h \
	$(ROOT)\lstring.c $(ROOT)\root.h $(ROOT)\root.c $(ROOT)\array.c \
	$(ROOT)\rmem.h $(ROOT)\rmem.c $(ROOT)\port.h \
	$(ROOT)\stringtable.h $(ROOT)\stringtable.c \
	$(ROOT)\gnuc.h $(ROOT)\gnuc.c $(ROOT)\man.c $(ROOT)\port.c \
	$(ROOT)\response.c $(ROOT)\async.h $(ROOT)\async.c \
	$(ROOT)\speller.h $(ROOT)\speller.c \
	$(ROOT)\aav.h $(ROOT)\aav.c

MAKEFILES=win32.mak posix.mak

#########################################

$(TARGET).exe : $(OBJS) win32.mak
	dmc -o$(TARGET).exe $(OBJS) -cpp -mn -Ar $(LFLAGS)


##################### INCLUDE MACROS #####################

CCH=
#TOTALH=$(CCH) total.sym
TOTALH=$(CCH) id.h
CH= $C\cc.h $C\global.h $C\oper.h $C\code.h $C\type.h $C\dt.h $C\cgcv.h $C\el.h $C\iasm.h

##################### GENERATED SOURCE #####################

msgs.h msgs.c sj1041.msg sj1036.msg sj1031.msg : msgsx.exe
	msgsx

msgsx.exe : msgsx.c
	dmc msgsx -mn -D$(TARGET) $(DEFINES) $(WINLIBS)

elxxx.c cdxxx.c optab.c debtab.c fltables.c tytab.c : \
	$C\cdef.h $C\cc.h $C\oper.h $C\ty.h $C\optabgen.c
	dmc -cpp -ooptabgen.exe $C\optabgen -DMARS -I$(TK) $(WINLIBS) #-L$(LINKS)
	optabgen

impcnvtab.c : impcnvgen.c
	$(CC) -I$(ROOT) -cpp impcnvgen
	impcnvgen

id.h id.c : idgen.c
	dmc -cpp idgen
	idgen

##################### SPECIAL BUILDS #####################

total.sym : $(ROOT)\root.h mars.h lexer.h parse.h enum.h dsymbol.h \
	mtype.h expression.h attrib.h init.h cond.h version.h \
	declaration.h statement.h scope.h import.h module.h id.h \
	template.h aggregate.h arraytypes.h lib.h total.h
	$(CC) -c $(CFLAGS) -HFtotal.sym total.h

impcnvtab.obj : mtype.h impcnvtab.c
	$(CC) -c -I$(ROOT) -cpp impcnvtab

iasm.obj : $(CH) $(TOTALH) $C\iasm.h iasm.c
	$(CC) -c $(MFLAGS) -I$(ROOT) iasm

bcomplex.obj : $C\bcomplex.c
	$(CC) -c $(MFLAGS) $C\bcomplex

aa.obj : $C\tinfo.h $C\aa.h $C\aa.c
	$(CC) -c $(MFLAGS) -I. $C\aa

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

debug.obj : $C\debug.c
	$(CC) -c $(MFLAGS) -I. $C\debug

dt.obj : $C\dt.h $C\dt.c
	$(CC) -c $(MFLAGS) $C\dt

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

html.obj : $(CH) $(TOTALH) $C\html.h $C\html.c
	$(CC) -c -I$(ROOT) $(MFLAGS) $C\html

imphint.obj : imphint.c
	$(CC) -c $(CFLAGS) $*

mars.obj : $(TOTALH) module.h mars.h mars.c
	$(CC) -c $(CFLAGS) $(PREC) $* -Ae

md5.obj : $C\md5.h $C\md5.c
	$(CC) -c $(MFLAGS) $C\md5

module.obj : $(TOTALH) $C\html.h module.c
	$(CC) -c $(CFLAGS) -I$C $(PREC) module.c

msc.obj : $(CH) mars.h msc.c
	$(CC) -c $(MFLAGS) msc

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

ph.obj : ph.c
	$(CC) -c $(MFLAGS) ph

ptrntab.obj : $C\iasm.h $C\ptrntab.c
	$(CC) -c $(MFLAGS) $C\ptrntab

rtlsym.obj : $C\rtlsym.h $C\rtlsym.c
	$(CC) -c $(MFLAGS) $C\rtlsym

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

s2ir.obj : $C\rtlsym.h statement.h s2ir.c
	$(CC) -c -I$(ROOT) $(MFLAGS) s2ir

e2ir.obj : $C\rtlsym.h expression.h toir.h e2ir.c
	$(CC) -c -I$(ROOT) $(MFLAGS) e2ir

toir.obj : $C\rtlsym.h expression.h toir.h toir.c
	$(CC) -c -I$(ROOT) $(MFLAGS) toir

tocsym.obj : $(CH) $(TOTALH) mars.h module.h tocsym.c
	$(CC) -c $(MFLAGS) -I$(ROOT) tocsym

unittests.obj : $(TOTALH) unittests.c
	$(CC) -c $(CFLAGS) $(PREC) $*

util.obj : util.c
	$(CC) -c $(MFLAGS) util

var.obj : $C\var.c optab.c
	$(CC) -c $(MFLAGS) -I. $C\var


tk.obj : tk.c
	$(CC) -c $(MFLAGS) tk.c

# ROOT

aav.obj : $(ROOT)\aav.h $(ROOT)\aav.c
	$(CC) -c $(CFLAGS) $(ROOT)\aav.c

array.obj : $(ROOT)\array.c
	$(CC) -c $(CFLAGS) $(ROOT)\array.c

async.obj : $(ROOT)\async.h $(ROOT)\async.c
	$(CC) -c $(CFLAGS) $(ROOT)\async.c

dchar.obj : $(ROOT)\dchar.c
	$(CC) -c $(CFLAGS) $(ROOT)\dchar.c

gnuc.obj : $(ROOT)\gnuc.c
	$(CC) -c $(CFLAGS) $(ROOT)\gnuc.c

lstring.obj : $(ROOT)\lstring.c
	$(CC) -c $(CFLAGS) $(ROOT)\lstring.c

man.obj : $(ROOT)\man.c
	$(CC) -c $(CFLAGS) $(ROOT)\man.c

rmem.obj : $(ROOT)\rmem.c
	$(CC) -c $(CFLAGS) $(ROOT)\rmem.c

port.obj : $(ROOT)\port.c
	$(CC) -c $(CFLAGS) $(ROOT)\port.c

root.obj : $(ROOT)\root.c
	$(CC) -c $(CFLAGS) $(ROOT)\root.c

response.obj : $(ROOT)\response.c
	$(CC) -c $(CFLAGS) $(ROOT)\response.c

speller.obj : $(ROOT)\speller.h $(ROOT)\speller.c
	$(CC) -c $(CFLAGS) $(ROOT)\speller.c

stringtable.obj : $(ROOT)\stringtable.c
	$(CC) -c $(CFLAGS) $(ROOT)\stringtable.c


################# Source file dependencies ###############

access.obj : $(TOTALH) enum.h aggregate.h init.h attrib.h access.c
aliasthis.obj : $(TOTALH) aliasthis.h aliasthis.c
argtypes.obj : $(TOTALH) mtype.h argtypes.c
arrayop.obj : $(TOTALH) identifier.h declaration.h arrayop.c
attrib.obj : $(TOTALH) identifier.h declaration.h attrib.h attrib.c
builtin.obj : $(TOTALH) builtin.c
cast.obj : $(TOTALH) expression.h mtype.h cast.c
class.obj : $(TOTALH) enum.h class.c
clone.obj : $(TOTALH) clone.c
constfold.obj : $(TOTALH) expression.h constfold.c
cond.obj : $(TOTALH) identifier.h declaration.h cond.h cond.c
declaration.obj : $(TOTALH) identifier.h attrib.h declaration.h declaration.c
delegatize.obj : $(TOTALH) delegatize.c
doc.obj : $(TOTALH) doc.h doc.c
enum.obj : $(TOTALH) identifier.h enum.h enum.c
expression.obj : $(TOTALH) expression.h expression.c
func.obj : $(TOTALH) identifier.h attrib.h declaration.h func.c
hdrgen.obj : $(TOTALH) hdrgen.h hdrgen.c
id.obj : $(TOTALH) id.h id.c
identifier.obj : $(TOTALH) identifier.h identifier.c
import.obj : $(TOTALH) dsymbol.h import.h import.c
inifile.obj : $(TOTALH) inifile.c
init.obj : $(TOTALH) init.h init.c
inline.obj : $(TOTALH) inline.c
interpret.obj : $(TOTALH) interpret.c declaration.h expression.h
intrange.obj : $(TOTALH) intrange.h intrange.c
json.obj : $(TOTALH) json.h json.c
lexer.obj : $(TOTALH) lexer.c
libomf.obj : $(TOTALH) lib.h libomf.c
link.obj : $(TOTALH) link.c
macro.obj : $(TOTALH) macro.h macro.c
mangle.obj : $(TOTALH) dsymbol.h declaration.h mangle.c
#module.obj : $(TOTALH) mars.h $C\html.h module.h module.c
opover.obj : $(TOTALH) expression.h opover.c
optimize.obj : $(TOTALH) expression.h optimize.c
parse.obj : $(TOTALH) attrib.h lexer.h parse.h parse.c
scope.obj : $(TOTALH) scope.h scope.c
statement.obj : $(TOTALH) statement.h statement.c
staticassert.obj : $(TOTALH) staticassert.h staticassert.c
struct.obj : $(TOTALH) identifier.h enum.h struct.c
traits.obj : $(TOTALH) traits.c
dsymbol.obj : $(TOTALH) identifier.h dsymbol.h dsymbol.c
mtype.obj : $(TOTALH) mtype.h mtype.c
#typinf.obj : $(TOTALH) mtype.h typinf.c
utf.obj : utf.h utf.c
template.obj : $(TOTALH) template.h template.c
version.obj : $(TOTALH) identifier.h dsymbol.h cond.h version.h version.c

################### Utilities ################

clean:
	del *.obj
	del total.sym
	del msgs.h msgs.c
	del elxxx.c cdxxx.c optab.c debtab.c fltables.c tytab.c
	del impcnvtab.c

zip : detab tolf $(MAKEFILES)
	del dmdsrc.zip
	zip32 dmdsrc $(MAKEFILES)
	zip32 dmdsrc $(SRCS)
	zip32 dmdsrc $(BACKSRC)
	zip32 dmdsrc $(TKSRC)
	zip32 dmdsrc $(ROOTSRC)

################### Detab ################

detab:
	detab $(SRCS) $(ROOTSRC) $(TKSRC) $(BACKSRC)

tolf:
	tolf $(SRCS) $(ROOTSRC) $(TKSRC) $(BACKSRC) $(MAKEFILES)

################### Install ################

install: detab install2

install2:
	copy dmd.exe $(DIR)\windows\bin\ 
	copy phobos\phobos.lib $(DIR)\windows\lib 
	$(CP) $(SRCS) $(DIR)\src\dmd\ 
	$(CP) $(ROOTSRC) $(DIR)\src\dmd\root\ 
	$(CP) $(TKSRC) $(DIR)\src\dmd\tk\  
	$(CP) $(BACKSRC) $(DIR)\src\dmd\backend\  
	$(CP) $(MAKEFILES) $(DIR)\src\dmd\  
	copy gpl.txt $(DIR)\src\dmd\ 
	copy readme.txt $(DIR)\src\dmd\ 
	copy artistic.txt $(DIR)\src\dmd\ 
	copy backendlicense.txt $(DIR)\src\dmd\ 

################### Write to SVN ################

svn:	detab tolf svn2

svn2:
	$(CP) $(SRCS) $(DMDSVN)\ 
	$(CP) $(ROOTSRC) $(DMDSVN)\root\ 
	$(CP) $(TKSRC) $(DMDSVN)\tk\  
	$(CP) $(BACKSRC) $(DMDSVN)\backend\  
	$(CP) $(MAKEFILES) $(DMDSVN)\  
	copy gpl.txt $(DMDSVN)\ 
	copy readme.txt $(DMDSVN)\ 
	copy artistic.txt $(DMDSVN)\ 
	copy backendlicense.txt $(DMDSVN)\ 

###################################
