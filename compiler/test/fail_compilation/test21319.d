// https://issues.dlang.org/show_bug.cgi?id=21319
/*
TEST_OUTPUT:
---
fail_compilation/test21319.d(13): Error: circular reference to `test21319.C.c`
    immutable C c = new C();
                    ^
---
*/

class C
{
    immutable C c = new C();
}
