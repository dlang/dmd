
C=backend
TK=tk
ROOT=root

MODEL=-m32

CC=g++ $(MODEL)

#OPT=-g -g3
#OPT=-O2

#COV=-fprofile-arcs -ftest-coverage

WARNINGS=-Wno-deprecated -Wstrict-aliasing

#GFLAGS = $(WARNINGS) -D__near= -D__pascal= -fno-exceptions -g -DDEBUG=1 $(COV)
GFLAGS = $(WARNINGS) -D__near= -D__pascal= -fno-exceptions -O2

CFLAGS = $(GFLAGS) -I$(ROOT) -D__I86__=1 -DMARS=1 -DTARGET_LINUX=1 -D_DH
MFLAGS = $(GFLAGS) -I$C -I$(TK) -D__I86__=1 -DMARS=1 -DTARGET_LINUX=1 -D_DH

CH= $C/cc.h $C/global.h $C/parser.h $C/oper.h $C/code.h $C/type.h \
	$C/dt.h $C/cgcv.h $C/el.h $C/iasm.h
TOTALH=

DMD_OBJS = \
	access.o array.o attrib.o bcomplex.o bit.o blockopt.o \
	cast.o code.o cg.o cg87.o cgcod.o cgcs.o cgelem.o cgen.o \
	cgreg.o cgsched.o class.o cod1.o cod2.o cod3.o cod4.o cod5.o \
	constfold.o irstate.o dchar.o cond.o debug.o \
	declaration.o dsymbol.o dt.o dump.o e2ir.o ee.o eh.o el.o \
	dwarf.o enum.o evalu8.o expression.o func.o gdag.o gflow.o \
	glocal.o gloop.o glue.o gnuc.o go.o gother.o html.o iasm.o id.o \
	identifier.o impcnvtab.o import.o inifile.o init.o inline.o \
	lexer.o link.o lstring.o mangle.o mars.o rmem.o module.o msc.o mtype.o \
	nteh.o cppmangle.o opover.o optimize.o os.o out.o outbuf.o \
	parse.o ph.o ptrntab.o root.o rtlsym.o s2ir.o scope.o statement.o \
	stringtable.o struct.o csymbol.o template.o tk.o tocsym.o todt.o \
	type.o typinf.o util.o var.o version.o strtold.o utf.o staticassert.o \
	unialpha.o toobj.o toctype.o toelfdebug.o entity.o doc.o macro.o \
	hdrgen.o delegatize.o aa.o ti_achar.o toir.o interpret.o traits.o \
	builtin.o clone.o aliasthis.o \
	man.o arrayop.o port.o response.o async.o json.o speller.o aav.o unittests.o \
	imphint.o argtypes.o \
	libelf.o elfobj.o

