// 9892
/*
TEST_OUTPUT:
---
fail_compilation/fail9892.d(11): Error: forward reference of enum member b
---
*/

enum
{
    a = b, //Segfault!
    b
}
