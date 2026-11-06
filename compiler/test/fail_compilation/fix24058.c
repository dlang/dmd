/* TEST_OUTPUT:
---
fail_compilation/fix24058.c(108): Error: redefinition of `q` with different type: `const(int)*` vs `const(short)*`
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
