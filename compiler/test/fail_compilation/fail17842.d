/* REQUIRED_ARGS: -preview=dip1000
 * TEST_OUTPUT:
---
fail_compilation/fail17842.d(18): Error: scope variable `p` assigned to non-scope `*q`
    *q = p;        // error
       ^
fail_compilation/fail17842.d(27): Error: scope variable `obj` may not be copied into allocated memory
    arr ~= obj;         // error
           ^
---
 */

// https://issues.dlang.org/show_bug.cgi?id=17842

void* testp(scope void* p) @safe
{
    scope void** q;
    *q = p;        // error
    void** t;
    *t = *q;
    return *t;
}

Object testobj(scope Object obj) @safe
{
    scope Object[] arr;
    arr ~= obj;         // error
    Object[] array;
    array ~= arr;
    return array[0];
}
