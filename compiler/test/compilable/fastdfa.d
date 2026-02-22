/*
 * REQUIRED_ARGS: -preview=fastdfa
 */

void typeNextIterate(Type t)
{
    Type ts;

    {
        Type ta = new Type;
        Type* pt;

        for (pt = &ts; *pt != t; pt = &(cast(TypeNext)*pt).next) // no error
        {
        }

        *pt = ta;
    }
}

void test8()
{
    bool b;
    bool* pb = &b;

    assert(b == false);
    *pb = true;
    assert(b == true);
    *pb = false;
    assert(b == false);
}

void uninitWithFuncCheck()
{
    struct Foo
    {
        bool isB;

        void initThis(bool b)
        {
            this.isB = b;
        }
    }

    Foo foo = void;
    foo.initThis = false; // ok, we can't know if a method will initialize
}

string apUninitWrite(void* ap)
{
    string result = void;
    auto p1 = cast(size_t*) &result;

    *p1 = *cast(size_t*) ap; // no error its a write after all
    return result;
}

void pointerArithmeticObj()
{
    ubyte[4] storage;

    ubyte* ptr = &storage[1];
    ptr++;
}

void pickPtr(bool condition)
{
    int i1, i2;
    int* ptr = condition ? &i1 : &i2;
}

@safe:

bool isNull1(int* ptr)
{
    return ptr is null;
}

void isNull2()
{
    int* ptr;

    if (ptr !is null)
    {
        int v = *ptr; // Will not error due to the null test
    }
    else
    {
    }
}

bool truthinessYes()
{
    return true;
}

bool truthinessNo()
{
    return false;
}

int* nullable1(int* ptr)
{
    int* ret;

    if (truthinessYes())
    {
    }
    else
    {
        ret = ptr;
    }

    int v = *ret; // no error, cannot know state of ret
    return ret;
}

void nullable2a(S2* head, S2* previous)
{
    S2* start;

    {
        S2* current;

        if (start is null)
        {
            previous = head;
            start = previous;
            current = start.next;
        }
        else
        {
            current = start.next;
        }

        previous = current.next; // should not error
    }
}

void nullable2b(S2* start, S2* head, S2* previous)
{
    {
        S2* current;

        if (start is null)
        {
            previous = head;
            start = previous;
            current = start.next;
        }
        else
        {
            current = start.next;
        }

        previous = current.next; // should not error
    }
}

void nullable3(S2** nextParent, S2* r)
{
    if (*nextParent is null)
        *nextParent = r; // should not error
}

void nullable4(int* temp) @trusted
{
    int buffer;

    if (temp is null)
        temp = &buffer;

    int v = *temp; // should not error
}

void truthiness1()
{
    bool a = true;
    assert(a != false);
    assert(a == !false);

    bool b = !a, c = a != false, d = a == false;
}

struct S1
{
    int* field;
}

struct S2
{
    S2* next;
    S2* another;
}

void trackS1(S1 s)
{
    bool b = s.field !is null;
}

void branchCheck()
{
    bool val;

    if (false)
    {
        val = true;
    }
}

void loopy()
{
    int j;

    Loop: foreach (i; 0 .. 10)
    {
        j += i * j;

        if (j > 5)
            continue;
        else if (j > 6)
            break;
    }
}

void loopy2()
{
    Loop: do
    {

    }
    while (false);
}

void loopy3()
{
    ReadLoopConsole: for (;;)
    {
    }
}

void loopy4()
{
    Loop1: foreach (i; 0 .. 10)
    {
        break Loop1;
    }

    Loop2: foreach (i; 0 .. 10)
    {
        continue Loop2;
    }
}

void loopy5()
{
    Loop: foreach (i; 0 .. 4)
    {
        switch (i)
        {
        case 0:
            break;

        case 1:
            continue;

        case 2:
            continue Loop;

        default:
            break Loop;
        }
    }
}

void loopy8()
{
    int* ptr = new int;
    bool b = ptr !is null;

    foreach (i; 0 .. 2)
    {
        assert(b); // outdated consequences
        ptr = null; // error
    }
}

void loopy9(int[] input)
{
    bool result;

    foreach (val; input)
    {
        if (val == 1)
            result = true;
    }

    assert(result);
}

void loop10(bool match, uint[] testCases)
{
    foreach (tc; testCases)
    {
        bool failure;
        if (!match)
            failure = true;
        assert(!failure);
    }
}

