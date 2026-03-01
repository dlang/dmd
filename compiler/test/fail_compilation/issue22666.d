/*
TEST_OUTPUT:
---
fail_compilation/issue22666.d(25): Error: function `issue22666.V4.opApply(int delegate(Object) @safe dg)` is not callable using argument types `(int delegate(Object _) nothrow @system)`
fail_compilation/issue22666.d(25):        cannot pass argument `int(Object _) => s` of type `int delegate(Object _) nothrow @system` to parameter `int delegate(Object) @safe dg`

---
*/
struct S4
{
    this(ref inout S4) @system {}
}

struct V4
{
    int opApply(int delegate(Object) @safe dg)
    {
        return dg(null);
    }
}

S4 h4()
{
    S4 s = S4();
    foreach (_; V4())
    {
        return s;
    }
    return S4();
}

void main()
{
    h4();
}
