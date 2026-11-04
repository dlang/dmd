// https://github.com/dlang/dmd/issues/24191

/*
DISABLED: freebsd32 openbsd32 linux32 osx32 win32 hurd32
TEST_OUTPUT:
---
fail_compilation/test24191.d(14): Error: vector operation `v += cast(__vector(int[4]))2` is not supported at compile time
fail_compilation/test24191.d(16):        called from here: `f()`
---
*/

import core.simd;

int f() { int4 v = 1; v += 2; return v[0]; }

enum a = f();
