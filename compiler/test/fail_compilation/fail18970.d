/*
TEST_OUTPUT:
---
fail_compilation/fail18970.d(34): Error: no property `y` for `S()` of type `fail18970.S`
    S().y(1);
       ^
fail_compilation/fail18970.d(34):        potentially malformed `opDispatch`. Use an explicit instantiation to get a better error message
fail_compilation/fail18970.d(23):        struct `S` defined here
struct S
^
fail_compilation/fail18970.d(41): Error: no property `yyy` for `this` of type `fail18970.S2`
        this.yyy;
            ^
fail_compilation/fail18970.d(41):        potentially malformed `opDispatch`. Use an explicit instantiation to get a better error message
fail_compilation/fail18970.d(37):        struct `S2` defined here
struct S2
^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=18970

struct S
{
    auto opDispatch(string name)(int)
    {
        alias T = typeof(x);
        static assert(!is(T.U));
        return 0;
    }
}
void f()
{
    S().y(1);
}

struct S2
{
    this(int)
    {
        this.yyy;
    }

    auto opDispatch(string name)()
    {
        alias T = typeof(x);
        static if(is(T.U)) {}
    }
}
