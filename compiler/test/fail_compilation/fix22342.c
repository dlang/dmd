/* TEST_OUTPUT:
---
fail_compilation/fix22342.c(103): Error: named parameter required before `...`
---
 */

#line 100

// https://issues.dlang.org/show_bug.cgi?id=22342

void func(...);
