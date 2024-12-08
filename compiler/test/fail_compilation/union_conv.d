/*
REQUIRED_ARGS: -preview=fixImmutableConv
TEST_OUTPUT:
---
fail_compilation/union_conv.d(20): Error: cannot implicitly convert expression `c` of type `const(U)` to `U`
    U m = c;
          ^
---
*/

union U
{
    int i;
    int* p;
}

void main()
{
    const U c;
    U m = c;
}
