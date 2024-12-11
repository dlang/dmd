/*
TEST_OUTPUT:
---
fail_compilation/fail311.d(20): Error: undefined identifier `undefined`
    undefined x;
              ^
fail_compilation/fail311.d(29): Error: template instance `fail311.foo!()` error instantiating
    foo!()();
    ^
---
*/

template Tuple(T...)
{
    alias T Tuple;
}

void foo()()
{
    undefined x;
    foreach (i; Tuple!(2))
    {
        static assert(true);
    }
}

void main()
{
    foo!()();
}
