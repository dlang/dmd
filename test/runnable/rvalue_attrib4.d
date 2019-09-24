/* REQUIRED_ARGS: -preview=rvalueattribute
TEST_OUTPUT:
---
int function(@rvalue ref int p)
int function(ref int p)
int function()
int function(ref int a) ref
int function(ref int a) @rvalue ref
---
*/

int fun()(auto @rvalue ref int p)
{
    static if (__traits(isRvalueRef, p))
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
    assert(fun(cast(@rvalue ref)i) == 1);
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
    return cast(@rvalue ref) a;
    pragma(msg, typeof(&fRvalueRef).stringof);
}
