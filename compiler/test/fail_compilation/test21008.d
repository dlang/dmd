/*
TEST_OUTPUT:
---
fail_compilation/test21008.d(110): Error: function `test21008.C.after` circular reference to class `C`
fail_compilation/test21008.d(117): Error: need `this` for `toString` of type `string()`
fail_compilation/test21008.d(105):        called from here: `handleMiddlewareAnnotation()`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=21008

#line 100

class Base
{
    bool after();

    mixin(handleMiddlewareAnnotation);
}

class C : Base
{
    override bool after();
}

string handleMiddlewareAnnotation()
{
    foreach (member; __traits(allMembers, C))
    {
        __traits(getMember, C, member);
    }
}
