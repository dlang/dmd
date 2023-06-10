// REQUIRED_ARGS: -de
/* TEST_OUTPUT:
---
fail_compilation/b19691e.d(16): Error: forward reference to template `this`
---
*/


// https://issues.dlang.org/show_bug.cgi?id=19691
module b19691e;

struct S1
{
    this(T)(T)
    {
        S2(42, "");
    }
}

struct S2
{
    this(int a, S1 s = ""){}
}
