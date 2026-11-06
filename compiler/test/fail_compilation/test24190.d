// https://github.com/dlang/dmd/issues/24190

/*
TEST_OUTPUT:
---
fail_compilation/test24190.d(15): Error: shift assign by 33 is outside the range `0..31`
fail_compilation/test24190.d(19):        called from here: `f()`
fail_compilation/test24190.d(16): Error: shift assign by 32 is outside the range `0..31`
fail_compilation/test24190.d(20):        called from here: `g()`
fail_compilation/test24190.d(17): Error: shift assign by -1 is outside the range `0..31`
fail_compilation/test24190.d(21):        called from here: `h()`
---
*/

int f() { int x = 1; int n = 33; x <<= n; return x; }
int g() { int x = -1; int n = 32; x >>>= n; return x; }
int h() { int x = -8; int n = -1; x >>= n; return x; }

enum a = f();
enum b = g();
enum c = h();
