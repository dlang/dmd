/*
 * REQUIRED_ARGS: -preview=fastdfa
 * TEST_OUTPUT:
---
fail_compilation/fastdfa.d(1019): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1034): Error: Argument is expected to be non-null but was null
fail_compilation/fastdfa.d(1027):        For parameter `ptr` in argument 0
fail_compilation/fastdfa.d(1044): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(1042): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(1051): Error: Variable `ptr` was required to be non-null and has become null
fail_compilation/fastdfa.d(1072): Error: Variable `ptr` was required to be non-null and has become null
fail_compilation/fastdfa.d(1087): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(1109): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(1126): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1132): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1141): Error: Dereference on null variable `ptr`
fail_compilation/fastdfa.d(1156): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1164): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1166): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1173): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1180): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1184): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1186): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1196): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1197): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1211): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1220): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1236): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1242): Error: Expression reads from an uninitialized variable, it must be written to at least once before reading
fail_compilation/fastdfa.d(1241):        For variable `val1`
fail_compilation/fastdfa.d(1245): Error: Expression reads from an uninitialized variable, it must be written to at least once before reading
fail_compilation/fastdfa.d(1241):        For variable `val1`
fail_compilation/fastdfa.d(1252): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1259): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1295): Error: Assert can be proven to be false
fail_compilation/fastdfa.d(1302): Error: Expression reads a default initialized variable that is a floating point type
fail_compilation/fastdfa.d(1302):        It will have the value of Not Any Number(nan), it will be propagated with mathematical operations
fail_compilation/fastdfa.d(1301):        For variable `v`
fail_compilation/fastdfa.d(1301):        Initialize to float.nan or 0 explicitly to disable this error
fail_compilation/fastdfa.d(1312): Error: Expression reads from an uninitialized variable, it must be written to at least once before reading
fail_compilation/fastdfa.d(1311):        For variable `v`
fail_compilation/fastdfa.d(1320): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa.d(1318):        Pointer stored in variable `b` has potentially escaped
fail_compilation/fastdfa.d(1339): Error: Stack variable stores a lifetime that exceeds its own
fail_compilation/fastdfa.d(1331):        For variable `ptr`
fail_compilation/fastdfa.d(1334):        A pointer to the cell of the variable `buf` has potentially escaped
fail_compilation/fastdfa.d(1350): Error: Expression reads from an uninitialized variable, it must be written to at least once before reading
fail_compilation/fastdfa.d(1349):        For variable `foo`
fail_compilation/fastdfa.d(1361): Error: Dereference on null variable `foo`
fail_compilation/fastdfa.d(1368): Error: Dereference on null object
fail_compilation/fastdfa.d(1399): Error: Cannot mutate the owner of an active borrow
fail_compilation/fastdfa.d(1397):        For variable `p`
fail_compilation/fastdfa.d(1398):        Borrowed here
fail_compilation/fastdfa.d(1406): Error: Cannot change a borrow variable declared outside of a loop
fail_compilation/fastdfa.d(1405):        For variable `b`
fail_compilation/fastdfa.d(1411): Error: Cannot store a borrow through a dereference in @safe code
fail_compilation/fastdfa.d(1418): Error: Cannot pass the owner of an active borrow to a function that may mutate it
fail_compilation/fastdfa.d(1418):        Parameter `p` must be const or immutable
fail_compilation/fastdfa.d(1417):        Borrowed here
fail_compilation/fastdfa.d(1426): Error: A borrow cannot outlive the variable it borrows from
fail_compilation/fastdfa.d(1425):        Possible source `s`
fail_compilation/fastdfa.d(1423):        The borrow is stored in variable `b`
fail_compilation/fastdfa.d(1434): Error: Cannot pass the owner of an active borrow to a function that may mutate it
fail_compilation/fastdfa.d(1434):        Parameter `p` must be const or immutable
fail_compilation/fastdfa.d(1433):        Borrowed here
fail_compilation/fastdfa.d(1442): Error: A borrow cannot outlive the variable it borrows from
fail_compilation/fastdfa.d(1441):        Possible source `x`
fail_compilation/fastdfa.d(1439):        The borrow is stored in variable `b`
fail_compilation/fastdfa.d(1449): Error: A borrow cannot outlive the variable it borrows from
fail_compilation/fastdfa.d(1448):        Possible source `x`
fail_compilation/fastdfa.d(1458): Error: Cannot change a borrow variable declared outside of a loop
fail_compilation/fastdfa.d(1455):        For variable `b`
fail_compilation/fastdfa.d(1474): Error: A borrow cannot outlive the variable it borrows from
fail_compilation/fastdfa.d(1473):        Possible source `c`
fail_compilation/fastdfa.d(1471):        The borrow is stored in variable `b`
fail_compilation/fastdfa.d(1488): Error: Cannot mutate the owner of an active borrow
fail_compilation/fastdfa.d(1483):        For variable `s`
fail_compilation/fastdfa.d(1484):        Borrowed here
fail_compilation/fastdfa.d(1489): Error: Cannot pass the owner of an active borrow to a function that may mutate it
fail_compilation/fastdfa.d(1489):        Parameter `obj` must be const or immutable
fail_compilation/fastdfa.d(1484):        Borrowed here
fail_compilation/fastdfa.d(1497): Error: Cannot mutate the owner of an active borrow
fail_compilation/fastdfa.d(1494):        For variable `x`
fail_compilation/fastdfa.d(1495):        Borrowed here
fail_compilation/fastdfa.d(1498): Error: Cannot mutate the owner of an active borrow
fail_compilation/fastdfa.d(1494):        For variable `x`
fail_compilation/fastdfa.d(1495):        Borrowed here
fail_compilation/fastdfa.d(1499): Error: Cannot mutate the owner of an active borrow
fail_compilation/fastdfa.d(1494):        For variable `x`
fail_compilation/fastdfa.d(1496):        Borrowed here
fail_compilation/fastdfa.d(1509): Error: Cannot mutate the owner of an active borrow
fail_compilation/fastdfa.d(1504):        For variable `x`
fail_compilation/fastdfa.d(1506):        Borrowed here
fail_compilation/fastdfa.d(1517): Error: Cannot mutate the owner of an active borrow
fail_compilation/fastdfa.d(1513):        For variable `x`
fail_compilation/fastdfa.d(1516):        Borrowed here
fail_compilation/fastdfa.d(1526): Error: Cannot mutate the owner of an active borrow
fail_compilation/fastdfa.d(1523):        For variable `x`
fail_compilation/fastdfa.d(1524):        Borrowed here
---
*/

