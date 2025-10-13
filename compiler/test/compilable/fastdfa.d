/*
 * REQUIRED_ARGS: -preview=fastdfa
 */

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

    int v = *ret; // ideally would error, but not required
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
        int vS = *ptr;

    int vMid = *ptr;
    truthinessNo;
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
