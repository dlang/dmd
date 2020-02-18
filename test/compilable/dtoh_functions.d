// REQUIRED_ARGS: -HCf=${RESULTS_DIR}/compilable/dtoh_functions.h -c
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/dtoh-postscript.sh

/*
TEST_OUTPUT:
---
---
*/

int foo(int x)
{
    return x * 42;
}

extern (C) int fun();
extern (C++) int fun2();

extern (C) int bar(int x)
{
    return x * 42;
}

extern (C) static int bar2(int x)
{
    return x * 42;
}

extern (C) private int bar3(int x)
{
    return x * 42;
}

extern (C) int bar4(int x = 42)
{
    return x * 42;
}

extern (C++) int baz(int x)
{
    return x * 42;
}

extern (C++) static int baz2(int x)
{
    return x * 42;
}

extern (C++) private int baz3(int x)
{
    return x * 42;
}

extern (C++) int baz3(int x = 42)
{
    return x * 42;
}