#line 1000

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

void theSitchFinally2()
{
    int* ptr;

    scope (exit)
        int vS = *ptr; // error

    int vMid = *ptr; // error
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

int* escapeCondVar(bool cond)
{
    int* a = new int;
    scope int* b = new int;
    return cond ? a : b;
} // error, but on b only

void escapeCleanupRequiredRead() @system
{
    struct S
    {
        ~this()
        {
        }
    }

    S* ptr;

    {
        S buf;
        ptr = &buf;
        buf.__xdtor;
    } // ok

    S temp = *ptr; // error
}

void unitClassField() @system
{
    class Foo
    {
        int a;
    }

    Foo foo = void;
    int v = foo.a; // error
}

void nullClassField()
{
    class Foo
    {
        int a;
    }

    Foo foo;
    int v = foo.a; // error
}

void checkViaObjNullDeref(bool cond, int** ptrArg) @system
{
    int* var;
    int** ptr = cond ? &var : ptrArg;
    **ptr = 2; // error
}

/****************** Borrow checker (errors) ******************/

@system:

enum __fastdfa_returnborrow;

int* borrowFn(@__fastdfa_returnborrow int* x) @trusted { return x; }
int** borrowFn2(@__fastdfa_returnborrow int** x) @trusted { return x; }

void borrowTake(int* p) @safe {}
void borrowTakeConst(const(int)* p) @safe {}

struct BorrowS { int field; }
struct BorrowDtor { ~this() {} int field; }

struct BorrowStruct
{
    int* p;

    int** get() @__fastdfa_returnborrow @trusted { return &this.p; }
}

void methodTake(int** p) @safe {}

void borrowErr1()
{
    int* p;
    int** b = borrowFn2(&p);
    p = null; // error: reassigning a reference-type owner of an active borrow
}

void borrowErr2()
{
    int x;
    int* b = borrowFn(&x);
    b = null; // error
}

void borrowSafeErr(int** p, int* src) @safe
{
    *p = borrowFn(src); // error
}

void borrowErr4()
{
    int x;
    int* b = borrowFn(&x);
    borrowTake(&x); // error
}

void methodOutliveErr()
{
    int** b;
    {
        BorrowStruct s;
        b = s.get(); // error: borrow of this outlives the owner
    }
}

void methodPassErr()
{
    BorrowStruct s;
    int** b = s.get();
    methodTake(&s.p); // error: passing the borrowed owner to a mutating function
}

void borrowOutliveErr1()
{
    int* b;
    {
        BorrowDtor x;
        b = borrowFn(&x.field); // error: borrow outlives owner
    }
}

int* borrowOutliveErr2()
{
    int x;
    return borrowFn(&x); // error: returning a borrow of a local
}

void borrowLoopErr1()
{
    int x;
    int* b = borrowFn(&x);
    for (int i = 0; i < 2; ++i)
    {
        b = null; // error: changing a borrow declared outside the loop
    }
}

class BorrowClass
{
    int* p;

    int** get() @__fastdfa_returnborrow @trusted { return &this.p; }
}

void classOutliveErr()
{
    int** b;
    {
        BorrowClass c = new BorrowClass;
        b = c.get(); // error: borrow of this outlives the owner object
    }
}

void borrowMutateAssignCall()
{
    void call(ref const BorrowStruct, scope int**) {}
    void borrow(scope int**) {}

    BorrowStruct s;
    int** c = s.get();
    call(s, c); // ok
    borrow(c); // ok

    s = s.init; // error
    destroy(s); // error
}

void ternaryByRefNoInfect(bool condition)
{
    int* x;
    int** q = condition ? borrowFn2(&x) : &x;
    int** r = condition ?
        borrowFn2(&x) : // error borrow could be in here, and param is not const
        borrowFn2(&x);  // error
    x = null;
}

void borrowInTernaryConditionNoInfect()
{
    int* x;
    int* y;
    int** result = (borrowFn2(&x) != null) ?
        borrowFn2(&x) : // ok, the previous borrow wasn't stored
        &y;
    x = null; // error could be a borrow
}

void borrowInTernaryConditionInfect() {
    int* x;
    int* y;
    int** temp;
    int** result = ((temp = borrowFn2(&x)) !is null) ?
        borrowFn2(&x) : // error
        &y;
}

void borrowInConditionInfect()
{
    int* x = new int;
    if (int** temp = borrowFn2(&x))
    {
        x = null; // error
    }
    else
    {
        x = null; // ok - borrow not active in false branch
    }
}

/****************** End borrow checker (errors) ******************/
