// https://issues.dlang.org/show_bug.cgi?id=20190
// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail20190.d(15): Deprecation: alias `fail20190.Const!char.Const` is deprecated
---
*/

deprecated template Const (T)
{
    deprecated alias Const = const(T);
}

void foo(Const!(char)[] a1) {}

void main()
{
}
