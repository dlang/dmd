/* TEST_OUTPUT:
---
fail_compilation/fail22853b.c(10): Error: found `/` instead of statement
    /+ https://issues.dlang.org/show_bug.cgi?id=22853 +/
    ^
---
*/
void test22853()
{
    /+ https://issues.dlang.org/show_bug.cgi?id=22853 +/
}
