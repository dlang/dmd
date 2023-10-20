/* TEST_OUTPUT:
---
fail_compilation/test23056.c(101): Error: function `test23056.test` no return value from function
fail_compilation/test23056.c(102):        called from here: `test()`
fail_compilation/test23056.c(102):        while evaluating: `static assert(test())`
---
*/

/* https://issues.dlang.org/show_bug.cgi?id=23056
 */

#line 100

int test(void){}
_Static_assert(test(), "");
