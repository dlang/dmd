// REQUIRED_ARGS: -de
/* TEST_OUTPUT:
---
fail_compilation/b19691e.d(22): Error: forward reference to template `this`
        S2(42, "");
          ^
fail_compilation/b19691e.d(22): Error: constructor `b19691e.S2.this(int a, S1 s = "")` is not callable using argument types `(int, string)`
        S2(42, "");
          ^
fail_compilation/b19691e.d(22): Error: forward reference to template `this`
        S2(42, "");
          ^
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
