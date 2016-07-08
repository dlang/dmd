
// REQUIRED_ARGS: -dip25

/*
TEST_OUTPUT:
---
fail_compilation/retref.d(31): Error: escaping reference to variable s
fail_compilation/retref.d(42): Error: retref.foo called with argument types (int) matches both:
fail_compilation/retref.d(36):     retref.foo(ref int x)
and:
fail_compilation/retref.d(37):     retref.foo(return ref int x)
---
*/


/************/

struct S
{
    int x;

    ref int bar() return
    {
        return x;
    }
}

ref int test()
{
    S s;
    return s.bar();
}

/************/

ref int foo(ref int x);
ref int foo(return ref int x);

void testover()
{
    int x;
    foo(x);
}

/************/

