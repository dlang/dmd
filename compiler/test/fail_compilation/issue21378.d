/*
TEST_OUTPUT:
---
fail_compilation/issue21378.d(19): Error: function `issue21378.fn` circular dependency. Functions cannot be interpreted while being compiled
int fn()
    ^
fail_compilation/issue21378.d(18):        called from here: `fn()`
pragma(inline, fn())
                 ^
fail_compilation/issue21378.d(18): Error: pragma(`inline`, `true` or `false`) expected, not `fn()`
pragma(inline, fn())
^
---
*/

// Cannot call the same function linked to the pragma
// Really hard to fix this limitation in the implementation
pragma(inline, fn())
int fn()
{
    return 1;
}
