/*
TEST_OUTPUT:
---
fail_compilation/fail5953a1.d(11): Error: expression expected, not `,`
    auto a2 = [,];    // invalid, but compiles
               ^
---
*/
void main()
{
    auto a2 = [,];    // invalid, but compiles
}
