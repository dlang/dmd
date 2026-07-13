/*
TEST_OUTPUT:
---
fail_compilation/fail10115.d(39): Error: cannot have `out` parameter of type `S` because the default construction is disabled
fail_compilation/fail10115.d(39): Error: cannot have `out` parameter of type `E` because the default construction is disabled
fail_compilation/fail10115.d(39): Error: cannot have `out` parameter of type `U` because the default construction is disabled
fail_compilation/fail10115.d(44): Error: default construction is disabled for type `S`
fail_compilation/fail10115.d(20):        because of `@disable this();` here
fail_compilation/fail10115.d(45): Error: default construction is disabled for type `S`
fail_compilation/fail10115.d(20):        because of `@disable this();` here
fail_compilation/fail10115.d(46): Error: default construction is disabled for type `U`
fail_compilation/fail10115.d(32):        because field `s` of type `S` has disabled default construction
fail_compilation/fail10115.d(20):        because of `@disable this();` here
---
*/

struct S
{
    int a;
    @disable this();
    //this(int) { a = 1; }
    //~this() { assert(a !is 0); }
}

enum E : S
{
    A = S.init
}

union U
{
    S s;
    //this(this) { assert (s.a !is 0); }
    //~this() { assert (s.a !is 0); }
}

void main()
{
    void foo(out S s, out E e, out U u) { }

    S[] a;
    E[] e;
    U[] u;
    a.length = 5;   // compiles -> NG
    e.length = 5;   // compiles -> NG
    u.length = 5;   // compiles -> NG

    S[1] x = (S[1]).init;
    foo(a[0],       // compiles -> NG
        e[0],       // compiles -> NG
        u[0]);      // compiles -> NG
}
