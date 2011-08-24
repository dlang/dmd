# NOTE: need to validate solaris behavior
ifeq (,$(TARGET))
    OS:=$(shell uname)
    OSVER:=$(shell uname -r)
    ifeq (Darwin,$(OS))
        TARGET=OSX
    else
        ifeq (Linux,$(OS))
            TARGET=LINUX
        else
            ifeq (FreeBSD,$(OS))
                TARGET=FREEBSD
            else
                ifeq (OpenBSD,$(OS))
                    TARGET=OPENBSD
                else
                    ifeq (Solaris,$(OS))
                        TARGET=SOLARIS
                    else
                        $(error Unrecognized or unsupported OS for uname: $(OS))
                    endif
                endif
            endif
        endif
    endif
endif

C=backend
TK=tk
ROOT=root

MODEL=32

ifeq (OSX,$(TARGET))
    ## See: http://developer.apple.com/documentation/developertools/conceptual/cross_development/Using/chapter_3_section_2.html#//apple_ref/doc/uid/20002000-1114311-BABGCAAB
    ENVP= MACOSX_DEPLOYMENT_TARGET=10.3
    #SDK=/Developer/SDKs/MacOSX10.4u.sdk #doesn't work because can't find <stdarg.h>
    #SDK=/Developer/SDKs/MacOSX10.5.sdk
    #SDK=/Developer/SDKs/MacOSX10.6.sdk
    SDK:=$(if $(filter 11.*, $(OSVER)), /Developer/SDKs/MacOSX10.5.sdk, /Developer/SDKs/MacOSX10.6.sdk)
    TARGET_CFLAGS=-isysroot ${SDK}
    #-syslibroot is only passed to libtool, not ld.
    #if gcc sees -isysroot it should pass -syslibroot to the linker when needed
    #LDFLAGS=-lstdc++ -isysroot ${SDK} -Wl,-syslibroot,${SDK} -framework CoreServices
    LDFLAGS=-lstdc++ -isysroot ${SDK} -Wl -framework CoreServices
else
    LDFLAGS=-lm -lstdc++ -lpthread
endif

CC=g++ -m$(MODEL) $(TARGET_CFLAGS)

#OPT=-g -g3
#OPT=-O2

#COV=-fprofile-arcs -ftest-coverage

WARNINGS=-Wno-deprecated -Wstrict-aliasing

#GFLAGS = $(WARNINGS) -D__near= -D__pascal= -fno-exceptions -g -DDEBUG=1 -DUNITTEST $(COV)
GFLAGS = $(WARNINGS) -D__near= -D__pascal= -fno-exceptions -O2

CFLAGS = $(GFLAGS) -I$(ROOT) -DMARS=1 -DTARGET_$(TARGET)=1
MFLAGS = $(GFLAGS) -I$C -I$(TK) -DMARS=1 -DTARGET_$(TARGET)=1

CH= $C/cc.h $C/global.h $C/oper.h $C/code.h $C/type.h \
	$C/dt.h $C/cgcv.h $C/el.h $C/iasm.h

DMD_OBJS = \
	access.o array.o attrib.o bcomplex.o blockopt.o \
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
	builtin.o clone.o aliasthis.o intrange.o \
	man.o arrayop.o port.o response.o async.o json.o speller.o aav.o unittests.o \
	imphint.o argtypes.o ti_pvoid.o

ifeq (OSX,$(TARGET))
    DMD_OBJS += libmach.o machobj.o
else
    DMD_OBJS += libelf.o elfobj.o
endif

