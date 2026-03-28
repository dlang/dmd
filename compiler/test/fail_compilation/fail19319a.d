/*
DFLAGS:
REQUIRED_ARGS: -conf= -Ifail_compilation/extra-files/minimal
TEST_OUTPUT:
---
fail_compilation/fail19319a.d(16): Error: `object._d_pow` not found. The current runtime does not support the ^^ operator, or the runtime is corrupt.
fail_compilation/fail19319a.d(17): Error: `object._d_pow` not found. The current runtime does not support the ^^ operator, or the runtime is corrupt.
---
*/

__gshared int g19319 = 0;

static assert(!__traits(compiles, 7 ^^ g19319));
static assert(!__traits(compiles, g19319 ^^= 7));

__gshared int e19319 = 7 ^^ g19319;
__gshared int a19319 = g19319 ^^= 7;;