SRC = win32.mak linux.mak osx.mak freebsd.mak solaris.mak \
	mars.c enum.c struct.c dsymbol.c import.c idgen.c impcnvgen.c \
	identifier.c mtype.c expression.c optimize.c template.h \
	template.c lexer.c declaration.c cast.c cond.h cond.c link.c \
	aggregate.h parse.c statement.c constfold.c version.h version.c \
	inifile.c iasm.c module.c scope.c dump.c init.h init.c attrib.h \
	attrib.c opover.c class.c mangle.c bit.c tocsym.c func.c inline.c \
	access.c complex_t.h irstate.h irstate.c glue.c msc.c ph.c tk.c \
	s2ir.c todt.c e2ir.c util.c identifier.h parse.h \
	scope.h enum.h import.h mars.h module.h mtype.h dsymbol.h \
	declaration.h lexer.h expression.h irstate.h statement.h eh.c \
	utf.h utf.c staticassert.h staticassert.c unialpha.c \
	typinf.c toobj.c toctype.c tocvdebug.c toelfdebug.c entity.c \
	doc.h doc.c macro.h macro.c hdrgen.h hdrgen.c arraytypes.h \
	delegatize.c toir.h toir.c interpret.c traits.c cppmangle.c \
	builtin.c clone.c lib.h libomf.c libelf.c libmach.c arrayop.c \
	aliasthis.h aliasthis.c json.h json.c unittests.c imphint.c \
	argtypes.c \
	$C/cdef.h $C/cc.h $C/oper.h $C/ty.h $C/optabgen.c \
	$C/global.h $C/parser.h $C/code.h $C/type.h $C/dt.h $C/cgcv.h \
	$C/el.h $C/iasm.h $C/rtlsym.h $C/html.h \
	$C/bcomplex.c $C/blockopt.c $C/cg.c $C/cg87.c \
	$C/cgcod.c $C/cgcs.c $C/cgcv.c $C/cgelem.c $C/cgen.c $C/cgobj.c \
	$C/cgreg.c $C/var.c $C/strtold.c \
	$C/cgsched.c $C/cod1.c $C/cod2.c $C/cod3.c $C/cod4.c $C/cod5.c \
	$C/code.c $C/symbol.c $C/debug.c $C/dt.c $C/ee.c $C/el.c \
	$C/evalu8.c $C/go.c $C/gflow.c $C/gdag.c \
	$C/gother.c $C/glocal.c $C/gloop.c $C/html.c $C/newman.c \
	$C/nteh.c $C/os.c $C/out.c $C/outbuf.c $C/ptrntab.c $C/rtlsym.c \
	$C/type.c $C/melf.h $C/mach.h $C/bcomplex.h \
	$C/cdeflnx.h $C/outbuf.h $C/token.h $C/tassert.h \
	$C/elfobj.c $C/cv4.h $C/dwarf2.h $C/cpp.h $C/exh.h $C/go.h \
	$C/dwarf.c $C/dwarf.h $C/aa.h $C/aa.c $C/tinfo.h $C/ti_achar.c \
	$C/machobj.c \
	$(TK)/filespec.h $(TK)/mem.h $(TK)/list.h $(TK)/vec.h \
	$(TK)/filespec.c $(TK)/mem.c $(TK)/vec.c $(TK)/list.c \
	$(ROOT)/dchar.h $(ROOT)/dchar.c $(ROOT)/lstring.h \
	$(ROOT)/lstring.c $(ROOT)/root.h $(ROOT)/root.c $(ROOT)/array.c \
	$(ROOT)/rmem.h $(ROOT)/rmem.c $(ROOT)/port.h $(ROOT)/port.c \
	$(ROOT)/gnuc.h $(ROOT)/gnuc.c $(ROOT)/man.c \
	$(ROOT)/stringtable.h $(ROOT)/stringtable.c \
	$(ROOT)/response.c $(ROOT)/async.h $(ROOT)/async.c \
	$(ROOT)/aav.h $(ROOT)/aav.c \
	$(ROOT)/speller.h $(ROOT)/speller.c


all: dmd

dmd: $(DMD_OBJS)
	gcc $(MODEL) -lstdc++ -lpthread $(COV) $(DMD_OBJS) -o dmd

clean:
	rm -f $(DMD_OBJS) dmd optab.o id.o impcnvgen idgen id.c id.h \
	impcnvtab.c optabgen debtab.c optab.c cdxxx.c elxxx.c fltables.c \
	tytab.c core \
	*.cov *.gcda *.gcno

######## optabgen generates some source

optabgen: $C/optabgen.c $C/cc.h $C/oper.h
	$(CC) $(MFLAGS) $< -o optabgen
	./optabgen

optabgen_output = debtab.c optab.c cdxxx.c elxxx.c fltables.c tytab.c
$(optabgen_output) : optabgen

######## idgen generates some source

idgen_output = id.h id.c
$(idgen_output) : idgen

idgen : idgen.c
	$(CC) idgen.c -o idgen
	./idgen

######### impcnvgen generates some source

impcnvtab_output = impcnvtab.c
$(impcnvtab_output) : impcnvgen

impcnvgen : mtype.h impcnvgen.c
	$(CC) $(CFLAGS) impcnvgen.c -o impcnvgen
	./impcnvgen

#########

$(DMD_OBJS) : $(idgen_output) $(optabgen_output) $(impcnvgen_output)

aa.o: $C/aa.h $C/tinfo.h $C/aa.c
	$(CC) -c $(MFLAGS) -I. $C/aa.c

aav.o: $(ROOT)/aav.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

access.o: access.c
	$(CC) -c $(CFLAGS) $<

aliasthis.o: aliasthis.c
	$(CC) -c $(CFLAGS) $<

argtypes.o: argtypes.c
	$(CC) -c $(CFLAGS) $<