SRC = win32.mak posix.mak \
	mars.c enum.c struct.c dsymbol.c import.c idgen.c impcnvgen.c \
	identifier.c mtype.c expression.c optimize.c template.h \
	template.c lexer.c declaration.c cast.c cond.h cond.c link.c \
	aggregate.h parse.c statement.c constfold.c version.h version.c \
	inifile.c iasm.c module.c scope.c dump.c init.h init.c attrib.h \
	attrib.c opover.c class.c mangle.c tocsym.c func.c inline.c \
	access.c complex_t.h irstate.h irstate.c glue.c msc.c ph.c tk.c \
	s2ir.c todt.c e2ir.c util.c identifier.h parse.h intrange.h \
	scope.h enum.h import.h mars.h module.h mtype.h dsymbol.h \
	declaration.h lexer.h expression.h irstate.h statement.h eh.c \
	utf.h utf.c staticassert.h staticassert.c unialpha.c \
	typinf.c toobj.c toctype.c tocvdebug.c toelfdebug.c entity.c \
	doc.h doc.c macro.h macro.c hdrgen.h hdrgen.c arraytypes.h \
	delegatize.c toir.h toir.c interpret.c traits.c cppmangle.c \
	builtin.c clone.c lib.h libomf.c libelf.c libmach.c arrayop.c \
	aliasthis.h aliasthis.c json.h json.c unittests.c imphint.c \
	argtypes.c intrange.c \
	$C/cdef.h $C/cc.h $C/oper.h $C/ty.h $C/optabgen.c \
	$C/global.h $C/code.h $C/type.h $C/dt.h $C/cgcv.h \
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
	$C/elfobj.c $C/cv4.h $C/dwarf2.h $C/exh.h $C/go.h \
	$C/dwarf.c $C/dwarf.h $C/aa.h $C/aa.c $C/tinfo.h $C/ti_achar.c \
	$C/ti_pvoid.c \
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
	$(ENVP) g++ -o dmd -m$(MODEL) $(COV) $(DMD_OBJS) $(LDFLAGS)

clean:
	rm -f $(DMD_OBJS) dmd optab.o id.o impcnvgen idgen id.c id.h \
	impcnvtab.c optabgen debtab.c optab.c cdxxx.c elxxx.c fltables.c \
	tytab.c core \
	*.cov *.gcda *.gcno

######## optabgen generates some source

optabgen: $C/optabgen.c $C/cc.h $C/oper.h
	$(ENVP) $(CC) $(MFLAGS) $< -o optabgen
	./optabgen

optabgen_output = debtab.c optab.c cdxxx.c elxxx.c fltables.c tytab.c
$(optabgen_output) : optabgen

######## idgen generates some source

idgen_output = id.h id.c
$(idgen_output) : idgen

idgen : idgen.c
	$(ENVP) $(CC) idgen.c -o idgen
	./idgen

######### impcnvgen generates some source

impcnvtab_output = impcnvtab.c
$(impcnvtab_output) : impcnvgen

impcnvgen : mtype.h impcnvgen.c
	$(ENVP) $(CC) $(CFLAGS) impcnvgen.c -o impcnvgen
	./impcnvgen

#########

$(DMD_OBJS) : $(idgen_output) $(optabgen_output) $(impcnvgen_output)

aa.o: $C/aa.c $C/aa.h $C/tinfo.h
	$(CC) -c $(MFLAGS) -I. $<

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

blockopt.o: $C/blockopt.c
	$(CC) -c $(MFLAGS) $<

builtin.o: builtin.c
	$(CC) -c $(CFLAGS) $<

cast.o: cast.c
	$(CC) -c $(CFLAGS) $<

cg.o: $C/cg.c fltables.c
	$(CC) -c $(MFLAGS) -I. $<

cg87.o: $C/cg87.c
	$(CC) -c $(MFLAGS) $<

cgcod.o: $C/cgcod.c
	$(CC) -c $(MFLAGS) -I. $<

cgcs.o: $C/cgcs.c
	$(CC) -c $(MFLAGS) $<

cgcv.o: $C/cgcv.c
	$(CC) -c $(MFLAGS) $<

cgelem.o: $C/cgelem.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) -I. $<

cgen.o: $C/cgen.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $<

cgobj.o: $C/cgobj.c
	$(CC) -c $(MFLAGS) $<

