/*
TEST_OUTPUT:
---
fail_compilation/fail12236.d(30): Error: forward reference to inferred return type of function `f1`
    pragma(msg, f1.mangleof);  // forward reference error
                  ^
fail_compilation/fail12236.d(30):        while evaluating `pragma(msg, f1.mangleof)`
    pragma(msg, f1.mangleof);  // forward reference error
    ^
fail_compilation/fail12236.d(35): Error: forward reference to inferred return type of function `f2`
    pragma(msg, f2.mangleof);  // error <- weird output: "v"
                  ^
fail_compilation/fail12236.d(35):        while evaluating `pragma(msg, f2(T)(T).mangleof)`
    pragma(msg, f2.mangleof);  // error <- weird output: "v"
    ^
fail_compilation/fail12236.d(41): Error: template instance `fail12236.f2!int` error instantiating
    f2(1);
      ^
fail_compilation/fail12236.d(45): Error: forward reference to inferred return type of function `__lambda_L43_C5`
        pragma(msg, __traits(parent, x).mangleof);
                                       ^
fail_compilation/fail12236.d(45):        while evaluating `pragma(msg, __lambda_L43_C5(__T1)(a).mangleof)`
        pragma(msg, __traits(parent, x).mangleof);
        ^
---
*/

auto f1(int)
{
    pragma(msg, f1.mangleof);  // forward reference error
}

auto f2(T)(T)
{
    pragma(msg, f2.mangleof);  // error <- weird output: "v"
}

void main()
{
    f1(1);
    f2(1);

    (a) {
        int x;
        pragma(msg, __traits(parent, x).mangleof);
    } (1);
}
