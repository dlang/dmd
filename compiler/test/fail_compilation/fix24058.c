/* TEST_OUTPUT:
---
fail_compilation/fix24058.c(108): Error: redefinition of `q` with different type: `const(int)*` vs `const(short)*`
fail_compilation/fix24058.c(114): Error: redefinition of `s` with different type: `struct S1` vs `struct S2`
---
 */

// https://github.com/dlang/dmd/issues/24058

#line 100

extern const int *p;
const int *p;

const int x;
extern const int x;

extern const int *q;
const short *q;

// https://github.com/dlang/dmd/issues/24438

struct S1 { int a; };
extern struct S1 s;
extern struct S2 s;
