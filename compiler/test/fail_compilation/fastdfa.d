/*
 * REQUIRED_ARGS: -preview=fastdfa
 * TEST_OUTPUT:
---
fail_compilation/fastdfa.d(63): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(78): Error: Argument is expected to be non-null but was null
fail_compilation/fastdfa.d(71):        For parameter `ptr` in argument 0
fail_compilation/fastdfa.d(96): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(94): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(104): Error: Variable `ptr` was required to be non-null and has become null
fail_compilation/fastdfa.d(125): Error: Variable `ptr` was required to be non-null and has become null
fail_compilation/fastdfa.d(140): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(162): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(179): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(185): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(194): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(209): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(217): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(219): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(226): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(233): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(237): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(239): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(249): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(250): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(264): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(273): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(289): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(295): Error: Expression reads from an uninitialized variable, it must be written to at least once before reading
fail_compilation/fastdfa.d(294):        For variable `val1`
fail_compilation/fastdfa.d(298): Error: Expression reads from an uninitialized variable, it must be written to at least once before reading
fail_compilation/fastdfa.d(294):        For variable `val1`
fail_compilation/fastdfa.d(305): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(312): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(348): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(355): Error: Expression reads a default initialized variable that is a floating point type
fail_compilation/fastdfa.d(355):        It will have the value of Not Any Number(nan), it will be propagated with mathematical operations
fail_compilation/fastdfa.d(354):        For variable `v`
fail_compilation/fastdfa.d(354):        Initialize to float.nan or 0 explicitly to disable this error
fail_compilation/fastdfa.d(365): Error: Expression reads from an uninitialized variable, it must be written to at least once before reading
fail_compilation/fastdfa.d(364):        For variable `v`
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

bool truthinessNo()
{
    return false;
}

int nonnull1(int* ptr)
{
    return *ptr;
}

void nonnullCall()
{
    nonnull1(null); // error
}

void theSitchFinally()
{
    {
        goto Label;
    }

    {
        Label:
    }

    int* ptr;

    scope (exit)
        int vS = *ptr; // error

    int vMid = *ptr; // error
    truthinessNo;
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

void basicVRP()
{
    int a = 2, b = 3;
    assert(a == a); // ok
    assert(a == b); // error
    assert(a != b); // ok
    assert(a != a); // error
}

void checkVRPUpper()
{
    ulong i = ulong.max;

    assert(i == 2); // error
    assert(i == ulong(long.max) + 2); // ok
}

void paNegate()
{
    int val = 2;
    assert(val == 3); // error
    assert(val == 2); // no error

    val = -val;
    assert(val == 3); // error
    assert(val == -2); // no error
    assert(val == 9); // error
}

void paAdd()
{
    int val = 2;

    val = val + 2;
    val += 1;

    assert(val == 3); // error
    assert(val == 4); // error
    assert(val == 5); // no error
}


void paBitwise()
{
    int a = 2, b = 3, c;

    c = a * b;

    int d = c & 2;

    assert(c == 6); // no error
    assert(d == 6); // error
    assert(d == 2); // no error
}

void paSliceLengthAppend()
{
    string text = "hello";
    text ~= " world";

    assert(text.length == 5); // error
    assert(text.length == 11); // no error
}

void checkPtrExact() {
    int* a = new int;
    int* b = a;

    if (a is b) {
        // ok
    } else {
        bool c;
        assert(c); // should not error
    }

    assert(a is b); // no error
    assert(a !is b); // error
}

void readFromUninit1() @trusted
{
    int val1 = void;
    int val2 = val1; // error

    int* ptr = &val1;
    int val3 = *ptr; // error
}

void seeEffectViaObject1(bool condition) @trusted
{
    bool a = true, b = true;
    bool got = *(condition ? &a : &b);
    assert(!got); // error
}

void seeEffectViaObject2(bool condition) @trusted
{
    bool a = false, b = false;
    bool got = *(condition ? &a : &b);
    assert(got); // error
}

void valueLoop1()
{
    int* obj = new int, oldObj = obj;

    foreach (i; 0 .. 0)
    {
        obj = new int;
    }

    // only true branch taken
    if (obj is oldObj)
    {
    }
    else
    {
        bool b;
        assert(b); // ok
    }

    obj = oldObj;

    foreach (i; 0 .. 10)
    {
        obj = new int;
    }

    // both branches must be taken
    if (obj is oldObj)
    {
    }
    else
    {
        bool b;
        assert(b); // error: cannot know state of obj after loop (null)
    }
}

void checkFloatInit1_2(bool condition)
{
    float v;
    float t = v * 2; // error math op

    if (condition)
        v = 2;

    float u = v * 2; // no error
}

float uninitFloat() {
    float v = void;
    return v * 2; // error
}
