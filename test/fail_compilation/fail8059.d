/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail8059.d(19): Deprecation: `.classinfo` property is deprecated - use `typeid(Object)` instead
fail_compilation/fail8059.d(20): Deprecation: `.classinfo` property is deprecated - use `typeid(Object)` instead
fail_compilation/fail8059.d(21): Deprecation: `.classinfo` property is deprecated - use `typeid(o)` instead
fail_compilation/fail8059.d(24): Deprecation: `.classinfo` property is deprecated - use `typeid(Interface).info` instead
fail_compilation/fail8059.d(25): Deprecation: `.classinfo` property is deprecated - use `typeid(i).info` instead
---
*/
// https://issues.dlang.org/show_bug.cgi?id=8059

interface Interface {}

void main ()
{
    scope o = new Object;
    assert(Object.classinfo !is null);
    assert(Object.classinfo  is typeid(Object));
    assert(o.classinfo       is typeid(o));

    Interface i;
    assert(Interface.classinfo !is null);
    assert(i.classinfo !is null);
}