void loopy11()
{
    static struct Tup(T...)
    {
        T field;
        alias field this;
    }

    auto t1 = Tup!(int, string)(10, "hi :)");
    int i;

    foreach (e; t1)
    {
        static if (is(typeof(e) == int))
        {
            assert(i == 0);
        }
        else static if (is(typeof(e) == string))
        {
            assert(i == 1);
        }

        i++;
    }
}

void nodeFind()
{
    static struct Node
    {
        Node* next;

        static Node* previous;
    }

    Node* start = Node.previous;
    Node* current;

    if (start is null)
    {
        start = Node.previous;
        current = start.next;
    }
    else
        current = start.next;

    Node.previous = current.next;
}

void referenceThat() @trusted
{
    int[2] val;
    int* ptr = &val[1];
}

void logicalAnd(bool b, int* ptr)
{
    bool a = true;

    if (a && b && ptr !is null)
    {
    }
}

void logicalOr(bool b, int* ptr)
{
    bool a = true;

    if ((a && b) || ptr !is null)
    {
        int val = *ptr;
    }
}

void rotateForChildren(void** parent)
{
    if (*parent is null)
        return;
}

void removeValue(S2* valueNode)
{
    if (valueNode.another !is null)
        valueNode.next.next = valueNode.next;

    if (valueNode.next.next is valueNode)
        valueNode.next.next = valueNode.another;
    else
        valueNode.next.another = valueNode.another;
}

void goingByRef1(ref int* ptr)
{
    ptr = new int;
}

void goingByRef2(ref int* ptr)
{
    if (ptr is null)
        ptr = new int;
}

void goingByRef3(ref int* ptr)
{
    if (*ptr == 3)
        ptr = new int;
}

void aaWrite1()
{
    string[string] env;
    env["MYVAR1"] = "first";
    env["MYVAR2"] = "second";

    assert(env["MYVAR1"] == "first");
}

void aaWrite2()
{
    struct Wrapper
    {
        string[string] env;
    }

    Wrapper* wrapper = new Wrapper;

    wrapper.env["MYVAR1"] = "first";
    wrapper.env["MYVAR2"] = "second";
}

void lengthChange()
{
    int[] test;
    test.length = 10;
    assert(test.length == 10);
    assert(test.ptr != null);

    test.length = 1;
    assert(test.length == 1);
    assert(test.ptr != null);

    test = test[5 .. 5];

    test.length = 0;
    assert(test.length == 0);
    assert(test.ptr != null);
}

void callLaterEffect1() @system
{
    static struct Thing
    {
        int* data;

        ~this()
        {
            (*data)++;
        }
    }

    int val;
    scope (exit)
        assert(val == 1);

    Thing thing = Thing(&val);
}

void callLaterEffect2() @system
{
    static struct Thing
    {
        int* data;

        ~this()
        {
            (*data)++;
        }
    }

    int val;
    Thing thing = Thing(&val);

    val = 0;
    assert(val == 1);
}

void callByRefEffect() @system
{
    static void effect(Args...)(auto ref Args args)
    {
        args[0] = -1;
    }

    int val;
    effect(val);
    assert(val == 1);
}

struct SkippableType
{
    bool a, b, c, d;
}

bool skipItIf(SkippableType* i, SkippableType** o)
{
    *o = i;
    return true;
}

void skippedNot(SkippableType* token) @system
{
    SkippableType* storage;

    if (token.a || token.b || skipItIf(token, &storage) && (storage.a
            || storage.b) || (token.c || token.d))
    {
    }
}

void indexAA()
{
    struct MyStruct
    {
        int x;
    }

    int[MyStruct] td;
    td[MyStruct(10)] = 4;
    assert(td[MyStruct(10)] == 4);
    assert(MyStruct(20) !in td);
    assert(td[MyStruct(10)] == 4);
}

void dupMatch()
{
    static ubyte[] copy(ubyte[] input)
    {
        return input;
    }

    struct Escape
    {
        ubyte[] array;
    }

    ubyte[] reference = new ubyte[20];
    ubyte[] another = copy(reference);
    Escape escape = Escape(another[0 .. 0]);

    assert(reference[] == another[]);
}

