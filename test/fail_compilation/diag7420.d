// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/diag7420.d(3): Error: static variable x cannot be read at compile time
fail_compilation/diag7420.d(3):        while evaluating: static assert(x < 4)
fail_compilation/diag7420.d(4): Error: static variable y cannot be read at compile time
fail_compilation/diag7420.d(4):        while evaluating: static assert(y == "abc")
fail_compilation/diag7420.d(5): Error: static variable y cannot be read at compile time
fail_compilation/diag7420.d(5):        while evaluating: static assert(cast(ubyte[])y != null)
fail_compilation/diag7420.d(6): Error: static variable y cannot be read at compile time
fail_compilation/diag7420.d(6):        while evaluating: static assert(cast(int)y[0] == 1)
fail_compilation/diag7420.d(7): Error: static variable y cannot be read at compile time
fail_compilation/diag7420.d(7):        while evaluating: static assert(y[0..1].length == 1u)
---
*/

#line 1
int x = 2;
char[] y = "abc".dup;
static assert(x < 4);
static assert(y == "abc");
static assert(cast(ubyte[])y != null);
static assert(y[0] == 1);
static assert(y[0..1].length == 1);
