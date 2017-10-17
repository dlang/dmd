/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail17748a.d(11): Deprecation: function fail17748a.S.foo is declared "extern (C)" and it is neither static nor defined at top level.
---
*/

struct S
{
    extern (C) void foo() {}
}

struct S2
{
    static extern (C) void foo() {}
}

void main()
{}