array.o: $(ROOT)/array.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

arrayop.o: arrayop.c
	$(CC) -c $(CFLAGS) $<

async.o: $(ROOT)/async.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

attrib.o: attrib.c
	$(CC) -c $(CFLAGS) $<

bcomplex.o: $C/bcomplex.c
	$(CC) -c $(MFLAGS) $<

bit.o: expression.h bit.c
	$(CC) -c -I$(ROOT) $(MFLAGS) bit.c

blockopt.o: $C/blockopt.c
	$(CC) -c $(MFLAGS) $C/blockopt.c

builtin.o: builtin.c
	$(CC) -c $(CFLAGS) $<

cast.o: cast.c
	$(CC) -c $(CFLAGS) $< 

cg.o: fltables.c $C/cg.c
	$(CC) -c $(MFLAGS) -I. $C/cg.c

cg87.o: $C/cg87.c
	$(CC) -c $(MFLAGS) $<

cgcod.o: $C/cgcod.c
	$(CC) -c $(MFLAGS) -I. $<

cgcs.o: $C/cgcs.c
	$(CC) -c $(MFLAGS) $<

cgcv.o: $C/cgcv.c
	$(CC) -c $(MFLAGS) $<

cgelem.o: $C/rtlsym.h $C/cgelem.c
	$(CC) -c $(MFLAGS) -I. $C/cgelem.c

cgen.o: $C/rtlsym.h $C/cgen.c
	$(CC) -c $(MFLAGS) $C/cgen.c

cgobj.o: $C/cgobj.c
	$(CC) -c $(MFLAGS) $<

cgreg.o: $C/cgreg.c
	$(CC) -c $(MFLAGS) $<

cgsched.o: $C/rtlsym.h $C/cgsched.c
	$(CC) -c $(MFLAGS) $C/cgsched.c

class.o: class.c
	$(CC) -c $(CFLAGS) $<

clone.o: clone.c
	$(CC) -c $(CFLAGS) $<

cod1.o: $C/rtlsym.h $C/cod1.c
	$(CC) -c $(MFLAGS) $C/cod1.c

cod2.o: $C/rtlsym.h $C/cod2.c
	$(CC) -c $(MFLAGS) $C/cod2.c

cod3.o: $C/rtlsym.h $C/cod3.c
	$(CC) -c $(MFLAGS) $C/cod3.c

cod4.o: $C/cod4.c
	$(CC) -c $(MFLAGS) $<

cod5.o: $C/cod5.c
	$(CC) -c $(MFLAGS) $<

code.o: $C/code.c
	$(CC) -c $(MFLAGS) $<

constfold.o: constfold.c
	$(CC) -c $(CFLAGS) $<

irstate.o: irstate.h irstate.c
	$(CC) -c $(MFLAGS) -I$(ROOT) irstate.c

csymbol.o : $C/symbol.c
	$(CC) -c $(MFLAGS) $C/symbol.c -o csymbol.o

dchar.o: $(ROOT)/dchar.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

cond.o: cond.c
	$(CC) -c $(CFLAGS) $<

cppmangle.o: cppmangle.c
	$(CC) -c $(CFLAGS) $<

debug.o: $C/debug.c
	$(CC) -c $(MFLAGS) -I. $<

declaration.o: declaration.c
	$(CC) -c $(CFLAGS) $<

delegatize.o: delegatize.c
	$(CC) -c $(CFLAGS) $<

doc.o: doc.c
	$(CC) -c $(CFLAGS) $<

dsymbol.o: dsymbol.c
	$(CC) -c $(CFLAGS) $<

dt.o: $C/dt.h $C/dt.c
	$(CC) -c $(MFLAGS) $C/dt.c

dump.o: dump.c
	$(CC) -c $(CFLAGS) $<

dwarf.o: $C/dwarf.h $C/dwarf.c
	$(CC) -c $(MFLAGS) -I. $C/dwarf.c

e2ir.o: $C/rtlsym.h expression.h toir.h e2ir.c
	$(CC) -c -I$(ROOT) $(MFLAGS) e2ir.c

ee.o: $C/ee.c
	$(CC) -c $(MFLAGS) $<

eh.o : $C/cc.h $C/code.h $C/type.h $C/dt.h eh.c
	$(CC) -c $(MFLAGS) eh.c

