/*
TEST_OUTPUT:
---
fail_compilation/diag13028.d(27): Error: variable `dg` cannot be read at compile time
    enum b = dg();
             ^
fail_compilation/diag13028.d(34): Error: variable `a` cannot be read at compile time
    enum b = a;
             ^
fail_compilation/diag13028.d(40): Error: CTFE failed because of previous errors in `foo`
    static assert(foo(() => 1) == 1);
                     ^
fail_compilation/diag13028.d(40):        while evaluating: `static assert(foo(() pure nothrow @nogc @safe => 1) == 1)`
    static assert(foo(() => 1) == 1);
    ^
fail_compilation/diag13028.d(41): Error: CTFE failed because of previous errors in `bar`
    static assert(bar(1) == 1);
                     ^
fail_compilation/diag13028.d(41):        while evaluating: `static assert(bar(delegate int() pure nothrow @nogc @safe => 1) == 1)`
    static assert(bar(1) == 1);
    ^
---
*/

int foo(int delegate() dg)
{
    enum b = dg();
    return b;
}


int bar(lazy int a)
{
    enum b = a;
    return a;
}

void main()
{
    static assert(foo(() => 1) == 1);
    static assert(bar(1) == 1);
}