void classCall() @trusted
{
    class C
    {
        this(int* val)
        {
            *val = 1;
        }

        void method() @safe
        {
        }
    }

    int anInt;
    C c = new C(&anInt);

    assert(anInt == 2);
    c.method;
}

void unknownLoopIterationCount()
{
    bool[] res;

    while (auto value = truthinessYes())
        res ~= value;

    assert(res == [1, 2, 3]);
}

struct OrAndIndirect
{
    OrAndIndirect* left_, right_;
    int val;

    OrAndIndirect* left()
    {
        return left_;
    }

    OrAndIndirect* right()
    {
        return right_;
    }

    OrAndIndirect* orAndIndirect(OrAndIndirect* w)
    {
        OrAndIndirect* wl = w.left;
        OrAndIndirect* wr = w.right;

        if ((wl is null || wl.val == 0) && (wr is null || wr.val == 0))
        {
        }
        else
        {
            if (wr is null || wr.val == 0)
            {
                wl.val = 0;
            }
        }

        return null;
    }
}

void gateUpgrade(bool gate)
{
    int* ptr;

    if (gate)
    {
        ptr = new int;
    }

    if (gate)
    {
        assert(ptr !is null); // no error
    }
}

void checkCompare(string input)
{
    if (input == "^^")
        return;
    char c = input[0];
}

void incrementEffect()
{
    int[] array;
    assert(array.length++ == 0);
    assert(array.length == 1);
}

void unknownArrayLiteralCall() @trusted
{
    int toCall(int* ptr)
    {
        return *ptr;
    }

    int val;
    int[] literal = [toCall(&val)];
    assert(val == 0);
}

void branchKill(bool b)
{
    assert(!b);

    if (b)
    {
        int* ptr;
        int val = *ptr; // no error branch dead
    }
}

void switchMakeKnown(int v, int[] slice)
{
    switch (v)
    {
    case 0:
        slice = [];
        break;
    default:
        break;
    }

    if (slice.length > 0 && slice[1] == 2)
        return;
}

void nullCompareDerefNot()
{
    static int* source;

    while (true)
    {
        int* ptr;

        while (true)
        {
        }

        ptr = source;

        if (ptr == null)
            break;

        switch (*ptr) // no error
        {
        default:
            break;
        }
    }
}

void sliceAssignNull(string[] dst)
{
    dst[] = null;
    dst[0] = null;
}

void gateCheckBadAssert1(bool gate)
{
    if (gate)
        assert(!gate); // no error its basically assert(0);
}

void gateCheckBadAssert2(bool gate)
{
    if (!gate)
        assert(gate); // no error its basically assert(0);
}

bool isEqualWithGuard(int* value, int* expected)
{
    if (value is null && expected is null)
        return true;

    return *value == *expected;
}

void orIfUnknown(bool b) @system
{
    Object o;

    if (b || (o = Object.factory("object.Object")) !is null)
    {
    }

    if (string s = o.toString)
    {
    }
}

void gatedIfVRP(bool gate)
{
    int i;

    if (gate)
        i = 3;

    assert(i == 3); // ok
}

void orUnknownNonNull(int* ptr)
{
    if (!ptr || *ptr == 2)
    {
    }
}

void sliceLength(int[] slice)
{
    assert(slice.length == 3); // ok
    assert(slice.length == 2); // error
}

struct Complex_f
{
    float re, im;

    static Complex_f sqrtc(ref Complex_f z)
    {
        if (z.re >= 0)
        {
        }
        return Complex_f.init;
    }
}

void loopConditionGreaterThan(int v)
{
    int val;

    foreach (i; 0 .. 10)
    {
        if (v > 2)
            assert(val > 0);
        else
            val++;
        v++;
    }
}

void paArgInterval(int another)
{
    assert(1 <= another && another <= 5);
    assert(another == 3);
}

void checkNullOr(int* val2)
{
    int* val;
    if ((val = val2) is null || *val)
    {
    }
}

void checkNumAssignCall()
{
    int func()
    {
        return 3;
    }

    int c = 0;
    c = func();
    assert(c != -1);
    assert(c == '2');
}

void checkPostfixPA()
{
    int i = 0;
    assert(++i == 1);
    assert(i++ == 1);
}

void checkGreaterThanNoInfer()
{
    bool inferable(string s)
    {
        return s.length < 3 || s[2] == 'e';
    }

    assert(inferable(null));
}

void checkEqualAssignInt(string str)
{
    int i;

    i = (str == "hello");
    assert(i == 1);
}

