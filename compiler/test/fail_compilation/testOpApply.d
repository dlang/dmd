/+
TEST_OUTPUT:
---
fail_compilation/testOpApply.d(89): Error: `testOpApply.SameAttr.opApply` called with argument types `(int delegate(int i) pure nothrow @nogc @safe)` matches both:
fail_compilation/testOpApply.d(75):     `testOpApply.SameAttr.opApply(int delegate(int) @system dg)`
and:
fail_compilation/testOpApply.d(80):     `testOpApply.SameAttr.opApply(int delegate(int) @system dg)`
    foreach (int i; sa) {}
    ^
fail_compilation/testOpApply.d(97): Error: `testOpApply.SameAttr.opApply` called with argument types `(int delegate(int i) pure nothrow @nogc @system)` matches both:
fail_compilation/testOpApply.d(75):     `testOpApply.SameAttr.opApply(int delegate(int) @system dg)`
and:
fail_compilation/testOpApply.d(80):     `testOpApply.SameAttr.opApply(int delegate(int) @system dg)`
    foreach (int i; sa) {}
    ^
fail_compilation/testOpApply.d(118): Error: `sa.opApply` matches more than one declaration:
    foreach (i; sa) {}
                ^
fail_compilation/testOpApply.d(104):        `int(int delegate(int) dg)`
and:
    int opApply(int delegate(int) dg)
        ^
fail_compilation/testOpApply.d(109):        `int(int delegate(string) dg)`
    int opApply(int delegate(string) dg)
        ^
fail_compilation/testOpApply.d(118): Error: cannot uniquely infer `foreach` argument types
    foreach (i; sa) {}
    ^
fail_compilation/testOpApply.d(139): Error: `sa.opApply` matches more than one declaration:
    foreach (i; sa) {}
                ^
fail_compilation/testOpApply.d(125):        `int(int delegate(int) dg)`
and:
    int opApply(int delegate(int) dg)
        ^
fail_compilation/testOpApply.d(130):        `int(int delegate(long) dg)`
    int opApply(int delegate(long) dg)
        ^
fail_compilation/testOpApply.d(139): Error: cannot uniquely infer `foreach` argument types
    foreach (i; sa) {}
    ^
fail_compilation/testOpApply.d(163): Error: `sa.opApply` matches more than one declaration:
    foreach (i; sa) {}
                ^
fail_compilation/testOpApply.d(147):        `int(int delegate(int) dg)`
and:
    int opApply(int delegate(int) dg)
        ^
fail_compilation/testOpApply.d(153):        `int(int delegate(ref int) dg)`
    int opApply(int delegate(ref int) dg)
        ^
fail_compilation/testOpApply.d(163): Error: cannot uniquely infer `foreach` argument types
    foreach (i; sa) {}
    ^
fail_compilation/testOpApply.d(171): Error: `sa.opApply` matches more than one declaration:
    foreach (ref i; sa) {}
                    ^
fail_compilation/testOpApply.d(147):        `int(int delegate(int) dg)`
and:
    int opApply(int delegate(int) dg)
        ^
fail_compilation/testOpApply.d(153):        `int(int delegate(ref int) dg)`
    int opApply(int delegate(ref int) dg)
        ^
fail_compilation/testOpApply.d(171): Error: cannot uniquely infer `foreach` argument types
    foreach (ref i; sa) {}
    ^
---
+/

// https://issues.dlang.org/show_bug.cgi?id=21683

struct SameAttr
{
    int opApply(int delegate(int) @system dg) @system
    {
        return 0;
    }

    int opApply(int delegate(int) @system dg) @safe
    {
        return 0;
    }
}

void testSameAttr() @safe
{
    SameAttr sa;
    foreach (int i; sa) {}
}

// Line 100 starts here

void testSameAttr() @system
{
    SameAttr sa;
    foreach (int i; sa) {}
}

// Line 200 starts here

struct DifferentTypes
{
    int opApply(int delegate(int) dg)
    {
        return 0;
    }

    int opApply(int delegate(string) dg)
    {
        return 0;
    }
}

void testDifferentTypes()
{
    DifferentTypes sa;
    foreach (i; sa) {}
}

// Line 300 starts here

struct CovariantTypes
{
    int opApply(int delegate(int) dg)
    {
        return 0;
    }

    int opApply(int delegate(long) dg)
    {
        return 0;
    }
}

void testCovariantTypes()
{
    CovariantTypes sa;
    foreach (i; sa) {}
}

// Line 400 starts here

struct DifferentQualifiers
{
    int x;
    int opApply(int delegate(int) dg)
    {
        x = 1;
        return 0;
    }

    int opApply(int delegate(ref int) dg)
    {
        x = 2;
        return 0;
    }
}

void testDifferentQualifiers()
{
    DifferentQualifiers sa;
    foreach (i; sa) {}
}

// Line 500 starts here

void testDifferentQualifiersRef()
{
    DifferentQualifiers sa;
    foreach (ref i; sa) {}
}
