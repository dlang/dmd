# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib

test: alloc_from_assert

alloc_from_assert:
	$(DMD) -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) test\allocations\src\$@.d
	$@.exe
	del $@.*
