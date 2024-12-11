// REQUIRED_ARGS: -de
/* TEST_OUTPUT:
---
fail_compilation/b19717a.d(24): Error: forward reference to template `a`
auto a(int b = a) {}
               ^
fail_compilation/b19717a.d(24): Error: forward reference to template `a`
auto a(int b = a) {}
               ^
fail_compilation/b19717a.d(24): Error: none of the overloads of `a` are callable using argument types `()`
auto a(int b = a) {}
               ^
fail_compilation/b19717a.d(23):        Candidates are: `b19717a.a(int b)`
auto a(int b) {}
     ^
fail_compilation/b19717a.d(24):                        `b19717a.a(int b = a)`
auto a(int b = a) {}
     ^
---
*/
module b19717a;

auto a(int b) {}
auto a(int b = a) {}
