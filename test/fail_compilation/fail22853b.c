/* TEST_OUTPUT:
---
fail_compilation/fail22853b.c(8): Error: found `/` instead of statement
---
*/
void test22853()
{
    /+ https://issues.dlang.org/show_bug.cgi?id=22853 +/
}
