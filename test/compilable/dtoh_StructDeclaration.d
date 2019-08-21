// REQUIRED_ARGS: -HCf=${RESULTS_DIR}/compilable/dtoh_StructDeclaration.out -c
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/dtoh-postscript.sh

/*
TEST_OUTPUT:
---
---
*/

/*
StructDeclaration has the following issues:
  * align different than 1 does nothing; we should support align(n), where `n` in [1, 2, 4, 8, 16]
  * align(n): inside struct definition doesn’t add alignment, but breaks generation of default ctors
  * default ctors should be generated only if struct has no ctors
  * if a struct has ctors defined, only default ctor (S() { … }) should be generated to init members to default values, and the defined ctors must be declared
  * if a struct has ctors defined, the declared ctors must have the name of the struct, not __ctor, as `__ctor` might not be portable
  * if a struct has a `member = void`, dtoh code segfaults
  * a struct should only define ctors if it’s extern (C++)
*/

extern (C++) struct S
{
    byte a;
    int b;
    long c;
}

extern (C++) struct S2
{
    int a = 42;
    int b;
    long c;

    this(int a) {}
}

extern (C) struct S3
{
    int a = 42;
    int b;
    long c;

    this(int a) {}
}

extern (C++) align(1) struct Aligned
{
    //align(1):
    byte a;
    int b;
    long c;

    this(int a) {}
}

extern (C++) struct A
{
    int a;
    S s;

    extern (D) void foo();
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

    alias I = Inner;

    extern(C++) class C;

}
