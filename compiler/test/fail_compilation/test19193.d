/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/test19193.d(14): Deprecation: enum member `test19193.T19193!int.A.b` is deprecated
fail_compilation/test19193.d(21):        `b` is declared here
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19193

void main ()
{
    cast(void)T19193!int.A.b;
}

template T19193(T)
{
    enum A
    {
        deprecated b
    }
}
