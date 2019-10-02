/* REQUIRED_ARGS: -preview=rvaluetype
TEST_OUTPUT:
---
int function(ref @rvalue(int) p)
int function(ref int p)
int function()
int function(ref int a) ref
@rvalue(int) function(ref int a) ref
int function(ref int a) ref
int function(ref int a)
---
*/

int fun()(auto @rvalue ref int p)
{
    static if (is(typeof(p) == @rvalue))
        return 1;
    else static if (__traits(isRef, p))
        return 2;
    else
        static assert(0);
    pragma(msg, typeof(&fun).stringof);
}

void main()
{
    assert(fun(0) == 1);
    int i;
    assert(fun(i) == 2);
    assert(fun(cast(@rvalue)i) == 1);
}

auto ref int fVal()
{
    return 1;
    pragma(msg, typeof(&fVal).stringof);
}

auto ref int fRef(ref int a)
{
    return a;
    pragma(msg, typeof(&fRef).stringof);
}

auto ref int fRvalueRef(ref int a)
{
    return cast(@rvalue) a;
    pragma(msg, typeof(&fRvalueRef).stringof);
}

auto ref int fmix0(ref int a)
{
    return cast(@rvalue) a; return a;
    pragma(msg, typeof(&fmix0).stringof);
}

auto ref int fmix1(ref int a)
{
    return cast(@rvalue) a; return 1;
    pragma(msg, typeof(&fmix1).stringof);
}