el.o: $C/rtlsym.h $C/el.h $C/el.c
	$(CC) -c $(MFLAGS) $C/el.c

elfobj.o: $C/elfobj.c
	$(CC) -c $(MFLAGS) $<

entity.o: entity.c
	$(CC) -c $(CFLAGS) $<

enum.o: enum.c
	$(CC) -c $(CFLAGS) $<

evalu8.o: $C/evalu8.c
	$(CC) -c $(MFLAGS) $<

expression.o: expression.c
	$(CC) -c $(CFLAGS) $<

func.o: func.c
	$(CC) -c $(CFLAGS) $<

gdag.o: $C/gdag.c
	$(CC) -c $(MFLAGS) $<

gflow.o: $C/gflow.c
	$(CC) -c $(MFLAGS) $<

#globals.o: globals.c
#	$(CC) -c $(CFLAGS) $<

glocal.o: $C/rtlsym.h $C/glocal.c
	$(CC) -c $(MFLAGS) $C/glocal.c

gloop.o: $C/gloop.c
	$(CC) -c $(MFLAGS) $<

glue.o: $(CH) $(TOTALH) $C/rtlsym.h mars.h module.h glue.c
	$(CC) -c $(MFLAGS) -I$(ROOT) glue.c

gnuc.o: $(ROOT)/gnuc.h $(ROOT)/gnuc.c
	$(CC) -c $(GFLAGS) $(ROOT)/gnuc.c

go.o: $C/go.c
	$(CC) -c $(MFLAGS) $<

gother.o: $C/gother.c
	$(CC) -c $(MFLAGS) $<

hdrgen.o: hdrgen.c
	$(CC) -c $(CFLAGS) $<

html.o: $(CH) $(TOTALH) $C/html.h $C/html.c
	$(CC) -c -I$(ROOT) $(MFLAGS) $C/html.c

iasm.o : $(CH) $(TOTALH) $C/iasm.h iasm.c
	$(CC) -c $(MFLAGS) -I$(ROOT) iasm.c

id.o : id.h id.c
	$(CC) -c $(CFLAGS) id.c

identifier.o: identifier.c
	$(CC) -c $(CFLAGS) $<

impcnvtab.o: mtype.h impcnvtab.c
	$(CC) -c $(CFLAGS) -I$(ROOT) impcnvtab.c

imphint.o: imphint.c
	$(CC) -c $(CFLAGS) $<

import.o: import.c
	$(CC) -c $(CFLAGS) $<

inifile.o: inifile.c
	$(CC) -c $(CFLAGS) $<

init.o: init.c
	$(CC) -c $(CFLAGS) $<

inline.o: inline.c
	$(CC) -c $(CFLAGS) $<

interpret.o: interpret.c
	$(CC) -c $(CFLAGS) $<

json.o: json.c
	$(CC) -c $(CFLAGS) $<

lexer.o: lexer.c
	$(CC) -c $(CFLAGS) $<

libelf.o: libelf.c $C/melf.h
	$(CC) -c $(CFLAGS) -I$C $<

libmach.o: libmach.c $C/mach.h
	$(CC) -c $(CFLAGS) -I$C $<

link.o: link.c
	$(CC) -c $(CFLAGS) $<

lstring.o: $(ROOT)/lstring.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

machobj.o: $C/machobj.c
	$(CC) -c $(MFLAGS) $<

macro.o: macro.c
	$(CC) -c $(CFLAGS) $<

man.o: $(ROOT)/man.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

mangle.o: mangle.c
	$(CC) -c $(CFLAGS) $<

mars.o: mars.c
	$(CC) -c $(CFLAGS) $<

rmem.o: $(ROOT)/rmem.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $(ROOT)/rmem.c
	
module.o: $(TOTALH) $C/html.h module.c
	$(CC) -c $(CFLAGS) -I$C module.c

msc.o: $(CH) mars.h msc.c
	$(CC) -c $(MFLAGS) msc.c

mtype.o: mtype.c
	$(CC) -c $(CFLAGS) $<

nteh.o: $C/rtlsym.h $C/nteh.c
	$(CC) -c $(MFLAGS) $C/nteh.c

opover.o: opover.c
	$(CC) -c $(CFLAGS) $<

optimize.o: optimize.c
	$(CC) -c $(CFLAGS) $<

