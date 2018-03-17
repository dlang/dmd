/*
REQUIRED_ARGS: -dip1000
PERMUTE_ARGS:
*/

/*
TEST_OUTPUT:
---
fail_compilation/retscope6.d(6007): Error: returning `& i` escapes a reference to local variable `i`
---
*/

#line 6000

// https://issues.dlang.org/show_bug.cgi?id=17795

int* test() @safe
{
    int i;
    int*[][] arr = new int*[][](1);
    arr[0] ~= &i;
    return arr[0][0];
}