cgreg.o: $C/cgreg.c
	$(CC) -c $(MFLAGS) $<

cgsched.o: $C/cgsched.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $<

class.o: class.c
	$(CC) -c $(CFLAGS) $<

clone.o: clone.c
	$(CC) -c $(CFLAGS) $<

cod1.o: $C/cod1.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $<

cod2.o: $C/cod2.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $<

cod3.o: $C/cod3.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $<

cod4.o: $C/cod4.c
	$(CC) -c $(MFLAGS) $<

cod5.o: $C/cod5.c
	$(CC) -c $(MFLAGS) $<

code.o: $C/code.c
	$(CC) -c $(MFLAGS) $<

constfold.o: constfold.c
	$(CC) -c $(CFLAGS) $<

irstate.o: irstate.c irstate.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

csymbol.o: $C/symbol.c
	$(CC) -c $(MFLAGS) $< -o $@

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

dt.o: $C/dt.c $C/dt.h
	$(CC) -c $(MFLAGS) $<

dump.o: dump.c
	$(CC) -c $(CFLAGS) $<

dwarf.o: $C/dwarf.c $C/dwarf.h
	$(CC) -c $(MFLAGS) -I. $<

e2ir.o: e2ir.c $C/rtlsym.h expression.h toir.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

ee.o: $C/ee.c
	$(CC) -c $(MFLAGS) $<

eh.o: eh.c $C/cc.h $C/code.h $C/type.h $C/dt.h
	$(CC) -c $(MFLAGS) $<

el.o: $C/el.c $C/rtlsym.h $C/el.h
	$(CC) -c $(MFLAGS) $<

elfobj.o: $C/elfobj.c
	$(CC) -c $(MFLAGS) $<

entity.o: entity.c
	$(CC) -c $(CFLAGS) $<

enum.o: enum.c
	$(CC) -c $(CFLAGS) $<

evalu8.o: $C/evalu8.c
	$(CC) -c $(MFLAGS) $<

expression.o: expression.c expression.h
	$(CC) -c $(CFLAGS) $<

func.o: func.c
	$(CC) -c $(CFLAGS) $<

gdag.o: $C/gdag.c
	$(CC) -c $(MFLAGS) $<

gflow.o: $C/gflow.c
	$(CC) -c $(MFLAGS) $<

#globals.o: globals.c
#	$(CC) -c $(CFLAGS) $<

glocal.o: $C/glocal.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $<

gloop.o: $C/gloop.c
	$(CC) -c $(MFLAGS) $<

glue.o: glue.c $(CH) $C/rtlsym.h mars.h module.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

gnuc.o: $(ROOT)/gnuc.c $(ROOT)/gnuc.h
	$(CC) -c $(GFLAGS) $<

go.o: $C/go.c
	$(CC) -c $(MFLAGS) $<

gother.o: $C/gother.c
	$(CC) -c $(MFLAGS) $<

hdrgen.o: hdrgen.c
	$(CC) -c $(CFLAGS) $<

html.o: $C/html.c $(CH) $C/html.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

iasm.o: iasm.c $(CH) $C/iasm.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

id.o: id.c id.h
	$(CC) -c $(CFLAGS) $<

identifier.o: identifier.c
	$(CC) -c $(CFLAGS) $<

impcnvtab.o: impcnvtab.c mtype.h
	$(CC) -c $(CFLAGS) -I$(ROOT) $<

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

intrange.o: intrange.h intrange.c
	$(CC) -c $(CFLAGS) intrange.c

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
	$(CC) -c $(MFLAGS) -I. $<

macro.o: macro.c
	$(CC) -c $(CFLAGS) $<

man.o: $(ROOT)/man.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

mangle.o: mangle.c
	$(CC) -c $(CFLAGS) $<

mars.o: mars.c
	$(CC) -c $(CFLAGS) $<

rmem.o: $(ROOT)/rmem.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

