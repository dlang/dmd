// REQUIRED_ARGS: -HCf=${RESULTS_DIR}/compilable/dtoh_ClassDeclaration.h -c
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/dtoh-postscript.sh

/*
TEST_OUTPUT:
---
---
*/

/*
ClassDeclaration has the following issues:
  * align(n) does nothing. You can use align on classes in C++, though It is generally regarded as bad practice and should be avoided
*/

extern (C++) class C
{
    byte a;
    int b;
    long c;
}

extern (C++) class C2
{
    int a = 42;
    int b;
    long c;

    this(int a) {}
}

extern (C) class C3
{
    int a = 42;
    int b;
    long c;

    this(int a) {}
}

extern (C++) align(1) class Aligned
{
    byte a;
    int b;
    long c;

    this(int a) {}
}

extern (C++) class A
{
    int a;
    C c;

    void foo();
    extern (C) void bar() {}
    extern (C++) void baz(int x = 42) {}

    struct
    {
        int x;
        int y;
    }

    union
    {
        int u1;
        char[4] u2;
    }

    struct Inner
    {
        int x;
    }

    static extern(C++) class InnerC
    {
        int x;
    }

    class NonStaticInnerC
    {
        int x;
    }

    alias I = Inner;

    extern(C++) class CC;

}
