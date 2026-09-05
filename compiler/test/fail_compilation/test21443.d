// https://issues.dlang.org/show_bug.cgi?id=21443

/*
TEST_OUTPUT:
---
fail_compilation/test21443.d(12): Error: `return` statements cannot be in `scope(failure)` bodies
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
