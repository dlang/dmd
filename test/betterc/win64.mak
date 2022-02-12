# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64

TESTS=test18828 test19416 test19421 test19561 test20088 test20613 test19924 test22336 test19933$(MINGW)

test: $(TESTS)

test18828:
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -run test\betterc\src\$@.d
	del $@.*

test19416:
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -run test\betterc\src\$@.d
	del $@.*

test19421:
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -run test\betterc\src\$@.d
	del $@.*

test19561:
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -run test\betterc\src\$@.d
	del $@.*

test20088:
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -run test\betterc\src\$@.d
	del $@.*

test20613:
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -run test\betterc\src\$@.d
	del $@.*

test19924:
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -run test\betterc\src\$@.d
	del $@.*

test22336:
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -run test\betterc\src\$@.d
	del $@.*

test19933:
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -run test\betterc\src\$@.d
	del $@.*

test19933_mingw:
	# DFLAGS=-mscrtlib=msvcrt120 takes precedence over any command line flags, so
	# specify vcruntime140.lib explicitly for using mingw with Universal CRT
	$(DMD) -m$(MODEL) -conf= -Isrc -betterC -Lvcruntime140.lib -Llegacy_stdio_definitions.lib -L/NODEFAULTLIB:msvcrt120.lib -run test\betterc\src\test19933.d
	del $@.*