module.o: module.c $C/html.h
	$(CC) -c $(CFLAGS) -I$C $<

msc.o: msc.c $(CH) mars.h
	$(CC) -c $(MFLAGS) $<

mtype.o: mtype.c
	$(CC) -c $(CFLAGS) $<

nteh.o: $C/nteh.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $<

opover.o: opover.c
	$(CC) -c $(CFLAGS) $<

optimize.o: optimize.c
	$(CC) -c $(CFLAGS) $<

os.o: $C/os.c
	$(CC) -c $(MFLAGS) $<

out.o: $C/out.c
	$(CC) -c $(MFLAGS) $<

outbuf.o: $C/outbuf.c $C/outbuf.h
	$(CC) -c $(MFLAGS) $<

parse.o: parse.c
	$(CC) -c $(CFLAGS) $<

ph.o: ph.c
	$(CC) -c $(MFLAGS) $<

port.o: $(ROOT)/port.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

ptrntab.o: $C/ptrntab.c $C/iasm.h
	$(CC) -c $(MFLAGS) $<

response.o: $(ROOT)/response.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

root.o: $(ROOT)/root.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

rtlsym.o: $C/rtlsym.c $C/rtlsym.h
	$(CC) -c $(MFLAGS) $<

s2ir.o: s2ir.c $C/rtlsym.h statement.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

scope.o: scope.c
	$(CC) -c $(CFLAGS) $<

speller.o: $(ROOT)/speller.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

statement.o: statement.c
	$(CC) -c $(CFLAGS) $<

staticassert.o: staticassert.c staticassert.h
	$(CC) -c $(CFLAGS) $<

stringtable.o: $(ROOT)/stringtable.c
	$(CC) -c $(GFLAGS) -I$(ROOT) $<

strtold.o: $C/strtold.c
	gcc -m$(MODEL) -c $<

struct.o: struct.c
	$(CC) -c $(CFLAGS) $<

template.o: template.c
	$(CC) -c $(CFLAGS) $<

ti_achar.o: $C/ti_achar.c $C/tinfo.h
	$(CC) -c $(MFLAGS) -I. $<

ti_pvoid.o: $C/ti_pvoid.c $C/tinfo.h
	$(CC) -c $(MFLAGS) -I. $<

tk.o: tk.c
	$(CC) -c $(MFLAGS) $<

tocsym.o: tocsym.c $(CH) mars.h module.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

toctype.o: toctype.c $(CH) $C/rtlsym.h mars.h module.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

todt.o: todt.c mtype.h expression.h $C/dt.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

toelfdebug.o: toelfdebug.c $(CH) mars.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

toir.o: toir.c $C/rtlsym.h expression.h toir.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

toobj.o: toobj.c $(CH) mars.h module.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

traits.o: traits.c
	$(CC) -c $(CFLAGS) $<

type.o: $C/type.c
	$(CC) -c $(MFLAGS) $<

typinf.o: typinf.c $(CH) mars.h module.h mtype.h
	$(CC) -c $(MFLAGS) -I$(ROOT) $<

util.o: util.c
	$(CC) -c $(MFLAGS) $<

utf.o: utf.c utf.h
	$(CC) -c $(CFLAGS) $<

unialpha.o: unialpha.c
	$(CC) -c $(CFLAGS) $<

unittests.o: unittests.c
	$(CC) -c $(CFLAGS) $<

var.o: $C/var.c optab.c
	$(CC) -c $(MFLAGS) -I. $<

version.o: version.c
	$(CC) -c $(CFLAGS) $<

######################################################

gcov:
	gcov access.c
	gcov aliasthis.c
	gcov arrayop.c
	gcov attrib.c
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
ifeq (OSX,$(TARGET))
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
	gcov intrange.c

#	gcov hdrgen.c
#	gcov tocvdebug.c

######################################################

zip:
	-rm -f dmdsrc.zip
	zip dmdsrc $(SRC)
