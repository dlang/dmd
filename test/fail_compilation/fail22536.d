// https://issues.dlang.org/show_bug.cgi?id=22536

/*
TEST_OUTPUT:
---
fail_compilation/fail22536.d(22): Error: uncaught CTFE exception `object.Exception("exception")`
fail_compilation/fail22536.d(25):        called from here: `foo(((S[2] __arrayliteral_on_stack3 = [S(1), S(2)];) , cast(S[])__arrayliteral_on_stack3))`
fail_compilation/fail22536.d(29):        called from here: `bar()`
fail_compilation/fail22536.d(29):        while evaluating: `static assert(bar())`
---
*/

void foo(T)(scope T[]) {}

int bar()
{
    int numDtor;

    struct S
    {
        int x;
        ~this() { throw new Exception("exception");}
    }

    foo([S(1), S(2)]);
    return numDtor;
}

static assert(bar()); // fails, returns 0
