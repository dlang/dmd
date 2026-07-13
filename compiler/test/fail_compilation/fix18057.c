/* TEST_OUTPUT:
---
fail_compilation/fix18057.c(105): Error: redefinition of `x` with different type: `int` vs `char`
---
 */

// https://issues.dlang.org/show_bug.cgi?id=22316

#line 100

int x;
extern int x;
typedef int INT;
extern INT x;
extern char x;