int* checkPtrFromStructNoEffect()
{
    // Make sure no effect can come from a field via a pointer.

    static struct PtrFromStruct
    {
        static PtrFromStruct* global;
        int field;
    }

    PtrFromStruct* ptrFromStruct()
    {
        return PtrFromStruct.global;
    }

    if (auto p = ptrFromStruct())
    return &p.field;
    return null;
}

void initDefault()
{
    bool b;
    bool got = b;
}

void seeEffectOnObject1(bool condition)
{
    bool* a = new bool(true), b = new bool(true);
    bool got = *(condition ? a : b);
    assert(!got); // would be nice to error, but won't due to indirection
}

void seeEffectOnObject2(bool condition)
{
    bool* a = new bool(false), b = new bool(false);
    bool got = *(condition ? a : b);
    assert(got); // would be nice to error, but won't due to indirection
}

void checkLengthDeref(int[] slice)
{
    static bool expectNonNull(ref int[] arr)
    {
        int v = arr[0];
        return true;
    }

    if (slice.length && expectNonNull(slice))
    {
    }
}

void uninitMsgPut1()
{
    static void uninitMsgSinkPut(ref char[] buf, string text)
    {
    }

    char[1024] buf = void;
    char[] sink = buf; // cast

    uninitMsgSinkPut(sink, "ok"); // mutates buf

    char[1024] result = buf; // ok
}

void uninitMsgPut2()
{
    static void uninitMsgSinkPut(ref char[] buf, string text)
    {
    }

    char[1024] buf = void;
    char[] sink = buf[]; // slice

    uninitMsgSinkPut(sink, "ok"); // mutates buf

    char[1024] result = buf; // ok
}

void loopInLoopCount()
{
    int count;
    auto sample = [99];

    foreach (j; sample)
    {
        if (j == 0)
        {
        }
        else if (j == 99)
        ++count;
    }

    assert(9 < count);
}

struct Ternary
{
    private ubyte value = 6;

    static Ternary make(ubyte b)
    {
        Ternary r = void;
        r.value = b; // no error
        return r; // no error
    }
}

class TypeNext
{
    Type next;
}

class Type
{

}

void uninitStackPtrOf()
{
    char[4] buf;
    auto ptr = buf.ptr;

    if (ptr is buf.ptr)
    {
    }
    else
    {
        bool b;
        assert(b); // ok, branch not taken
    }
}

struct BigFoo
{
    ubyte[256] buf;

    static BigFoo getUninitBigFoo()
    {
        BigFoo ret = void;
        return ret; // no error
    }
}

void initOverBranches(bool gate)
{
    int value = void;

    for (;;)
    {
        if (gate)
        value = 1;
        else
        value = 2;

        if (value > 0)
        break;
    }
}

void uninitTestConditionAndDoLoop(bool b) {
    size_t bufStart = void;
    if (b)
    {
        bufStart = 39;
        do
        {
        } while (true);
    }
    else
    {
        bufStart = 39;
        do
        {
        } while (true);
    }

    const minw = bufStart;
}

void checkFloatInit1_1(bool condition)
{
    float v;
    float t = v; // ok, not a math op

    if (condition)
        v = 2;

    float u = v * 2; // no error
}

void checkFloatInit2_1(bool condition)
{
    float v = float.init;
    float t = v; // ok

    if (condition)
        v = 2;

    float u = v * 2; // no error
}

void checkFloatInit3_1(bool condition)
{
    float v = 0;
    float t = v; // ok

    if (condition)
        v = 2;

    float u = v * 2; // no error
}

void readFromUninit2()
{
    struct Foo
    {
        int val;
    }

    Foo foo = void;
    foo.val = 2; // ok, partial initialization
}

void checkFloatInit2_2(bool condition)
{
    float v = float.init;
    float t = v * 2; // ok

    if (condition)
        v = 2;

    float u = v * 2; // no error
}

void checkFloatInit3_2(bool condition)
{
    float v = 0;
    float t = v * 2; // ok

    if (condition)
        v = 2;

    float u = v * 2; // no error
}

void checkFloatInit4(float[] array) {
    foreach(e; array) {
        float t = e * 2; // no error
    }
}

void checkFloatInit5() {
    float thing = 2;

    if (float var = thing) {
        float t = var * 2;
    }
}
