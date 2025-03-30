/*
TEST_OUTPUT:
---
fail_compilation/test15989.d(41): Error: variable `test15989.main.ctRegex` : Unable to initialize enum with class or pointer to struct
fail_compilation/test15989.d(41):        use static const variable instead
fail_compilation/test15989.d(50): Error: variable `test15989.test.c` : Unable to initialize enum with class or pointer to struct
fail_compilation/test15989.d(50):        use static const variable instead
fail_compilation/test15989.d(51): Error: cannot use non-constant CTFE pointer in an initializer `new int(3)`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15989

import core.stdc.stdio;

interface Kickstart{
    bool foo( int );
}

class ShiftOr : Kickstart
{
    bool foo( int i )
    {
        printf("i = %d\n", i);
        return false;
    }
}

struct Regex
{
    Kickstart kickstart;
}

Regex regex()
{
    return Regex(new ShiftOr());
}

void main()
{
    enum ctRegex = regex();
    Regex r = ctRegex;
    r.kickstart.foo(7);
}

class C { }

void test()
{
    enum c = new C();
    enum pi = new int(3);
}
