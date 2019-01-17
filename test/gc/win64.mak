# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib

SRC_GC = src/gc/impl/conservative/gc.d
SRC = $(SRC_GC) src/rt/lifetime.d src/object.d
UDFLAGS = -m$(MODEL) -g -unittest -conf= -Isrc -defaultlib=$(DRUNTIMELIB)

test: sentinel printf memstomp invariant logging precise precisegc

sentinel:
	$(DMD) -debug=SENTINEL $(UDFLAGS) -main -of$@.exe $(SRC)
	.\$@.exe
	del $@.exe $@.obj $@.ilk $@.pdb

printf:
	$(DMD) -debug=PRINTF -debug=PRINTF_TO_FILE -debug=COLLECT_PRINTF $(UDFLAGS) -main -of$@.exe $(SRC_GC)
	.\$@.exe
	del $@.exe $@.obj $@.ilk $@.pdb gcx.log

memstomp:
	$(DMD) -debug=MEMSTOMP $(UDFLAGS) -main -of$@.exe $(SRC)
	.\$@.exe
	del $@.exe $@.obj $@.ilk $@.pdb

invariant:
	$(DMD) -debug -debug=INVARIANT -debug=PTRCHECK -debug=PTRCHECK2 $(UDFLAGS) -main -of$@.exe $(SRC)
	.\$@.exe
	del $@.exe $@.obj $@.ilk $@.pdb

logging:
	$(DMD) -debug=LOGGING $(UDFLAGS) -of$@.exe -main $(SRC)
	.\$@.exe
	del $@.exe $@.obj $@.ilk $@.pdb

precise:
	$(DMD) -debug -debug=INVARIANT -debug=MEMSTOMP $(UDFLAGS) -main -of$@.exe $(SRC)
	.\$@.exe --DRT-gcopt=gc:precise
	del $@.exe $@.obj $@.ilk $@.pdb

precisegc:
	$(DMD) $(UDFLAGS) -of$@.exe -gx $(SRC) test/gc/precisegc.d
	.\$@.exe
	del $@.exe $@.obj $@.ilk $@.pdb
