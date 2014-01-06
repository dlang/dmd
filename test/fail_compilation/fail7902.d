/*
TEST_OUTPUT:
---
fail_compilation/fail7902.d(17): Error: function fail7902.F1.foo synchronized can only be applied to class declarations
fail_compilation/fail7902.d(23): Error: function fail7902.F2.foo synchronized can only be applied to class declarations
fail_compilation/fail7902.d(29): Error: function fail7902.F3.__invariant1 synchronized can only be applied to class declarations
---
*/
synchronized class K1
{
    void foo() { }
    void bar() {}
}

class F1
{
    synchronized void foo() { }
    void bar() {}
}

struct F2
{
    synchronized void foo() { }
    void bar() {}
}

class F3
{
    synchronized invariant() { }
}
