// REQUIRED_ARGS: -verrors=5

void main()
{
    { T a; }    // 1
    { T a; }    // 2
    { T a; }    // 3
    { T a; }    // 4
    { T a; }    // 5
    { T a; }    // 6
    { T a; }    // 7
    { T a; }    // 8
    { T a; }    // 9
    { T a; }    // 10
    { T a; }    // 11
    { T a; }    // 12
    { T a; }    // 13
    { T a; }    // 14
    { T a; }    // 15
    { T a; }    // 16
    { T a; }    // 17
    { T a; }    // 18
    { T a; }    // 19
    { T a; }    // 20 (default limit)
    { T a; }    // 21
    { T a; }    // 22
    { T a; }    // 23
    { T a; }    // 24
    { T a; }    // 25
}
/*
TEST_OUTPUT:
---
fail_compilation/verrors5.d(5): Error: undefined identifier `T`
fail_compilation/verrors5.d(6): Error: undefined identifier `T`
fail_compilation/verrors5.d(7): Error: undefined identifier `T`
fail_compilation/verrors5.d(8): Error: undefined identifier `T`
fail_compilation/verrors5.d(9): Error: undefined identifier `T`
error limit (5) reached, use `-verrors=0` to show all
---
*/
