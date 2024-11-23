// https://issues.dlang.org/show_bug.cgi?id=23591
/*
TEST_OUTPUT:
---
fail_compilation/fail23591.d(17): Error: cannot implicitly convert expression `square(i) , null` of type `string` to `int`
    int x = cast(string)square(i);
                              ^
fail_compilation/fail23591.d(18): Error: cannot implicitly convert expression `assert(0) , null` of type `real function(char)` to `int`
    int y = cast(real function(char))assert(0);
                                     ^
---
*/
noreturn square(int x);

int example(int i)
{
    int x = cast(string)square(i);
    int y = cast(real function(char))assert(0);
    return x + y;
}
