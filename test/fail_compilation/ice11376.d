/*
TEST_OUTPUT:
---
fail_compilation/ice11376.d(17): Error: invalid array operation 'x1[] = x2[] * x3[]' because X doesn't support necessary arithmetic operations
fail_compilation/ice11376.d(21): Error: invalid array operation 's2[] += s1[]' because string is not a scalar type
fail_compilation/ice11376.d(25): Error: invalid array operation 'pa1[] *= pa2[]' for element type int*
---
*/

void main()
{
    struct X { }

    auto x1 = [X()];
    auto x2 = [X()];
    auto x3 = [X()];
    x1[] = x2[] * x3[];

    string[] s1;
    string[] s2;
    s2[] += s1[];

    int*[] pa1;
    int*[] pa2;
    pa1[] *= pa2[];
}
