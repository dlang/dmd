/* https://issues.dlang.org/show_bug.cgi?id=23097
REQUIRED_ARGS: -verrors=spec
TEST_OUTPUT:
---
---
*/
void emplaceRef(UT, Args)(UT chunk, Args args)
{
    static if (__traits(compiles, chunk = args))
        chunk = args;
}

struct CpCtor23097(T)
{
    T* payload;
    this(ref inout typeof(this)) { }
    ref opAssign(typeof(this)) { }
}

struct S23097
{
    CpCtor23097!int payload;
}

void test23097(S23097 lhs, const S23097 rhs)
{
    emplaceRef(lhs, rhs);
}
