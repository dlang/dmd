/*
TEST_OUTPUT:
---
fail_compilation/fail15702.d(52): Error: cast from int*[] to void[] not allowed in safe code
fail_compilation/fail15702.d(53): Error: cast from Object[] to void[] not allowed in safe code
fail_compilation/fail15702.d(54): Error: cannot implicitly convert expression (ptrs) of type int*[] to void[] in @safe code because int*[] has indirections
fail_compilation/fail15702.d(55): Error: cannot implicitly convert expression (objs) of type Object[] to void[] in @safe code because Object[] has indirections
fail_compilation/fail15702.d(56): Error: cannot implicitly convert expression (tees) of type T[] to void[] in @safe code because T[] has indirections
fail_compilation/fail15702.d(57): Error: cannot implicitly convert expression ([new Object]) of type Object[] to void[] in @safe code because Object[] has indirections
fail_compilation/fail15702.d(58): Error: cast from Object[] to int[] not allowed in safe code
---
*/
void notTrustworthy(void[] buf) @trusted
{
    auto bytes = cast(ubyte[]) buf;
    bytes[0] = 123;
}
void trustworthy(const(void)[] buf) @trusted { }

class A {}
class B : A {}
struct S { int x; }
struct T { int* x; }

int[] ints;
int*[] ptrs;
Object[] objs;
S[] asses;
T[] tees;

void safeFun() @safe
{
    // should be allowed:
    notTrustworthy(ints);
    notTrustworthy(asses);
    trustworthy(ints);
    trustworthy(ptrs);
    trustworthy(objs);
    const(void)[] arrconst = ptrs;
    const(void[]) constarr = ptrs;
    auto a1 = cast(const(int)[]) objs;
    auto a2 = cast(int*[]) ptrs;
    const(int*)[] a3 = ptrs;
    auto a4 = cast(const(int*)[]) a3;
    double[][] dbls = [[1, 2], [3, 4], [5, 6, 7]];
    const(T)[] cts = tees;

    // typeof should not emit errors
    alias X = typeof(notTrustworthy(ptrs));

    // should be prohibited:
    notTrustworthy(cast(void[]) ptrs);
    notTrustworthy(cast(void[]) objs);
    notTrustworthy(ptrs);
    notTrustworthy(objs);
    notTrustworthy(tees);
    void[] b1 = [ new Object() ];
    auto b2 = cast(int[]) objs;
}

void unsafeFun() @system
{
    notTrustworthy(ints);
    notTrustworthy(asses);
    trustworthy(ints);
    trustworthy(ptrs);
    trustworthy(objs);
    const(void)[] arrconst = ptrs;
    const(void[]) constarr = ptrs;
    auto a1 = cast(const(int)[]) objs;
    auto a2 = cast(int*[]) ptrs;
    const(int*)[] a3 = ptrs;
    auto a4 = cast(const(int*)[]) a3;
    double[][] dbls = [[1, 2], [3, 4], [5, 6, 7]];
    const(T)[] cts = tees;

    alias X = typeof(notTrustworthy(ptrs));

    notTrustworthy(cast(void[]) ptrs);
    notTrustworthy(cast(void[]) objs);
    notTrustworthy(ptrs);
    notTrustworthy(objs);
    notTrustworthy(tees);
    void[] b1 = [ new Object() ];
    auto b2 = cast(int[]) objs;
}
