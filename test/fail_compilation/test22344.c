/* TEST_OUTPUT:
---
fail_compilation/test22344.c(104): Error: function `test22344.func` redeclaration with different type
---
 */

// https://issues.dlang.org/show_bug.cgi?id=22344

#line 100

int func(double a);

int func(int b)
{
    return 0;
}
