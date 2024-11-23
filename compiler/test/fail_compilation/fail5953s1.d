/*
TEST_OUTPUT:
---
fail_compilation/fail5953s1.d(12): Error: expression expected, not `,`
    S s2 = {,};   // invalid, but compiles
            ^
---
*/
void main()
{
    struct S{}
    S s2 = {,};   // invalid, but compiles
}
