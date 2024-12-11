// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/diag7420.d(41): Error: static variable `x` cannot be read at compile time
static assert(x < 4);
              ^
fail_compilation/diag7420.d(41):        while evaluating: `static assert(x < 4)`
static assert(x < 4);
^
fail_compilation/diag7420.d(42): Error: static variable `y` cannot be read at compile time
static assert(y == "abc");
              ^
fail_compilation/diag7420.d(42):        called from here: `__equals(y, "abc")`
fail_compilation/diag7420.d(42):        while evaluating: `static assert(y == "abc")`
static assert(y == "abc");
^
fail_compilation/diag7420.d(43): Error: static variable `y` cannot be read at compile time
static assert(cast(ubyte[])y != null);
                           ^
fail_compilation/diag7420.d(43):        while evaluating: `static assert(cast(ubyte[])y != null)`
static assert(cast(ubyte[])y != null);
^
fail_compilation/diag7420.d(44): Error: static variable `y` cannot be read at compile time
static assert(y[0] == 1);
              ^
fail_compilation/diag7420.d(44):        while evaluating: `static assert(cast(int)y[0] == 1)`
static assert(y[0] == 1);
^
fail_compilation/diag7420.d(45): Error: static variable `y` cannot be read at compile time
static assert(y[0..1].length == 1);
              ^
fail_compilation/diag7420.d(45):        while evaluating: `static assert(y[0..1].length == 1u)`
static assert(y[0..1].length == 1);
^
---
*/

int x = 2;
char[] y = "abc".dup;
static assert(x < 4);
static assert(y == "abc");
static assert(cast(ubyte[])y != null);
static assert(y[0] == 1);
static assert(y[0..1].length == 1);
