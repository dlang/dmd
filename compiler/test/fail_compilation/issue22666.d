/*
TEST_OUTPUT:
---
fail_compilation/issue22666.d(38): Error: function `issue22666.V4Nothrow.opApply(int delegate(Object) nothrow dg)` is not callable using argument types `(int delegate(Object _) @system)`
fail_compilation/issue22666.d(38):        cannot pass argument `int(Object _) => result = 0 , result.this(s) , result , 2` of type `int delegate(Object _) @system` to parameter `int delegate(Object) nothrow dg`
fail_compilation/issue22666.d(48): Error: function `issue22666.V4Safe.opApply(int delegate(Object) @safe dg)` is not callable using argument types `(int delegate(Object _) @system)`
fail_compilation/issue22666.d(48):        cannot pass argument `int(Object _) => result = 0 , result.this(s) , result , 2` of type `int delegate(Object _) @system` to parameter `int delegate(Object) @safe dg`
---
*/

struct S4
{
    this(ref inout S4) @system
    {
        throw new Exception("");
    }
}

struct V4Nothrow
{
    int opApply(int delegate(Object) nothrow dg) nothrow
    {
        return dg(null);
    }
}

struct V4Safe
{
    int opApply(int delegate(Object) @safe dg)
    {
        return dg(null);
    }
}

S4 h4nothrow() nothrow
{
    S4 s = S4();
    foreach (_; V4Nothrow())
    {
        return s;
    }
    return S4();
}

S4 h4safe()
{
    S4 s = S4();
    foreach (_; V4Safe())
    {
        return s;
    }
    return S4();
}

void main()
{
    h4nothrow();
    h4safe();
}
