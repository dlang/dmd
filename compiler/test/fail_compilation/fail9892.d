// https://issues.dlang.org/show_bug.cgi?id=9892
/*
TEST_OUTPUT:
---
fail_compilation/fail9892.d(13): Error: enum member `fail9892.a` circular reference to `enum` member
    a = b, //Segfault!
    ^
---
*/

enum
{
    a = b, //Segfault!
    b
}
