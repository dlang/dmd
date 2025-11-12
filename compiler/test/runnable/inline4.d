struct S
{
    int a;
    int b;
    int c;

    bool test(int a_, int b_, int c_) inout
    {
        return a_ == a && b_ == b && c_ == c;
    }
}

__gshared S globalS = S(2, 3, 4);
__gshared S globalS2 = S();
immutable S immutableS = S(9, 8, 7);

S getVal()
{
    // Returns by value
    return globalS;
}

ref S getRef()
{
    // Returns by reference
    return globalS;
}

ref S getRefRvalue() __rvalue
{
    // Takes ownership of globalS
    return globalS;
}

S getImmutable()
{
    return immutableS;
}

struct D
{
    int d;

    ~this()
    {
        d++;
    }
}

__gshared D globalD;
__gshared D globalD2 = D(10000);

D getD()
{
    // Returns by value
    return globalD;
}

D getRvalueD()
{
    // Returns by moving globalD, but should not have reference semantics
    // Tests if the inliner incorrectly applies reference semantics
    return __rvalue(globalD);
}

ref D getRefD()
{
    // Returns by reference
    return globalD;
}

ref D getRefRvalueD() __rvalue
{
    // Takes ownership of globalS
    return globalD;
}

/************************************/
// Test inlining of return by value

S funcVal1()
{
    return getVal();
}

S funcVal2()
{
    return getRef();
}

S funcVal3()
{
    return getRefRvalue();
}

S funcVal4()
{
    return globalS.a ? immutableS : globalS;
}

S funcVal5()
{
    return globalS.a ? globalS : S();
}

D funcVal6()
{
    return getD();
}

D funcVal7()
{
    return getRvalueD();
}

D funcVal8()
{
    return getRefD();
}

D funcVal9()
{
    return getRefRvalueD();
}

D funcVal10()
{
    return __rvalue(globalS.a ? globalD : D());
}

void consumeD(D d) {}

void testValueReturn()
{
    // Returning by value should not change the source object
    getVal().a++;
    assert(globalS.test(2, 3, 4));
    getImmutable().a++;
    assert(immutableS.test(9, 8, 7));
    funcVal1().a++;
    assert(globalS.test(2, 3, 4));
    funcVal2().c++;
    assert(globalS.test(2, 3, 4));
    funcVal3().c++;
    assert(globalS.test(2, 3, 4));
    funcVal4().a++;
    assert(immutableS.test(9, 8, 7));
    funcVal5().a++;
    assert(globalS.test(2, 3, 4));

    // Similarly, moving returned objects should not change the source object
    consumeD(getD());
    consumeD(__rvalue(getD()));
    consumeD(getRvalueD());
    consumeD(__rvalue(getRvalueD()));
    consumeD(funcVal6());
    consumeD(__rvalue(funcVal6()));
    consumeD(funcVal7());
    consumeD(__rvalue(funcVal7()));
    consumeD(funcVal8());
    consumeD(__rvalue(funcVal8()));
    consumeD(funcVal9());
    consumeD(__rvalue(funcVal9()));
    consumeD(funcVal10());
    consumeD(__rvalue(funcVal10()));
    assert(globalD.d == 0);
}


/************************************/
// Test inlining of return by reference

ref S funcRef1()
{
    return getRef();
}

ref S funcRef2()
{

    return globalS.a ? globalS : globalS2;
}

ref D funcRef3()
{
    return getRefD();
}

ref D funcRef4()
{
    return __rvalue(globalS.a ? globalD : globalD2);
}

bool consumeRefD(ref D d, int expect)
{
    bool ok = d.d == expect;
    consumeD(__rvalue(d));
    ok = ok && d.d == expect + 1;
    return ok;
}

void testRefReturn()
{
    // Returning by ref should mutate the source object
    funcRef1().a++;
    assert(globalS.test(3, 3, 4));
    funcRef2().c++;
    assert(globalS.test(3, 3, 5));

    globalD.d = 0;
    // Passing ref to value parameter should trigger a copy
    consumeD(funcRef3());
    assert(globalD.d == 0);
    // ... but not if there is __rvalue
    consumeD(__rvalue(funcRef3()));
    assert(globalD.d == 1);

    globalD.d = 0;
    // ditto
    consumeD(funcRef4());
    assert(globalD.d == 0);
    consumeD(__rvalue(funcRef4()));
    assert(globalD.d == 1);

    globalD.d = 0;
    assert(consumeRefD(funcRef3(), 0));
    assert(consumeRefD(funcRef4(), 1));
}

/************************************/
// Test inlining of return by rvalue reference

ref S funcRvalueRef1() __rvalue
{
    return getRef();
}

ref S funcRvalueRef2() __rvalue
{
    return globalS.a ? globalS : globalS2;
}

ref D funcRvalueRef3() __rvalue
{
    return getRefD();
}

ref D funcRvalueRef4() __rvalue
{
    return globalS.a ? globalD : globalD2;
}

bool consumeRvalueRefD(D d, int expect)
{
    d.d++;
    bool ok = globalD.d == expect + 1 && d.d == expect + 1;
    consumeD(__rvalue(d));
    ok = ok && d.d == expect + 2;

    // This changes the source object if it is passed by rvalue ref,
    // whose destructor will run before consumeRvalueRefD returns,
    // leaving globalD.d == 1 after return.
    // Unsure this is the specified behavior, just testing the inliner here.
    d = D();

    return ok;
}

void testRvalueRefReturn()
{
    // rvalue ref is ref
    funcRvalueRef1().a++;
    assert(globalS.test(4, 3, 5));
    funcRvalueRef2().c++;
    assert(globalS.test(4, 3, 6));

    globalD.d = 0;
    // Test double destruction behavior
    assert(consumeRvalueRefD(funcRvalueRef3(), 0));
    assert(consumeRvalueRefD(funcRvalueRef4(), 1));
}

/************************************/

void main()
{
    testValueReturn();
    testRefReturn();
    testRvalueRefReturn();
}
