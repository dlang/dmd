# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib
CC=cl

_MSC_VER = $(file < ..\..\ver.txt)

TESTS= array allocator new string vector

test: $(TESTS)

$(TESTS):
	"$(CC)" -c /Fo$@_cpp.obj test\stdcpp\src\$@.cpp /EHsc /MT
	"$(DMD)" -of=$@.exe -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest -version=_MSC_VER_$(_MSC_VER) -mscrtlib=libcmt test\stdcpp\src\$@_test.d $@_cpp.obj
	$@.exe
	del $@.exe $@.obj $@_cpp.obj

	"$(CC)" -c /Fo$@_cpp.obj test\stdcpp\src\$@.cpp /EHsc /MD
	"$(DMD)" -of=$@.exe -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest -version=_MSC_VER_$(_MSC_VER) -mscrtlib=msvcrt test\stdcpp\src\$@_test.d $@_cpp.obj
	$@.exe
	del $@.exe $@.obj $@_cpp.obj

	"$(CC)" -c /Fo$@_cpp.obj test\stdcpp\src\$@.cpp /EHsc /MTd
	"$(DMD)" -of=$@.exe -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest -version=_MSC_VER_$(_MSC_VER) -mscrtlib=libcmtd test\stdcpp\src\$@_test.d $@_cpp.obj
	$@.exe
	del $@.exe $@.obj $@_cpp.obj

	"$(CC)" -c /Fo$@_cpp.obj test\stdcpp\src\$@.cpp /EHsc /MDd
	"$(DMD)" -of=$@.exe -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest -version=_MSC_VER_$(_MSC_VER) -mscrtlib=msvcrtd test\stdcpp\src\$@_test.d $@_cpp.obj
	$@.exe
	del $@.exe $@.obj $@_cpp.obj
