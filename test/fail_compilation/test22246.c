/* TEST_OUTPUT:
---
fail_compilation/test22246.c(106): Error: argument to `_Alignof` must be a type
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22246

#line 100

struct S { int m; };

int test()
{
    struct S s;
    return _Alignof(s);
}
