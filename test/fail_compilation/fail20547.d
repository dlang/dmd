/*
TEST_OUTPUT:
---
fail_compilation/fail20547.d(11): Error: cannot create a `int[string]` with `new`
fail_compilation/fail20547.d(12): Error: cannot create a `int[string]` with `new`
---
*/

void main()
{
    int[string] b = new int[string];
    int[string] c = new typeof(b);
}
