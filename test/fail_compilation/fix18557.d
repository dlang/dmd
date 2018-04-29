/* TEST_OUTPUT:
---
fail_compilation/fix18557.d(13): Error: AA key type `struct S` has no data fields and cannot be used as a key
fail_compilation/fix18557.d(18): Error: AA key type `int[0]` has no size and cannot be used as a key
---
*/

struct S { }

void test(int[S] x)
{
    S s;
    x[s] = 3;
}

void test2()
{
    int[int[0]] bb;
}
