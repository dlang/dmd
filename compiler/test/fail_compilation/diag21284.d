/*
TEST_OUTPUT:
---
fail_compilation/diag21284.d(16): Error: no property `three` for type `E`
fail_compilation/diag21284.d(9):        enum `E` defined here
---
*/
// https://issues.dlang.org/show_bug.cgi?id=21284 (github issue)
enum E { one, two }

void test21284()
{
    auto x =
        E
        .
        three;
}
