/*
REQUIRED_ARGS: -preview=rvalueattribute
TEST_OUTPUT:
---
fail_compilation/rvalue_attrib2.d(14): Error: variable `rvalue_attrib2.var0.a` only parameters can be `@rvalue ref`
fail_compilation/rvalue_attrib2.d(20): Error: returning `cast(@rvalue ref)a` escapes a reference to local variable `a`
fail_compilation/rvalue_attrib2.d(37): Error: returning `f0(cast(@rvalue ref)a)` escapes a reference to local variable `a`
fail_compilation/rvalue_attrib2.d(39): Error: returning `f1(a)` escapes a reference to local variable `a`
---
*/

void var0()
{
    @rvalue ref int a;
}

@rvalue ref escape0()
{
    int a;
    return cast(@rvalue ref)a;
}

@rvalue ref int escape1(int i)
{
    static @rvalue ref f0(@rvalue ref int a)
    {
        return cast(@rvalue ref)a;
    }

    static @rvalue ref f1(ref int a)
    {
        return cast(@rvalue ref)a;
    }

    int a;
    if (i)
        return f0(cast(@rvalue ref)a);
    else
        return f1(a);
}
