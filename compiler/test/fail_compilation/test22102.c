/* TEST_OUTPUT:
---
fail_compilation/test22102.c(254): Error: identifier or `(` expected
fail_compilation/test22102.c(254): Error: found `;` when expecting `)`
fail_compilation/test22102.c(255): Error: `=`, `;` or `,` expected to end declaration instead of `int22102`
---
*/
/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22102

#line 250
typedef int int22102;

void test22102()
{
    int22102();
    int22102(0);
}
