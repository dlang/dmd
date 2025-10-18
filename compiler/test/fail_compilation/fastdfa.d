/*
 * REQUIRED_ARGS: -preview=fastdfa
 * TEST_OUTPUT:
---
fail_compilation/fastdfa.d(37): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(47): Error: Argument is expected to be non-null but was null
fail_compilation/fastdfa.d(40):        For parameter `ptr` in argument 0
fail_compilation/fastdfa.d(54): Error: Variable `ptr` was required to be non-null and has become null
fail_compilation/fastdfa.d(75): Error: Variable `ptr` was required to be non-null and has become null
fail_compilation/fastdfa.d(90): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(112): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(129): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(135): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(144): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(159): Error: Assert can be proven to be false
---
 */

@safe:

void conditionalAssert()
{
    int a;
    int b;

    int c;

    if (c)
    {
        a = 9;
    }
    else
    {
        b = 22;
    }

    assert(c); // Error: c is false
}

int nonnull1(int* ptr)
{
    return *ptr;
}

void nonnullCall()
{
    nonnull1(null); // error
}

void loopy6()
{
    int* ptr = new int;

    foreach (i; 0 .. 2) // error
    {
        int val = *ptr;
        ptr = null; // error
    }
}

void loopy7()
{
    int* ptr = new int;

    foreach (i; 0 .. 2)
    {
        if (ptr !is null)
            int val1 = *ptr; // ok

        ptr = null;
    }

    ptr = new int;

    foreach (i; 0 .. 2) // error
    {
        if (ptr !is null)
            int val1 = *ptr; // ok

        int val2 = *ptr; // error
        ptr = null;
    }
}

void nested1()
{
    static void nested2()
    {
        int* ptr;
        int v = *ptr; // error
    }

    int* ptr;

    void nested3()
    {
        int v = *ptr;
    }

    nested2;
    nested3;
}

void theSitch(int arg)
{
    bool passedBy;

    switch (arg)
    {
    case 0:
        int* ptr;
        int v = *ptr; // error
        goto default;

    case 1:
        return;

    default:
        if (passedBy)
            goto case 1;
        passedBy = true;
        goto case 0;
    }
}

void assertNoCompare()
{
    int val;
    assert(val); // Error: val is 0
}

void vectorExp()
{
    string[] stack;
    assert(stack.length == 1); // Error: stack is null
}

int nullSet(int* ptr, bool gate)
{
    if (ptr !is null)
    {
        if (gate)
            ptr = null;
        return *ptr; // error could be null
    }

    return -1;
}

void gateDowngrade(bool gate, int* ptr)
{
    if (gate)
    {
        ptr = null;
    }

    if (gate)
    {
        assert(ptr !is null); // error
    }
}
