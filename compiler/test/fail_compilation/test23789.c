/* TEST_OUTPUT:
---
fail_compilation/test23789.c(101): Error: __decspec(align(3)) must be an integer positive power of 2 and be <= 8,192
fail_compilation/test23789.c(103): Error: alignment value expected, not `"a"`
---
 */

// https://issues.dlang.org/show_bug.cgi?id=23789

#line 100

struct __declspec(align(3)) S { int a; };

struct __declspec(align("a")) T { int a; };
