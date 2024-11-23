/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test20881.d(28): Error: scope variable `this` may not be returned
    int* borrowC() scope return { return ptr; }
                                         ^
fail_compilation/test20881.d(35): Error: address of variable `s` assigned to `global` with longer lifetime
    global = s.borrowA;
           ^
fail_compilation/test20881.d(36): Error: address of variable `s` assigned to `global` with longer lifetime
    global = s.borrowB;
           ^
fail_compilation/test20881.d(37): Error: address of variable `s` assigned to `global` with longer lifetime
    global = s.borrowC;
           ^
---
*/
@safe:

// https://issues.dlang.org/show_bug.cgi?id=20881
struct S
{
    int* ptr;

    auto borrowA() return /*scope inferred*/ { return ptr; }
    int* borrowB() return { return ptr; }
    int* borrowC() scope return { return ptr; }
}

void main()
{
    static int* global;
    S s;
    global = s.borrowA;
    global = s.borrowB;
    global = s.borrowC;
}
