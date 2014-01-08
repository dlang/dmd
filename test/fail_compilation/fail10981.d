/*
TEST_OUTPUT:
---
fail_compilation/fail10981.d(17): Error: pure nested function '__require' cannot access mutable data 'i'
fail_compilation/fail10981.d(18): Error: pure nested function '__ensure' cannot access mutable data 'i'
fail_compilation/fail10981.d(27): Error: pure nested function '__require' cannot access mutable data 'i'
fail_compilation/fail10981.d(28): Error: pure nested function '__ensure' cannot access mutable data 'i'
---
*/

void foo(int i)
in
{
    class X1
    {
        void in_nested() pure
        in { assert(i); }   // NG
        out { assert(i); }  // NG
        body {}
    }
}
out
{
    class X2
    {
        void out_nested() pure
        in { assert(i); }   // NG
        out { assert(i); }  // NG
        body {}
    }
}
body
{
}
