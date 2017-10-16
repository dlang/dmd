/*
REQUIRED_ARGS: -dip1000
PERMUTE_ARGS:
*/

/*
TEST_OUTPUT:
---
fail_compilation/retscope3.d(2009): Error: scope variable `arr` may not be returned
fail_compilation/retscope3.d(2018): Error: scope variable `arr` may not be returned
---
*/

#line 2000

// https://issues.dlang.org/show_bug.cgi?id=17790

@safe:

int* bar1()
{
    int i;
    int*[] arr = [ &i ];
    return arr[0];      // Error: scope variable arr may not be returned
}

struct S2000 { int* p; }

S2000 bar2()
{
    int i;
    S2000[] arr = [ S2000(&i) ];
    return arr[0];
}

void bar3(string[] u...) @safe pure nothrow @nogc
{
    foreach (str; u)
    {
    }
}

void bar4()
{
    static struct S { int* p; }
    S[2][10] pairs;
    foreach (ref pair; pairs)
    {
    }
}
