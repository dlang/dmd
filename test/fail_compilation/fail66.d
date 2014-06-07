/*
TEST_OUTPUT:
---
fail_compilation/fail66.d(11): Error: constructor fail66.C1.this missing initializer for const field y
---
*/

class C1
{
    const int y;
    this() {}
}

/*
TEST_OUTPUT:
---
fail_compilation/fail66.d(28): Error: can only initialize const member y inside constructor
---
*/
class C2
{
    const int y;
    this() { y = 7; }
}
void test2()
{
    C2 c = new C2();
    c.y = 3;
}

/*
TEST_OUTPUT:
---
fail_compilation/fail66.d(43): Error: can only initialize const member y inside constructor
---
*/
class C3
{
    const int y;
    this() { y = 7; }
    void foo()
    {
        y = 6;
    }
}

/*
TEST_OUTPUT:
---
fail_compilation/fail66.d(59): Error: can only initialize static const member x inside static constructor
---
*/
class C4
{
    static const int x;
    static this() { x = 5; }
    void foo()
    {
        x = 4;
    }
}

/*
TEST_OUTPUT:
---
fail_compilation/fail66.d(73): Error: can only initialize const member z5 inside constructor
---
*/
const int z5;
static this() { z5 = 3; }
void test5()
{
    z5 = 4;
}

/*
TEST_OUTPUT:
---
fail_compilation/fail66.d(89): Error: can only initialize const member y inside constructor
---
*/
class C6
{
    const int y;
    this()
    {
        C6 c = this;
        y = 7;
        c.y = 8;
    }
}
