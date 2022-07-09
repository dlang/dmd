// https://issues.dlang.org/show_bug.cgi?id=22536

/*
TEST_OUTPUT:
---
fail_compilation/fail22536.d(21): Error: uncaught CTFE exception `object.Exception("exception")`
fail_compilation/fail22536.d(28): Error: static assert:  `bar()` is false

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
