/*
TEST_OUTPUT:
---
fail_compilation/fail5953a2.d(17): Error: expression expected, not `,`
    auto a3 = [,,,];    // invalid, but compiles
               ^
fail_compilation/fail5953a2.d(17): Error: expression expected, not `,`
    auto a3 = [,,,];    // invalid, but compiles
                ^
fail_compilation/fail5953a2.d(17): Error: expression expected, not `,`
    auto a3 = [,,,];    // invalid, but compiles
                 ^
---
*/
void main()
{
    auto a3 = [,,,];    // invalid, but compiles
}
