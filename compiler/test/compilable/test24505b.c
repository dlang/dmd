// https://issues.dlang.org/show_bug.cgi?id=24505 - reversed order

// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
#defines($n$): function-like macro `test24505b.stat(__MP$n$, __MP$n$)(__MP$n$ x, __MP$n$ y)` conflicts with struct `test24505b.stat` at compilable/test24505b.c(15), not translating to a D template
---
*/

void __stat(int x, int y);
#define stat(x, y) __stat(x, y)

struct stat { int x; };
