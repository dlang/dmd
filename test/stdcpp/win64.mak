# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib
CC=cl

TESTS=array allocator new string utility vector

_MSC_VER=$(file < ..\..\ver.txt)
ADD_CFLAGS=$(file < ..\..\cflags.txt)
ADD_DFLAGS=$(file < ..\..\dflags.txt)
ADD_TESTS=$(file < ..\..\add_tests.txt)

TESTS=$(TESTS) $(ADD_TESTS)

test: $(TESTS)

$(TESTS):
	"$(CC)" -c /Fo$@_cpp.obj test\stdcpp\src\$@.cpp /EHsc /MT $(ADD_CFLAGS)
	"$(DMD)" -of=$@.exe -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest -version=_MSC_VER_$(_MSC_VER) -mscrtlib=libcmt $(ADD_DFLAGS) test\stdcpp\src\$@_test.d $@_cpp.obj
	$@.exe
	del $@.exe $@.obj $@_cpp.obj

	"$(CC)" -c /Fo$@_cpp.obj test\stdcpp\src\$@.cpp /EHsc /MD $(ADD_CFLAGS)
	"$(DMD)" -of=$@.exe -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest -version=_MSC_VER_$(_MSC_VER) -mscrtlib=msvcrt $(ADD_DFLAGS) test\stdcpp\src\$@_test.d $@_cpp.obj
	$@.exe
	del $@.exe $@.obj $@_cpp.obj

	"$(CC)" -c /Fo$@_cpp.obj test\stdcpp\src\$@.cpp /EHsc /MTd $(ADD_CFLAGS)
	"$(DMD)" -of=$@.exe -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest -version=_MSC_VER_$(_MSC_VER) -mscrtlib=libcmtd $(ADD_DFLAGS) test\stdcpp\src\$@_test.d $@_cpp.obj
	$@.exe
	del $@.exe $@.obj $@_cpp.obj

	"$(CC)" -c /Fo$@_cpp.obj test\stdcpp\src\$@.cpp /EHsc /MDd $(ADD_CFLAGS)
	"$(DMD)" -of=$@.exe -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -main -unittest -version=_MSC_VER_$(_MSC_VER) -mscrtlib=msvcrtd $(ADD_DFLAGS) test\stdcpp\src\$@_test.d $@_cpp.obj
	$@.exe
	del $@.exe $@.obj $@_cpp.obj
