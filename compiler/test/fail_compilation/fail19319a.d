/*
DFLAGS:
REQUIRED_ARGS: -conf= -Ifail_compilation/extra-files/minimal
TEST_OUTPUT:
---
fail_compilation/fail19319a.d(20): Error: `7 ^^ g19319` requires `std.math` for `^^` operators
__gshared int e19319 = 7 ^^ g19319;
                       ^
fail_compilation/fail19319a.d(21): Error: `g19319 ^^ 7` requires `std.math` for `^^` operators
__gshared int a19319 = g19319 ^^= 7;;
                              ^
---
*/

__gshared int g19319 = 0;

static assert(!__traits(compiles, 7 ^^ g19319));
static assert(!__traits(compiles, g19319 ^^= 7));

__gshared int e19319 = 7 ^^ g19319;
__gshared int a19319 = g19319 ^^= 7;;
