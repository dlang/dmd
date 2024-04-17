// https://issues.dlang.org/show_bug.cgi?id=24505

// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
#defines($n$): function-like macro `test24505a.stat(__MP$n$, __MP$n$)(__MP$n$ x, __MP$n$ y)` conflicts with struct `test24505a.stat` at compilable/test24505a.c(12), not translating to a D template
---
*/

struct stat { int x; };

void __stat(int x, int y);
#define stat(x, y) __stat(x, y)
