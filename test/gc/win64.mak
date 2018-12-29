# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib

SRC = src/gc/impl/conservative/gc.d src/rt/lifetime.d src/object.d
UDFLAGS = -m$(MODEL) -g -unittest -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main

test: sentinel

sentinel:
	$(DMD) -debug=SENTINEL $(UDFLAGS) -of$@.exe $(SRC)
	$@.exe
	del $@.exe $@.obj
