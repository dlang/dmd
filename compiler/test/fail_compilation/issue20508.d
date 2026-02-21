/* TEST_OUTPUT:
---
fail_compilation/issue20508.d(16): Error: returning `slice` inferred as scope as it may leak a reference to the stack is not allowed in a `@safe` function
fail_compilation/issue20508.d(22): Error: returning scope variable `p` as it may leak a reference to the stack is not allowed in a `@safe` function
fail_compilation/issue20508.d(29): Error: assigning address of variable `arr` to `slice` with longer lifetime is not allowed in a `@safe` function
---
*/

module issue20508 2024;

@safe
int[] foo()
{
    int[3] arr = [1,2,3];
    int[] slice = arr[];
    return slice;
}

@safe int* bar()
{
    scope int* p;
    return p;
}

int[] slice;
@safe void abc()
{
    int[3] arr = [1,2,3];
    slice = arr[];
}