os.o: $C/os.c
	$(CC) -c $(MFLAGS) $<

out.o: $C/out.c
	$(CC) -c $(MFLAGS) $<

outbuf.o : $C/outbuf.h $C/outbuf.c
	$(CC) -c $(MFLAGS) $C/outbuf.c

parse.o: parse.c
	$(CC) -c $(CFLAGS) $<

ph.o: ph.c
	$(CC) -c $(MFLAGS) $<

port.o: $(ROOT)/port.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

ptrntab.o: $C/iasm.h $C/ptrntab.c
	$(CC) -c $(MFLAGS) $C/ptrntab.c

response.o: $(ROOT)/response.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

root.o: $(ROOT)/root.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

rtlsym.o: $C/rtlsym.h $C/rtlsym.c
	$(CC) -c $(MFLAGS) $C/rtlsym.c

s2ir.o : $C/rtlsym.h statement.h s2ir.c
	$(CC) -c -I$(ROOT) $(MFLAGS) s2ir.c

scope.o: scope.c
	$(CC) -c $(CFLAGS) $<

speller.o: $(ROOT)/speller.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

statement.o: statement.c
	$(CC) -c $(CFLAGS) $<

staticassert.o: staticassert.h staticassert.c
	$(CC) -c $(CFLAGS) staticassert.c

stringtable.o: $(ROOT)/stringtable.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

strtold.o: $C/strtold.c
	gcc $(MODEL) -c $C/strtold.c

struct.o: struct.c
	$(CC) -c $(CFLAGS) $<

template.o: template.c
	$(CC) -c $(CFLAGS) $<

ti_achar.o: $C/tinfo.h $C/ti_achar.c
	$(CC) -c $(MFLAGS) -I. $C/ti_achar.c

tk.o: tk.c
	$(CC) -c $(MFLAGS) tk.c

tocsym.o: $(CH) $(TOTALH) mars.h module.h tocsym.c
	$(CC) -c $(MFLAGS) -I$(ROOT) tocsym.c

toctype.o: $(CH) $(TOTALH) $C/rtlsym.h mars.h module.h toctype.c
	$(CC) -c $(MFLAGS) -I$(ROOT) toctype.c

todt.o : mtype.h expression.h $C/dt.h todt.c
	$(CC) -c -I$(ROOT) $(MFLAGS) todt.c

toelfdebug.o: $(CH) $(TOTALH) mars.h toelfdebug.c
	$(CC) -c $(MFLAGS) -I$(ROOT) toelfdebug.c

toir.o: $C/rtlsym.h expression.h toir.h toir.c
	$(CC) -c -I$(ROOT) $(MFLAGS) toir.c

toobj.o: $(CH) $(TOTALH) mars.h module.h toobj.c
	$(CC) -c $(MFLAGS) -I$(ROOT) toobj.c

traits.o: $(TOTALH) traits.c
	$(CC) -c $(CFLAGS) $<

type.o: $C/type.c
	$(CC) -c $(MFLAGS) $C/type.c

typinf.o: $(CH) $(TOTALH) mars.h module.h mtype.h typinf.c
	$(CC) -c $(MFLAGS) -I$(ROOT) typinf.c

util.o: util.c
	$(CC) -c $(MFLAGS) $<

utf.o: utf.h utf.c
	$(CC) -c $(CFLAGS) utf.c

unialpha.o: unialpha.c
	$(CC) -c $(CFLAGS) $<

unittests.o: unittests.c
	$(CC) -c $(CFLAGS) $<

var.o: $C/var.c optab.c
	$(CC) -c $(MFLAGS) -I. $C/var.c

version.o: version.c
	$(CC) -c $(CFLAGS) $<

######################################################

gcov:
	gcov access.c
	gcov aliasthis.c
	gcov arrayop.c
	gcov attrib.c
	gcov bit.c
	gcov builtin.c
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
	gcov irstate.c
	gcov json.c
	gcov lexer.c
	gcov libelf.c
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
	gcov ph.c
	gcov scope.c
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
	gcov unialpha.c
	gcov utf.c
	gcov util.c
	gcov version.c

#	gcov hdrgen.c
#	gcov tocvdebug.c

######################################################

zip:
	-rm -f dmdsrc.zip
	zip dmdsrc $(SRC)
