/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=10047

/*
TEST_OUTPUT:
---
fail_compilation/fail10047.d(16): Error: static assert:  `0` is false
fail_compilation/fail10047.d(26):        instantiated from here: `opDispatch!"foo10047"`
---
*/

struct Typedef10047(T)
{
    template opDispatch(string name)
    {
        static assert(0);
    }
}

struct A10047 {}
int foo10047(Typedef10047!A10047 a) { return 10; }

void test10047()
{
    Typedef10047!A10047 a;
    assert(a.foo10047() == 10);
}
