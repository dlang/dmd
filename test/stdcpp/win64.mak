# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib
CC=cl

TESTS= array new

test: $(TESTS)

$(TESTS):
	"$(CC)" -c /Fo$@_cpp.obj test\stdcpp\src\$@.cpp /EHsc
	"$(DMD)" -of=$@.exe -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest test\stdcpp\src\$@_test.d $@_cpp.obj
	$@.exe
	del $@.exe $@.obj $@_cpp.obj
