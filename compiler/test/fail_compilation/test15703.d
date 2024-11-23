/*
REQUIRED_ARGS: -m32
TEST_OUTPUT:
---
fail_compilation/test15703.d(33): Error: cast from `Object[]` to `uint[]` not allowed in safe code
     auto longs = cast(size_t[]) objs;          // error
                  ^
fail_compilation/test15703.d(33):        Target element type is mutable and source element type contains a pointer
fail_compilation/test15703.d(35): Error: cast from `object.Object` to `const(uint)*` not allowed in safe code
     auto longp = cast(const(size_t)*) objs[0]; // error
                  ^
fail_compilation/test15703.d(35):        Source type is incompatible with target type containing a pointer
fail_compilation/test15703.d(38): Error: cast from `uint[]` to `Object[]` not allowed in safe code
     objs = cast(Object[]) al;                  // error
            ^
fail_compilation/test15703.d(38):        Target element type contains a pointer
fail_compilation/test15703.d(54): Error: cast from `int[]` to `S[]` not allowed in safe code
    S[] b = cast(S[]) a;
            ^
fail_compilation/test15703.d(54):        Target element type is opaque
fail_compilation/test15703.d(55): Error: cast from `S[]` to `int[]` not allowed in safe code
    a = cast(int[]) b;
        ^
fail_compilation/test15703.d(55):        Source element type is opaque
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15703

void test() @safe
{
     auto objs = [ new Object() ];
     auto longs = cast(size_t[]) objs;          // error
     auto longc = cast(const(size_t)[]) objs;   // ok
     auto longp = cast(const(size_t)*) objs[0]; // error

     size_t[] al;
     objs = cast(Object[]) al;                  // error

     auto am = cast(int[])[];
}

void test2() @safe
{
    const(ubyte)[] a;
    auto b = cast(const(uint[])) a;
}

struct S;

void opaque() @safe
{
    auto a = [1, 2];
    S[] b = cast(S[]) a;
    a = cast(int[]) b;
}
