/*
TEST_OUTPUT:
---
fail_compilation/fail180.d(23): Error: can only initialize const member x inside constructor
fail_compilation/fail180.d(24): Error: can only initialize const member x inside constructor
fail_compilation/fail180.d(38): Error: can only initialize const member x inside constructor
fail_compilation/fail180.d(39): Error: can only initialize const member x inside constructor
fail_compilation/fail180.d(50): Error: variable fail180.main.t final cannot be applied to variable, perhaps you meant const?
fail_compilation/fail180.d(62): Error: variable fail180.test.d final cannot be applied to variable, perhaps you meant const?
---
*/

struct S59
{
    int x;

    void foo()
    {
        x = 3;
    }
    const void bar()
    {
        x = 4;
        this.x = 5;
    }
}

class C
{
    int x;

    void foo()
    {
        x = 3;
    }
    const void bar()
    {
        x = 4;
        this.x = 5;
    }
}

void main()
{
    S59 s;

    s.foo();
    s.bar();

    final S59 t;
    t.foo();
    t.bar();
}

void test()
{
    C c = new C;

    c.foo();
    c.bar();

    final C d = new C;
    d.foo();
    d.bar();
}
