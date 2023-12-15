/* TEST_OUTPUT:
---
fail_compilation/test22102.c(254): Error: expected identifier for declarator
fail_compilation/test22102.c(255): Error: no type-specifier for parameter
fail_compilation/test22102.c(255): Error: found `0` when expecting `,`
fail_compilation/test22102.c(255): Error: expected identifier for declarator
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
