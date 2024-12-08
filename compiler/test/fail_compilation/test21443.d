// https://issues.dlang.org/show_bug.cgi?id=21443
// REQUIRED_ARGS: -de

/*
TEST_OUTPUT:
---
fail_compilation/test21443.d(16): Deprecation: `return` statements cannot be in `scope(failure)` bodies.
    scope (failure) return 10;
                    ^
fail_compilation/test21443.d(16):        Use try-catch blocks for this purpose
---
*/

ulong get () @safe nothrow
{
    scope (failure) return 10;
    throw new Error("");
}

void main () @safe
{
    assert(get() == 10);  // passes
}
