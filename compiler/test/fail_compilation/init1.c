/* TEST_OUTPUT:
---
fail_compilation/init1.c(100): Error: array initializer has 4 elements, but array length is 3
fail_compilation/init1.c(103): Error: `.identifier` expected for C struct field initializer `{[0]=3}`
fail_compilation/init1.c(104): Error: only 1 designator currently allowed for C struct field initializer `{.a[0]=3}`
fail_compilation/init1.c(106): Error: `[ constant-expression ]` expected for C array element initializer `{.a=3}`
fail_compilation/init1.c(107): Error: only 1 designator currently allowed for C array element initializer `{[0][1]=3}`
fail_compilation/init1.c(110): Error: overlapping initialization for field `a` and `b`
fail_compilation/init1.c(113): Error: struct `init1.S6` unknown size
---
 */

#line 100
int a1[3] = { 1,2,3,4 };

typedef struct S1 { int a; } S1;
S1 s1 = { [0] = 3 };
S1 s2 = { .a[0] = 3 };

int a3[2] = { .a = 3 };
int a4[2] = { [0][1] = 3 };

union U { int a, b; };
union U u = { 1, 2 };

struct S6;
struct S6 a6[2] = { 1, 2 };
