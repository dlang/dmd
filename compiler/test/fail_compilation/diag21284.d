/*
 * Fix for issue 21284: "no property" error should point at the identifier, not the dot.
 * The error location should be on the line of the undefined identifier (`three`), not the dot.
TEST_OUTPUT:
---
fail_compilation/diag21284.d(17): Error: no property `three` for type `E`
fail_compilation/diag21284.d(10):        enum `E` defined here
---
*/
enum E { one, two }

void main()
{
    auto x =
        E
        .
        three;
}
