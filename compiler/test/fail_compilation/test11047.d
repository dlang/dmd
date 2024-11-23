/*
TEST_OUTPUT:
---
fail_compilation/test11047.d(15): Error: value of `x` is not known at compile time
@(++x, ++x) void foo(){}
  ^
fail_compilation/test11047.d(15): Error: value of `x` is not known at compile time
@(++x, ++x) void foo(){}
       ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=11047

int x;
@(++x, ++x) void foo(){}

@safe pure void test()
{
    __traits(getAttributes, foo);
    __traits(getAttributes, foo)[0];
}
