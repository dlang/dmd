/*
TEST_OUTPUT:
---
fail_compilation/fail12228.d(25): Error: class fail12228.F1.F1N base type must be class or interface, not 'this'. Did you mean to use 'typeof(this)'?
fail_compilation/fail12228.d(32): Error: class fail12228.F2.F2N base type must be class or interface, not 'super'. Did you mean to use 'typeof(super)'?
---
*/

class K1
{
    static class K1N : typeof(this)  // ok
    {
    }
}

class K2 : K1
{
    static class K2N : typeof(super)  // ok
    {
    }
}

class F1
{
    static class F1N : this  // fail
    {
    }
}

class F2
{
    static class F2N : super // fail
    {
    }
}
