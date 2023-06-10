// REQUIRED_ARGS: -de
/* TEST_OUTPUT:
---
fail_compilation/b19717a.d(10): Error: forward reference to template `a`
---
*/
module b19717a;

auto a(int b) {}
auto a(int b = a) {}
