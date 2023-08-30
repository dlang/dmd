/*
TEST_OUTPUT:
---
fail_compilation/noreturn_bin.d(33): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(47):        called from here: `a()`
fail_compilation/noreturn_bin.d(34): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(48):        called from here: `b()`
fail_compilation/noreturn_bin.d(35): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(49):        called from here: `c()`
fail_compilation/noreturn_bin.d(36): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(50):        called from here: `d()`
fail_compilation/noreturn_bin.d(37): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(51):        called from here: `e()`
fail_compilation/noreturn_bin.d(38): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(52):        called from here: `f()`
fail_compilation/noreturn_bin.d(39): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(53):        called from here: `g()`
fail_compilation/noreturn_bin.d(40): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(54):        called from here: `h()`
fail_compilation/noreturn_bin.d(41): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(55):        called from here: `i()`
fail_compilation/noreturn_bin.d(42): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(56):        called from here: `j()`
fail_compilation/noreturn_bin.d(43): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(57):        called from here: `k()`
fail_compilation/noreturn_bin.d(44): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(58):        called from here: `l()`
fail_compilation/noreturn_bin.d(45): Error: Accessed expression of type `noreturn`
fail_compilation/noreturn_bin.d(59):        called from here: `m()`
---
*/

int a() { noreturn v; return v + 1; };
int b() { noreturn v; return v - 1; };
int c() { noreturn v; return v * 1; };
int d() { noreturn v; return v / 1; };
int e() { noreturn v; return v % 1; };
int f() { noreturn v; return v ^^ 1; };
int g() { noreturn v; return v & 1; };
int h() { noreturn v; return v | 1; };
int i() { noreturn v; return v ^ 1; };
int j() { noreturn v; return 1 == v; };
int k() { noreturn v; return 1 < v; };
int l() { noreturn v; return 1 is v; };
int m() { noreturn v; return 1 && v; };

enum ea = a();
enum eb = b();
enum ec = c();
enum ed = d();
enum ee = e();
enum ef = f();
enum eg = g();
enum eh = h();
enum ei = i();
enum ej = j();
enum ek = k();
enum el = l();
enum em = m();
